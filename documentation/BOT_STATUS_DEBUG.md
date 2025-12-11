# Bot Status Display Issues - Debugging Guide

## Issues Reported

1. ❌ **Bot card shows "scheduled" even when schedule status is "active" or "completed"**
2. ❌ **Live river deployment shows wrong status (not matching RTDB)**

---

## Root Cause Analysis

### Issue 1: Bot Card Status

**Where it gets the status**: `BotCard` → `widget.bot.displayStatus` → `BotModel.status` (from RTDB)

**Possible causes**:
1. RTDB `bots/{botId}/status` field is null or not set
2. RTDB status is actually "scheduled" (not updated when schedule activated)
3. `RealtimeBotService` is not properly merging RTDB data
4. Bot status in RTDB hasn't been updated after schedule activation

### Issue 2: Dashboard River Deployment Status

**Where it gets the status**: `_buildRiverCardFromDeployment` → `deployment.status` → `ActiveDeploymentInfo.status` (from RTDB)

**Same root causes as Issue 1**

---

## Quick Diagnostic Steps

### Step 1: Check RTDB Bot Node

1. Open Firebase Console → Realtime Database
2. Navigate to `bots/{your_bot_id}`
3. Check if `status` field exists and what value it has:

```json
{
  "bots": {
    "bot123": {
      "status": "???",  // ← What value is here?
      "battery": 85,
      "lat": 14.5995,
      "lng": 120.9842
    }
  }
}
```

**Expected values**: `"idle"`, `"active"`, `"deployed"`, `"recalling"`, `"maintenance"`

**If status is missing or wrong**: Bot status wasn't synced properly when schedule was activated.

---

### Step 2: Check if `startSchedule()` Was Called

When a schedule is activated, `ScheduleService.startSchedule(scheduleId)` must be called to sync RTDB.

**Check**:
```dart
// When activating schedule, make sure this is called:
await ScheduleService().startSchedule(scheduleId);
```

**What it should do**:
1. Update Firestore schedule → `status: 'active'`
2. Update Firestore deployment → `status: 'active'`
3. **Update RTDB bot** → `status: 'active'`, `current_schedule_id`, `current_deployment_id`
4. **Create RTDB deployment** → `deployments/{deploymentId}`

---

### Step 3: Verify RealtimeBotService is Working

The `RealtimeBotService` should automatically merge Firestore + RTDB data.

**Add debug logging** to check what data is being received:

```dart
// In lib/core/services/realtime_bot_service.dart
// In _startRealtimeListening method, add:

_realtimeSubscriptions[botId] = _database
    .ref('bots/$botId')
    .onValue
    .listen((event) async {
  if (event.snapshot.exists) {
    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    print('🔴 RTDB data for bot $botId: $data'); // ← ADD THIS
    _realtimeData[botId] = data;
    await _mirrorTelemetryIfActive(botId, data);
  }
  _emitUpdatedBots();
});
```

Check Flutter console for this output when bot status changes.

---

## Solutions

### Solution 1: Manually Set Bot Status in RTDB

If RTDB bot status is wrong, manually fix it:

```json
// In Firebase Console > RTDB > bots/{botId}
{
  "status": "active",  // ← Set this
  "current_schedule_id": "your_schedule_id",
  "current_deployment_id": "your_deployment_id",
  "battery": 85,
  "lat": 14.5995,
  "lng": 120.9842,
  "active": true,
  "last_updated": 1234567890000
}
```

**Result**: Bot card and dashboard should update immediately (1-2 seconds)

---

### Solution 2: Re-activate the Schedule

If schedule is already active but RTDB wasn't synced:

```dart
// Call this to force sync:
final scheduleService = ScheduleService();
await scheduleService.startSchedule(scheduleId);
```

This will:
- ✅ Set RTDB bot status to "active"
- ✅ Set `current_schedule_id` and `current_deployment_id`
- ✅ Create RTDB deployment node

---

### Solution 3: Create Bot Status Sync Utility

Create a helper method to sync bot status from Firestore schedule to RTDB:

```dart
// In lib/core/services/schedule_service.dart

Future<void> syncBotStatusFromSchedule(String scheduleId) async {
  final schedule = await getById(scheduleId);
  if (schedule == null) return;

  final realtimeDb = FirebaseDatabase.instance.ref();
  
  String rtdbStatus;
  switch (schedule.status) {
    case 'active':
      rtdbStatus = 'active';
      break;
    case 'completed':
    case 'cancelled':
      rtdbStatus = 'idle';
      break;
    default:
      rtdbStatus = 'idle';
  }

  await realtimeDb.child('bots/${schedule.botId}').update({
    'status': rtdbStatus,
    'current_schedule_id': schedule.status == 'active' ? scheduleId : null,
    'last_updated': ServerValue.timestamp,
  });
  
  print('✅ Synced bot ${schedule.botId} status to: $rtdbStatus');
}
```

**Usage**:
```dart
await scheduleService.syncBotStatusFromSchedule(scheduleId);
```

---

## Expected Behavior

### When Schedule is "scheduled" (not started yet):
```json
// RTDB bots/{botId}
{
  "status": "idle",  // ← Bot is idle until schedule starts
  "current_schedule_id": null
}
```

### When Schedule is "active":
```json
// RTDB bots/{botId}
{
  "status": "active",  // ← Bot is actively deployed
  "current_schedule_id": "schedule123",
  "current_deployment_id": "deployment123"
}
```

### When Schedule is "completed":
```json
// RTDB bots/{botId}
{
  "status": "idle",  // ← Bot returns to idle
  "current_schedule_id": null,
  "current_deployment_id": null
}
```

---

## Status Mapping

### Schedule Status → Bot Status in RTDB:

| Schedule Status | RTDB Bot Status | Description |
|----------------|-----------------|-------------|
| `scheduled` | `idle` | Not started yet |
| `active` | `active` or `deployed` | Currently running |
| `completed` | `idle` | Finished |
| `cancelled` | `idle` | Cancelled |

---

## Testing Checklist

### Test 1: Create and Activate Schedule

1. Create schedule with status "scheduled"
2. Call `startSchedule(scheduleId)`
3. Check RTDB `bots/{botId}/status` → should be "active"
4. Open app's bots page → bot card should show "ACTIVE"
5. Open dashboard → river deployment should show "Active"

### Test 2: Manually Update RTDB Status

1. In Firebase Console RTDB, change `bots/{botId}/status` to "maintenance"
2. Within 1-2 seconds, app should update:
   - Bot card → "MAINTENANCE"
   - Dashboard (if active deployment) → "Maintenance"

### Test 3: Complete Schedule

1. Call `completeSchedule(scheduleId)`
2. Check RTDB `bots/{botId}/status` → should be "idle"
3. Bot card should show "IDLE"
4. Dashboard should no longer show in "Live River Deployments"

---

## Common Fixes

### Fix 1: Status Stays "idle" When Schedule is Active

**Cause**: `startSchedule()` not called

**Fix**:
```dart
// When activating schedule:
await ScheduleService().startSchedule(scheduleId);

// Verify RTDB:
// bots/{botId}/status should be "active"
```

---

### Fix 2: Status Shows Old Value

**Cause**: RTDB not updated, RealtimeBotService not running

**Fix**:
1. Verify `botsStreamProvider` uses `RealtimeBotService`
2. Check network connection
3. Verify Firebase security rules allow read/write

---

### Fix 3: Status is Null

**Cause**: RTDB bot node doesn't have `status` field

**Fix**:
```json
// Add status field to RTDB:
{
  "bots": {
    "bot123": {
      "status": "idle",  // ← Add this
      "active": true,
      "battery": 85
    }
  }
}
```

---

## Debugging Commands

### Check Bot Status from Dart:
```dart
import 'package:firebase_database/firebase_database.dart';

Future<void> debugBotStatus(String botId) async {
  final snapshot = await FirebaseDatabase.instance
      .ref('bots/$botId')
      .get();
      
  if (snapshot.exists) {
    final data = snapshot.value as Map;
    print('Bot $botId RTDB data:');
    print('  status: ${data['status']}');
    print('  battery: ${data['battery']}');
    print('  current_schedule_id: ${data['current_schedule_id']}');
    print('  active: ${data['active']}');
  } else {
    print('❌ Bot $botId not found in RTDB!');
  }
}
```

---

## Prevention

To prevent status sync issues in the future:

### 1. Always Use ScheduleService Methods
✅ DO: `scheduleService.startSchedule(id)`  
❌ DON'T: Manually update Firestore without syncing RTDB

### 2. Add Validation
```dart
// Before displaying bot card:
if (bot.status == null) {
  print('⚠️ Bot ${bot.id} has null status in RTDB!');
  // Set default status or show warning
}
```

### 3. Add UI Indicators
Show sync status in UI:
```dart
if (bot.status == null) {
  return Text('Status: Syncing...', style: warningStyle);
}
```

---

## Quick Fix Script

Run this to fix all bots with null/wrong status:

```dart
Future<void> fixAllBotStatuses() async {
  final firestore = FirebaseFirestore.instance;
  final rtdb = FirebaseDatabase.instance.ref();
  
  // Get all active schedules
  final activeSchedules = await firestore
      .collection('schedules')
      .where('status', isEqualTo: 'active')
      .get();
  
  for (final doc in activeSchedules.docs) {
    final schedule = doc.data();
    final botId = schedule['bot_id'];
    final scheduleId = doc.id;
    
    // Update RTDB
    await rtdb.child('bots/$botId').update({
      'status': 'active',
      'current_schedule_id': scheduleId,
      'last_updated': ServerValue.timestamp,
    });
    
    print('✅ Fixed bot $botId status');
  }
  
  print('✅ All bot statuses fixed!');
}
```

---

## Summary

**Root Cause**: RTDB bot `status` field is not being updated when schedules are activated/completed.

**Quick Fix**: Manually set `status` in RTDB or call `startSchedule()` to sync.

**Permanent Fix**: Ensure all schedule activations call `ScheduleService.startSchedule()` which updates both Firestore and RTDB.

**Verification**: Check RTDB bot node has `status` field with correct value, then app should update immediately.
