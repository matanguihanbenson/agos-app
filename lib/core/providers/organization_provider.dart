import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organization_model.dart';
import '../services/organization_service.dart';
import 'auth_provider.dart';

class OrganizationState {
  final List<OrganizationModel> organizations;
  final bool isLoading;
  final String? error;

  const OrganizationState({
    this.organizations = const [],
    this.isLoading = false,
    this.error,
  });

  OrganizationState copyWith({
    List<OrganizationModel>? organizations,
    bool? isLoading,
    String? error,
  }) {
    return OrganizationState(
      organizations: organizations ?? this.organizations,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class OrganizationNotifier extends Notifier<OrganizationState> {
  @override
  OrganizationState build() => const OrganizationState();

  Future<void> loadOrganizations() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      final organizations = await organizationService.getAllOnce();
      state = state.copyWith(
        organizations: organizations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadActiveOrganizations() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      final organizations = await organizationService.getByFieldOnce('status', 'active');
      state = state.copyWith(
        organizations: organizations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadOrganizationsByCreator(String creatorUserId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      final organizations = await organizationService.getByFieldOnce('created_by', creatorUserId);
      state = state.copyWith(
        organizations: organizations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createOrganization(OrganizationModel organization) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      await organizationService.create(organization);
      await loadOrganizations(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateOrganization(String organizationId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      await organizationService.update(organizationId, data);
      await loadOrganizations(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteOrganization(String organizationId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      await organizationService.delete(organizationId);
      await loadOrganizations(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateOrganizationStatus(String organizationId, String status) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final organizationService = ref.read(organizationServiceProvider);
      await organizationService.updateOrganizationStatus(organizationId, status);
      await loadOrganizations(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<List<OrganizationModel>> searchOrganizations(String searchTerm) async {
    try {
      final organizationService = ref.read(organizationServiceProvider);
      return await organizationService.searchOrganizationsByName(searchTerm);
    } catch (e) {
      return [];
    }
  }

  Future<OrganizationModel?> getOrganizationByName(String name) async {
    try {
      final organizationService = ref.read(organizationServiceProvider);
      return await organizationService.getOrganizationByName(name);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<String?> createOrganizationByName(String name, {String? description}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final organizationService = ref.read(organizationServiceProvider);
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser == null) throw Exception('No user');
      
      final id = await organizationService.createOrganizationIfNotExists(
        name: name,
        createdBy: currentUser.id,
        description: description,
      );
      await loadOrganizationsByCreator(currentUser.id);
      return id;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // Alias method for convenience
  Future<String?> createOrganizationIfNotExists(String name, {String? description}) async {
    return createOrganizationByName(name, description: description);
  }
}

final organizationServiceProvider = Provider<OrganizationService>((ref) {
  return OrganizationService();
});

final organizationProvider = NotifierProvider<OrganizationNotifier, OrganizationState>(() {
  return OrganizationNotifier();
});

// Stream providers for real-time data
final organizationsStreamProvider = StreamProvider<List<OrganizationModel>>((ref) {
  final organizationService = ref.read(organizationServiceProvider);
  return organizationService.getAll();
});

final activeOrganizationsStreamProvider = StreamProvider<List<OrganizationModel>>((ref) {
  final organizationService = ref.read(organizationServiceProvider);
  return organizationService.getActiveOrganizations();
});
