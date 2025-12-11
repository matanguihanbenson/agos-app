import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/models/active_deployment_info.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/providers/auth_provider.dart';

class DashboardState {
  final List<ActiveDeploymentInfo> activeDeployments;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.activeDeployments = const [],
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    List<ActiveDeploymentInfo>? activeDeployments,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      activeDeployments: activeDeployments ?? this.activeDeployments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardState();

  // No manual loading needed - use stream provider instead
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});

// Stream provider for active deployments with real-time RTDB updates
final activeDeploymentsStreamProvider = StreamProvider.autoDispose<List<ActiveDeploymentInfo>>((ref) async* {
  final authState = ref.watch(authProvider);
  final currentUser = authState.userProfile;

  if (currentUser == null) {
    yield [];
    return;
  }

  final controller = StreamController<List<ActiveDeploymentInfo>>();
  StreamSubscription? schedulesSubscription;
  final subscriptions = <StreamSubscription>[];
  Map<String, ScheduleModel> currentSchedulesMap = {};
  Timer? pollTimer;

  Future<void> processSnapshot(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    currentSchedulesMap.clear();
    for (final scheduleDoc in docs) {
      try {
        final schedule = ScheduleModel.fromMap(scheduleDoc.data(), scheduleDoc.id);
        currentSchedulesMap[schedule.botId] = schedule;
      } catch (_) {}
    }
    if (currentSchedulesMap.isEmpty) {
      controller.add([]);
      pollTimer?.cancel();
    } else {
      final deployments = await _fetchActiveDeploymentsData(currentSchedulesMap);
      controller.add(deployments);
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (currentSchedulesMap.isNotEmpty) {
          final updatedDeployments = await _fetchActiveDeploymentsData(currentSchedulesMap);
          controller.add(updatedDeployments);
        }
      });
    }
  }

  if (currentUser.isAdmin) {
    List<String> userIdsToMonitor = [currentUser.id];
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('created_by', isEqualTo: currentUser.id)
          .get();
      final operatorIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      userIdsToMonitor.addAll(operatorIds);
    } catch (e) {
      print('Error fetching created users: $e');
    }

    final schedulesStream = FirebaseFirestore.instance
        .collection('schedules')
        .where('status', isEqualTo: 'active')
        .where('owner_admin_id', whereIn: userIdsToMonitor.isEmpty ? ['dummy'] : userIdsToMonitor)
        .snapshots();
    schedulesSubscription = schedulesStream.listen((snapshot) async {
      await processSnapshot(snapshot.docs);
    });
    subscriptions.add(schedulesSubscription);
  } else {
    List<String> assignedBotIds = [];
    try {
      final botsQuery = await FirebaseFirestore.instance
          .collection('bots')
          .where('assigned_to', isEqualTo: currentUser.id)
          .get();
      assignedBotIds = botsQuery.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('ERROR fetching assigned bots: $e');
    }

    if (assignedBotIds.isEmpty) {
      yield [];
      return;
    }

    final latestChunkDocs = <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    int chunkIndex = 0;
    for (var i = 0; i < assignedBotIds.length; i += 10) {
      final localIndex = chunkIndex;
      final chunk = assignedBotIds.sublist(
        i,
        i + 10 > assignedBotIds.length ? assignedBotIds.length : i + 10,
      );
      final sub = FirebaseFirestore.instance
          .collection('schedules')
          .where('status', isEqualTo: 'active')
          .where('bot_id', whereIn: chunk)
          .snapshots()
          .listen((snapshot) async {
        latestChunkDocs[localIndex] = snapshot.docs;
        final combinedDocs = latestChunkDocs.values.expand((d) => d).toList();
        await processSnapshot(combinedDocs);
          });
      subscriptions.add(sub);
      chunkIndex++;
    }
    
  }

  

  ref.onDispose(() async {
    pollTimer?.cancel();
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    await controller.close();
  });

  // Yield from the controller stream
  await for (final deployments in controller.stream) {
    yield deployments;
  }
});

const Duration _requestTimeout = Duration(seconds: 5);

Future<double> _getRiverTotalToday(String riverId) async {
  try {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final deploymentsSnapshot = await FirebaseFirestore.instance
        .collection('deployments')
        .where('river_id', isEqualTo: riverId)
        .get()
        .timeout(_requestTimeout);

    double totalTrash = 0.0;
    
    for (final doc in deploymentsSnapshot.docs) {
      final data = doc.data();

      // Determine the effective completion date for "today" calculations.
      // Prefer actual_end_time if available, otherwise fall back to created_at.
      DateTime? completedAt;
      final createdAt = data['created_at'];
      final actualEnd = data['actual_end_time'];

      if (actualEnd is Timestamp) {
        completedAt = actualEnd.toDate();
      } else if (createdAt is Timestamp) {
        completedAt = createdAt.toDate();
      }

      // Skip deployments that are not from today
      if (completedAt == null ||
          completedAt.isBefore(startOfDay) ||
          !completedAt.isBefore(endOfDay)) {
        continue;
      }

      if (data['trash_collection'] != null) {
        final trashCollection = data['trash_collection'] as Map<String, dynamic>;
        final weight = (trashCollection['total_weight'] as num?)?.toDouble() ?? 0.0;
        totalTrash += weight;
      }
    }
    
    return totalTrash;
  } catch (e) {
    print('Error calculating river total today: $e');
    return 0.0;
  }
}

// Helper function to fetch deployment data from RTDB
Future<List<ActiveDeploymentInfo>> _fetchActiveDeploymentsData(Map<String, ScheduleModel> schedulesMap) async {
  final List<ActiveDeploymentInfo> activeDeployments = [];

  for (final entry in schedulesMap.entries) {
    final botId = entry.key;
    final schedule = entry.value;

    try {
      // Get real-time bot data from RTDB
      final botSnapshot = await FirebaseDatabase.instance
          .ref('bots/$botId')
          .get()
          .timeout(_requestTimeout);

      if (botSnapshot.exists) {
        final botData = Map<String, dynamic>.from(botSnapshot.value as Map);
        
        // Derive effective status: if active=true, prefer 'active'
        final bool isActive = botData['active'] == true;
        String? derivedStatus = botData['status'] as String?;
        if (isActive && (derivedStatus == null || derivedStatus.toLowerCase() == 'idle' || derivedStatus.toLowerCase() == 'scheduled')) {
          derivedStatus = 'active';
        }

        // Get current_load, default to 0.0 if not set or null
        final currentLoad = (botData['current_load'] as num?)?.toDouble() ?? 0.0;

        // Calculate river's total trash collected today
        final riverTotalToday = await _getRiverTotalToday(schedule.riverId);

        activeDeployments.add(ActiveDeploymentInfo(
          scheduleId: schedule.id,
          scheduleName: schedule.name,
          botId: schedule.botId,
          botName: schedule.botName ?? 'Unknown Bot',
          riverId: schedule.riverId,
          riverName: schedule.riverName ?? 'Unknown River',
          // Real-time data from RTDB
          currentLat: (botData['lat'] as num?)?.toDouble(),
          currentLng: (botData['lng'] as num?)?.toDouble(),
          battery: (botData['battery_level'] as num?)?.toInt() ?? (botData['battery'] as num?)?.toInt(),
          status: derivedStatus,
          solarCharging: botData['solar_charging'] == true,
          // Use current_load consistently as trash collected for the live card
          trashCollected: currentLoad,
          scheduledStartTime: schedule.scheduledDate,
          operationLocation: schedule.operationArea.locationName,
          // Water quality sensor data
          temperature: (botData['temp'] as num?)?.toDouble(),
          phLevel: (botData['ph_level'] as num?)?.toDouble(),
          turbidity: (botData['turbidity'] as num?)?.toDouble(),
          // Trash load metrics - default to 0.0 if not set
          currentLoad: currentLoad,
          maxLoad: (botData['max_load'] as num?)?.toDouble() ?? 10.0,
          // River's total today (all bots on this river)
          riverTotalToday: riverTotalToday,
        ));
      } else {
        // Bot not found in RTDB, add with schedule data only
        // Calculate river's total trash collected today
        final riverTotalToday = await _getRiverTotalToday(schedule.riverId);
        
        activeDeployments.add(ActiveDeploymentInfo(
          scheduleId: schedule.id,
          scheduleName: schedule.name,
          botId: schedule.botId,
          botName: schedule.botName ?? 'Unknown Bot',
          riverId: schedule.riverId,
          riverName: schedule.riverName ?? 'Unknown River',
          scheduledStartTime: schedule.scheduledDate,
          operationLocation: schedule.operationArea.locationName,
          currentLoad: 0.0, // Default to 0 when bot not in RTDB
          maxLoad: 10.0,
          riverTotalToday: riverTotalToday,
        ));
      }
    } catch (e) {
      print('Error processing bot $botId: $e');
      // Continue processing other bots
    }
  }

  return activeDeployments;
}

// Dashboard stats model
class DashboardStats {
  final int totalBots;
  final int activeBots;
  final double totalTrashToday;
  final int riversMonitoredToday;
  final int uniqueRiversToday; // New field for unique rivers
  final Map<String, int> trashByType; // New field for trash breakdown

  const DashboardStats({
    required this.totalBots,
    required this.activeBots,
    required this.totalTrashToday,
    required this.riversMonitoredToday,
    required this.uniqueRiversToday,
    this.trashByType = const {},
  });
}

// Comprehensive stats provider with new logic for admins and field operators
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final authState = ref.watch(authProvider);
  final currentUser = authState.userProfile;

  if (currentUser == null) {
    return const DashboardStats(
      totalBots: 0,
      activeBots: 0,
      totalTrashToday: 0,
      riversMonitoredToday: 0,
      uniqueRiversToday: 0,
    );
  }

  try {
    final isAdmin = currentUser.isAdmin;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    print('DEBUG: Dashboard stats for user ${currentUser.id}, isAdmin: $isAdmin');

    // === TOTAL BOTS ===
    int totalBots = 0;
    try {
      if (isAdmin) {
        // Admin: All bots they own
        final totalBotsQuery = await FirebaseFirestore.instance
            .collection('bots')
            .where('owner_admin_id', isEqualTo: currentUser.id)
            .get()
            .timeout(_requestTimeout);
        totalBots = totalBotsQuery.docs.length;
        print('DEBUG: Admin owns $totalBots bots');
      } else {
        // Field Operator: Only bots assigned to them
        final assignedBotsQuery = await FirebaseFirestore.instance
            .collection('bots')
            .where('assigned_to', isEqualTo: currentUser.id)
            .get()
            .timeout(_requestTimeout);
        totalBots = assignedBotsQuery.docs.length;
        print('DEBUG: Field operator assigned $totalBots bots');
      }
    } catch (e) {
      print('ERROR fetching total bots: $e');
    }

    // === ACTIVE BOTS (from RTDB active:true) ===
    int activeBots = 0;
    List<String> relevantBotIds = [];
    
    try {
      if (isAdmin) {
        // Get all bots owned by admin
        final botsQuery = await FirebaseFirestore.instance
            .collection('bots')
            .where('owner_admin_id', isEqualTo: currentUser.id)
            .get()
            .timeout(_requestTimeout);
        relevantBotIds = botsQuery.docs.map((doc) => doc.id).toList();
      } else {
        // Get bots assigned to field operator
        final botsQuery = await FirebaseFirestore.instance
            .collection('bots')
            .where('assigned_to', isEqualTo: currentUser.id)
            .get()
            .timeout(_requestTimeout);
        relevantBotIds = botsQuery.docs.map((doc) => doc.id).toList();
      }

      print('DEBUG: Checking ${relevantBotIds.length} bots in RTDB for active status');

      // Check RTDB for active status
      for (final botId in relevantBotIds) {
        try {
          final botSnapshot = await FirebaseDatabase.instance
              .ref('bots/$botId')
              .get()
              .timeout(_requestTimeout);
          
          if (botSnapshot.exists) {
            final botData = Map<String, dynamic>.from(botSnapshot.value as Map);
            final isActive = botData['active'] == true;
            print('DEBUG: Bot $botId active status: $isActive');
            if (isActive) {
              activeBots++;
            }
          }
        } catch (e) {
          print('ERROR checking bot $botId in RTDB: $e');
        }
      }
      print('DEBUG: $activeBots bots are active');
    } catch (e) {
      print('ERROR fetching active bots: $e');
    }

    // === TRASH COLLECTED TODAY (with breakdown by type) ===
    double totalTrashToday = 0.0;
    Map<String, int> trashByType = {};
    final List<String> riverIdsToday = []; // Allow duplicates

    // Get list of user IDs whose deployments we should count
    List<String> userIdsToCount = [currentUser.id];
    
    if (isAdmin) {
      // Admin: also include all field operators they created
      try {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('created_by', isEqualTo: currentUser.id)
            .get()
            .timeout(_requestTimeout);
        
        final operatorIds = usersSnapshot.docs.map((doc) => doc.id).toList();
        userIdsToCount.addAll(operatorIds);
        print('DEBUG: Admin will count deployments from ${userIdsToCount.length} users (admin + ${operatorIds.length} field operators)');
      } catch (e) {
        print('ERROR fetching field operators: $e');
      }
    }

    // Get deployments completed today from Firestore
    try {
      print('DEBUG: Fetching completed deployments today (${startOfDay} to ${endOfDay})');

      List<QueryDocumentSnapshot> allTodayDeployments = [];

      if (isAdmin) {
        try {
          final completedSnap = await FirebaseFirestore.instance
              .collection('deployments')
              .where('owner_admin_id', isEqualTo: currentUser.id)
              .where('status', isEqualTo: 'completed')
              .where('actual_end_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('actual_end_time', isLessThan: Timestamp.fromDate(endOfDay))
              .get()
              .timeout(_requestTimeout);
          allTodayDeployments.addAll(completedSnap.docs);
        } catch (e) {
          print('WARN: Index not ready for admin completed deployments query, falling back: $e');
          final fallback = await FirebaseFirestore.instance
              .collection('deployments')
              .where('owner_admin_id', isEqualTo: currentUser.id)
              .get()
              .timeout(_requestTimeout);
          allTodayDeployments.addAll(fallback.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final statusStr = (data['status'] as String?)?.toLowerCase();
            if (statusStr != 'completed') return false;
            final endVal = data['actual_end_time'];
            DateTime? endTime;
            if (endVal is Timestamp) endTime = endVal.toDate();
            if (endVal is String) {
              try { endTime = DateTime.parse(endVal); } catch (_) {}
            }
            if (endTime == null) return false;
            return !endTime.isBefore(startOfDay) && endTime.isBefore(endOfDay);
          }));
        }
      } else {
        // Field operator: fetch deployments by assigned bots
        List<String> assignedBotIds = [];
        try {
          final botsQuery = await FirebaseFirestore.instance
              .collection('bots')
              .where('assigned_to', isEqualTo: currentUser.id)
              .get()
              .timeout(_requestTimeout);
          assignedBotIds = botsQuery.docs.map((d) => d.id).toList();
        } catch (e) {
          print('ERROR fetching assigned bots: $e');
        }

        for (var i = 0; i < assignedBotIds.length; i += 10) {
          final chunk = assignedBotIds.sublist(
            i,
            i + 10 > assignedBotIds.length ? assignedBotIds.length : i + 10,
          );
          try {
            final snap = await FirebaseFirestore.instance
                .collection('deployments')
                .where('bot_id', whereIn: chunk)
                .where('status', isEqualTo: 'completed')
                .where('actual_end_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .where('actual_end_time', isLessThan: Timestamp.fromDate(endOfDay))
                .get()
                .timeout(_requestTimeout);
            allTodayDeployments.addAll(snap.docs);
          } catch (e) {
            print('WARN: Index not ready for operator deployments query, falling back: $e');
            final fallback = await FirebaseFirestore.instance
                .collection('deployments')
                .where('bot_id', whereIn: chunk)
                .get()
                .timeout(_requestTimeout);
            allTodayDeployments.addAll(fallback.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final statusStr = (data['status'] as String?)?.toLowerCase();
              if (statusStr != 'completed') return false;
              final endVal = data['actual_end_time'];
              DateTime? endTime;
              if (endVal is Timestamp) endTime = endVal.toDate();
              if (endVal is String) {
                try { endTime = DateTime.parse(endVal); } catch (_) {}
              }
              if (endTime == null) return false;
              return !endTime.isBefore(startOfDay) && endTime.isBefore(endOfDay);
            }));
          }
        }
      }

      print('DEBUG: Found ${allTodayDeployments.length} deployments completed today');

      for (final doc in allTodayDeployments) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['river_id'] != null) {
          riverIdsToday.add(data['river_id'] as String);
        }
        if (data['trash_collection'] != null) {
          final trashCollection = data['trash_collection'] as Map<String, dynamic>;
          final weight = (trashCollection['total_weight'] as num?)?.toDouble() ?? 0.0;
          totalTrashToday += weight;
          if (trashCollection['trash_by_type'] != null) {
            final trashTypes = trashCollection['trash_by_type'] as Map<String, dynamic>;
            trashTypes.forEach((type, count) {
              trashByType[type] = (trashByType[type] ?? 0) + (count as int);
            });
          }
        }
      }

      print('DEBUG: Total trash today: $totalTrashToday kg');
      print('DEBUG: Rivers monitored today: ${riverIdsToday.length}');
    } catch (e) {
      print('ERROR fetching completed deployments today: $e');
    }

    // Also check active deployments from RTDB for river tracking
    // (We don't add trash from active deployments anymore, only from completed)
    for (final botId in relevantBotIds) {
      try {
        final botSnapshot = await FirebaseDatabase.instance
            .ref('bots/$botId')
            .get()
            .timeout(_requestTimeout);
        
        if (botSnapshot.exists) {
          final botData = Map<String, dynamic>.from(botSnapshot.value as Map);
          final isActive = botData['active'] == true;
          
          if (isActive) {
            // Get river from current schedule
            final scheduleId = botData['current_schedule_id'] as String?;
            if (scheduleId != null) {
              try {
                final scheduleDoc = await FirebaseFirestore.instance
                    .collection('schedules')
                    .doc(scheduleId)
                    .get()
                    .timeout(_requestTimeout);
                
                if (scheduleDoc.exists) {
                  final scheduleData = scheduleDoc.data();
                  final riverId = scheduleData?['river_id'] as String?;
                  if (riverId != null) {
                    riverIdsToday.add(riverId);
                    print('DEBUG: Active bot $botId monitoring river $riverId');
                  }
                }
              } catch (e) {
                print('ERROR fetching schedule for active bot: $e');
              }
            }
          }
        }
      } catch (e) {
        print('ERROR checking active bot $botId: $e');
      }
    }

    // Count unique rivers
    final uniqueRiversSet = riverIdsToday.toSet();

    print('DEBUG: Unique rivers today: ${uniqueRiversSet.length}');
    print('DEBUG: Final stats - Bots: $totalBots, Active: $activeBots, Trash: $totalTrashToday kg, Rivers: ${riverIdsToday.length}');

    return DashboardStats(
      totalBots: totalBots,
      activeBots: activeBots,
      totalTrashToday: totalTrashToday,
      riversMonitoredToday: riverIdsToday.length, // Total with duplicates
      uniqueRiversToday: uniqueRiversSet.length, // Unique count
      trashByType: trashByType,
    );
  } catch (e) {
    print('ERROR: Fatal error fetching dashboard stats: $e');
    print('Stack trace: ${StackTrace.current}');
    return const DashboardStats(
      totalBots: 0,
      activeBots: 0,
      totalTrashToday: 0,
      riversMonitoredToday: 0,
      uniqueRiversToday: 0,
    );
  }
});
 
