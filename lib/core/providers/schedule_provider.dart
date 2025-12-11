import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';
import '../models/deployment_model.dart';
import '../services/schedule_service.dart';
import '../services/deployment_service.dart';
import '../services/logging_service.dart';
import 'auth_provider.dart';

class ScheduleState {
  final List<ScheduleModel> schedules;
  final bool isLoading;
  final String? error;
  final String? filterStatus; // null, 'scheduled', 'active', 'completed'

  const ScheduleState({
    this.schedules = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus,
  });

  ScheduleState copyWith({
    List<ScheduleModel>? schedules,
    bool? isLoading,
    String? error,
    String? filterStatus,
    bool clearFilter = false,
  }) {
    return ScheduleState(
      schedules: schedules ?? this.schedules,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  List<ScheduleModel> get filteredSchedules {
    if (filterStatus == null) return schedules;
    return schedules.where((s) => s.status == filterStatus).toList();
  }
}

class ScheduleNotifier extends Notifier<ScheduleState> {
  @override
  ScheduleState build() => const ScheduleState();

  Future<void> loadSchedules() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final authState = ref.read(authProvider);
      final currentUser = authState.userProfile;

      if (currentUser != null) {
        if (currentUser.isAdmin) {
          await scheduleService.updateAllScheduleStatusesByTime(currentUser.id);
          final schedules = await scheduleService.getSchedulesByOwner(currentUser.id);
          schedules.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
          state = state.copyWith(schedules: schedules, isLoading: false);
        } else {
          await scheduleService.updateAllScheduleStatusesByTime(currentUser.createdBy ?? currentUser.id);
          List<String> assignedBotIds = [];
          try {
            final botsSnapshot = await FirebaseFirestore.instance
                .collection('bots')
                .where('assigned_to', isEqualTo: currentUser.id)
                .get();
            assignedBotIds = botsSnapshot.docs.map((d) => d.id).toList();
          } catch (_) {}

          if (assignedBotIds.isEmpty) {
            state = state.copyWith(schedules: [], isLoading: false);
            return;
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> scheduleDocs = [];
          for (var i = 0; i < assignedBotIds.length; i += 10) {
            final chunk = assignedBotIds.sublist(
              i,
              i + 10 > assignedBotIds.length ? assignedBotIds.length : i + 10,
            );
            try {
              final snap = await FirebaseFirestore.instance
                  .collection('schedules')
                  .where('bot_id', whereIn: chunk)
                  .get();
              scheduleDocs.addAll(snap.docs);
            } catch (_) {}
          }

          final schedules = scheduleDocs
              .map((doc) => ScheduleModel.fromMap(doc.data(), doc.id))
              .toList();
          schedules.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
          state = state.copyWith(schedules: schedules, isLoading: false);
        }
      } else {
        state = state.copyWith(schedules: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setFilter(String? status) {
    if (status == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterStatus: status);
    }
  }

  Future<void> createSchedule(ScheduleModel schedule) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final deploymentService = ref.read(deploymentServiceProvider);
      final realtimeDb = FirebaseDatabase.instance.ref();

      // 1) Battery validation from RTDB before allowing schedule
      try {
        final botSnap = await realtimeDb.child('bots/${schedule.botId}').get();
        if (botSnap.exists && botSnap.value is Map) {
          final data = Map<String, dynamic>.from(botSnap.value as Map);
          final battery = (data['battery_level'] ?? data['battery'] ?? data['battery_pct']) as num?;
          if (battery != null && battery.toDouble() <= 15.0) {
            throw Exception('This bot\'s battery is ${battery.toDouble().toStringAsFixed(0)}%. Please charge above 15% before scheduling.');
          }
        }
      } catch (_) {
        // If battery unreadable, let it pass; device might not publish yet
      }

      // 2) Check if bot already has active or scheduled deployment
      final hasActiveDeployment = await deploymentService.hasBotActiveOrScheduledDeployment(schedule.botId);
      if (hasActiveDeployment) {
        throw Exception('This bot is already scheduled or actively deployed. Please choose another bot or wait for the current deployment to complete.');
      }

      // 3) Create schedule first (Firestore)
      final scheduleId = await scheduleService.create(schedule);
      
      // Create deployment (Firestore) and capture ID for history
      final deployment = DeploymentModel(
        id: '',
        scheduleId: scheduleId,
        scheduleName: schedule.name,
        botId: schedule.botId,
        botName: schedule.botName ?? schedule.botId,
        riverId: schedule.riverId,
        riverName: schedule.riverName ?? schedule.riverId,
        ownerAdminId: schedule.ownerAdminId,
        scheduledStartTime: schedule.scheduledDate,
        scheduledEndTime: schedule.scheduledEndDate ?? schedule.scheduledDate.add(const Duration(hours: 2)),
        status: 'scheduled',
        operationLat: schedule.operationArea.center.latitude,
        operationLng: schedule.operationArea.center.longitude,
        operationRadius: schedule.operationArea.radiusInMeters,
        operationLocation: schedule.operationArea.locationName,
        notes: schedule.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final firestoreDeploymentId = await deploymentService.create(deployment);

      // Link the Firestore deployment back to the schedule for traceability
      try {
        await scheduleService.update(scheduleId, {
          'deployment_id': firestoreDeploymentId,
        });
      } catch (_) {
        // Non-fatal: continue even if this linking fails
      }

      // Update Realtime Database with bot status and deployment metadata
      // IMPORTANT: Use botId as the RTDB deployment node ID to align with Google Apps Script
      // RTDB writes should be best-effort and must not block UX, so run them fire-and-forget.
      () async {
        try {
          final rtdbDeploymentId = schedule.botId;
          final scheduledStartMs = schedule.scheduledDate.millisecondsSinceEpoch;
          final scheduledEndMs = (schedule.scheduledEndDate ?? schedule.scheduledDate.add(const Duration(hours: 2))).millisecondsSinceEpoch;

          // Check if bot node exists in RTDB
          final botSnapshot = await realtimeDb.child('bots/${schedule.botId}').get();
          
          if (botSnapshot.exists) {
            // Bot exists - UPDATE and RESET values for new deployment
            await realtimeDb.child('bots/${schedule.botId}').update({
              // Schedule metadata
              'schedule_name': schedule.name,
              'river_id': schedule.riverId,
              'river_name': schedule.riverName ?? schedule.riverId,
              'operation_lat': schedule.operationArea.center.latitude,
              'operation_lng': schedule.operationArea.center.longitude,
              'operation_radius_m': schedule.operationArea.radiusInMeters,
              'operation_location': schedule.operationArea.locationName,
              'scheduled_start_time': scheduledStartMs,
              'scheduled_end_time': scheduledEndMs,
              
              // Reset trash collection data to zero for new deployment
              'current_load': 0.0,
              'max_load': 10.0,
              'trash_collection': null, // Clear trash items array
              'trash_by_type': null, // Clear trash type counts
              
              // Reset water quality parameters
              'ph_level': null,
              'turbidity': null,
              'temp': null,
              'temperature': null,
              'dissolved_oxygen': null,
              
              // Note: battery_level, lat, lng are NOT reset - preserve existing values from bot
              'last_updated': ServerValue.timestamp,
            });
          } else {
            // Bot doesn't exist in RTDB - CREATE with all fields initialized
            await realtimeDb.child('bots/${schedule.botId}').update({
              // Location (initialize with operation center)
              'lat': schedule.operationArea.center.latitude,
              'lng': schedule.operationArea.center.longitude,
              
              // Power (initialize at 100%)
              'battery': 100,
              'battery_level': 100,
              
              // Water Quality Sensors (null until first reading)
              'ph_level': null,
              'temp': null,
              'temperature': null,
              'turbidity': null,
              'dissolved_oxygen': null,
              
              // Trash Collection (start at zero)
              'current_load': 0.0,
              'max_load': 10.0,
              'trash_collection': null, // Will be an array of items
              'trash_by_type': null, // Will be a map of type counts
              
              // Schedule metadata
              'schedule_name': schedule.name,
              'river_id': schedule.riverId,
              'river_name': schedule.riverName ?? schedule.riverId,
              'operation_lat': schedule.operationArea.center.latitude,
              'operation_lng': schedule.operationArea.center.longitude,
              'operation_radius_m': schedule.operationArea.radiusInMeters,
              'operation_location': schedule.operationArea.locationName,
              'scheduled_start_time': scheduledStartMs,
              'scheduled_end_time': scheduledEndMs,
              
              // Metadata
              'last_updated': ServerValue.timestamp,
            });
          }

          // Create/update the deployment node in RTDB with all fields initialized
          await realtimeDb.child('deployments/$rtdbDeploymentId').set({
            // Firestore reference
            'deployment_id': firestoreDeploymentId,
            'schedule_id': scheduleId,
            'schedule_name': schedule.name,
            
            // Bot info
            'bot_id': schedule.botId,
            'bot_name': schedule.botName ?? schedule.botId,
            'owner_admin_id': schedule.ownerAdminId,
            
            // River info
            'river_id': schedule.riverId,
            'river_name': schedule.riverName ?? schedule.riverId,
            
            // Status
            'status': 'scheduled',
            
            // Schedule times
            'scheduled_start_time': scheduledStartMs,
            'scheduled_end_time': scheduledEndMs,
            'actual_start_time': null,
            'actual_end_time': null,
            
            // Operation area
            'operation_lat': schedule.operationArea.center.latitude,
            'operation_lng': schedule.operationArea.center.longitude,
            'operation_radius_m': schedule.operationArea.radiusInMeters,
            'operation_location': schedule.operationArea.locationName,
            
            // Progress metrics (initialized to zero)
            'trash_collected': 0.0,
            'area_covered_percentage': 0.0,
            'distance_traveled': 0.0,
            
            // Water quality averages (null until deployment completes)
            'avg_ph': null,
            'avg_ph_level': null,
            'avg_temp': null,
            'avg_temperature': null,
            'avg_turbidity': null,
            'avg_dissolved_oxygen': null,
            
            // Trash breakdown (will be populated during deployment)
            'trash_by_type': null,
            'total_trash_items': 0,
            
            // Timestamps
            'created_at': ServerValue.timestamp,
            'updated_at': ServerValue.timestamp,
          });
        } catch (e) {
          // Do not rethrow — allow UI to proceed. Logging here is sufficient.
          // print('RTDB sync error: $e');
        }
      }();

      // Log schedule created for activity logs
      try {
        final authState = ref.read(authProvider);
        final creator = authState.userProfile;
        if (creator != null) {
          await LoggingService().logScheduleCreated(
            userId: creator.id,
            userName: creator.fullName,
            scheduleId: scheduleId,
            scheduleName: schedule.name,
            botId: schedule.botId,
            botName: schedule.botName ?? schedule.botId,
            scheduledTime: schedule.scheduledDate,
          );
        }
      } catch (_) {}

      // Just fetch schedules without updating all statuses
      final schedules = await scheduleService.getSchedulesByOwner(schedule.ownerAdminId);
      schedules.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      state = state.copyWith(schedules: schedules, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateSchedule(String scheduleId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.update(scheduleId, data);
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> startSchedule(String scheduleId) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.startSchedule(scheduleId);
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> completeSchedule(
    String scheduleId, {
    double? trashCollected,
    double? areaCleanedPercentage,
    String? notes,
  }) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.completeSchedule(
        scheduleId,
        trashCollected: trashCollected,
        areaCleanedPercentage: areaCleanedPercentage,
        notes: notes,
      );
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> cancelSchedule(String scheduleId, {String? reason}) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.cancelSchedule(scheduleId, reason: reason);
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.delete(scheduleId);
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }


  Future<void> recallSchedule(String scheduleId) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.recallSchedule(scheduleId);
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Manually trigger status update for a specific schedule
  Future<void> updateScheduleStatusByTime(String scheduleId, ScheduleModel schedule) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.updateScheduleStatusByTime(scheduleId, schedule);
      await loadSchedules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Manually trigger status update for all schedules
  Future<void> updateAllScheduleStatuses() async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final authState = ref.read(authProvider);
      final currentUser = authState.userProfile;
      
      if (currentUser != null && currentUser.isAdmin) {
        await scheduleService.updateAllScheduleStatusesByTime(currentUser.id);
        await loadSchedules();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Providers
final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

final deploymentServiceProvider = Provider<DeploymentService>((ref) {
  return DeploymentService();
});

final scheduleProvider = NotifierProvider<ScheduleNotifier, ScheduleState>(() {
  return ScheduleNotifier();
});

// Real-time stream provider for schedules
final schedulesStreamProvider = StreamProvider.autoDispose<List<ScheduleModel>>((ref) async* {
  final scheduleService = ref.watch(scheduleServiceProvider);
  final authState = ref.watch(authProvider);
  final currentUser = authState.userProfile;

  if (currentUser == null) {
    yield [];
    return;
  }

  if (currentUser.isAdmin) {
    yield* scheduleService.watchSchedulesByOwner(currentUser.id);
    return;
  }

  List<String> assignedBotIds = [];
  try {
    final botsSnapshot = await FirebaseFirestore.instance
        .collection('bots')
        .where('assigned_to', isEqualTo: currentUser.id)
        .get();
    assignedBotIds = botsSnapshot.docs.map((d) => d.id).toList();
  } catch (_) {}

  if (assignedBotIds.isEmpty) {
    yield [];
    return;
  }

  final controller = StreamController<List<ScheduleModel>>();
  final subscriptions = <StreamSubscription>[];

  for (var i = 0; i < assignedBotIds.length; i += 10) {
    final chunk = assignedBotIds.sublist(
      i,
      i + 10 > assignedBotIds.length ? assignedBotIds.length : i + 10,
    );
    final sub = FirebaseFirestore.instance
        .collection('schedules')
        .where('bot_id', whereIn: chunk)
        .snapshots()
        .listen((snapshot) {
      final schedules = snapshot.docs
          .map((doc) => ScheduleModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
      controller.add(schedules);
    });
    subscriptions.add(sub);
  }

  ref.onDispose(() async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    await controller.close();
  });

  await for (final schedules in controller.stream) {
    yield schedules;
  }
});
