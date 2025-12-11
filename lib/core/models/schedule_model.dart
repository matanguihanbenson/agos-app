import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';

class LocationPoint {
  final double latitude;
  final double longitude;
  final String? locationName; // Reverse geocoded name

  LocationPoint({
    required this.latitude,
    required this.longitude,
    this.locationName,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      locationName: map['location_name'],
    );
  }

  LocationPoint copyWith({
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return LocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
    );
  }
}

class OperationArea {
  final LocationPoint center;
  final double radiusInMeters;
  final String? locationName; // Reverse geocoded name

  OperationArea({
    required this.center,
    required this.radiusInMeters,
    this.locationName,
  });

  Map<String, dynamic> toMap() {
    return {
      'center': center.toMap(),
      'radius_in_meters': radiusInMeters,
      'location_name': locationName,
    };
  }

  factory OperationArea.fromMap(Map<String, dynamic> map) {
    return OperationArea(
      center: LocationPoint.fromMap(map['center'] ?? {}),
      radiusInMeters: map['radius_in_meters']?.toDouble() ?? 0.0,
      locationName: map['location_name'],
    );
  }

  OperationArea copyWith({
    LocationPoint? center,
    double? radiusInMeters,
    String? locationName,
  }) {
    return OperationArea(
      center: center ?? this.center,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      locationName: locationName ?? this.locationName,
    );
  }
}

class ScheduleModel extends BaseModel {
  final String name;
  final String botId;
  final String? botName;
  final String riverId;
  final String? riverName;
  final String ownerAdminId;
  final String? assignedOperatorId;
  final String? assignedOperatorName;
  
  // Operation details
  final OperationArea operationArea;
  final LocationPoint dockingPoint;
  
  // Schedule details
  final DateTime scheduledDate;
  final DateTime? scheduledEndDate; // End date/time for the cleanup
  final String status; // 'scheduled', 'active', 'completed', 'cancelled'
  final DateTime? startedAt;
  final DateTime? completedAt;
  
  // Results (filled after completion)
  final double? trashCollected; // in kg
  final double? areaCleanedPercentage;
  final String? notes;

  ScheduleModel({
    required String id,
    required this.name,
    required this.botId,
    this.botName,
    required this.riverId,
    this.riverName,
    required this.ownerAdminId,
    this.assignedOperatorId,
    this.assignedOperatorName,
    required this.operationArea,
    required this.dockingPoint,
    required this.scheduledDate,
    this.scheduledEndDate,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.trashCollected,
    this.areaCleanedPercentage,
    this.notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  bool get isScheduled => status == 'scheduled';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  
  String get statusDisplay {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'active':
        return 'Currently Running';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map, String id) {
    return ScheduleModel(
      id: id,
      name: map['name'] ?? '',
      botId: map['bot_id'] ?? '',
      botName: map['bot_name'],
      riverId: map['river_id'] ?? '',
      riverName: map['river_name'],
      ownerAdminId: map['owner_admin_id'] ?? '',
      assignedOperatorId: map['assigned_operator_id'],
      assignedOperatorName: map['assigned_operator_name'],
      operationArea: OperationArea.fromMap(map['operation_area'] ?? {}),
      dockingPoint: LocationPoint.fromMap(map['docking_point'] ?? {}),
      scheduledDate: (map['scheduled_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledEndDate: (map['scheduled_end_date'] as Timestamp?)?.toDate(),
      status: map['status'] ?? 'scheduled',
      startedAt: (map['started_at'] as Timestamp?)?.toDate(),
      completedAt: (map['completed_at'] as Timestamp?)?.toDate(),
      trashCollected: map['trash_collected']?.toDouble(),
      areaCleanedPercentage: map['area_cleaned_percentage']?.toDouble(),
      notes: map['notes'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bot_id': botId,
      'bot_name': botName,
      'river_id': riverId,
      'river_name': riverName,
      'owner_admin_id': ownerAdminId,
      'assigned_operator_id': assignedOperatorId,
      'assigned_operator_name': assignedOperatorName,
      'operation_area': operationArea.toMap(),
      'docking_point': dockingPoint.toMap(),
      'scheduled_date': Timestamp.fromDate(scheduledDate),
      'scheduled_end_date': scheduledEndDate != null ? Timestamp.fromDate(scheduledEndDate!) : null,
      'status': status,
      'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'trash_collected': trashCollected,
      'area_cleaned_percentage': areaCleanedPercentage,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  ScheduleModel copyWith({
    String? name,
    String? botId,
    String? botName,
    String? riverId,
    String? riverName,
    String? ownerAdminId,
    String? assignedOperatorId,
    String? assignedOperatorName,
    OperationArea? operationArea,
    LocationPoint? dockingPoint,
    DateTime? scheduledDate,
    DateTime? scheduledEndDate,
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    double? trashCollected,
    double? areaCleanedPercentage,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ScheduleModel(
      id: id,
      name: name ?? this.name,
      botId: botId ?? this.botId,
      botName: botName ?? this.botName,
      riverId: riverId ?? this.riverId,
      riverName: riverName ?? this.riverName,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
      assignedOperatorId: assignedOperatorId ?? this.assignedOperatorId,
      assignedOperatorName: assignedOperatorName ?? this.assignedOperatorName,
      operationArea: operationArea ?? this.operationArea,
      dockingPoint: dockingPoint ?? this.dockingPoint,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledEndDate: scheduledEndDate ?? this.scheduledEndDate,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      trashCollected: trashCollected ?? this.trashCollected,
      areaCleanedPercentage: areaCleanedPercentage ?? this.areaCleanedPercentage,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
