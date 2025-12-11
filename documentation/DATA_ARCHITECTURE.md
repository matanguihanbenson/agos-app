# Centralized Data Architecture & Reporting Strategy

## Overview

This document outlines a centralized data structure for all reports and dashboards, maximizing the use of existing Firestore collections and RTDB paths while minimizing redundancy.

---

## 🎯 Core Principle

**Single Source of Truth (SSOT)**: Each piece of data lives in ONE place and is referenced everywhere else.

---

## 📊 Data Flow

```
Schedules (Firestore) 
    ↓ (when activated)
Deployments (Firestore) + RTDB bots/{botId}
    ↓ (real-time data)
RTDB deployments/{deploymentId}/readings
    ↓ (when completed)
Deployments (Firestore) - updated with summary
    ↓ (aggregation)
Rivers (Firestore) - analytics updated
```

---

## 🗄️ Firestore Collections (Permanent Storage)

### 1. **`bots`** Collection
**Purpose**: Bot metadata and configuration  
**Source of Truth for**: Bot info, ownership, assignment

```javascript
bots/{botId}
{
  // Metadata
  name: string,
  bot_id: string,
  owner_admin_id: string,
  assigned_to: string | null,
  assigned_at: timestamp | null,
  organization_id: string,
  
  // Static info (from Firestore only)
  created_at: timestamp,
  updated_at: timestamp,
  
  // Note: Real-time data (status, battery, location, etc.) 
  // is ONLY in RTDB bots/{botId}, NOT duplicated here
}
```

### 2. **`schedules`** Collection  
**Purpose**: Planned cleanup operations  
**Source of Truth for**: Schedule configuration, timeline

```javascript
schedules/{scheduleId}
{
  name: string,
  bot_id: string,
  bot_name: string,  // Denormalized for display
  river_id: string,
  river_name: string,  // Denormalized for display
  owner_admin_id: string,
  assigned_operator_id: string | null,
  assigned_operator_name: string | null,
  
  // Operation details
  operation_area: {
    center: { latitude: number, longitude: number },
    radius_in_meters: number,
    location_name: string
  },
  docking_point: { latitude: number, longitude: number },
  
  // Timeline
  scheduled_date: timestamp,
  scheduled_end_date: timestamp,
  status: 'scheduled' | 'active' | 'completed' | 'cancelled',
  started_at: timestamp | null,
  completed_at: timestamp | null,
  
  // Summary (filled after completion)
  trash_collected: number | null,  // kg
  area_cleaned_percentage: number | null,
  notes: string | null,
  
  created_at: timestamp,
  updated_at: timestamp
}
```

**Status Flow**:
- `scheduled` → `active` (when deployment starts)
- `active` → `completed` (when deployment completes)
- Any → `cancelled` (if cancelled)

### 3. **`deployments`** Collection
**Purpose**: Actual cleanup operations and results  
**Source of Truth for**: Deployment execution, collected data, summaries

```javascript
deployments/{deploymentId}
{
  // References
  schedule_id: string,
  schedule_name: string,  // Denormalized
  bot_id: string,
  bot_name: string,  // Denormalized
  river_id: string,
  river_name: string,  // Denormalized
  owner_admin_id: string,
  
  // Timeline
  scheduled_start_time: timestamp,
  actual_start_time: timestamp | null,
  scheduled_end_time: timestamp,
  actual_end_time: timestamp | null,
  status: 'scheduled' | 'active' | 'completed' | 'cancelled',
  
  // Operation area (copied from schedule)
  operation_lat: number,
  operation_lng: number,
  operation_radius: number,
  operation_location: string | null,
  
  // COLLECTED DATA (aggregated from RTDB on completion)
  water_quality: {
    avg_ph_level: number,
    avg_turbidity: number,
    avg_temperature: number,
    avg_dissolved_oxygen: number,
    sample_count: number
  } | null,
  
  trash_collection: {
    trash_by_type: { [classification: string]: count },
    total_weight: number,  // kg
    total_items: number
  } | null,
  
  trash_items: [  // Detailed items
    {
      classification: string,
      confidence_level: number,
      collected_at: timestamp,
      weight: number | null
    }
  ] | null,
  
  // Performance metrics
  area_covered_percentage: number | null,
  distance_traveled: number | null,  // meters
  duration_minutes: number | null,
  
  notes: string | null,
  created_at: timestamp,
  updated_at: timestamp
}
```

### 4. **`rivers`** Collection
**Purpose**: River metadata and aggregated analytics  
**Source of Truth for**: River info, deployment counts, total trash

```javascript
rivers/{riverId}
{
  name: string,
  name_lower: string,  // For search
  description: string | null,
  owner_admin_id: string,
  organization_id: string | null,
  created_by: string,
  
  // AGGREGATED ANALYTICS (updated after each deployment)
  total_deployments: number,
  active_deployments: number,
  total_trash_collected: number,  // kg - lifetime total
  last_deployment: timestamp | null,
  
  created_at: timestamp,
  updated_at: timestamp
}
```

### 5. **`users`** Collection
**Purpose**: User profiles  
**Source of Truth for**: User info

```javascript
users/{userId}
{
  first_name: string,
  last_name: string,
  email: string,
  role: 'admin' | 'field_operator',
  status: 'active' | 'inactive',
  organization_id: string | null,
  created_at: timestamp,
  updated_at: timestamp
}
```

---

## ⚡ Firebase RTDB (Real-Time Data)

### 1. **`bots/{botId}`** - Real-Time Telemetry
**Purpose**: Live bot status, telemetry, location  
**Source of Truth for**: Current real-time data ONLY

```javascript
bots/{botId}
{
  // Real-time status
  status: 'idle' | 'deployed' | 'active' | 'scheduled' | 'recalling' | 'maintenance',
  active: boolean,
  
  // Live telemetry
  battery: number,  // 0-100
  lat: number,
  lng: number,
  
  // Water quality (live)
  ph_level: number | null,
  temp: number | null,
  turbidity: number | null,
  
  // Trash (live)
  trash_collected: number | null,  // Current session kg
  
  // Current operation
  current_deployment_id: string | null,
  current_schedule_id: string | null,
  
  // Metadata
  last_updated: number  // Unix timestamp in ms
}
```

**Note**: This data is TEMPORARY and LIVE. It's mirrored to Firestore deployments collection only when deployment completes.

### 2. **`deployments/{deploymentId}/readings/{timestamp}`** - Telemetry History
**Purpose**: Time-series sensor readings during deployment  
**Lifecycle**: Created during active deployment, kept for historical analysis

```javascript
deployments/{deploymentId}/readings/{timestamp}
{
  ts: number,  // Unix timestamp in ms
  ph_level: number | null,
  turbidity: number | null,
  temp: number | null,
  trash_collected: number | null,  // Cumulative
  battery_level: number | null,
  lat: number | null,
  lng: number | null
}
```

**Note**: These readings are aggregated into `deployments` collection (Firestore) when deployment completes.

### 3. **`control_locks/{botId}`** - Control State
**Purpose**: Bot control locking mechanism  
**Lifecycle**: Temporary, 60-second TTL

```javascript
control_locks/{botId}
{
  uid: string,
  name: string,
  role: string,
  sessionId: string,
  startedAt: number,
  lastSeen: number,
  expiresAt: number,
  takeover: {
    requestedByUid: string,
    requestedByName: string,
    requestedAt: number,
    executeAt: number
  } | null
}
```

---

## 📈 Dashboard Data Sources

### Dashboard: **Live River Deployments** Widget

**Data Source**: Mix of Firestore and RTDB

```dart
// Query active schedules from Firestore
schedules (Firestore)
  .where('status', '==', 'active')
  .where('owner_admin_id', '==', currentUser.id)

// For each active schedule, get live data from RTDB
For each schedule:
  bots/{schedule.bot_id} (RTDB) → Get real-time lat, lng, status, battery
```

**Why this works**:
- Schedules in Firestore tell us WHICH operations are active
- RTDB bots tell us WHERE the bots are right now
- No duplication, clean separation

### Dashboard: **Overview Stats** Widget

**For Admin Dashboard**:

```dart
// Total Bots
bots (Firestore)
  .where('owner_admin_id', '==', currentUser.id)
  .count()

// Active Bots (bots currently on a deployment)
// Option 1: Query RTDB
bots/* (RTDB)
  .where('current_deployment_id', '!=', null)
  .where(owner matches) // Need to join with Firestore

// Option 2: Query Firestore schedules (RECOMMENDED)
schedules (Firestore)
  .where('status', '==', 'active')
  .where('owner_admin_id', '==', currentUser.id)
  .count()

// Total Trash Collected Today
deployments (Firestore)
  .where('owner_admin_id', '==', currentUser.id)
  .where('actual_start_time', '>=', todayStart)
  .where('actual_start_time', '<=', todayEnd)
  .get()
→ Sum up trash_collection.total_weight

// Rivers Monitored Today
deployments (Firestore)
  .where('owner_admin_id', '==', currentUser.id)
  .where('actual_start_time', '>=', todayStart)
  .where('actual_start_time', '<=', todayEnd)
  .get()
→ Get unique river_id count
```

### Monitoring Page

**Data Source**: RTDB + Firestore

```dart
// Get all active bots with real-time data
bots (RTDB) → Listen to all bots with current_deployment_id != null

// Enrich with Firestore data
For each active bot:
  deployments/{current_deployment_id} (Firestore) → Get schedule info, river name
```

### Schedule Details: Cleanup Summary

**Data Source**: Firestore deployments collection

```dart
// Get deployment linked to this schedule
deployments (Firestore)
  .where('schedule_id', '==', scheduleId)
  .limit(1)
  .get()

// Display:
- trash_collection.total_weight
- trash_collection.trash_by_type
- water_quality averages
- area_covered_percentage
```

### Deployment Details: Summary

**Data Source**: Firestore deployments collection

```dart
// Get specific deployment
deployments/{deploymentId} (Firestore).get()

// Display all summary data from deployment document
```

### Rivers Management

**Data Source**: Firestore rivers collection

```dart
// Get all rivers with analytics
rivers (Firestore)
  .where('owner_admin_id', '==', currentUser.id)
  .get()

// Display:
- total_deployments (already aggregated in river doc)
- active_deployments (already aggregated)
- total_trash_collected (already aggregated)
- last_deployment (already stored)
```

### Live Feed

**Data Source**: RTDB

```dart
// Listen to live telemetry
bots/{botId} (RTDB) → Real-time lat, lng, status, battery, etc.

// If deployment is active:
deployments/{deployment_id}/readings/* (RTDB) → Time-series data
```

---

## 🔄 Data Lifecycle & Updates

### When Schedule is Created:
```
1. Create document in schedules (Firestore)
   status: 'scheduled'
```

### When Schedule Activates (Deployment Starts):
```
1. Update schedule (Firestore):
   status: 'active'
   started_at: now

2. Create deployment (Firestore):
   status: 'active'
   actual_start_time: now
   (Copy all relevant data from schedule)

3. Update bot RTDB:
   bots/{botId}/status: 'active'
   bots/{botId}/current_deployment_id: deploymentId
   bots/{botId}/current_schedule_id: scheduleId

4. Update river (Firestore):
   active_deployments: +1
```

### During Deployment (Real-Time):
```
1. Bot sends telemetry to RTDB:
   bots/{botId}/* → Updated continuously

2. RealtimeBotService mirrors readings to RTDB:
   deployments/{deploymentId}/readings/{timestamp}
   (Every 15 seconds while active)
```

### When Deployment Completes:
```
1. Aggregate RTDB readings:
   - Calculate averages (pH, turbidity, temp, etc.)
   - Sum trash collected
   - Count items by type

2. Update deployment (Firestore):
   status: 'completed'
   actual_end_time: now
   water_quality: { aggregated data }
   trash_collection: { aggregated data }
   trash_items: [ detailed items ]
   duration_minutes: calculated
   area_covered_percentage: calculated

3. Update schedule (Firestore):
   status: 'completed'
   completed_at: now
   trash_collected: total kg
   area_cleaned_percentage: calculated

4. Update bot RTDB:
   bots/{botId}/status: 'idle'
   bots/{botId}/current_deployment_id: null
   bots/{botId}/current_schedule_id: null

5. Update river (Firestore):
   total_deployments: +1
   active_deployments: -1
   total_trash_collected: + deployment trash
   last_deployment: now

6. OPTIONAL: Clean up old RTDB readings
   deployments/{deploymentId}/readings/* 
   (Keep for 30 days, then delete for storage savings)
```

---

## 📊 Aggregation Strategy

### Option 1: **Real-Time Aggregation** (Current Approach)
**When**: On deployment completion  
**How**: Cloud Function or app logic reads RTDB readings, calculates aggregates, writes to Firestore

**Pros**:
- Simple
- Works with your current setup
- No additional infrastructure

**Cons**:
- Aggregation happens in app
- Limited by client device performance

### Option 2: **Cloud Function Aggregation** (Recommended for Production)
**When**: Triggered on deployment status change to 'completed'  
**How**: Cloud Function automatically aggregates RTDB data

```javascript
// Cloud Function pseudo-code
exports.onDeploymentComplete = functions.firestore
  .document('deployments/{deploymentId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    
    if (after.status === 'completed' && !after.water_quality) {
      // Aggregate RTDB readings
      const readings = await rtdb.ref(`deployments/${deploymentId}/readings`).once('value');
      const aggregated = aggregateReadings(readings.val());
      
      // Update Firestore deployment
      await change.after.ref.update({
        water_quality: aggregated.waterQuality,
        trash_collection: aggregated.trashCollection,
        // ... other aggregated data
      });
      
      // Update river analytics
      await updateRiverAnalytics(after.river_id, aggregated);
    }
  });
```

---

## 🎯 Implementation Plan

### Phase 1: Use Existing Structure (Immediate)
✅ **Schedules** → Already in Firestore  
✅ **Deployments** → Already in Firestore  
✅ **RTDB bots** → Already exists  
✅ **RTDB deployments/readings** → Already being written by RealtimeBotService

**What to do**:
1. Ensure deployments are created when schedules activate
2. Ensure RTDB readings are mirrored during active deployments
3. Ensure aggregation happens on completion

### Phase 2: Dashboard Queries (Next)
1. **Live River Deployments**:
   - Query: `schedules.where('status == active')`
   - For each: Listen to `RTDB bots/{bot_id}`

2. **Overview Stats**:
   - Total Bots: Count `bots` collection
   - Active Bots: Count `schedules.where('status == active')`
   - Trash Today: Aggregate `deployments.where('actual_start_time >= today')`
   - Rivers Today: Unique river_ids from today's deployments

3. **Monitoring Page**:
   - Listen to `RTDB bots/*` where bot has `current_deployment_id`
   - Enrich with deployment info from Firestore

### Phase 3: River Analytics (Ongoing)
- Update `rivers.total_deployments` when deployment completes
- Update `rivers.active_deployments` when deployment starts/ends
- Update `rivers.total_trash_collected` when deployment completes

---

## 💡 Key Decisions Made

### ✅ **YES - Keep Schedules and Deployments Separate**
**Why**:
- Schedule = PLAN (what you want to do)
- Deployment = EXECUTION (what actually happened)
- One schedule can have multiple deployment attempts
- Historical data integrity

### ✅ **YES - Use RTDB for Live Data Only**
**Why**:
- Real-time updates are fast
- Automatic cleanup (can set TTL)
- Scales well for telemetry
- Firestore for permanent records

### ✅ **YES - Aggregate on Completion**
**Why**:
- Don't store duplicate data
- RTDB readings are temporary
- Firestore deployment gets final summary
- Can always re-aggregate if needed

### ✅ **YES - Denormalize Display Names**
**Why**:
- Faster queries (no joins)
- Better offline experience
- Names rarely change
- If name changes, can update in batch

### ✅ **YES - Use Existing Collections**
**Why**:
- Your structure is already good!
- Minimal changes needed
- Just need better aggregation
- Add computed fields to rivers

---

## 📝 Summary

### Data Sources:
| Report/Dashboard | Primary Source | Secondary Source |
|-----------------|----------------|------------------|
| Live Deployments | schedules (Firestore) | bots (RTDB) |
| Overview Stats | deployments (Firestore) | schedules (Firestore) |
| Monitoring | bots (RTDB) | deployments (Firestore) |
| Schedule Details | deployments (Firestore) | - |
| Deployment Details | deployments (Firestore) | - |
| Rivers Management | rivers (Firestore) | - |
| Live Feed | bots (RTDB) | deployments readings (RTDB) |

### One-Time Setup:
1. Ensure deployment creation when schedule activates
2. Ensure aggregation on deployment completion
3. Ensure river analytics updates

### No Changes Needed:
- Your existing collections structure ✅
- Your existing RTDB structure ✅
- Your existing models ✅

### Small Additions Needed:
- Aggregation logic (can be app-side for now)
- River analytics update triggers
- Dashboard query implementations

---

**Last Updated**: 2025-10-01  
**Version**: 1.0  
**Status**: Ready for implementation
