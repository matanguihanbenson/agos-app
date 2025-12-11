import '../models/user_model.dart';
import 'base_service.dart';

class UserService extends BaseService<UserModel> {
  @override
  String get collectionName => 'users';

  @override
  UserModel fromMap(Map<String, dynamic> map, String id) {
    return UserModel.fromMap(map, id);
  }

  // Get users by organization
  Stream<List<UserModel>> getUsersByOrganization(String organizationId) {
    return getByField('organization_id', organizationId);
  }

  // Get users by role
  Stream<List<UserModel>> getUsersByRole(String role) {
    return getByField('role', role);
  }

  // Get active users
  Stream<List<UserModel>> getActiveUsers() {
    return getByField('status', 'active');
  }

  // Get users created by specific admin
  Stream<List<UserModel>> getUsersByCreator(String createdBy) {
    return getByField('created_by', createdBy);
  }

  // Update user status
  Future<void> updateUserStatus(String userId, String status) async {
    await update(userId, {'status': status});
  }

  // Update user role
  Future<void> updateUserRole(String userId, String role) async {
    await update(userId, {'role': role});
  }

  // Assign user to organization
  Future<void> assignUserToOrganization(String userId, String organizationId) async {
    await update(userId, {'organization_id': organizationId});
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final users = await getByFieldOnce('email', email);
      return users.isNotEmpty ? users.first : null;
    } catch (e) {
      return null;
    }
  }

  // Search users by name
  Future<List<UserModel>> searchUsersByName(String searchTerm) async {
    try {
      final allUsers = await getAllOnce();
      return allUsers.where((user) {
        final fullName = user.fullName.toLowerCase();
        final search = searchTerm.toLowerCase();
        return fullName.contains(search);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get users count by organization
  Future<int> getUsersCountByOrganization(String organizationId) async {
    try {
      final users = await getByFieldOnce('organization_id', organizationId);
      return users.length;
    } catch (e) {
      return 0;
    }
  }

  // Get users count by role
  Future<int> getUsersCountByRole(String role) async {
    try {
      final users = await getByFieldOnce('role', role);
      return users.length;
    } catch (e) {
      return 0;
    }
  }
}
