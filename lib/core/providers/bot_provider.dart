import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_model.dart';
import '../services/bot_service.dart';
import '../services/bot_registry_service.dart';
import '../services/realtime_bot_service.dart';
import 'auth_provider.dart';

class BotState {
  final List<BotModel> bots;
  final bool isLoading;
  final String? error;

  const BotState({
    this.bots = const [],
    this.isLoading = false,
    this.error,
  });

  BotState copyWith({
    List<BotModel>? bots,
    bool? isLoading,
    String? error,
  }) {
    return BotState(
      bots: bots ?? this.bots,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class BotNotifier extends Notifier<BotState> {
  @override
  BotState build() => const BotState();

  Future<void> loadBots() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      final authState = ref.read(authProvider);
      final currentUser = authState.userProfile;
      
      List<BotModel> bots;
      
      print('DEBUG: Loading bots for user: ${currentUser?.id}, role: ${currentUser?.role}');
      
      // Filter bots based on user role
      if (currentUser != null && currentUser.role == 'admin') {
        // For admin users, show only bots they own with realtime data
        bots = await botService.getBotsByOwnerWithRealtimeData(currentUser.id);
        print('DEBUG: Found ${bots.length} bots for admin ${currentUser.id}');
        
        // If no bots found with owner filtering, temporarily show all bots for debugging
        if (bots.isEmpty) {
          print('DEBUG: No bots found with owner filtering, getting all bots for debugging...');
          final allBots = await botService.getAllBotsWithRealtimeData();
          print('DEBUG: Total bots in system: ${allBots.length}');
          for (final bot in allBots) {
            print('DEBUG: Bot ${bot.id} - name: ${bot.name}, owner: ${bot.ownerAdminId}');
          }
          // Temporarily show all bots for debugging
          bots = allBots;
        } else {
          for (final bot in bots) {
            print('DEBUG: Bot ${bot.id} - name: ${bot.name}, owner: ${bot.ownerAdminId}');
          }
        }
      } else {
        // For field operators, get all bots with realtime data (can be filtered later)
        bots = await botService.getAllBotsWithRealtimeData();
        print('DEBUG: Found ${bots.length} total bots');
      }
      
      state = state.copyWith(
        bots: bots,
        isLoading: false,
      );
    } catch (e) {
      print('DEBUG: Error loading bots: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBotsByOrganization(String organizationId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      final bots = await botService.getByFieldOnce('organization_id', organizationId);
      state = state.copyWith(
        bots: bots,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBotsByStatus(String status) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      final bots = await botService.getByFieldOnce('status', status);
      state = state.copyWith(
        bots: bots,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBotsByUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      final bots = await botService.getByFieldOnce('assigned_to', userId);
      state = state.copyWith(
        bots: bots,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createBot(BotModel bot) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.create(bot);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateBot(String botId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.update(botId, data);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteBot(String botId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.delete(botId);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateBotStatus(String botId, String status) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.updateBotStatus(botId, status);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> assignBotToUser(String botId, String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.assignBotToUser(botId, userId);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> unassignBot(String botId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.unassignBot(botId);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateBotLocation(String botId, double latitude, double longitude) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.updateBotLocation(botId, latitude, longitude);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateBotBatteryLevel(String botId, double batteryLevel) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final botService = ref.read(botServiceProvider);
      await botService.updateBotBatteryLevel(botId, batteryLevel);
      await loadBots(); // Refresh the list
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<List<BotModel>> searchBots(String searchTerm) async {
    try {
      final botService = ref.read(botServiceProvider);
      return await botService.searchBotsByName(searchTerm);
    } catch (e) {
      return [];
    }
  }

  Future<List<BotModel>> getOfflineBots() async {
    try {
      final botService = ref.read(botServiceProvider);
      return await botService.getOfflineBots();
    } catch (e) {
      return [];
    }
  }

  Future<List<BotModel>> getBotsWithLowBattery() async {
    try {
      final botService = ref.read(botServiceProvider);
      return await botService.getBotsWithLowBattery();
    } catch (e) {
      return [];
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Start realtime bot tracking
  void startRealtimeTracking() {
    final realtimeService = ref.read(realtimeBotServiceProvider);
    
    realtimeService.getRealtimeBots(ref).listen(
      (bots) {
        state = state.copyWith(
          bots: bots,
          isLoading: false,
          error: null,
        );
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.toString(),
        );
      },
    );
  }
}

final botServiceProvider = Provider<BotService>((ref) {
  return BotService();
});

final botRegistryServiceProvider = Provider<BotRegistryService>((ref) {
  return BotRegistryService();
});

final botProvider = NotifierProvider<BotNotifier, BotState>(() {
  return BotNotifier();
});

// Real-time stream provider for bots with RTDB telemetry
final botsStreamProvider = StreamProvider.autoDispose<List<BotModel>>((ref) {
  final realtimeBotService = ref.watch(realtimeBotServiceProvider);
  final authState = ref.watch(authProvider);
  final currentUser = authState.userProfile;

  if (currentUser == null) {
    return Stream.value([]);
  }

  // Use RealtimeBotService which merges Firestore + RTDB data automatically
  return realtimeBotService.getRealtimeBots(ref);
});


final botsByOrganizationStreamProvider = StreamProvider.family<List<BotModel>, String>((ref, organizationId) {
  final botService = ref.read(botServiceProvider);
  return botService.getBotsByOrganization(organizationId);
});

final botsByStatusStreamProvider = StreamProvider.family<List<BotModel>, String>((ref, status) {
  final botService = ref.read(botServiceProvider);
  return botService.getBotsByStatus(status);
});

final botsByUserStreamProvider = StreamProvider.family<List<BotModel>, String>((ref, userId) {
  final botService = ref.read(botServiceProvider);
  return botService.getBotsByUser(userId);
});
