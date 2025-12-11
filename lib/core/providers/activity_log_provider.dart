import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_log_model.dart';
import 'auth_provider.dart';

/// Provider for recent activity logs (for dashboard)
/// Admins see all recent activities, Field Operators see only their own
final recentActivityLogsProvider = StreamProvider.autoDispose<List<ActivityLogModel>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.currentUser;
  final isAdmin = authState.userProfile?.isAdmin ?? false;

  if (currentUser == null) {
    return Stream.value([]);
  }

  final firestore = FirebaseFirestore.instance;

  if (isAdmin) {
    // Admin: Show all recent activity logs (last 20)
    return firestore
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return ActivityLogModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          print('Error parsing activity log: $e');
          return null;
        }
      }).whereType<ActivityLogModel>().toList();
    });
  } else {
    // Field Operator: Show only their own activity logs (last 20)
    return firestore
        .collection('activity_logs')
        .where('user_id', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return ActivityLogModel.fromMap(doc.data(), doc.id);
        } catch (e) {
          print('Error parsing activity log: $e');
          return null;
        }
      }).whereType<ActivityLogModel>().toList();
    });
  }
});

/// Provider for paginated activity logs (for activity logs page)
/// This can be extended in the future if needed for pagination
class ActivityLogsNotifier extends AsyncNotifier<List<ActivityLogModel>> {
  @override
  Future<List<ActivityLogModel>> build() async {
    return await _loadLogs();
  }
  
  Future<List<ActivityLogModel>> _loadLogs({
    ActivityLogCategory? categoryFilter,
    String? searchQuery,
    String timeRange = 'all',
  }) async {
    try {
      final authState = ref.read(authProvider);
      final currentUser = authState.currentUser;
      final isAdmin = authState.userProfile?.isAdmin ?? false;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Time range calculation
      DateTime? start;
      final now = DateTime.now();
      switch (timeRange) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case '7d':
          start = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          start = now.subtract(const Duration(days: 30));
          break;
        case 'all':
        default:
          start = null;
      }

      final firestore = FirebaseFirestore.instance;
      List<ActivityLogModel> logs = [];

      if (isAdmin) {
        // Admin: Get all logs with optional time filter
        Query query = firestore
            .collection('activity_logs')
            .orderBy('timestamp', descending: true)
            .limit(200);

        if (start != null) {
          query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
        }

        final snapshot = await query.get();
        logs = snapshot.docs.map((doc) {
          try {
            return ActivityLogModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing log: $e');
            return null;
          }
        }).whereType<ActivityLogModel>().toList();

        // Apply category filter client-side
        if (categoryFilter != null) {
          logs = logs.where((l) => l.category == categoryFilter).toList();
        }
      } else {
        // Field Operator: Get only their logs
        Query query = firestore
            .collection('activity_logs')
            .where('user_id', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .limit(100);

        if (categoryFilter != null) {
          query = query.where('category', isEqualTo: categoryFilter.name);
        }

        if (start != null) {
          query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
        }

        final snapshot = await query.get();
        logs = snapshot.docs.map((doc) {
          try {
            return ActivityLogModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing log: $e');
            return null;
          }
        }).whereType<ActivityLogModel>().toList();
      }

      // Apply search filter locally if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        logs = logs.where((log) {
          return log.title.toLowerCase().contains(query) ||
                 log.description.toLowerCase().contains(query) ||
                 (log.userName?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      return logs;
    } catch (e, stack) {
      print('Error loading activity logs: $e');
      rethrow;
    }
  }

  Future<void> loadLogs({
    ActivityLogCategory? categoryFilter,
    String? searchQuery,
    String timeRange = 'all',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadLogs(
      categoryFilter: categoryFilter,
      searchQuery: searchQuery,
      timeRange: timeRange,
    ));
  }
}

final activityLogsProvider = AsyncNotifierProvider<ActivityLogsNotifier, List<ActivityLogModel>>(() {
  return ActivityLogsNotifier();
});
