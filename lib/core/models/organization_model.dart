import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';
import '../constants/app_constants.dart';

class OrganizationModel extends BaseModel {
  final String name;
  final String description;
  final String status;
  final String? createdBy;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final List<String>? botIds;

  OrganizationModel({
    required String id,
    required this.name,
    required this.description,
    required this.status,
    this.createdBy,
    this.contactEmail,
    this.contactPhone,
    this.address,
    this.botIds,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  bool get isActive => status == AppConstants.orgStatusActive;

  factory OrganizationModel.fromMap(Map<String, dynamic> map, String id) {
    return OrganizationModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? AppConstants.orgStatusActive,
      createdBy: map['created_by'],
      contactEmail: map['contact_email'],
      contactPhone: map['contact_phone'],
      address: map['address'],
      botIds: map['bot_ids'] != null ? List<String>.from(map['bot_ids']) : null,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'status': status,
      'created_by': createdBy,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'address': address,
      'bot_ids': botIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  OrganizationModel copyWith({
    String? name,
    String? description,
    String? status,
    String? createdBy,
    String? contactEmail,
    String? contactPhone,
    String? address,
    List<String>? botIds,
    DateTime? updatedAt,
  }) {
    return OrganizationModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      botIds: botIds ?? this.botIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'OrganizationModel(id: $id, name: $name, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrganizationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
