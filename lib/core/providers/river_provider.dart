import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_model.dart';
import '../services/river_service.dart';
import 'auth_provider.dart';

class RiverState {
  final List<RiverModel> rivers;
  final bool isLoading;
  final String? error;

  const RiverState({
    this.rivers = const [],
    this.isLoading = false,
    this.error,
  });

  RiverState copyWith({
    List<RiverModel>? rivers,
    bool? isLoading,
    String? error,
  }) {
    return RiverState(
      rivers: rivers ?? this.rivers,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class RiverNotifier extends Notifier<RiverState> {
  @override
  RiverState build() => const RiverState();

  Future<void> loadRivers() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final riverService = ref.read(riverServiceProvider);
      final authState = ref.read(authProvider);
      final currentUser = authState.userProfile;

      if (currentUser != null) {
        final rivers = await riverService.getRiversVisibleToUser(currentUser, orgId: currentUser.organizationId);
        state = state.copyWith(rivers: rivers, isLoading: false);
      } else {
        state = state.copyWith(rivers: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<String?> createRiverByName(String name, {String? description, String? organizationId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final riverService = ref.read(riverServiceProvider);
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser == null) throw Exception('No user');
      final id = await riverService.createRiverIfNotExists(
        name: name,
        description: description,
        creator: currentUser,
        orgId: organizationId ?? currentUser.organizationId,
      );
      await loadRivers();
      return id;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> updateRiver(String riverId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final riverService = ref.read(riverServiceProvider);
      await riverService.update(riverId, data);
      await loadRivers();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteRiver(String riverId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final riverService = ref.read(riverServiceProvider);
      await riverService.delete(riverId);
      await loadRivers();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<List<RiverModel>> searchRivers(String searchTerm) async {
    try {
      final riverService = ref.read(riverServiceProvider);
      final currentUser = ref.read(authProvider).userProfile;

      if (currentUser != null) {
        return await riverService.searchRiversVisibleByName(currentUser, searchTerm, orgId: currentUser.organizationId);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

// Providers
final riverServiceProvider = Provider<RiverService>((ref) {
  return RiverService();
});

final riverProvider = NotifierProvider<RiverNotifier, RiverState>(() {
  return RiverNotifier();
});
