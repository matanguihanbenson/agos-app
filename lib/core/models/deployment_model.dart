import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';

class WaterQualitySnapshot {
  final double avgPhLevel;
  final double avgTurbidity;
  final double avgTemperature;
  final double avgDissolvedOxygen;
  final int sampleCount;

  WaterQualitySnapshot({
    required this.avgPhLevel,
    required this.avgTurbidity,
    required this.avgTemperature,
    required this.avgDissolvedOxygen,
    required this.sampleCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'avg_ph_level': avgPhLevel,
      'avg_turbidity': avgTurbidity,
      'avg_temperature': avgTemperature,
      'avg_dissolved_oxygen': avgDissolvedOxygen,
      'sample_count': sampleCount,
    };
  }

  factory WaterQualitySnapshot.fromMap(Map<String, dynamic> map) {
    return WaterQualitySnapshot(
      avgPhLevel: map['avg_ph_level']?.toDouble() ?? 0.0,
      avgTurbidity: map['avg_turbidity']?.toDouble() ?? 0.0,
      avgTemperature: map['avg_temperature']?.toDouble() ?? 0.0,
      avgDissolvedOxygen: map['avg_dissolved_oxygen']?.toDouble() ?? 0.0,
      sampleCount: map['sample_count']?.toInt() ?? 0,
    );
  }
}

class TrashItem {
  final String classification;
  final double confidenceLevel;
  final DateTime collectedAt;
  final double? weight; // in kg

  TrashItem({
    required this.classification,
    required this.confidenceLevel,
    required this.collectedAt,
    this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'classification': classification,
      'confidence_level': confidenceLevel,
      'collected_at': Timestamp.fromDate(collectedAt),
      'weight': weight,
    };
  }

  factory TrashItem.fromMap(Map<String, dynamic> map) {
    return TrashItem(
      classification: map['classification'] ?? '',
      confidenceLevel: map['confidence_level']?.toDouble() ?? 0.0,
      collectedAt: (map['collected_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weight: map['weight']?.toDouble(),
    );
  }
}

class TrashCollectionSummary {
  final Map<String, int> trashByType; // classification -> count
  final double totalWeight; // in kg
  final int totalItems;

  TrashCollectionSummary({
    required this.trashByType,
    required this.totalWeight,
    required this.totalItems,
  });

  Map<String, dynamic> toMap() {
    return {
      'trash_by_type': trashByType,
      'total_weight': totalWeight,
      'total_items': totalItems,
    };
  }

  factory TrashCollectionSummary.fromMap(Map<String, dynamic> map) {
    return TrashCollectionSummary(
      trashByType: Map<String, int>.from(map['trash_by_type'] ?? {}),
      totalWeight: map['total_weight']?.toDouble() ?? 0.0,
      totalItems: map['total_items']?.toInt() ?? 0,
    );
  }
}

class DeploymentModel extends BaseModel {
  final String scheduleId;
  final String scheduleName;
  final String botId;
  final String botName;
  final String riverId;
  final String riverName;
  final String ownerAdminId;
  
  // Deployment timeline
  final DateTime scheduledStartTime;
  final DateTime? actualStartTime;
  final DateTime scheduledEndTime;
  final DateTime? actualEndTime;
  final String status; // 'scheduled', 'active', 'completed', 'cancelled'
  
  // Location data
  final double operationLat;
  final double operationLng;
  final double operationRadius;
  final String? operationLocation;
  
  // Collected data (aggregated from realtime DB on completion)
  final WaterQualitySnapshot? waterQuality;
  final TrashCollectionSummary? trashCollection;
  final List<TrashItem>? trashItems;
  
  // Individual water quality readings (for reporting)
  final double? phLevel;
  final double? turbidity;
  final double? temperature;
  final double? dissolvedOxygen;
  
  // Performance metrics
  final double? areaCoveredPercentage;
  final double? distanceTraveled; // in meters
  final int? durationMinutes;
  
  // Notes
  final String? notes;

  DeploymentModel({
    required String id,
    required this.scheduleId,
    required this.scheduleName,
    required this.botId,
    required this.botName,
    required this.riverId,
    required this.riverName,
    required this.ownerAdminId,
    required this.scheduledStartTime,
    this.actualStartTime,
    required this.scheduledEndTime,
    this.actualEndTime,
    required this.status,
    required this.operationLat,
    required this.operationLng,
    required this.operationRadius,
    this.operationLocation,
    this.waterQuality,
    this.trashCollection,
    this.trashItems,
    this.phLevel,
    this.turbidity,
    this.temperature,
    this.dissolvedOxygen,
    this.areaCoveredPercentage,
    this.distanceTraveled,
    this.durationMinutes,
    this.notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  bool get isScheduled => status == 'scheduled';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  // Helper to parse datetime that can be either Timestamp or ISO string
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  factory DeploymentModel.fromMap(Map<String, dynamic> map, String id) {
    return DeploymentModel(
      id: id,
      scheduleId: map['schedule_id'] ?? '',
      scheduleName: map['schedule_name'] ?? '',
      botId: map['bot_id'] ?? '',
      botName: map['bot_name'] ?? '',
      riverId: map['river_id'] ?? '',
      riverName: map['river_name'] ?? '',
      ownerAdminId: map['owner_admin_id'] ?? '',
      scheduledStartTime: _parseDateTime(map['scheduled_start_time']) ?? DateTime.now(),
      actualStartTime: _parseDateTime(map['actual_start_time']),
      scheduledEndTime: _parseDateTime(map['scheduled_end_time']) ?? DateTime.now(),
      actualEndTime: _parseDateTime(map['actual_end_time']),
      status: map['status'] ?? 'scheduled',
      operationLat: map['operation_lat']?.toDouble() ?? 0.0,
      operationLng: map['operation_lng']?.toDouble() ?? 0.0,
      operationRadius: map['operation_radius']?.toDouble() ?? 0.0,
      operationLocation: map['operation_location'],
      waterQuality: map['water_quality'] != null 
          ? WaterQualitySnapshot.fromMap(map['water_quality'])
          : null,
      trashCollection: map['trash_collection'] != null
          ? TrashCollectionSummary.fromMap(map['trash_collection'])
          : null,
      trashItems: map['trash_items'] != null
          ? (map['trash_items'] as List).map((item) => TrashItem.fromMap(item)).toList()
          : null,
      phLevel: map['ph_level']?.toDouble(),
      turbidity: map['turbidity']?.toDouble(),
      temperature: map['temperature']?.toDouble(),
      dissolvedOxygen: map['dissolved_oxygen']?.toDouble(),
      areaCoveredPercentage: map['area_covered_percentage']?.toDouble(),
      distanceTraveled: map['distance_traveled']?.toDouble(),
      durationMinutes: map['duration_minutes']?.toInt(),
      notes: map['notes'],
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'schedule_id': scheduleId,
      'schedule_name': scheduleName,
      'bot_id': botId,
      'bot_name': botName,
      'river_id': riverId,
      'river_name': riverName,
      'owner_admin_id': ownerAdminId,
      'scheduled_start_time': Timestamp.fromDate(scheduledStartTime),
      'actual_start_time': actualStartTime != null ? Timestamp.fromDate(actualStartTime!) : null,
      'scheduled_end_time': Timestamp.fromDate(scheduledEndTime),
      'actual_end_time': actualEndTime != null ? Timestamp.fromDate(actualEndTime!) : null,
      'status': status,
      'operation_lat': operationLat,
      'operation_lng': operationLng,
      'operation_radius': operationRadius,
      'operation_location': operationLocation,
      'water_quality': waterQuality?.toMap(),
      'trash_collection': trashCollection?.toMap(),
      'trash_items': trashItems?.map((item) => item.toMap()).toList(),
      'ph_level': phLevel,
      'turbidity': turbidity,
      'temperature': temperature,
      'dissolved_oxygen': dissolvedOxygen,
      'area_covered_percentage': areaCoveredPercentage,
      'distance_traveled': distanceTraveled,
      'duration_minutes': durationMinutes,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  DeploymentModel copyWith({
    String? scheduleId,
    String? scheduleName,
    String? botId,
    String? botName,
    String? riverId,
    String? riverName,
    String? ownerAdminId,
    DateTime? scheduledStartTime,
    DateTime? actualStartTime,
    DateTime? scheduledEndTime,
    DateTime? actualEndTime,
    String? status,
    double? operationLat,
    double? operationLng,
    double? operationRadius,
    String? operationLocation,
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
    DateTime? updatedAt,
  }) {
    return DeploymentModel(
      id: id,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleName: scheduleName ?? this.scheduleName,
      botId: botId ?? this.botId,
      botName: botName ?? this.botName,
      riverId: riverId ?? this.riverId,
      riverName: riverName ?? this.riverName,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      status: status ?? this.status,
      operationLat: operationLat ?? this.operationLat,
      operationLng: operationLng ?? this.operationLng,
      operationRadius: operationRadius ?? this.operationRadius,
      operationLocation: operationLocation ?? this.operationLocation,
      waterQuality: waterQuality ?? this.waterQuality,
      trashCollection: trashCollection ?? this.trashCollection,
      trashItems: trashItems ?? this.trashItems,
      phLevel: phLevel ?? this.phLevel,
      turbidity: turbidity ?? this.turbidity,
      temperature: temperature ?? this.temperature,
      dissolvedOxygen: dissolvedOxygen ?? this.dissolvedOxygen,
      areaCoveredPercentage: areaCoveredPercentage ?? this.areaCoveredPercentage,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
