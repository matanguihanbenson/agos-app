import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  const UserState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() => const UserState();

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      final users = await userService.getAllOnce();
      state = state.copyWith(
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadUsersByOrganization(String organizationId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      final users = await userService.getByFieldOnce('organization_id', organizationId);
      state = state.copyWith(
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadUsersByRole(String role) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      final users = await userService.getByFieldOnce('role', role);
      state = state.copyWith(
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadUsersByCreator(String createdBy) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      final users = await userService.getByFieldOnce('created_by', createdBy);
      state = state.copyWith(
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createUser(UserModel user) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      await userService.create(user);
      await loadUsers(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      await userService.update(userId, data);
      await loadUsers(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      await userService.delete(userId);
      await loadUsers(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateUserStatus(String userId, String status) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      await userService.updateUserStatus(userId, status);
      await loadUsers(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      await userService.updateUserRole(userId, role);
      await loadUsers(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> assignUserToOrganization(String userId, String organizationId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userService = ref.read(userServiceProvider);
      await userService.assignUserToOrganization(userId, organizationId);
      await loadUsers(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<List<UserModel>> searchUsers(String searchTerm) async {
    try {
      final userService = ref.read(userServiceProvider);
      return await userService.searchUsersByName(searchTerm);
    } catch (e) {
      return [];
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

final userProvider = NotifierProvider<UserNotifier, UserState>(() {
  return UserNotifier();
});

// Stream providers for real-time data
final usersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final userService = ref.read(userServiceProvider);
  return userService.getAll();
});

final usersByOrganizationStreamProvider = StreamProvider.family<List<UserModel>, String>((ref, organizationId) {
  final userService = ref.read(userServiceProvider);
  return userService.getUsersByOrganization(organizationId);
});

final usersByRoleStreamProvider = StreamProvider.family<List<UserModel>, String>((ref, role) {
  final userService = ref.read(userServiceProvider);
  return userService.getUsersByRole(role);
});
