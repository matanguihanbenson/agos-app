import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bot_registry_model.dart';
import 'base_service.dart';

class BotRegistryService extends BaseService<BotRegistryModel> {
  @override
  String get collectionName => 'bot_registry';

  @override
  BotRegistryModel fromMap(Map<String, dynamic> map, String id) {
    return BotRegistryModel.fromMap(map, id);
  }

  // Get bot registry entry by bot ID (document ID)
  Future<BotRegistryModel?> getBotRegistryByBotId(String botId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(botId)
          .get();

      if (doc.exists && doc.data() != null) {
        return fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get bot registry entry: $e');
    }
  }

  // Check if bot ID exists in registry
  Future<bool> botIdExists(String botId) async {
    try {
      final entry = await getBotRegistryByBotId(botId);
      return entry != null;
    } catch (e) {
      return false;
    }
  }

  // Check if bot is already registered
  Future<bool> isBotRegistered(String botId) async {
    try {
      final entry = await getBotRegistryByBotId(botId);
      return entry?.isRegistered ?? false;
    } catch (e) {
      return false;
    }
  }

  // Mark bot as registered
  Future<void> markBotAsRegistered(String botId, String registeredBy) async {
    try {
      // Check if bot exists in registry first
      final exists = await botIdExists(botId);
      if (!exists) {
        throw Exception('Bot ID not found in registry');
      }
      
      // Update the document (botId is the document ID)
      await update(botId, {
        'is_registered': true,
        'registered_by': registeredBy,
        'registered_at': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to mark bot as registered: $e');
    }
  }

  // Unregister bot (mark as not registered)
  Future<void> unregisterBot(String botId) async {
    try {
      // Check if bot exists in registry first
      final exists = await botIdExists(botId);
      if (!exists) {
        throw Exception('Bot ID not found in registry');
      }
      
      // Update the document (botId is the document ID)
      await update(botId, {
        'is_registered': false,
        'registered_by': null,
        'registered_at': null,
      });
    } catch (e) {
      throw Exception('Failed to unregister bot: $e');
    }
  }
}
