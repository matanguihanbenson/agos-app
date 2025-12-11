import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/utils/validators.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/providers/auth_provider.dart';

class BotRegistrationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const BotRegistrationState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  BotRegistrationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return BotRegistrationState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class BotRegistrationNotifier extends Notifier<BotRegistrationState> {
  @override
  BotRegistrationState build() => const BotRegistrationState();

  Future<bool> registerBot({
    String? botId,
    required String name,
    String? organizationId,
    String? description,
    String? location,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final botService = ref.read(botServiceProvider);
      
      // If botId is provided, validate and check for duplicates
      if (botId != null) {
        final botIdError = Validators.validateBotId(botId);
        if (botIdError != null) {
          state = state.copyWith(
            isLoading: false,
            error: botIdError,
          );
          return false;
        }

        // Check if bot ID already exists
        final existingBot = await botService.getBotByBotId(botId);
        if (existingBot != null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Bot with ID "$botId" already exists',
          );
          return false;
        }
      }

      // Create new bot
      final bot = BotModel(
        id: botId ?? '', // Use provided botId or empty if null
        name: name,
        organizationId: organizationId,
        ownerAdminId: ref.read(authProvider).userProfile?.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // If botId is provided, use it as document ID
      if (botId != null && botId.isNotEmpty) {
        await botService.createWithId(bot, botId);
        
        // Mark bot as registered in bot_registry collection
        final botRegistryService = ref.read(botRegistryServiceProvider);
        await botRegistryService.markBotAsRegistered(botId, ref.read(authProvider).userProfile?.id ?? '');
      } else {
        await botService.create(bot);
      }
      
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
      );
      
      // Refresh the bot list to show the new bot immediately
      ref.read(botProvider.notifier).loadBots();
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const BotRegistrationState();
  }
}

final botRegistrationProvider = NotifierProvider<BotRegistrationNotifier, BotRegistrationState>(() {
  return BotRegistrationNotifier();
});
