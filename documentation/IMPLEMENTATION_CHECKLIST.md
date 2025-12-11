# Implementation Checklist - Centralized Reporting

## ✅ Quick Reference

Use this checklist to implement the centralized data architecture.

---

## 📋 Phase 1: Dashboard - Live River Deployments

### Query Implementation:
```dart
// In dashboard_page.dart or dashboard_provider.dart

Stream<List<ActiveDeploymentInfo>> getActiveDeployments(String adminId) {
  // Step 1: Listen to active schedules in Firestore
  final schedulesStream = FirebaseFirestore.instance
      .collection('schedules')
      .where('status', isEqualTo: 'active')
      .where('owner_admin_id', isEqualTo: adminId)
      .snapshots();
  
  return schedulesStream.asyncMap((snapshot) async {
    final List<ActiveDeploymentInfo> activeDeployments = [];
    
    for (final scheduleDoc in snapshot.docs) {
      final schedule = ScheduleModel.fromMap(scheduleDoc.data(), scheduleDoc.id);
      
      // Step 2: Get real-time bot data from RTDB
      final botSnapshot = await FirebaseDatabase.instance
          .ref('bots/${schedule.botId}')
          .get();
      
      if (botSnapshot.exists) {
        final botData = Map<String, dynamic>.from(botSnapshot.value as Map);
        
        activeDeployments.add(ActiveDeploymentInfo(
          scheduleId: schedule.id,
          scheduleName: schedule.name,
          botId: schedule.botId,
          botName: schedule.botName,
          riverId: schedule.riverId,
          riverName: schedule.riverName,
          // Real-time data from RTDB
          currentLat: botData['lat']?.toDouble(),
          currentLng: botData['lng']?.toDouble(),
          battery: botData['battery']?.toInt(),
          status: botData['status'],
        ));
      }
    }
    
    return activeDeployments;
  });
}
```

**Tasks**:
- [ ] Create `ActiveDeploymentInfo` model
- [ ] Add query to dashboard provider
- [ ] Update dashboard UI to use this stream
- [ ] Add map widget to show bot locations

---

## 📊 Phase 2: Dashboard - Overview Stats

### Query Implementation:
```dart
// In dashboard_provider.dart

class DashboardStats {
  final int totalBots;
  final int activeBots;
  final double totalTrashToday;
  final int riversMonitoredToday;
}

Future<DashboardStats> getOverviewStats(String adminId) async {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  
  // Total Bots
  final botsQuery = await FirebaseFirestore.instance
      .collection('bots')
      .where('owner_admin_id', isEqualTo: adminId)
      .get();
  final totalBots = botsQuery.docs.length;
  
  // Active Bots (count active schedules)
  final activeSchedulesQuery = await FirebaseFirestore.instance
      .collection('schedules')
      .where('status', isEqualTo: 'active')
      .where('owner_admin_id', isEqualTo: adminId)
      .get();
  final activeBots = activeSchedulesQuery.docs.length;
  
  // Total Trash Today + Rivers Monitored
  final deploymentsQuery = await FirebaseFirestore.instance
      .collection('deployments')
      .where('owner_admin_id', isEqualTo: adminId)
      .where('actual_start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
      .where('actual_start_time', isLessThan: Timestamp.fromDate(todayEnd))
      .get();
  
  double totalTrash = 0;
  Set<String> uniqueRivers = {};
  
  for (final doc in deploymentsQuery.docs) {
    final deployment = DeploymentModel.fromMap(doc.data(), doc.id);
    totalTrash += deployment.trashCollection?.totalWeight ?? 0;
    uniqueRivers.add(deployment.riverId);
  }
  
  return DashboardStats(
    totalBots: totalBots,
    activeBots: activeBots,
    totalTrashToday: totalTrash,
    riversMonitoredToday: uniqueRivers.length,
  );
}
```

**Tasks**:
- [ ] Create `DashboardStats` class
- [ ] Add `getOverviewStats` method to dashboard provider
- [ ] Update dashboard UI cards with these stats
- [ ] Add refresh button/pull-to-refresh

---

## 🗺️ Phase 3: Monitoring Page

### Query Implementation:
```dart
// In monitoring_provider.dart

Stream<List<ActiveBotInfo>> getActiveBots() {
  // Listen to all bots in RTDB
  return FirebaseDatabase.instance
      .ref('bots')
      .onValue
      .asyncMap((event) async {
    if (!event.snapshot.exists) return [];
    
    final botsData = Map<String, dynamic>.from(event.snapshot.value as Map);
    final List<ActiveBotInfo> activeBots = [];
    
    for (final entry in botsData.entries) {
      final botId = entry.key;
      final botData = Map<String, dynamic>.from(entry.value);
      final deploymentId = botData['current_deployment_id'];
      
      // Only include bots with active deployments
      if (deploymentId != null) {
        // Get deployment info from Firestore
        final deploymentDoc = await FirebaseFirestore.instance
            .collection('deployments')
            .doc(deploymentId)
            .get();
        
        if (deploymentDoc.exists) {
          final deployment = DeploymentModel.fromMap(
            deploymentDoc.data()!,
            deploymentDoc.id,
          );
          
          activeBots.add(ActiveBotInfo(
            botId: botId,
            botName: deployment.botName,
            deploymentId: deploymentId,
            scheduleName: deployment.scheduleName,
            riverName: deployment.riverName,
            // Real-time data
            lat: botData['lat']?.toDouble(),
            lng: botData['lng']?.toDouble(),
            battery: botData['battery']?.toInt(),
            status: botData['status'],
            trashCollected: botData['trash_collected']?.toDouble(),
          ));
        }
      }
    }
    
    return activeBots;
  });
}
```

**Tasks**:
- [ ] Create `ActiveBotInfo` model
- [ ] Update monitoring provider with this stream
- [ ] Update monitoring page UI
- [ ] Add filters (by river, by status)
- [ ] Add map view

---

## 📅 Phase 4: Schedule Details - Cleanup Summary

### Query Implementation:
```dart
// In schedule_detail_page.dart

Future<DeploymentModel?> getScheduleDeployment(String scheduleId) async {
  final query = await FirebaseFirestore.instance
      .collection('deployments')
      .where('schedule_id', isEqualTo: scheduleId)
      .where('status', isEqualTo: 'completed')
      .limit(1)
      .get();
  
  if (query.docs.isEmpty) return null;
  
  return DeploymentModel.fromMap(
    query.docs.first.data(),
    query.docs.first.id,
  );
}
```

**Tasks**:
- [ ] Add deployment query to schedule detail page
- [ ] Show "No data yet" if deployment not completed
- [ ] Display trash collection summary
- [ ] Display water quality summary
- [ ] Show trash breakdown by type (pie chart)

---

## 🏞️ Phase 5: Rivers Management - Analytics

### Query Implementation:
```dart
// In rivers_management_page.dart

Stream<List<RiverModel>> getRiversWithAnalytics(String adminId) {
  return FirebaseFirestore.instance
      .collection('rivers')
      .where('owner_admin_id', isEqualTo: adminId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return RiverModel.fromMap(doc.data(), doc.id);
    }).toList();
  });
}
```

**Display**:
```dart
// Each river card shows:
- river.name
- river.totalDeployments
- river.activeDeployments  
- river.totalTrashCollected
- river.lastDeployment (formatted)
```

**Tasks**:
- [ ] Update rivers page to use this stream
- [ ] Add analytics cards to river details
- [ ] Add "View History" button → filters deployments by river_id

---

## 🔄 Phase 6: Deployment Lifecycle

### When Schedule Activates:

```dart
// In schedule_service.dart or deployment_service.dart

Future<void> activateSchedule(String scheduleId) async {
  final schedule = await getSchedule(scheduleId);
  final deploymentId = FirebaseFirestore.instance.collection('deployments').doc().id;
  
  // 1. Create deployment in Firestore
  await FirebaseFirestore.instance
      .collection('deployments')
      .doc(deploymentId)
      .set({
    'schedule_id': scheduleId,
    'schedule_name': schedule.name,
    'bot_id': schedule.botId,
    'bot_name': schedule.botName,
    'river_id': schedule.riverId,
    'river_name': schedule.riverName,
    'owner_admin_id': schedule.ownerAdminId,
    'scheduled_start_time': schedule.scheduledDate,
    'scheduled_end_time': schedule.scheduledEndDate,
    'actual_start_time': FieldValue.serverTimestamp(),
    'status': 'active',
    'operation_lat': schedule.operationArea.center.latitude,
    'operation_lng': schedule.operationArea.center.longitude,
    'operation_radius': schedule.operationArea.radiusInMeters,
    'operation_location': schedule.operationArea.locationName,
    'created_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 2. Update schedule status
  await FirebaseFirestore.instance
      .collection('schedules')
      .doc(scheduleId)
      .update({
    'status': 'active',
    'started_at': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 3. Update bot in RTDB
  await FirebaseDatabase.instance
      .ref('bots/${schedule.botId}')
      .update({
    'status': 'active',
    'current_deployment_id': deploymentId,
    'current_schedule_id': scheduleId,
  });
  
  // 4. Update river analytics
  await FirebaseFirestore.instance
      .collection('rivers')
      .doc(schedule.riverId)
      .update({
    'active_deployments': FieldValue.increment(1),
    'updated_at': FieldValue.serverTimestamp(),
  });
}
```

**Tasks**:
- [ ] Implement `activateSchedule` method
- [ ] Add button to schedule detail page
- [ ] Add confirmation dialog
- [ ] Handle errors gracefully

### When Deployment Completes:

```dart
// In deployment_service.dart

Future<void> completeDeployment(String deploymentId) async {
  final deployment = await getDeployment(deploymentId);
  
  // 1. Aggregate RTDB readings
  final readingsSnapshot = await FirebaseDatabase.instance
      .ref('deployments/$deploymentId/readings')
      .get();
  
  if (!readingsSnapshot.exists) {
    throw Exception('No readings found for deployment');
  }
  
  final readings = Map<String, dynamic>.from(readingsSnapshot.value as Map);
  final aggregated = _aggregateReadings(readings);
  
  // 2. Update deployment in Firestore
  await FirebaseFirestore.instance
      .collection('deployments')
      .doc(deploymentId)
      .update({
    'status': 'completed',
    'actual_end_time': FieldValue.serverTimestamp(),
    'water_quality': aggregated.waterQuality?.toMap(),
    'trash_collection': aggregated.trashCollection?.toMap(),
    'duration_minutes': aggregated.durationMinutes,
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 3. Update schedule
  await FirebaseFirestore.instance
      .collection('schedules')
      .doc(deployment.scheduleId)
      .update({
    'status': 'completed',
    'completed_at': FieldValue.serverTimestamp(),
    'trash_collected': aggregated.trashCollection?.totalWeight,
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 4. Update bot in RTDB
  await FirebaseDatabase.instance
      .ref('bots/${deployment.botId}')
      .update({
    'status': 'idle',
    'current_deployment_id': null,
    'current_schedule_id': null,
  });
  
  // 5. Update river analytics
  await FirebaseFirestore.instance
      .collection('rivers')
      .doc(deployment.riverId)
      .update({
    'total_deployments': FieldValue.increment(1),
    'active_deployments': FieldValue.increment(-1),
    'total_trash_collected': FieldValue.increment(
      aggregated.trashCollection?.totalWeight ?? 0
    ),
    'last_deployment': FieldValue.serverTimestamp(),
    'updated_at': FieldValue.serverTimestamp(),
  });
}

AggregatedData _aggregateReadings(Map<String, dynamic> readings) {
  // Implement aggregation logic
  // Calculate averages, sums, counts, etc.
}
```

**Tasks**:
- [ ] Implement `completeDeployment` method
- [ ] Implement `_aggregateReadings` helper
- [ ] Add "Complete Deployment" button
- [ ] Add confirmation dialog with summary preview

---

## ✅ Testing Checklist

### Dashboard Tests:
- [ ] Active deployments show on map
- [ ] Bot markers update in real-time
- [ ] Overview stats are accurate
- [ ] Stats refresh when data changes

### Monitoring Tests:
- [ ] All active bots appear
- [ ] Real-time location updates
- [ ] Battery levels update
- [ ] Filters work correctly

### Schedule Tests:
- [ ] Activate schedule creates deployment
- [ ] Schedule status updates correctly
- [ ] Cleanup summary displays after completion
- [ ] Summary data is accurate

### Rivers Tests:
- [ ] Analytics display correctly
- [ ] Counters update after deployment
- [ ] Total trash accumulates correctly
- [ ] Last deployment timestamp is correct

---

## 🚀 Deployment Order

1. ✅ Update models (if needed)
2. ✅ Implement deployment lifecycle methods
3. ✅ Implement dashboard queries
4. ✅ Update dashboard UI
5. ✅ Implement monitoring queries
6. ✅ Update monitoring UI
7. ✅ Implement rivers analytics
8. ✅ Update rivers UI
9. ✅ Test end-to-end flow
10. ✅ Deploy to production

---

**Last Updated**: 2025-10-01  
**Status**: Ready to implement
