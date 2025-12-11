import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_model.dart';
import '../constants/app_constants.dart';

class UserModel extends BaseModel {
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String status;
  final String? createdBy;
  final String? organizationId;

  UserModel({
    required String id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    this.createdBy,
    this.organizationId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  bool get isAdmin => role == AppConstants.adminRole;
  bool get isFieldOperator => role == AppConstants.fieldOperatorRole;
  bool get isActive => status == AppConstants.userStatusActive;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? AppConstants.fieldOperatorRole,
      status: map['status'] ?? AppConstants.userStatusActive,
      createdBy: map['created_by'],
      organizationId: map['organization_id'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': role,
      'status': status,
      'created_by': createdBy,
      'organization_id': organizationId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    String? status,
    String? createdBy,
    String? organizationId,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, email: $email, role: $role, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
