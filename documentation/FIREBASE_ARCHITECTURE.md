# AGOS App - Centralized Firebase Architecture

This document describes the centralized Firebase architecture that enables efficient data access, real-time updates, and easy aggregation for the AGOS river cleanup monitoring system.

---

## Architecture Overview

The AGOS app uses a **hybrid Firebase architecture** that combines:

1. **Firestore**: For persistent, queryable metadata and historical records
2. **Realtime Database (RTDB)**: For live telemetry, real-time status updates, and fast synchronization

This architecture enables:
- ✅ Real-time dashboard updates without excessive Firestore reads
- ✅ Efficient queries for historical data and reports
- ✅ Low-latency bot status monitoring
- ✅ Scalable data aggregation for analytics

---

## 1. Firestore Collections

### 1.1 `bots` Collection

**Purpose**: Stores persistent bot metadata and ownership information.

**Document Structure**:
```dart
{
  "id": "bot123",                          // Auto-generated document ID
  "name": "AGOS Bot #1",                   // Human-readable bot name
  "owner_admin_id": "user_uid",            // UID of the admin who owns this bot
  "assigned_to": "operator_uid",           // UID of assigned field operator (optional)
  "assigned_at": Timestamp,                // When the bot was assigned
  "organization_id": "org_id",             // Organization this bot belongs to
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

**Queries Used**:
- Get all bots owned by a user: `where('owner_admin_id', '==', userUID)`
- Get bots assigned to an operator: `where('assigned_to', '==', operatorUID)`

---

### 1.2 `schedules` Collection

**Purpose**: Stores deployment schedules with operation area and timing details.

**Document Structure**:
```dart
{
  "id": "schedule123",
  "name": "Morning Pasig Cleanup",
  "bot_id": "bot123",
  "bot_name": "AGOS Bot #1",
  "river_id": "river123",
  "river_name": "Pasig River",
  "owner_admin_id": "user_uid",
  "assigned_operator_id": "operator_uid",
  "assigned_operator_name": "John Doe",
  
  // Operation details
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
  
  // Schedule timing
  "scheduled_date": Timestamp,
  "scheduled_end_date": Timestamp,
  "status": "scheduled | active | completed | cancelled",
  "started_at": Timestamp,
  "completed_at": Timestamp,
  
  // Results (filled after completion)
  "trash_collected": 12.5,                 // in kg
  "area_cleaned_percentage": 85.0,
  "notes": "Successfully completed",
  
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

**Queries Used**:
- Get active schedules: `where('status', '==', 'active').where('owner_admin_id', '==', userUID)`
- Get schedules for a bot: `where('bot_id', '==', botId)`
- Get operator's schedules: `where('assigned_operator_id', '==', operatorUID)`

---

### 1.3 `deployments` Collection

**Purpose**: Stores completed deployment records with aggregated results and performance metrics.

**Document Structure**:
```dart
{
  "id": "deployment123",
  "schedule_id": "schedule123",
  "schedule_name": "Morning Pasig Cleanup",
  "bot_id": "bot123",
  "bot_name": "AGOS Bot #1",
  "river_id": "river123",
  "river_name": "Pasig River",
  "owner_admin_id": "user_uid",
  
  // Timeline
  "scheduled_start_time": Timestamp,
  "actual_start_time": Timestamp,
  "scheduled_end_time": Timestamp,
  "actual_end_time": Timestamp,
  "status": "scheduled | active | completed | cancelled",
  
  // Location
  "operation_lat": 14.5995,
  "operation_lng": 120.9842,
  "operation_radius": 500,
  "operation_location": "Manila, Philippines",
  
  // Water quality (aggregated from RTDB readings)
  "water_quality": {
    "avg_ph_level": 7.2,
    "avg_turbidity": 15.3,
    "avg_temperature": 28.5,
    "avg_dissolved_oxygen": 6.8,
    "sample_count": 150
  },
  
  // Trash collection (aggregated)
  "trash_collection": {
    "trash_by_type": {
      "plastic": 50,
      "paper": 30,
      "metal": 10,
      "organic": 60
    },
    "total_weight": 12.5,                  // in kg
    "total_items": 150
  },
  
  // Detailed trash items (optional, for detailed analysis)
  "trash_items": [
    {
      "classification": "plastic_bottle",
      "confidence_level": 0.95,
      "collected_at": Timestamp,
      "weight": 0.05
    }
  ],
  
  // Performance metrics
  "area_covered_percentage": 85.0,
  "distance_traveled": 1250.5,             // in meters
  "duration_minutes": 120,
  "notes": "Successfully completed",
  
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

**Queries Used**:
- Get today's completed deployments: 
  ```dart
  where('owner_admin_id', '==', userUID)
  .where('status', '==', 'completed')
  .where('actual_end_time', '>=', startOfDay)
  .where('actual_end_time', '<', endOfDay)
  ```
- Get deployments for a river: `where('river_id', '==', riverId)`
- Get deployment history: `orderBy('actual_end_time', descending: true)`

---

### 1.4 `rivers` Collection

**Purpose**: Stores river metadata and monitoring analytics.

**Document Structure**:
```dart
{
  "id": "river123",
  "name": "Pasig River",
  "description": "Major river in Metro Manila",
  "owner_admin_id": "user_uid",
  "organization_id": "org_id",
  
  // Aggregated stats
  "total_deployments": 45,
  "active_deployments": 2,
  "total_trash_collected": 580.5,          // Total kg collected all-time
  "last_deployment": Timestamp,
  
  // Location bounds (optional, for map display)
  "bounds": {
    "north": 14.6000,
    "south": 14.5000,
    "east": 121.0000,
    "west": 120.9000
  },
  
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

---

### 1.5 `users` Collection

**Purpose**: Stores user profiles, roles, and permissions.

**Document Structure**:
```dart
{
  "id": "user_uid",
  "email": "user@example.com",
  "display_name": "John Doe",
  "role": "admin | field_operator | viewer",
  "is_admin": true,
  "organization_id": "org_id",
  "profile_photo_url": "https://...",
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

---

### 1.6 `organizations` Collection

**Purpose**: Stores organization/company information for multi-tenant support.

**Document Structure**:
```dart
{
  "id": "org123",
  "name": "AGOS Manila",
  "description": "River cleanup organization",
  "owner_id": "user_uid",
  "members": ["user1", "user2"],
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

---

### 1.7 `logs` Collection

**Purpose**: Audit trail for control operations and system events.

**Document Structure**:
```dart
{
  "id": "log123",
  "type": "bot_control | schedule_created | deployment_completed",
  "bot_id": "bot123",
  "user_id": "user_uid",
  "action": "manual_control_acquired",
  "details": { ... },
  "timestamp": Timestamp
}
```

---

## 2. Realtime Database (RTDB) Structure

### 2.1 `bots/{botId}` Node

**Purpose**: Live bot telemetry, status, and sensor data updated frequently by the bot devices.

**Data Structure**:
```json
{
  "bots": {
    "bot123": {
      // Location
      "lat": 14.5995,
      "lng": 120.9842,
      
      // Status
      "status": "active | idle | deployed | recalling | maintenance",
      "active": true,
      "battery": 85,
      
      // Current schedule/deployment
      "current_schedule_id": "schedule123",
      "current_deployment_id": "deployment123",
      
      // Water quality sensors (updated every few seconds)
      "temp": 28.5,                        // Celsius
      "ph_level": 7.2,                     // 0-14
      "turbidity": 12.3,                   // NTU
      "dissolved_oxygen": 6.8,             // mg/L
      
      // Trash collection (live counters)
      "trash_collected": 8.4,              // Total kg collected in current session
      "current_load": 3.2,                 // Current load in kg
      "max_load": 10.0,                    // Max capacity in kg
      "trash_count": 145,                  // Number of items collected
      
      // Navigation
      "speed": 1.2,                        // m/s
      "heading": 270,                      // degrees
      
      // Timestamps
      "last_updated": 1234567890000        // Unix timestamp in milliseconds
    }
  }
}
```

**Update Frequency**: Every 1-5 seconds (depending on sensor type)

**Listeners**: Dashboard, monitoring page, live feed

---

### 2.2 `control_locks/{botId}` Node

**Purpose**: Manages bot control locking to ensure only one operator controls a bot at a time.

**Data Structure**:
```json
{
  "control_locks": {
    "bot123": {
      "locked_by": "user_uid",
      "locked_at": 1234567890000,
      "expires_at": 1234567890000,
      "session_id": "session123"
    }
  }
}
```

**TTL**: Locks automatically expire after 5 minutes of inactivity.

---

### 2.3 `deployments/{deploymentId}/readings` Node (Optional)

**Purpose**: Time-series telemetry data collected during deployments for detailed analysis.

**Data Structure**:
```json
{
  "deployments": {
    "deployment123": {
      "readings": {
        "1234567890000": {
          "lat": 14.5995,
          "lng": 120.9842,
          "battery": 85,
          "temp": 28.5,
          "ph_level": 7.2,
          "turbidity": 12.3,
          "trash_collected": 8.4
        },
        "1234567895000": {
          // Next reading 5 seconds later
        }
      }
    }
  }
}
```

**Note**: This is optional and can be aggregated to Firestore upon deployment completion to save storage.

---

## 3. Data Flow & Synchronization

### 3.1 Bot Status & Telemetry Flow

```
Bot Device (Hardware/Simulator)
    ↓ (Every 1-5 seconds)
RTDB: bots/{botId}
    ↓ (Real-time listener)
Flutter App (Dashboard, Monitoring)
    ↓ (Display live data)
User Interface
```

**Implementation**:
- Bot devices write directly to RTDB `bots/{botId}` path
- Flutter app listens to RTDB for instant updates
- No Firestore reads needed for live telemetry → **Cost-efficient**

---

### 3.2 Schedule & Deployment Lifecycle

```
1. Schedule Created (Firestore)
   ↓
2. Schedule Activated → status = 'active'
   ↓
3. Deployment Document Created (Firestore)
   ↓
4. Bot Updates RTDB with Live Telemetry
   ↓
5. Deployment Completes → Aggregate RTDB Data
   ↓
6. Update Deployment Document (Firestore) with Results
   ↓
7. Update River Stats (Firestore)
```

**Implementation**:
- Schedules managed in Firestore
- When activated, create deployment document
- Bot writes live data to RTDB
- Cloud Function or client aggregates RTDB data upon completion
- Store summary in Firestore deployment document

---

### 3.3 Dashboard Data Queries

#### Active Deployments Widget

```dart
// Query Firestore for active schedules
schedules
  .where('status', isEqualTo: 'active')
  .where('owner_admin_id', isEqualTo: currentUser.uid)
  .snapshots()
  
// For each schedule, fetch live bot data from RTDB
FirebaseDatabase.instance.ref('bots/${schedule.botId}').get()

// Combine Firestore metadata + RTDB telemetry
// → Display in UI
```

#### Overview Stats Cards

```dart
// Total Bots
bots.where('owner_admin_id', '==', userUID).get().length

// Active Bots
schedules.where('status', '==', 'active').get().length

// Total Trash Today
deployments
  .where('owner_admin_id', '==', userUID)
  .where('status', '==', 'completed')
  .where('actual_end_time', '>=', startOfDay)
  .get()
  .sum(deployment.trash_collection.total_weight)

// Rivers Monitored Today
deployments (today).uniqueRiverIds.count
```

---

## 4. Provider Architecture (Flutter)

### 4.1 Dashboard Providers

**Location**: `lib/features/dashboard/providers/dashboard_provider.dart`

```dart
// Stream provider for active deployments (real-time)
final activeDeploymentsStreamProvider = StreamProvider<List<ActiveDeploymentInfo>>((ref) {
  // 1. Listen to Firestore schedules
  // 2. For each schedule, fetch RTDB bot data
  // 3. Combine and return list
});

// Future provider for dashboard stats
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  // Query Firestore for aggregated stats
  // Return DashboardStats model
});
```

### 4.2 Data Models

**Location**: `lib/core/models/`

- `bot_model.dart`: Bot metadata (Firestore) + telemetry (RTDB)
- `schedule_model.dart`: Schedule metadata
- `deployment_model.dart`: Deployment with aggregated results
- `active_deployment_info.dart`: Combined schedule + live bot data for dashboard

---

## 5. Best Practices & Recommendations

### 5.1 Data Sync Strategy

✅ **Use RTDB for**:
- Live telemetry (sensor readings, GPS, battery)
- Real-time status updates
- Control locking
- High-frequency data (> 1 update/second)

✅ **Use Firestore for**:
- Metadata and configuration
- User profiles and permissions
- Historical records and reports
- Queryable data (filters, ordering)
- Data that needs complex queries

---

### 5.2 Cost Optimization

✅ **Minimize Firestore Reads**:
- Cache schedule/bot metadata locally
- Use RTDB for live data instead of Firestore snapshots
- Implement pagination for large lists

✅ **Aggregate Data**:
- Store summarized results in deployment documents
- Update river stats in batch (not per-reading)
- Use Cloud Functions for server-side aggregation

✅ **Use Firestore Offline Persistence**:
```dart
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

---

### 5.3 Security Rules

**Firestore Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /schedules/{scheduleId} {
      allow read: if request.auth != null && 
                     resource.data.owner_admin_id == request.auth.uid;
      allow write: if request.auth != null && 
                      request.resource.data.owner_admin_id == request.auth.uid;
    }
    
    match /bots/{botId} {
      allow read: if request.auth != null && 
                     resource.data.owner_admin_id == request.auth.uid;
      allow write: if request.auth != null && 
                      request.resource.data.owner_admin_id == request.auth.uid;
    }
    
    match /deployments/{deploymentId} {
      allow read: if request.auth != null && 
                     resource.data.owner_admin_id == request.auth.uid;
      allow write: if request.auth != null;
    }
  }
}
```

**RTDB Rules**:
```json
{
  "rules": {
    "bots": {
      "$botId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "control_locks": {
      "$botId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

---

## 6. Future Enhancements

### 6.1 Cloud Functions Integration

- **Auto-aggregate deployment data**: Triggered on deployment completion
- **Update river statistics**: Batch update river stats when deployment completes
- **Generate reports**: Scheduled function to generate daily/weekly reports
- **Send notifications**: Alert users of low battery, high trash load, etc.

### 6.2 Analytics & Machine Learning

- Store time-series RTDB data for ML training
- Predict optimal cleanup times based on historical data
- Classify trash types with higher accuracy
- Generate water quality reports and trends

---

## 7. Migration from Mock Data

The dashboard has been updated to use real data from Firebase:

✅ **Completed**:
- Extended `ActiveDeploymentInfo` model with sensor fields
- Updated `activeDeploymentsStreamProvider` to fetch RTDB telemetry
- Implemented `dashboardStatsProvider` for real-time statistics
- Replaced mock data in `dashboard_page.dart` with provider data

✅ **Next Steps** (if needed):
- Implement Recent Activity from Firestore logs
- Add real-time notifications for critical events
- Create deployment history page with charts
- Build admin analytics dashboard

---

## Summary

This architecture provides:
- ✅ **Real-time updates** via RTDB for live telemetry
- ✅ **Efficient queries** via Firestore for historical data
- ✅ **Cost optimization** by minimizing Firestore reads
- ✅ **Scalability** for multiple users, bots, and rivers
- ✅ **Flexibility** to add new features without restructuring

For troubleshooting, refer to `FIREBASE_DASHBOARD_DEBUG_GUIDE.md`.
