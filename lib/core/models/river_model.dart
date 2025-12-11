import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';

class RiverModel extends BaseModel {
  final String name;
  final String? description;
  final String ownerAdminId; // admin_id / owner_admin_id
  final String? organizationId; // group_id / organization_id
  final String? createdBy; // user who created
  final String? nameLower; // lowercase name for dedup/search
  final bool isArchived; // whether river is archived
  
  // Analytics data
  final int totalDeployments;
  final int activeDeployments;
  final double? totalTrashCollected; // in kg
  final DateTime? lastDeployment;

  RiverModel({
    required String id,
    required this.name,
    this.description,
    required this.ownerAdminId,
    this.organizationId,
    this.createdBy,
    this.nameLower,
    this.isArchived = false,
    this.totalDeployments = 0,
    this.activeDeployments = 0,
    this.totalTrashCollected,
    this.lastDeployment,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  factory RiverModel.fromMap(Map<String, dynamic> map, String id) {
    return RiverModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      ownerAdminId: map['owner_admin_id'] ?? map['admin_id'] ?? '',
      organizationId: map['organization_id'] ?? map['group_id'],
      createdBy: map['created_by'],
      nameLower: map['name_lower'],
      isArchived: map['is_archived'] ?? false,
      totalDeployments: map['total_deployments'] ?? 0,
      activeDeployments: map['active_deployments'] ?? 0,
      totalTrashCollected: map['total_trash_collected']?.toDouble(),
      lastDeployment: (map['last_deployment'] as Timestamp?)?.toDate(),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'name_lower': nameLower ?? name.toLowerCase(),
      'description': description,
      'owner_admin_id': ownerAdminId,
      'organization_id': organizationId,
      'created_by': createdBy,
      'is_archived': isArchived,
      'total_deployments': totalDeployments,
      'active_deployments': activeDeployments,
      'total_trash_collected': totalTrashCollected,
      'last_deployment': lastDeployment != null ? Timestamp.fromDate(lastDeployment!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  RiverModel copyWith({
    String? name,
    String? description,
    String? ownerAdminId,
    String? organizationId,
    String? createdBy,
    String? nameLower,
    bool? isArchived,
    int? totalDeployments,
    int? activeDeployments,
    double? totalTrashCollected,
    DateTime? lastDeployment,
    DateTime? updatedAt,
  }) {
    return RiverModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      nameLower: nameLower ?? this.nameLower ?? (name ?? this.name).toLowerCase(),
      isArchived: isArchived ?? this.isArchived,
      totalDeployments: totalDeployments ?? this.totalDeployments,
      activeDeployments: activeDeployments ?? this.activeDeployments,
      totalTrashCollected: totalTrashCollected ?? this.totalTrashCollected,
      lastDeployment: lastDeployment ?? this.lastDeployment,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
