import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';
import '../models/deployment_model.dart';
import 'base_service.dart';
import 'deployment_service.dart';

class ScheduleService extends BaseService<ScheduleModel> {
  @override
  String get collectionName => 'schedules';

  @override
  ScheduleModel fromMap(Map<String, dynamic> map, String id) {
    return ScheduleModel.fromMap(map, id);
  }

  // Get schedules by owner admin (one-time)
  Future<List<ScheduleModel>> getSchedulesByOwner(String ownerAdminId) async {
    return await getByFieldOnce('owner_admin_id', ownerAdminId);
  }

  // Get schedules by owner admin (real-time stream)
  Stream<List<ScheduleModel>> watchSchedulesByOwner(String ownerAdminId) {
    return getByField('owner_admin_id', ownerAdminId);
  }

  // Get schedules by bot
  Future<List<ScheduleModel>> getSchedulesByBot(String botId) async {
    return await getByFieldOnce('bot_id', botId);
  }

  // Get schedules by river
  Future<List<ScheduleModel>> getSchedulesByRiver(String riverId) async {
    return await getByFieldOnce('river_id', riverId);
  }

  // Get schedules by status
  Future<List<ScheduleModel>> getSchedulesByStatus(String status, String ownerAdminId) async {
    try {
      final allSchedules = await getSchedulesByOwner(ownerAdminId);
      return allSchedules.where((schedule) => schedule.status == status).toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_get_by_status',
      );
      return [];
    }
  }

  // Get upcoming schedules
  Future<List<ScheduleModel>> getUpcomingSchedules(String ownerAdminId) async {
    try {
      final allSchedules = await getSchedulesByOwner(ownerAdminId);
      final now = DateTime.now();
      return allSchedules
          .where((schedule) =>
              schedule.scheduledDate.isAfter(now) && schedule.status == 'scheduled')
          .toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_get_upcoming',
      );
      return [];
    }
  }

  // Get active schedules
  Future<List<ScheduleModel>> getActiveSchedules(String ownerAdminId) async {
    return await getSchedulesByStatus('active', ownerAdminId);
  }

  // Start schedule
  Future<void> startSchedule(String scheduleId) async {
    await update(scheduleId, {
      'status': 'active',
      'started_at': DateTime.now(),
    });

    try {
      final schedule = await getById(scheduleId);
      if (schedule == null) return;

      // Find and update deployment for this schedule in Firestore
      final deploymentService = DeploymentService();
      final deployments = await deploymentService.getDeploymentsBySchedule(scheduleId);
      final scheduledDeployment = deployments.where((d) => d.status == 'scheduled').firstOrNull;
      
      String? deploymentId;
      // Update Firestore deployment to active
      if (scheduledDeployment != null) {
        await deploymentService.startDeployment(scheduledDeployment.id);
        deploymentId = scheduledDeployment.id;
      }

      // Update bot status in RTDB with schedule and deployment IDs
      final realtimeDb = FirebaseDatabase.instance.ref();
      await realtimeDb.child('bots/${schedule.botId}').update({
        'status': 'active',
        'active': true,
        'current_schedule_id': scheduleId,
        // IMPORTANT: Use botId for current_deployment_id to align with GAS and telemetry mirroring
        'current_deployment_id': schedule.botId,
        'last_updated': ServerValue.timestamp,
      });
      
      // Create/update deployment node in RTDB using botId as key
      await realtimeDb.child('deployments/${schedule.botId}').set({
        'deployment_id': deploymentId ?? scheduleId,
        'schedule_id': scheduleId,
        'bot_id': schedule.botId,
        'river_id': schedule.riverId,
        'status': 'active',
        'actual_start_time': ServerValue.timestamp,
        'created_at': ServerValue.timestamp,
        'updated_at': ServerValue.timestamp,
      });
      
      await loggingService.logEvent(
        event: 'schedule_started',
        parameters: {
          'schedule_id': scheduleId,
          'bot_id': schedule.botId,
          'deployment_id': deploymentId,
        },
      );
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_start',
      );
    }
  }

  // Complete schedule
  Future<void> completeSchedule(
    String scheduleId, {
    double? trashCollected,
    double? areaCleanedPercentage,
    String? notes,
  }) async {
    final Map<String, dynamic> updates = {
      'status': 'completed',
      'completed_at': DateTime.now(),
    };

    if (trashCollected != null) updates['trash_collected'] = trashCollected;
    if (areaCleanedPercentage != null) {
      updates['area_cleaned_percentage'] = areaCleanedPercentage;
    }
    if (notes != null) updates['notes'] = notes;

    await update(scheduleId, updates);

    // Also complete the corresponding deployment with metrics from RTDB
    String? botIdForRtdbUpdate;
    try {
      final deploymentService = DeploymentService();
      final deployments = await deploymentService.getDeploymentsBySchedule(scheduleId);
      final activeDeployment = deployments.where((d) => d.status == 'active' || d.status == 'scheduled').firstOrNull;
      
      // Snapshot realtime metrics from bots/{botId} and aggregate from deployments/{botId}/readings
      WaterQualitySnapshot? wq;
      TrashCollectionSummary? trashSummary;
      try {
        final schedule = await getById(scheduleId);
        if (schedule != null) {
          botIdForRtdbUpdate = schedule.botId;
          final rtdb = FirebaseDatabase.instance.ref();
          // Aggregate readings for water quality and trash from deployments/{botId}/readings
          try {
            final readingsSnap = await rtdb.child('deployments/${schedule.botId}/readings').get();
            if (readingsSnap.exists && readingsSnap.value is Map) {
              final readings = Map<String, dynamic>.from(readingsSnap.value as Map);
              double sumPh = 0.0;
              double sumTurb = 0.0;
              double sumTemp = 0.0;
              double sumDo = 0.0;
              int count = 0;
              double maxTrash = 0.0;
              for (final entry in readings.entries) {
                final m = Map<String, dynamic>.from(entry.value as Map);
                final ph = (m['ph_level'] as num?)?.toDouble();
                final turb = (m['turbidity'] as num?)?.toDouble();
                final temp = (m['temp'] as num?)?.toDouble();
                final doVal = (m['dissolved_oxygen'] as num?)?.toDouble();
                final trash = (m['trash_collected'] as num?)?.toDouble();
                if (ph != null) { sumPh += ph; count++; }
                if (turb != null) sumTurb += turb ?? 0.0;
                if (temp != null) sumTemp += temp ?? 0.0;
                if (doVal != null) sumDo += doVal ?? 0.0;
                if (trash != null) { maxTrash = trash > maxTrash ? trash : maxTrash; }
              }
              if (count > 0) {
                wq = WaterQualitySnapshot(
                  avgPhLevel: sumPh / count,
                  avgTurbidity: count > 0 ? sumTurb / count : 0.0,
                  avgTemperature: count > 0 ? sumTemp / count : 0.0,
                  avgDissolvedOxygen: count > 0 ? sumDo / count : 0.0,
                  sampleCount: count,
                );
              }
              // Prepare trash summary totalWeight from max of readings
              trashSummary = TrashCollectionSummary(
                trashByType: {},
                totalWeight: maxTrash,
                totalItems: 0,
              );
            }
          } catch (_) {}
          final botSnap = await rtdb.child('bots/${schedule.botId}').get();
          if (botSnap.exists && botSnap.value is Map) {
            final data = Map<String, dynamic>.from(botSnap.value as Map);
            
            // Water Quality Data
            final ph = (data['ph_level'] as num?)?.toDouble();
            final turb = (data['turbidity'] as num?)?.toDouble();
            final temp = (data['temp'] as num?)?.toDouble();
            final dissolvedOxygen = (data['dissolved_oxygen'] as num?)?.toDouble() ?? 0.0;
            final samples = [ph, turb, temp].where((v) => v != null).length;
            if (wq == null && samples > 0) {
              wq = WaterQualitySnapshot(
                avgPhLevel: ph ?? 0.0,
                avgTurbidity: turb ?? 0.0,
                avgTemperature: temp ?? 0.0,
                avgDissolvedOxygen: dissolvedOxygen,
                sampleCount: samples,
              );
            }
            
            // Trash Collection Data
            final currentLoad = (data['current_load'] as num?)?.toDouble() ?? 0.0;
            
            // Build trash_by_type from trash_collection map if available,
            // fall back to legacy trash_by_type map otherwise.
            Map<String, int> trashByType = {};
            int totalItems = 0;
            
            if (data['trash_collection'] is Map) {
              final trashCollectionData = Map<String, dynamic>.from(data['trash_collection'] as Map);
              trashCollectionData.forEach((_, value) {
                if (value is Map) {
                  final item = Map<String, dynamic>.from(value);
                  final type = (item['type'] as String?)?.toLowerCase() ?? 'other';
                  trashByType[type] = (trashByType[type] ?? 0) + 1;
                  totalItems += 1;
                }
              });
            } else if (data['trash_by_type'] is Map) {
              final trashTypesData = Map<String, dynamic>.from(data['trash_by_type'] as Map);
              trashTypesData.forEach((key, value) {
                final count = (value is num) ? value.toInt() : 0;
                if (count > 0) {
                  trashByType[key] = count;
                  totalItems += count;
                }
              });
            }
            
            final derivedWeight = (trashSummary?.totalWeight ?? 0.0) > 0.0 
                ? (trashSummary?.totalWeight ?? 0.0) 
                : currentLoad;
            trashSummary = TrashCollectionSummary(
              trashByType: trashByType,
              totalWeight: derivedWeight,
              totalItems: totalItems,
            );
          }
        }
      } catch (_) {}
      
      if (activeDeployment != null) {
        botIdForRtdbUpdate = activeDeployment.botId;
        
        // Individual values (use aggregated averages if available)
        double? phValue;
        double? turbValue;
        double? tempValue;
        double? doValue;
        try {
          final schedule = await getById(scheduleId);
          final rtdb = FirebaseDatabase.instance.ref();
          final botSnap = await rtdb.child('bots/${schedule?.botId ?? activeDeployment.botId}').get();
          if (botSnap.exists && botSnap.value is Map) {
            final data = Map<String, dynamic>.from(botSnap.value as Map);
            phValue = (data['ph_level'] as num?)?.toDouble();
            turbValue = (data['turbidity'] as num?)?.toDouble();
            tempValue = (data['temp'] as num?)?.toDouble();
            doValue = (data['dissolved_oxygen'] as num?)?.toDouble();
          }
        } catch (_) {}
        if (wq != null) {
          phValue ??= wq!.avgPhLevel;
          turbValue ??= wq!.avgTurbidity;
          tempValue ??= wq!.avgTemperature;
          doValue ??= wq!.avgDissolvedOxygen;
        }
        
        await deploymentService.completeDeployment(
          activeDeployment.id,
          waterQuality: wq,
          trashCollection: trashSummary,
          phLevel: phValue,
          turbidity: turbValue,
          temperature: tempValue,
          dissolvedOxygen: doValue,
          notes: notes,
        );
        
        // Update river statistics after deployment completes
        try {
          final schedule = await getById(scheduleId);
          if (schedule != null && trashSummary != null) {
            await _updateRiverStatistics(
              schedule.riverId,
              trashSummary.totalWeight,
            );
          }
        } catch (e) {
          print('Error updating river statistics: $e');
        }
      }

      // Ensure bot status in RTDB is reset to 'idle' and pointers cleared on completion
      try {
        final rtdb = FirebaseDatabase.instance.ref();
        final targetBotId = botIdForRtdbUpdate;
        if (targetBotId != null && targetBotId.isNotEmpty) {
          await rtdb.child('bots/$targetBotId').update({
            'status': 'idle',
            'active': false,
            'current_deployment_id': null,
            'current_schedule_id': null,
            'last_updated': ServerValue.timestamp,
          });
        }
      } catch (_) {
        // Non-fatal: UI should still reflect completion from Firestore stream
        // and next realtime update will correct the state.
      }
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_complete_sync_deployment',
      );
    }
  }

  // Cancel schedule
  Future<void> cancelSchedule(String scheduleId, {String? reason}) async {
    final Map<String, dynamic> updates = {
      'status': 'cancelled',
    };

    if (reason != null) updates['notes'] = reason;

    await update(scheduleId, updates);
  }


  // Recall bot (complete schedule early)
  Future<void> recallSchedule(String scheduleId) async {
    try {
      // Get the schedule to find the bot and deployment
      final schedule = await getById(scheduleId);
      if (schedule == null) {
        throw Exception('Schedule not found');
      }

      await update(scheduleId, {
        'notes': 'Bot recalled early',
      });

      // Find and complete the active deployment for this schedule
      final deploymentService = DeploymentService();
      final deployments = await deploymentService.getDeploymentsBySchedule(scheduleId);
      final activeDeployment = deployments.where((d) => d.status == 'active').firstOrNull;
      
      if (activeDeployment != null) {
        // Pull last metrics from RTDB
        WaterQualitySnapshot? wq;
        TrashCollectionSummary? trashSummary;
        double? phValue;
        double? turbValue;
        double? tempValue;
        double? doValue;
        
        try {
          final rtdb = FirebaseDatabase.instance.ref();
          final botSnap = await rtdb.child('bots/${schedule.botId}').get();
          if (botSnap.exists && botSnap.value is Map) {
            final data = Map<String, dynamic>.from(botSnap.value as Map);
            
            // Water Quality Data
            final ph = (data['ph_level'] as num?)?.toDouble();
            final turb = (data['turbidity'] as num?)?.toDouble();
            final temp = (data['temp'] as num?)?.toDouble();
            final dissolvedOxygen = (data['dissolved_oxygen'] as num?)?.toDouble() ?? 0.0;
            
            // Store individual values for reporting
            phValue = ph;
            turbValue = turb;
            tempValue = temp;
            doValue = dissolvedOxygen;
            
            final samples = [ph, turb, temp].where((v) => v != null).length;
            if (samples > 0) {
              wq = WaterQualitySnapshot(
                avgPhLevel: ph ?? 0.0,
                avgTurbidity: turb ?? 0.0,
                avgTemperature: temp ?? 0.0,
                avgDissolvedOxygen: dissolvedOxygen,
                sampleCount: samples,
              );
            }
            
            // Trash Collection Data
            final currentLoad = (data['current_load'] as num?)?.toDouble() ?? 0.0;
            
            // Build trash_by_type from trash_collection map if available,
            // fall back to legacy trash_by_type map otherwise.
            Map<String, int> trashByType = {};
            int totalItems = 0;
            
            if (data['trash_collection'] is Map) {
              final trashCollectionData = Map<String, dynamic>.from(data['trash_collection'] as Map);
              trashCollectionData.forEach((_, value) {
                if (value is Map) {
                  final item = Map<String, dynamic>.from(value);
                  final type = (item['type'] as String?)?.toLowerCase() ?? 'other';
                  trashByType[type] = (trashByType[type] ?? 0) + 1;
                  totalItems += 1;
                }
              });
            } else if (data['trash_by_type'] is Map) {
              final trashTypesData = Map<String, dynamic>.from(data['trash_by_type'] as Map);
              trashTypesData.forEach((key, value) {
                final count = (value is num) ? value.toInt() : 0;
                if (count > 0) {
                  trashByType[key] = count;
                  totalItems += count;
                }
              });
            }
            
            trashSummary = TrashCollectionSummary(
              trashByType: trashByType,
              totalWeight: currentLoad,
              totalItems: totalItems,
            );
          }
        } catch (_) {}
        
        // Skip completing deployment here; keep returning until docking
      }

      // Update bot and deployment status in Firebase Realtime Database
      final realtimeDb = FirebaseDatabase.instance.ref();
      
      // First set bot to 'recalling' status
      await realtimeDb.child('bots/${schedule.botId}').update({
        'status': 'recalling',
        'solar_charging': true,
        'last_updated': ServerValue.timestamp,
      });
      
      // Mark deployment returning in RTDB
      if (activeDeployment != null) {
        await realtimeDb.child('deployments/${activeDeployment.id}').update({
          'status': 'returning',
          'updated_at': ServerValue.timestamp,
        });
      }

      await loggingService.logEvent(
        event: 'schedule_recalled',
        parameters: {
          'schedule_id': scheduleId,
          'bot_id': schedule.botId,
        },
      );
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_recall',
      );
      rethrow;
    }
  }

  // Get schedule statistics
  Future<Map<String, dynamic>> getScheduleStatistics(String ownerAdminId) async {
    try {
      final allSchedules = await getSchedulesByOwner(ownerAdminId);
      
      final scheduled = allSchedules.where((s) => s.status == 'scheduled').length;
      final active = allSchedules.where((s) => s.status == 'active').length;
      final completed = allSchedules.where((s) => s.status == 'completed').length;
      final cancelled = allSchedules.where((s) => s.status == 'cancelled').length;

      final totalTrash = allSchedules
          .where((s) => s.trashCollected != null)
          .fold<double>(0, (sum, s) => sum + (s.trashCollected ?? 0));

      return {
        'total': allSchedules.length,
        'scheduled': scheduled,
        'active': active,
        'completed': completed,
        'cancelled': cancelled,
        'total_trash_collected': totalTrash,
      };
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_get_statistics',
      );
      return {
        'total': 0,
        'scheduled': 0,
        'active': 0,
        'completed': 0,
        'cancelled': 0,
        'total_trash_collected': 0.0,
      };
    }
  }

  // Auto-update schedule status based on scheduled date and end date
  Future<void> updateScheduleStatusByTime(String scheduleId, ScheduleModel schedule) async {
    final now = DateTime.now();
    
    // Skip if already completed or cancelled
    if (schedule.isCompleted || schedule.isCancelled) {
      return;
    }

    try {
      // If current time is past scheduled date and status is still 'scheduled', make it 'active'
      if (schedule.status == 'scheduled' && now.isAfter(schedule.scheduledDate)) {
        await update(scheduleId, {
          'status': 'active',
          'started_at': schedule.scheduledDate, // Use the scheduled start time
        });
        
        // Update Firestore deployment AND RTDB
        try {
          final deploymentService = DeploymentService();
          final deployments = await deploymentService.getDeploymentsBySchedule(scheduleId);
          final scheduledDeployment = deployments.where((d) => d.status == 'scheduled').firstOrNull;
          
          String? deploymentId;
          // Update Firestore deployment to active
          if (scheduledDeployment != null) {
            await deploymentService.startDeployment(scheduledDeployment.id);
            deploymentId = scheduledDeployment.id;
          }
          
          // Update RTDB bot with schedule and deployment IDs
          final realtimeDb = FirebaseDatabase.instance.ref();
          await realtimeDb.child('bots/${schedule.botId}').update({
            'status': 'active',
            'active': true,
            'current_schedule_id': scheduleId,
            // IMPORTANT: Use botId for current_deployment_id to align with GAS
            'current_deployment_id': schedule.botId,
            'last_updated': ServerValue.timestamp,
          });
          
          // Create/update deployment node in RTDB using botId as key
          await realtimeDb.child('deployments/${schedule.botId}').set({
            'deployment_id': deploymentId ?? scheduleId,
            'schedule_id': scheduleId,
            'bot_id': schedule.botId,
            'river_id': schedule.riverId,
            'status': 'active',
            'actual_start_time': ServerValue.timestamp,
            'created_at': ServerValue.timestamp,
            'updated_at': ServerValue.timestamp,
          });
        } catch (_) {}
        
        await loggingService.logEvent(
          event: 'schedule_auto_started',
          parameters: {'schedule_id': scheduleId},
        );
      }
      
      
      if (schedule.status == 'active' && 
          schedule.scheduledEndDate != null &&
          schedule.scheduledEndDate!.isAfter(schedule.scheduledDate) && 
          now.isAfter(schedule.scheduledEndDate!)) {
        try {
          await recallSchedule(scheduleId);
          await loggingService.logEvent(
            event: 'schedule_auto_recall',
            parameters: {'schedule_id': scheduleId},
          );
        } catch (e) {
          await loggingService.logError(
            error: e.toString(),
            context: 'schedule_auto_complete_at_end',
          );
        }
      }
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_auto_update_status',
      );
    }
  }

  // Update all schedules status based on current time
  Future<void> updateAllScheduleStatusesByTime(String ownerAdminId) async {
    try {
      final allSchedules = await getSchedulesByOwner(ownerAdminId);
      
      for (final schedule in allSchedules) {
        if (!schedule.isCompleted && !schedule.isCancelled) {
          await updateScheduleStatusByTime(schedule.id, schedule);
        }
      }
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'schedule_update_all_statuses',
      );
    }
  }

  // Helper method to update river statistics
  Future<void> _updateRiverStatistics(String riverId, double trashWeight) async {
    try {
      final riverDoc = await FirebaseFirestore.instance
          .collection('rivers')
          .doc(riverId)
          .get();

      if (riverDoc.exists) {
        final currentDeployments = (riverDoc.data()?['total_deployments'] as num?)?.toInt() ?? 0;
        final currentTrash = (riverDoc.data()?['total_trash_collected'] as num?)?.toDouble() ?? 0.0;

        await FirebaseFirestore.instance
            .collection('rivers')
            .doc(riverId)
            .update({
          'total_deployments': currentDeployments + 1,
          'total_trash_collected': currentTrash + trashWeight,
          'last_deployment': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        print('Updated river $riverId stats: deployments=${currentDeployments + 1}, trash=${currentTrash + trashWeight}kg');
      }
    } catch (e) {
      print('Error updating river statistics for $riverId: $e');
    }
  }
}
