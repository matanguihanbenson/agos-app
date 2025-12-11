import '../../../core/services/bot_service.dart';
import '../../../core/models/bot_model.dart';

class BotRepository {
  final BotService _botService;

  BotRepository(this._botService);

  // Get all bots
  Future<List<BotModel>> getAllBots() async {
    return await _botService.getAllOnce();
  }

  // Get bots by organization
  Future<List<BotModel>> getBotsByOrganization(String organizationId) async {
    return await _botService.getByFieldOnce('organization_id', organizationId);
  }

  // Get bots by status
  Future<List<BotModel>> getBotsByStatus(String status) async {
    return await _botService.getByFieldOnce('status', status);
  }

  // Get bots by user
  Future<List<BotModel>> getBotsByUser(String userId) async {
    return await _botService.getByFieldOnce('assigned_to', userId);
  }

  // Get bot by ID
  Future<BotModel?> getBotById(String id) async {
    return await _botService.getById(id);
  }

  // Get bot by bot ID
  Future<BotModel?> getBotByBotId(String botId) async {
    return await _botService.getBotByBotId(botId);
  }

  // Create bot
  Future<String> createBot(BotModel bot) async {
    return await _botService.create(bot);
  }

  // Update bot
  Future<void> updateBot(String id, Map<String, dynamic> data) async {
    await _botService.update(id, data);
  }

  // Delete bot
  Future<void> deleteBot(String id) async {
    await _botService.delete(id);
  }

  // Update bot status
  Future<void> updateBotStatus(String id, String status) async {
    await _botService.updateBotStatus(id, status);
  }

  // Assign bot to user
  Future<void> assignBotToUser(String id, String userId) async {
    await _botService.assignBotToUser(id, userId);
  }

  // Unassign bot
  Future<void> unassignBot(String id) async {
    await _botService.unassignBot(id);
  }

  // Update bot location
  Future<void> updateBotLocation(String id, double latitude, double longitude) async {
    await _botService.updateBotLocation(id, latitude, longitude);
  }

  // Update bot battery level
  Future<void> updateBotBatteryLevel(String id, double batteryLevel) async {
    await _botService.updateBotBatteryLevel(id, batteryLevel);
  }

  // Search bots by name
  Future<List<BotModel>> searchBots(String searchTerm) async {
    return await _botService.searchBotsByName(searchTerm);
  }

  // Get offline bots
  Future<List<BotModel>> getOfflineBots() async {
    return await _botService.getOfflineBots();
  }

  // Get bots with low battery
  Future<List<BotModel>> getBotsWithLowBattery() async {
    return await _botService.getBotsWithLowBattery();
  }
}
