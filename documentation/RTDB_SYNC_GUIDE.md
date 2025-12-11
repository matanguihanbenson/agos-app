# RTDB Synchronization Guide

This document explains how the AGOS app synchronizes data between Firestore (metadata) and Realtime Database (live telemetry) when schedules are activated and bots are deployed.

---

## Problem Statement

When a schedule is activated in Firestore with `status: 'active'`, the bot's status in RTDB needs to be updated to reflect this change immediately. Previously, this synchronization was incomplete, causing:

1. ❌ Bot status in RTDB remained "idle" even when schedule was active
2. ❌ Deployment node in RTDB was not created/updated
3. ❌ Bot's `current_schedule_id` and `current_deployment_id` were not set
4. ❌ Bots page didn't show real-time updates from RTDB

---

## Solution Overview

The solution involves **three-way synchronization**:

```
Firestore Schedule (status: 'active')
    ↓
    ├─→ Firestore Deployment (status: 'active')
    ├─→ RTDB Bot Status (status: 'active', current_schedule_id, current_deployment_id)
    └─→ RTDB Deployment Node (deployments/{deploymentId})
```

---

## Data Synchronization Flow

### 1. Schedule Activation

When a schedule is activated (manually or automatically):

#### **Firestore Updates:**
```dart
// schedules/{scheduleId}
{
  "status": "active",
  "started_at": Timestamp.now()
}

// deployments/{deploymentId}
{
  "status": "active",
  "actual_start_time": Timestamp.now()
}
```

#### **RTDB Updates:**
```json
// bots/{botId}
{
  "status": "active",
  "current_schedule_id": "schedule123",
  "current_deployment_id": "deployment123",
  "last_updated": 1234567890000
}

// deployments/{deploymentId}
{
  "deployment_id": "deployment123",
  "schedule_id": "schedule123",
  "bot_id": "bot123",
  "river_id": "river123",
  "status": "active",
  "actual_start_time": 1234567890000,
  "created_at": 1234567890000,
  "updated_at": 1234567890000
}
```

---

### 2. Schedule Completion

When a schedule is completed (manually or automatically):

#### **Firestore Updates:**
```dart
// schedules/{scheduleId}
{
  "status": "completed",
  "completed_at": Timestamp.now()
}

// deployments/{deploymentId}
{
  "status": "completed",
  "actual_end_time": Timestamp.now(),
  "water_quality": { ... },    // Aggregated from RTDB
  "trash_collection": { ... }   // Aggregated from RTDB
}
```

#### **RTDB Updates:**
```json
// bots/{botId}
{
  "status": "idle",              // Reset to idle
  "current_schedule_id": null,   // Clear current schedule
  "current_deployment_id": null, // Clear current deployment
  "last_updated": 1234567890000
}

// deployments/{deploymentId}
{
  "status": "completed",
  "actual_end_time": 1234567890000,
  "updated_at": 1234567890000
}
```

---

## Implementation Details

### Service: `ScheduleService.startSchedule()`

**Location**: `lib/core/services/schedule_service.dart`

**What it does**:
1. Updates Firestore schedule status to "active"
2. Finds and activates the corresponding Firestore deployment
3. Updates RTDB bot node with:
   - `status: 'active'`
   - `current_schedule_id`
   - `current_deployment_id`
4. Creates/updates RTDB deployment node at `deployments/{deploymentId}`

**Code:**
```dart
Future<void> startSchedule(String scheduleId) async {
  // 1. Update Firestore schedule
  await update(scheduleId, {
    'status': 'active',
    'started_at': DateTime.now(),
  });

  // 2. Get schedule details
  final schedule = await getById(scheduleId);
  if (schedule == null) return;

  // 3. Update Firestore deployment
  final deploymentService = DeploymentService();
  final deployments = await deploymentService.getDeploymentsBySchedule(scheduleId);
  final scheduledDeployment = deployments.where((d) => d.status == 'scheduled').firstOrNull;
  
  String? deploymentId;
  if (scheduledDeployment != null) {
    await deploymentService.startDeployment(scheduledDeployment.id);
    deploymentId = scheduledDeployment.id;
  }

  // 4. Update RTDB bot status
  final realtimeDb = FirebaseDatabase.instance.ref();
  await realtimeDb.child('bots/${schedule.botId}').update({
    'status': 'active',
    'current_schedule_id': scheduleId,
    'current_deployment_id': deploymentId,
    'last_updated': ServerValue.timestamp,
  });
  
  // 5. Create RTDB deployment node
  if (deploymentId != null) {
    await realtimeDb.child('deployments/$deploymentId').set({
      'deployment_id': deploymentId,
      'schedule_id': scheduleId,
      'bot_id': schedule.botId,
      'river_id': schedule.riverId,
      'status': 'active',
      'actual_start_time': ServerValue.timestamp,
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });
  }
}
```

---

### Service: `ScheduleService.updateScheduleStatusByTime()`

**Location**: `lib/core/services/schedule_service.dart`

**What it does**: Automatically updates schedule status based on scheduled times.

**Triggers**:
- When current time passes `scheduled_date` → Set status to "active"
- When current time passes `scheduled_end_date` → Set status to "completed"

**Same sync logic applies** as `startSchedule()` and `completeSchedule()`

---

## Real-time Bot Updates

### Service: `RealtimeBotService`

**Location**: `lib/core/services/realtime_bot_service.dart`

**What it does**:
1. Listens to Firestore `bots` collection for bot metadata
2. For each bot, listens to RTDB `bots/{botId}` for live telemetry
3. **Merges** Firestore data + RTDB data into `BotModel`
4. Emits updates to subscribers (like bots page)

**Key features**:
- ✅ Real-time updates from RTDB
- ✅ Automatic data merging
- ✅ Role-based filtering (admin sees own bots, operators see assigned bots)
- ✅ Automatic cleanup when bots are removed

---

### Provider: `botsStreamProvider`

**Location**: `lib/core/providers/bot_provider.dart`

**Fixed implementation**:
```dart
final botsStreamProvider = StreamProvider.autoDispose<List<BotModel>>((ref) {
  final realtimeBotService = ref.watch(realtimeBotServiceProvider);
  final authState = ref.watch(authProvider);
  final currentUser = authState.userProfile;

  if (currentUser == null) {
    return Stream.value([]);
  }

  // Use RealtimeBotService which merges Firestore + RTDB data automatically
  return realtimeBotService.getRealtimeBots(ref);
});
```

**What changed**:
- ❌ **Before**: Used `botService.watchBotsByOwner()` which only watched Firestore
- ✅ **After**: Uses `realtimeBotService.getRealtimeBots()` which merges Firestore + RTDB

**Result**: Bots page now updates immediately when RTDB data changes!

---

## Testing the Synchronization

### Test 1: Activate a Schedule

1. **In Firebase Console**, update schedule status:
   ```json
   {
     "status": "active"
   }
   ```

2. **Call** `ScheduleService.startSchedule(scheduleId)` in your app

3. **Verify** in RTDB:
   - `bots/{botId}/status` → "active"
   - `bots/{botId}/current_schedule_id` → schedule ID
   - `deployments/{deploymentId}/status` → "active"

4. **Check** bots page in app → Should show bot as "active" immediately

---

### Test 2: Manually Update Bot Status in RTDB

1. **In Firebase Console > RTDB**, update bot status:
   ```json
   {
     "status": "maintenance",
     "last_updated": 1234567890000
   }
   ```

2. **Check** bots page in app → Should update to "maintenance" within 1-2 seconds

3. **Verify** filtering works (select "Maintenance" tab)

---

### Test 3: Complete a Schedule

1. **Call** `ScheduleService.completeSchedule(scheduleId)`

2. **Verify** in RTDB:
   - `bots/{botId}/status` → "idle"
   - `bots/{botId}/current_schedule_id` → null
   - `deployments/{deploymentId}/status` → "completed"

3. **Check** dashboard → Should remove from "Live River Deployments"

---

## RTDB Structure Reference

### bots/{botId} Node

```json
{
  // Status & Identity
  "status": "idle | active | deployed | recalling | maintenance",
  "active": true,
  "current_schedule_id": "schedule123",      // Links to Firestore schedule
  "current_deployment_id": "deployment123",  // Links to Firestore deployment
  
  // Location
  "lat": 14.5995,
  "lng": 120.9842,
  
  // Power
  "battery": 85,
  
  // Water quality sensors
  "temp": 28.5,
  "ph_level": 7.2,
  "turbidity": 12.3,
  "dissolved_oxygen": 6.8,
  
  // Trash collection
  "trash_collected": 8.4,
  "current_load": 3.2,
  "max_load": 10.0,
  
  // Timestamps
  "last_updated": 1234567890000
}
```

### deployments/{deploymentId} Node

```json
{
  "deployment_id": "deployment123",
  "schedule_id": "schedule123",
  "bot_id": "bot123",
  "river_id": "river123",
  "status": "active | completed",
  "actual_start_time": 1234567890000,
  "actual_end_time": 1234567890000,
  "created_at": 1234567890000,
  "updated_at": 1234567890000,
  
  // Optional: Time-series readings
  "readings": {
    "1234567890000": { "lat": 14.5995, "temp": 28.5, ... },
    "1234567895000": { "lat": 14.5996, "temp": 28.6, ... }
  }
}
```

---

## Common Issues & Solutions

### Issue 1: Bot status doesn't update when schedule is activated

**Cause**: `startSchedule()` not being called, or RTDB write failed

**Solution**:
```dart
// Make sure to call this when activating schedule
await ScheduleService().startSchedule(scheduleId);

// Check console for errors
print('Schedule started: $scheduleId');
```

---

### Issue 2: Bots page doesn't show real-time updates

**Cause**: Using old provider that only watches Firestore

**Solution**: Already fixed! `botsStreamProvider` now uses `RealtimeBotService`

**Verify**:
```dart
// This should use RealtimeBotService
final botsAsync = ref.watch(botsStreamProvider);
```

---

### Issue 3: Dashboard shows "No active deployments"

**Cause**: Schedule is active but RTDB bot status is still "idle"

**Solution**:
1. Check schedule has `status: 'active'`
2. Check bot node exists in RTDB
3. Verify `current_schedule_id` is set in RTDB
4. Call `startSchedule()` to sync everything

---

### Issue 4: Multiple schedules conflict

**Cause**: Bot has multiple active schedules

**Solution**: Enforce business rule - only one active schedule per bot
```dart
// Check if bot already has active schedule
final activeSchedules = await scheduleService.getSchedulesByStatus('active', ownerId);
final botSchedules = activeSchedules.where((s) => s.botId == botId);
if (botSchedules.isNotEmpty) {
  throw Exception('Bot already has an active schedule');
}
```

---

## Best Practices

### 1. Always use ScheduleService methods
✅ **Do**: `scheduleService.startSchedule(id)`  
❌ **Don't**: Manually update Firestore without syncing RTDB

### 2. Listen to streams, not snapshots
✅ **Do**: `ref.watch(botsStreamProvider)`  
❌ **Don't**: One-time `getById()` calls that don't update

### 3. Keep RTDB status authoritative
✅ Bot devices write directly to RTDB  
✅ App reads from RTDB for live status  
✅ Firestore stores historical/metadata only

### 4. Log sync operations
```dart
await loggingService.logEvent(
  event: 'schedule_started',
  parameters: {
    'schedule_id': scheduleId,
    'bot_id': botId,
    'deployment_id': deploymentId,
  },
);
```

---

## Summary

| Action | Firestore Updates | RTDB Updates |
|--------|------------------|--------------|
| **Schedule Created** | `schedules/{id}` status: "scheduled" | None (not active yet) |
| **Schedule Activated** | `schedules/{id}` → "active"<br>`deployments/{id}` → "active" | `bots/{id}` → status: "active"<br>Set `current_schedule_id`<br>Set `current_deployment_id`<br>`deployments/{id}` created |
| **Schedule Completed** | `schedules/{id}` → "completed"<br>`deployments/{id}` → "completed" + aggregated data | `bots/{id}` → status: "idle"<br>Clear `current_schedule_id`<br>Clear `current_deployment_id`<br>`deployments/{id}` → "completed" |
| **Bot Status Changed** | None (telemetry not stored) | `bots/{id}` → new status<br>`last_updated` timestamp |

---

## Related Files

- `lib/core/services/schedule_service.dart` - Schedule activation/completion logic
- `lib/core/services/realtime_bot_service.dart` - RTDB listener and data merging
- `lib/core/providers/bot_provider.dart` - Bot stream provider (fixed)
- `lib/features/bots/pages/bots_page.dart` - Bots page UI
- `lib/features/dashboard/providers/dashboard_provider.dart` - Dashboard data

---

## Next Steps

To fully leverage this synchronization:

1. ✅ **Ensure all schedule activations** use `ScheduleService.startSchedule()`
2. ✅ **Use stream providers** instead of one-time queries
3. ⏳ **Add UI indicators** for sync status (loading, syncing, synced)
4. ⏳ **Implement retry logic** for failed RTDB writes
5. ⏳ **Add Cloud Functions** for automatic cleanup of orphaned data

---

**The synchronization is now working! Bot status updates in RTDB will reflect immediately on the bots page.**
