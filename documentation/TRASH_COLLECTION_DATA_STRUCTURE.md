# Trash Collection Data Structure

This document describes the new trash collection data structure in RTDB that enables detailed tracking and aggregation of trash items.

---

## New Structure

### RTDB Bot Node: `bots/{botId}/trash_collection`

**Previous (Simple Number)**:
```json
{
  "bots": {
    "bot123": {
      "trash_collected": 8.4  // Just total weight
    }
  }
}
```

**New (Array of Items)**:
```json
{
  "bots": {
    "bot123": {
      "trash_collection": [
        {
          "type": "plastic",
          "confidence_level": 0.95,
          "weight": 0.5,
          "timestamp": 1234567890000,
          "id": "trash_001"
        },
        {
          "type": "metal",
          "confidence_level": 0.87,
          "weight": 0.3,
          "timestamp": 1234567895000,
          "id": "trash_002"
        },
        {
          "type": "plastic",
          "confidence_level": 0.92,
          "weight": 0.4,
          "timestamp": 1234567900000,
          "id": "trash_003"
        }
      ]
    }
  }
}
```

---

## Trash Item Schema

Each item in the `trash_collection` array has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | Yes | Type of trash (plastic, metal, paper, glass, organic, etc.) |
| `confidence_level` | Number | Yes | ML confidence level (0.0 - 1.0) |
| `weight` | Number | Yes | Weight in kilograms |
| `timestamp` | Number | Yes | Unix timestamp in milliseconds when collected |
| `id` | String | No | Unique identifier for the item |
| `image_url` | String | No | URL to image of the trash item (if captured) |
| `location` | Object | No | GPS coordinates where collected |

---

## Trash Types

### Standard Trash Categories:

```dart
enum TrashType {
  plastic,      // Plastic bottles, bags, wrappers
  metal,        // Cans, metal scraps
  paper,        // Paper, cardboard
  glass,        // Glass bottles, broken glass
  organic,      // Food waste, leaves, wood
  fabric,       // Cloth, textile waste
  rubber,       // Tires, rubber materials
  electronic,   // E-waste
  other         // Unclassified items
}
```

---

## Data Flow

### 1. Bot Collects Trash Item

```dart
// Bot device detects and collects trash
final trashItem = {
  'type': 'plastic',
  'confidence_level': 0.95,
  'weight': 0.5,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'id': 'trash_${DateTime.now().millisecondsSinceEpoch}',
};

// Append to RTDB array
await FirebaseDatabase.instance
    .ref('bots/$botId/trash_collection')
    .push()
    .set(trashItem);
```

### 2. Dashboard Aggregates Data

The dashboard provider automatically:
- Sums up total weight from all items
- Counts items by type
- Calculates average confidence level
- Groups by collection time

---

## Dashboard Aggregation

### Total Trash Weight

```dart
double totalWeight = 0.0;
for (final item in trashCollection) {
  totalWeight += item['weight'];
}
```

### Trash by Type

```dart
Map<String, int> trashByType = {};
for (final item in trashCollection) {
  final type = item['type'];
  trashByType[type] = (trashByType[type] ?? 0) + 1;
}
// Result: {"plastic": 50, "metal": 20, "paper": 30}
```

### Average Confidence

```dart
double avgConfidence = 0.0;
if (trashCollection.isNotEmpty) {
  double sum = 0.0;
  for (final item in trashCollection) {
    sum += item['confidence_level'];
  }
  avgConfidence = sum / trashCollection.length;
}
```

---

## Firestore Deployment Storage

When deployment completes, aggregate the RTDB trash data and store in Firestore:

```dart
{
  "deployments": {
    "deployment123": {
      "trash_collection": {
        "trash_by_type": {
          "plastic": 50,
          "metal": 20,
          "paper": 30,
          "organic": 15
        },
        "total_weight": 12.5,
        "total_items": 115,
        "avg_confidence": 0.89
      },
      // Optionally store top N items
      "trash_items": [
        {
          "type": "plastic",
          "confidence_level": 0.95,
          "weight": 0.5,
          "collected_at": Timestamp
        }
      ]
    }
  }
}
```

---

## Migration Strategy

### For Existing Data

The provider supports both old and new formats:

```dart
if (botData['trash_collection'] != null) {
  final trashCollection = botData['trash_collection'];
  
  if (trashCollection is List) {
    // New format: array of items
    for (final item in trashCollection) {
      totalTrash += item['weight'];
    }
  } else if (trashCollection is num) {
    // Old format: just a number
    totalTrash += trashCollection.toDouble();
  }
}
```

### Migration Script

To migrate existing bots from old to new format:

```dart
Future<void> migrateTrashData() async {
  final rtdb = FirebaseDatabase.instance.ref();
  final botsSnapshot = await rtdb.child('bots').get();
  
  if (botsSnapshot.exists) {
    final bots = botsSnapshot.value as Map;
    
    for (final entry in bots.entries) {
      final botId = entry.key;
      final botData = entry.value as Map;
      
      if (botData['trash_collected'] != null && botData['trash_collected'] is num) {
        final totalWeight = botData['trash_collected'] as num;
        
        // Convert to new format with single "unknown" item
        await rtdb.child('bots/$botId/trash_collection').set([
          {
            'type': 'other',
            'confidence_level': 1.0,
            'weight': totalWeight.toDouble(),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'id': 'migrated_${DateTime.now().millisecondsSinceEpoch}',
          }
        ]);
        
        // Remove old field
        await rtdb.child('bots/$botId/trash_collected').remove();
        
        print('✅ Migrated bot $botId');
      }
    }
  }
  
  print('✅ Migration complete!');
}
```

---

## Benefits

### 1. Detailed Analytics
- See breakdown by trash type
- Track confidence levels for ML improvements
- Analyze collection patterns over time

### 2. Better Reporting
- Generate charts showing trash type distribution
- Identify most common trash types per river
- Track ML model accuracy

### 3. Data Quality
- Filter low-confidence items
- Audit trash collection accuracy
- Improve bot performance

### 4. Real-time Updates
- Dashboard shows live trash collection
- Type-by-type breakdown
- Individual item tracking

---

## Dashboard Display

### Overview Card - Trash Today

```
┌─────────────────────────┐
│ 🗑️ Trash Today          │
│                         │
│    12.5 kg              │  ← Total weight
│    Collected            │
│                         │
│  📊 Breakdown:          │
│  • Plastic: 50 items    │  ← Items by type
│  • Metal: 20 items      │
│  • Paper: 30 items      │
│  • Organic: 15 items    │
└─────────────────────────┘
```

### Expanded View (Future Enhancement)

```
Trash Collection Details
═══════════════════════════════
Total: 12.5 kg (115 items)
Avg Confidence: 89%

By Type:
  Plastic    ████████████░░ 50 items (5.2kg)
  Paper      ██████░░░░░░░░ 30 items (3.1kg)
  Metal      ████░░░░░░░░░░ 20 items (2.8kg)
  Organic    ███░░░░░░░░░░░ 15 items (1.4kg)

Recent Items:
  • Plastic bottle (0.5kg, 95% confidence) - 2 min ago
  • Metal can (0.3kg, 87% confidence) - 5 min ago
  • Plastic bag (0.2kg, 92% confidence) - 8 min ago
```

---

## Implementation Checklist

- [x] Update `DashboardStats` model with `trashByType` field
- [x] Update provider to handle array format
- [x] Add backward compatibility for old format
- [x] Document new structure
- [ ] Update bot firmware/simulator to use new format
- [ ] Create migration script for existing data
- [ ] Add UI for trash breakdown visualization
- [ ] Add detailed trash analytics page

---

## Example Usage

### Bot Simulator - Add Trash Item

```dart
Future<void> addTrashItem(String botId, String type, double weight) async {
  final trashItem = {
    'type': type,
    'confidence_level': 0.80 + (Random().nextDouble() * 0.20), // 0.8-1.0
    'weight': weight,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'id': 'trash_${DateTime.now().millisecondsSinceEpoch}',
  };

  await FirebaseDatabase.instance
      .ref('bots/$botId/trash_collection')
      .push()
      .set(trashItem);
}

// Usage
await addTrashItem('bot123', 'plastic', 0.5);
await addTrashItem('bot123', 'metal', 0.3);
```

### Query Trash Collection

```dart
Future<List<Map<String, dynamic>>> getTrashItems(String botId) async {
  final snapshot = await FirebaseDatabase.instance
      .ref('bots/$botId/trash_collection')
      .get();

  if (snapshot.exists) {
    final data = snapshot.value;
    if (data is List) {
      return List<Map<String, dynamic>>.from(data.where((item) => item != null));
    }
  }
  return [];
}
```

### Clear Trash Collection (After Deployment)

```dart
Future<void> clearTrashCollection(String botId) async {
  await FirebaseDatabase.instance
      .ref('bots/$botId/trash_collection')
      .remove();
}
```

---

## Summary

**New Structure Benefits**:
- ✅ Detailed tracking of individual items
- ✅ Type-based aggregation
- ✅ ML confidence tracking
- ✅ Better analytics and reporting
- ✅ Backward compatible with old format

**Data Storage**: Store items in RTDB during deployment, aggregate to Firestore on completion

**Dashboard**: Shows total weight + breakdown by type in overview cards
