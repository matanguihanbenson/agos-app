# Firebase Dashboard Debug Guide

This guide helps you verify your Firebase Firestore and Realtime Database (RTDB) structure and troubleshoot data access issues for the AGOS dashboard.

## Overview

The dashboard displays real-time data from:
- **Firestore**: Persistent metadata (schedules, bots, deployments, rivers)
- **RTDB**: Live telemetry (sensor readings, battery, location, trash collection)

## Prerequisites

Before debugging, ensure:
1. Firebase project is properly configured in your Flutter app
2. User is authenticated and has a valid UID
3. Firebase security rules allow read access to the collections

---

## Step 1: Verify Firestore Collections

### 1.1 Check Schedules Collection

**Path**: `firestore/schedules`

**Required fields for active schedules**:
```json
{
  "id": "schedule_doc_id",
  "name": "Morning Cleanup",
  "status": "active",                    // MUST be exactly "active" (case-sensitive)
  "owner_admin_id": "user_uid",          // MUST match logged-in user's UID
  "bot_id": "bot123",
  "bot_name": "AGOS Bot #1",
  "river_id": "river123",
  "river_name": "Pasig River",
  "operation_area": {
    "center": {
      "latitude": 14.5995,
      "longitude": 120.9842,
      "location_name": "Manila, Philippines"
    },
    "radius_in_meters": 500,
    "location_name": "Manila, Philippines"
  },
  "docking_point": {
    "latitude": 14.5995,
    "longitude": 120.9842
  },
  "scheduled_date": "Timestamp",
  "created_at": "Timestamp",
  "updated_at": "Timestamp"
}
```

**How to verify**:
```javascript
// In Firebase Console > Firestore
1. Navigate to 'schedules' collection
2. Filter documents where:
   - status == 'active'
   - owner_admin_id == YOUR_USER_UID
3. Ensure at least one document exists with these conditions
```

### 1.2 Check Bots Collection

**Path**: `firestore/bots`

**Required fields**:
```json
{
  "id": "bot123",
  "name": "AGOS Bot #1",
  "owner_admin_id": "user_uid",
  "assigned_to": "operator_uid",
  "organization_id": "org_id",
  "created_at": "Timestamp",
  "updated_at": "Timestamp"
}
```

### 1.3 Check Deployments Collection (for stats)

**Path**: `firestore/deployments`

**Required fields for completed deployments**:
```json
{
  "id": "deployment_doc_id",
  "schedule_id": "schedule_id",
  "bot_id": "bot123",
  "river_id": "river123",
  "owner_admin_id": "user_uid",
  "status": "completed",
  "actual_start_time": "Timestamp",
  "actual_end_time": "Timestamp",
  "trash_collection": {
    "total_weight": 12.5,              // in kg
    "total_items": 150,
    "trash_by_type": {
      "plastic": 50,
      "paper": 30
    }
  },
  "water_quality": {
    "avg_ph_level": 7.2,
    "avg_turbidity": 15.3,
    "avg_temperature": 28.5,
    "sample_count": 100
  }
}
```

---

## Step 2: Verify Realtime Database (RTDB)

### 2.1 Check Bot Telemetry Node

**Path**: `rtdb/bots/{botId}`

**Required fields**:
```json
{
  "lat": 14.5995,                       // Numeric latitude
  "lng": 120.9842,                      // Numeric longitude
  "battery": 85,                        // Integer 0-100
  "status": "active",                   // "active", "idle", "deployed", "recalling"
  "active": true,                       // Boolean
  
  // Water quality sensors
  "temp": 28.5,                         // Temperature in Celsius
  "ph_level": 7.2,                      // pH level 0-14
  "turbidity": 12.3,                    // Turbidity in NTU
  
  // Trash collection metrics
  "trash_collected": 8.4,               // Total trash collected (kg)
  "current_load": 3.2,                  // Current load in kg
  "max_load": 10.0,                     // Max capacity in kg
  
  "last_updated": 1234567890000         // Timestamp in milliseconds
}
```

**How to verify**:
```javascript
// In Firebase Console > Realtime Database
1. Navigate to the 'bots' node
2. Find the bot ID referenced in your active schedule
3. Verify all required numeric fields exist and have valid values
4. Check that lat/lng are actual numbers (not strings)
```

---

## Step 3: Debugging Common Issues

### Issue 1: "No active deployments" shown on dashboard

**Possible causes**:
1. ✅ No schedules with `status: "active"` exist
2. ✅ Active schedules exist but `owner_admin_id` doesn't match logged-in user
3. ✅ Status field is not exactly "active" (check for typos, capitalization)
4. ✅ User is not authenticated

**How to fix**:
```dart
// Check authentication
print('Current User UID: ${FirebaseAuth.instance.currentUser?.uid}');

// Check schedules query
FirebaseFirestore.instance
  .collection('schedules')
  .where('status', isEqualTo: 'active')
  .where('owner_admin_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
  .get()
  .then((snapshot) {
    print('Active schedules count: ${snapshot.docs.length}');
    for (var doc in snapshot.docs) {
      print('Schedule: ${doc.id} - ${doc.data()}');
    }
  });
```

### Issue 2: Active deployment cards show 0.0 for sensor readings

**Possible causes**:
1. ✅ Bot node doesn't exist in RTDB at `bots/{botId}`
2. ✅ Bot ID in schedule doesn't match bot ID in RTDB
3. ✅ Sensor fields are missing or have null values in RTDB
4. ✅ Field names don't match expected names (e.g., `ph` vs `ph_level`)

**How to fix**:
```dart
// Check bot data in RTDB
final botId = 'bot123'; // Replace with actual bot ID from schedule
FirebaseDatabase.instance.ref('bots/$botId').get().then((snapshot) {
  if (snapshot.exists) {
    print('Bot data: ${snapshot.value}');
  } else {
    print('Bot node does not exist in RTDB');
  }
});
```

### Issue 3: Stats cards show 0 for all values

**Possible causes**:
1. ✅ No bots registered under current user
2. ✅ No completed deployments for today
3. ✅ `owner_admin_id` mismatch in bots/deployments collection
4. ✅ Firestore security rules blocking read access

**How to fix**:
```dart
// Check total bots
FirebaseFirestore.instance
  .collection('bots')
  .where('owner_admin_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
  .get()
  .then((snapshot) {
    print('Total bots: ${snapshot.docs.length}');
  });

// Check today's deployments
final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
final endOfDay = startOfDay.add(const Duration(days: 1));

FirebaseFirestore.instance
  .collection('deployments')
  .where('owner_admin_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
  .where('status', isEqualTo: 'completed')
  .where('actual_end_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
  .where('actual_end_time', isLessThan: Timestamp.fromDate(endOfDay))
  .get()
  .then((snapshot) {
    print('Completed deployments today: ${snapshot.docs.length}');
  });
```

### Issue 4: "Error loading deployments" shown

**Possible causes**:
1. ✅ Firebase not initialized properly
2. ✅ Network connection issues
3. ✅ Security rules denying access
4. ✅ Malformed data causing parsing errors

**How to fix**:
1. Check Flutter console for detailed error messages
2. Verify Firebase security rules allow read access:
   ```javascript
   // Firestore Security Rules
   match /schedules/{scheduleId} {
     allow read: if request.auth != null && 
                    resource.data.owner_admin_id == request.auth.uid;
   }
   
   match /bots/{botId} {
     allow read: if request.auth != null && 
                    resource.data.owner_admin_id == request.auth.uid;
   }
   
   // RTDB Security Rules
   {
     "rules": {
       "bots": {
         "$botId": {
           ".read": "auth != null"
         }
       }
     }
   }
   ```

---

## Step 4: Test Data Setup

### Create Test Schedule in Firestore

Use Firebase Console or this code to create a test schedule:

```dart
await FirebaseFirestore.instance.collection('schedules').add({
  'name': 'Test Morning Cleanup',
  'status': 'active',
  'owner_admin_id': FirebaseAuth.instance.currentUser!.uid,
  'bot_id': 'test_bot_001',
  'bot_name': 'Test AGOS Bot #1',
  'river_id': 'test_river_001',
  'river_name': 'Test Pasig River',
  'operation_area': {
    'center': {
      'latitude': 14.5995,
      'longitude': 120.9842,
      'location_name': 'Manila, Philippines'
    },
    'radius_in_meters': 500,
    'location_name': 'Manila, Philippines'
  },
  'docking_point': {
    'latitude': 14.5995,
    'longitude': 120.9842,
  },
  'scheduled_date': Timestamp.now(),
  'created_at': Timestamp.now(),
  'updated_at': Timestamp.now(),
});
```

### Create Test Bot Data in RTDB

```dart
await FirebaseDatabase.instance.ref('bots/test_bot_001').set({
  'lat': 14.5995,
  'lng': 120.9842,
  'battery': 85,
  'status': 'active',
  'active': true,
  'temp': 28.5,
  'ph_level': 7.2,
  'turbidity': 12.3,
  'trash_collected': 8.4,
  'current_load': 3.2,
  'max_load': 10.0,
  'last_updated': DateTime.now().millisecondsSinceEpoch,
});
```

---

## Step 5: Monitor Real-time Updates

### Enable Debug Logging

Add this to your main app initialization:

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Enable Firestore logging
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  runApp(const MyApp());
}
```

### Watch Provider State Changes

```dart
// In your dashboard page, add logging
@override
Widget build(BuildContext context) {
  final activeDeploymentsAsync = ref.watch(activeDeploymentsStreamProvider);
  
  activeDeploymentsAsync.whenData((deployments) {
    print('Dashboard: ${deployments.length} active deployments loaded');
    for (var deployment in deployments) {
      print('  - ${deployment.riverName}: battery=${deployment.battery}, temp=${deployment.temperature}');
    }
  });
  
  // ... rest of build method
}
```

---

## Expected Data Flow

1. **User logs in** → User UID available
2. **Dashboard loads** → `activeDeploymentsStreamProvider` queries Firestore
3. **Firestore query** → Fetches schedules where `status='active'` and `owner_admin_id=userUID`
4. **For each schedule** → Queries RTDB at `bots/{botId}` for real-time telemetry
5. **Combines data** → Creates `ActiveDeploymentInfo` objects with both Firestore and RTDB data
6. **Dashboard displays** → Real-time sensor readings, battery, location, etc.

---

## Checklist for Successful Dashboard Display

- [ ] User is authenticated (check Firebase Auth console)
- [ ] At least one schedule exists with `status: "active"`
- [ ] Schedule's `owner_admin_id` matches logged-in user's UID
- [ ] Schedule has valid `bot_id`, `river_id`, `bot_name`, `river_name`
- [ ] RTDB has a node at `bots/{bot_id}` matching the schedule's bot_id
- [ ] Bot node has numeric `lat`, `lng`, `battery` fields
- [ ] Bot node has sensor fields: `temp`, `ph_level`, `turbidity`
- [ ] Firebase security rules allow read access
- [ ] No console errors in Flutter debug output

---

## Contact Support

If issues persist after following this guide:
1. Export your Firestore schedule document as JSON
2. Export your RTDB bot node as JSON
3. Share your Firebase security rules
4. Include Flutter console error logs
5. Confirm your logged-in user's UID

This will help diagnose the specific issue with your Firebase configuration.
