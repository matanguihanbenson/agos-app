import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';
import '../constants/app_constants.dart';

class BotModel extends BaseModel {
  final String name;
  final String? assignedTo;
  final DateTime? assignedAt;
  final String? organizationId;
  final String? ownerAdminId;
  
  // Realtime database fields (from bots/botid)
  final String? status; // idle, deployed, maintenance
  final double? batteryLevel;
  final double? lat;
  final double? lng;
  final bool? active;
  final double? phLevel;
  final double? temp;
  final double? turbidity;
  final DateTime? lastUpdated;

  BotModel({
    required String id,
    required this.name,
    this.assignedTo,
    this.assignedAt,
    this.organizationId,
    this.ownerAdminId,
    this.status,
    this.batteryLevel,
    this.lat,
    this.lng,
    this.active,
    this.phLevel,
    this.temp,
    this.turbidity,
    this.lastUpdated,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  bool get isDeployed => status == 'deployed';
  bool get isIdle => status == 'idle';
  bool get isInMaintenance => status == 'maintenance';
  bool get isOnline => active == true;
  bool get isOffline => active == false;
  bool get isAssigned => assignedTo != null && assignedTo!.isNotEmpty;
  bool get hasLocation => lat != null && lng != null;
  
  String get displayStatus => status ?? 'idle';
  String get displayLocation => hasLocation ? 'Lat: ${lat?.toStringAsFixed(4)}, Lng: ${lng?.toStringAsFixed(4)}' : 'Location unavailable';
  String get displayAssignedTo => isAssigned ? 'Assigned' : 'None';

  factory BotModel.fromMap(Map<String, dynamic> map, String id) {
    return BotModel(
      id: id,
      name: map['name'] ?? '',
      assignedTo: map['assigned_to'],
      assignedAt: (map['assigned_at'] as Timestamp?)?.toDate(),
      organizationId: map['organization_id'],
      ownerAdminId: map['owner_admin_id'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Factory for creating BotModel with realtime data merged
  factory BotModel.fromMapWithRealtimeData(
    Map<String, dynamic> firestoreMap, 
    String id, 
    Map<String, dynamic>? realtimeMap
  ) {
    return BotModel(
      id: id,
      name: firestoreMap['name'] ?? '',
      assignedTo: firestoreMap['assigned_to'],
      assignedAt: (firestoreMap['assigned_at'] as Timestamp?)?.toDate(),
      organizationId: firestoreMap['organization_id'],
      ownerAdminId: firestoreMap['owner_admin_id'],
      // Realtime data - try both field name variations
      status: realtimeMap?['status'],
      batteryLevel: (realtimeMap?['battery_level'] ?? realtimeMap?['battery'])?.toDouble(),
      lat: realtimeMap?['lat']?.toDouble(),
      lng: realtimeMap?['lng']?.toDouble(),
      active: realtimeMap?['active'],
      phLevel: realtimeMap?['ph_level']?.toDouble(),
      temp: realtimeMap?['temp']?.toDouble(),
      turbidity: realtimeMap?['turbidity']?.toDouble(),
      lastUpdated: realtimeMap?['last_updated'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(realtimeMap!['last_updated'])
          : null,
      createdAt: (firestoreMap['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (firestoreMap['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'assigned_to': assignedTo,
      'assigned_at': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'organization_id': organizationId,
      'owner_admin_id': ownerAdminId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  // Method to get realtime data for Firebase Realtime Database
  Map<String, dynamic> toRealtimeMap() {
    return {
      'status': status,
      'battery_level': batteryLevel,
      'lat': lat,
      'lng': lng,
      'active': active,
      'ph_level': phLevel,
      'temp': temp,
      'turbidity': turbidity,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
    };
  }

  @override
  BotModel copyWith({
    String? name,
    String? assignedTo,
    DateTime? assignedAt,
    String? organizationId,
    String? ownerAdminId,
    String? status,
    double? batteryLevel,
    double? lat,
    double? lng,
    bool? active,
    double? phLevel,
    double? temp,
    double? turbidity,
    DateTime? lastUpdated,
    DateTime? updatedAt,
  }) {
    return BotModel(
      id: id,
      name: name ?? this.name,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedAt: assignedAt ?? this.assignedAt,
      organizationId: organizationId ?? this.organizationId,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      active: active ?? this.active,
      phLevel: phLevel ?? this.phLevel,
      temp: temp ?? this.temp,
      turbidity: turbidity ?? this.turbidity,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'BotModel(id: $id, name: $name, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BotModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
