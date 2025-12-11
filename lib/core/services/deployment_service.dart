import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deployment_model.dart';
import 'base_service.dart';

class DeploymentService extends BaseService<DeploymentModel> {
  @override
  String get collectionName => 'deployments';

  @override
  DeploymentModel fromMap(Map<String, dynamic> map, String id) {
    return DeploymentModel.fromMap(map, id);
  }

  // Get deployments by bot (one-time)
  Future<List<DeploymentModel>> getDeploymentsByBot(String botId) async {
    return await getByFieldOnce('bot_id', botId);
  }

  // Watch deployments by bot (real-time stream)
  Stream<List<DeploymentModel>> watchDeploymentsByBot(String botId) {
    return getByField('bot_id', botId);
  }

  // Get deployments by owner
  Future<List<DeploymentModel>> getDeploymentsByOwner(String ownerAdminId) async {
    return await getByFieldOnce('owner_admin_id', ownerAdminId);
  }

  // Get deployments by schedule
  Future<List<DeploymentModel>> getDeploymentsBySchedule(String scheduleId) async {
    return await getByFieldOnce('schedule_id', scheduleId);
  }

  // Get deployments by river
  Future<List<DeploymentModel>> getDeploymentsByRiver(String riverId) async {
    return await getByFieldOnce('river_id', riverId);
  }

  // Get deployments by status
  Future<List<DeploymentModel>> getDeploymentsByStatus(String status, String ownerAdminId) async {
    try {
      final allDeployments = await getDeploymentsByOwner(ownerAdminId);
      return allDeployments.where((deployment) => deployment.status == status).toList();
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'deployment_get_by_status',
      );
      return [];
    }
  }

  // Start deployment (when schedule becomes active)
  Future<void> startDeployment(String deploymentId) async {
    await update(deploymentId, {
      'status': 'active',
      'actual_start_time': DateTime.now(),
    });
  }

  // Complete deployment with collected data
  Future<void> completeDeployment(
    String deploymentId, {
    WaterQualitySnapshot? waterQuality,
    TrashCollectionSummary? trashCollection,
    List<TrashItem>? trashItems,
    double? phLevel,
    double? turbidity,
    double? temperature,
    double? dissolvedOxygen,
    double? areaCoveredPercentage,
    double? distanceTraveled,
    int? durationMinutes,
    String? notes,
  }) async {
    final Map<String, dynamic> updates = {
      'status': 'completed',
      'actual_end_time': DateTime.now(),
    };

    if (waterQuality != null) updates['water_quality'] = waterQuality.toMap();
    if (trashCollection != null) updates['trash_collection'] = trashCollection.toMap();
    if (trashItems != null) updates['trash_items'] = trashItems.map((item) => item.toMap()).toList();
    
    // Individual water quality readings for reporting
    if (phLevel != null) updates['ph_level'] = phLevel;
    if (turbidity != null) updates['turbidity'] = turbidity;
    if (temperature != null) updates['temperature'] = temperature;
    if (dissolvedOxygen != null) updates['dissolved_oxygen'] = dissolvedOxygen;
    
    if (areaCoveredPercentage != null) updates['area_covered_percentage'] = areaCoveredPercentage;
    if (distanceTraveled != null) updates['distance_traveled'] = distanceTraveled;
    if (durationMinutes != null) updates['duration_minutes'] = durationMinutes;
    if (notes != null) updates['notes'] = notes;

    await update(deploymentId, updates);
  }

  // Cancel deployment
  Future<void> cancelDeployment(String deploymentId, {String? reason}) async {
    final Map<String, dynamic> updates = {
      'status': 'cancelled',
    };

    if (reason != null) updates['notes'] = reason;

    await update(deploymentId, updates);
  }

  // Get deployment statistics
  Future<Map<String, dynamic>> getDeploymentStatistics(String ownerAdminId) async {
    try {
      final allDeployments = await getDeploymentsByOwner(ownerAdminId);
      
      final scheduled = allDeployments.where((d) => d.status == 'scheduled').length;
      final active = allDeployments.where((d) => d.status == 'active').length;
      final completed = allDeployments.where((d) => d.status == 'completed').length;
      final cancelled = allDeployments.where((d) => d.status == 'cancelled').length;

      final totalTrash = allDeployments
          .where((d) => d.trashCollection != null)
          .fold<double>(0, (sum, d) => sum + (d.trashCollection?.totalWeight ?? 0));

      final totalDistance = allDeployments
          .where((d) => d.distanceTraveled != null)
          .fold<double>(0, (sum, d) => sum + (d.distanceTraveled ?? 0));

      return {
        'total': allDeployments.length,
        'scheduled': scheduled,
        'active': active,
        'completed': completed,
        'cancelled': cancelled,
        'total_trash_collected': totalTrash,
        'total_distance_traveled': totalDistance,
      };
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'deployment_get_statistics',
      );
      return {
        'total': 0,
        'scheduled': 0,
        'active': 0,
        'completed': 0,
        'cancelled': 0,
        'total_trash_collected': 0.0,
        'total_distance_traveled': 0.0,
      };
    }
  }

  // Check if bot has active or scheduled deployment (with auto-update)
  Future<bool> hasBotActiveOrScheduledDeployment(String botId) async {
    try {
      final now = DateTime.now();
      
      // Use a single efficient query to check schedules directly
      // This avoids fetching all deployments and expensive status updates
      final scheduleCollection = firestore.collection('schedules');
      final scheduleQuery = await scheduleCollection
          .where('bot_id', isEqualTo: botId)
          .where('status', whereIn: ['scheduled', 'active'])
          .limit(10) // Only need to check a few recent ones
          .get();
      
      if (scheduleQuery.docs.isNotEmpty) {
        // Check if any schedule is actually in the future or ongoing
        for (final doc in scheduleQuery.docs) {
          final data = doc.data();
          final endTime = (data['scheduled_end_date'] as Timestamp?)?.toDate();
          
          // If end time is in the future, bot is still busy
          if (endTime != null && now.isBefore(endTime)) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'deployment_check_bot_active',
      );
      return false;
    }
  }

  // Auto-update deployment statuses based on scheduled times
  Future<void> autoUpdateDeploymentStatuses(String ownerAdminId) async {
    try {
      final now = DateTime.now();
      final deployments = await getDeploymentsByOwner(ownerAdminId);
      
      for (final deployment in deployments) {
        // Update scheduled to active if start time has passed
        if (deployment.status == 'scheduled' && 
            now.isAfter(deployment.scheduledStartTime) &&
            now.isBefore(deployment.scheduledEndTime)) {
          await update(deployment.id, {
            'status': 'active',
            'actual_start_time': deployment.scheduledStartTime,
          });
        }
        // Update active to completed if end time has passed
        else if (deployment.status == 'active' && 
                 now.isAfter(deployment.scheduledEndTime)) {
          await update(deployment.id, {
            'status': 'completed',
            'actual_end_time': deployment.scheduledEndTime,
          });
        }
      }
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'deployment_auto_update_statuses',
      );
    }
  }

  // Get active deployment for a bot
  Future<DeploymentModel?> getActiveDeploymentForBot(String botId) async {
    try {
      final deployments = await getDeploymentsByBot(botId);
      final activeDeployments = deployments.where((d) => d.status == 'active').toList();
      return activeDeployments.isNotEmpty ? activeDeployments.first : null;
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'deployment_get_active',
      );
      return null;
    }
  }
}
