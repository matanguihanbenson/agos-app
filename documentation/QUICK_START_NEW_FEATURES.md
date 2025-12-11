# 🚀 Quick Start Guide - New Features

**Last Updated**: December 1, 2025

---

## 🗺️ 1. Waste Mapping

**What it does**: Shows all trash detections on an interactive map with filters

**How to use**:
```dart
Navigator.pushNamed(context, AppRoutes.wasteMapping);
```

**Features**:
- Click any marker to see detection details (bot ID, timestamp, location, confidence, weight)
- Filter by waste type (plastic, metal, paper, etc.)
- Filter by custom date range
- View legend with counts per type
- See total detections, weight, and avg confidence

**Data**: Pulls from Firebase RTDB `bots/{botId}/trash_collection`

---

## 📊 2. Waste Analytics

**What it does**: Analytics dashboard with charts, trends, and insights

**How to use**:
```dart
Navigator.pushNamed(context, AppRoutes.wasteAnalytics);
```

**Features**:
- Summary cards (total weight, total items)
- Distribution by type (horizontal bar chart)
- Distribution by location (top 5 polluted areas)
- Daily collection trend chart
- Key insights (most common type, most polluted location, daily average)

**Filters**: Time range (7d/30d/90d/all), River selection

**Data**: Aggregates from Firestore `deployments` + RTDB `bots/{botId}/trash_collection`

---

## 🌊 3. Environmental Monitoring

**What it does**: Live water quality monitoring from active bots

**How to use**:
```dart
Navigator.pushNamed(context, AppRoutes.environmentalMonitoring);
```

**Features**:
- Real-time sensor readings (pH, turbidity, temperature, dissolved oxygen)
- Color-coded status (Excellent/Good/Fair/Poor based on thresholds)
- River filter
- Click history icon (🕐) on any bot card to view past deployment data
- Auto-refresh via real-time listeners

**Status Thresholds**:
- **pH**: Normal (6.5-8.5), Acceptable (6.0-9.0), Poor (outside)
- **Turbidity**: Excellent (<5), Good (<25), Fair (<50), Poor (≥50)
- **Temperature**: Normal (15-30°C), Cold (<15), Warm (>30)
- **DO**: Good (≥6), Acceptable (≥4), Poor (<4)

**Data**: 
- Live: RTDB `bots/{botId}` (ph_level, turbidity, temp, dissolved_oxygen)
- Historical: Firestore `deployments/water_quality_snapshot`

---

## 📜 4. Deployment History

**What it does**: Complete history of all deployments with filters

**How to use**:
```dart
Navigator.pushNamed(context, AppRoutes.deploymentHistory);
```

**Features**:
- Filter by status (All/Active/Completed/Cancelled/Scheduled)
- Filter by time range (7d/30d/90d/all)
- Tap any card to see full details in draggable bottom sheet
- Shows trash collection breakdown by type
- Shows water quality snapshot (pH, turbidity, temp, DO)
- Includes timeline (scheduled vs actual start/end)

**Data**: Firestore `deployments` collection

---

## ⛈️ 5. Storm Alert Widget

**What it does**: Real-time storm alert display (hardware-driven, read-only)

**How to use**: **Automatically displayed on Dashboard** (no navigation needed)

**Features**:
- 5 alert levels: None (green), Low (blue), Medium (yellow), High (orange), Critical (red)
- Shows auto-recall status (enabled/triggered badges)
- Displays wind speed and pressure
- Alert message from hardware
- Relative timestamp ("5m ago")
- Compact "All Clear" view when no alerts

**Data**: Firebase RTDB `weather_alerts/current`

**Example RTDB Structure**:
```json
{
  "level": "medium",
  "message": "Tropical depression approaching",
  "auto_recall_enabled": true,
  "auto_recall_triggered": false,
  "wind_speed": 45.5,
  "pressure": 1008.3,
  "last_updated": 1701417600000
}
```

---

## ✏️ 6. Schedule Editing

**What it does**: Edit existing schedules (dates, times, locations, notes)

**How to use**: 
1. Navigate to schedule detail page or schedule card
2. Tap "Edit" button
3. Opens `EditSchedulePage` with pre-filled data

**Features**:
- Edit start/end date and time (pickers)
- Live duration calculator
- Edit operation area (lat, lng, radius) with map selector
- Edit docking point (lat, lng) with map selector
- Auto reverse geocoding for location names
- Form validation
- Success/error feedback

**Note**: Schedule editing was already implemented. Just confirmed it's fully functional.

---

## 🎯 QUICK NAVIGATION SETUP

### Add to Dashboard Quick Actions:

```dart
// Example for admin
_buildQuickActionCard(
  context: context,
  icon: Icons.map,
  label: 'Waste Map',
  color: Colors.orange,
  onTap: () => Navigator.pushNamed(context, AppRoutes.wasteMapping),
),

_buildQuickActionCard(
  context: context,
  icon: Icons.analytics,
  label: 'Analytics',
  color: Colors.blue,
  onTap: () => Navigator.pushNamed(context, AppRoutes.wasteAnalytics),
),

_buildQuickActionCard(
  context: context,
  icon: Icons.water_drop,
  label: 'Environment',
  color: Colors.green,
  onTap: () => Navigator.pushNamed(context, AppRoutes.environmentalMonitoring),
),
```

### Add to Sidebar:

```dart
_buildNavItem(
  icon: Icons.map_outlined,
  title: 'Waste Mapping',
  onTap: () {
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRoutes.wasteMapping);
  },
),

_buildNavItem(
  icon: Icons.analytics_outlined,
  title: 'Waste Analytics',
  onTap: () {
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRoutes.wasteAnalytics);
  },
),

_buildNavItem(
  icon: Icons.water_drop_outlined,
  title: 'Water Quality',
  onTap: () {
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRoutes.environmentalMonitoring);
  },
),
```

---

## 🧪 TESTING WITH MOCK DATA

### 1. Test Storm Alerts:

Use Firebase Console → Realtime Database:

```json
// Path: weather_alerts/current
{
  "level": "critical",
  "message": "Severe typhoon warning. All bots recalled.",
  "auto_recall_enabled": true,
  "auto_recall_triggered": true,
  "wind_speed": 120,
  "pressure": 980,
  "last_updated": [current timestamp in ms]
}
```

**Expected**: Dashboard shows red critical alert with emergency recall banner

### 2. Test Waste Detection:

Add to RTDB:

```json
// Path: bots/bot_001/trash_collection/item_001
{
  "type": "plastic",
  "latitude": 14.5995,
  "longitude": 120.9842,
  "timestamp": [current timestamp in ms],
  "confidence_level": 0.92,
  "weight": 0.8
}
```

**Expected**: Marker appears on Waste Mapping page, counted in Analytics

### 3. Test Environmental Sensors:

Update RTDB:

```json
// Path: bots/bot_001
{
  "status": "active",
  "ph_level": 8.2,
  "turbidity": 18,
  "temp": 27,
  "dissolved_oxygen": 6.5,
  "last_updated": [current timestamp in ms]
}
```

**Expected**: Bot appears in Environmental Monitoring with "Normal" status (green)

---

## 🔧 TROUBLESHOOTING

### Issue: Waste map is empty
**Fix**: Check RTDB `bots/{botId}/trash_collection` has data and timestamps are within filter range

### Issue: Environmental monitoring shows no bots
**Fix**: Ensure at least one bot has `status: "active"` or `status: "deployed"` in RTDB

### Issue: Storm alert not showing
**Fix**: Create `weather_alerts/current` node in RTDB. If missing, shows "All Clear" by default.

### Issue: Deployment history is empty
**Fix**: Check Firestore `deployments` collection has `owner_admin_id` matching current user

### Issue: Analytics shows zero
**Fix**: Ensure completed deployments have `trash_collection_summary` field in Firestore

---

## 📱 RECOMMENDED USER FLOW

**For Admins**:
1. Dashboard → Check Storm Alert Widget
2. Environmental Monitoring → Monitor active bots
3. Waste Mapping → See real-time detections
4. Waste Analytics → Analyze trends
5. Deployment History → Review past operations

**For Field Operators**:
1. Dashboard → Check Storm Alert Widget
2. Environmental Monitoring → Monitor assigned bots
3. Waste Mapping → View detections from assigned bots
4. Deployment History → Review personal deployment history

---

## ✅ DONE!

All features are **production-ready** and integrated with your existing Firebase structure!

**Need Help?** Refer to:
- `NEW_FEATURES_SUMMARY.md` - Detailed feature docs
- `IMPLEMENTATION_COMPLETE.md` - Complete implementation details
- `documentation/` folder - Comprehensive project documentation

