import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bot_model.dart';
import 'base_service.dart';
import 'bot_registry_service.dart';

class BotService extends BaseService<BotModel> {
  final DatabaseReference _realtimeDb = FirebaseDatabase.instance.ref();

  @override
  String get collectionName => 'bots';

  @override
  BotModel fromMap(Map<String, dynamic> map, String id) {
    return BotModel.fromMap(map, id);
  }

  // Create bot with specific document ID
  Future<void> createWithId(BotModel bot, String documentId) async {
    try {
      final data = bot.toMap();
      data['created_at'] = FieldValue.serverTimestamp();
      data['updated_at'] = FieldValue.serverTimestamp();
      
      await collection.doc(documentId).set(data);
      
      // Note: Bot registration logging should be done at the registration page level
      // with proper user context using LoggingService().logBotRegistered()
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'bot_create_with_id_error',
      );
      rethrow;
    }
  }

  // Get all bots with realtime data merged
  Future<List<BotModel>> getAllBotsWithRealtimeData() async {
    try {
      // Get Firestore documents directly to preserve the original data
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .get();
      
      final List<BotModel> botsWithRealtimeData = [];

      for (final doc in snapshot.docs) {
        final firestoreData = doc.data();
        final realtimeSnapshot = await _realtimeDb.child('bots/${doc.id}').get();
        final realtimeData = realtimeSnapshot.exists 
            ? Map<String, dynamic>.from(realtimeSnapshot.value as Map)
            : null;

        final botWithRealtimeData = BotModel.fromMapWithRealtimeData(
          firestoreData,
          doc.id,
          realtimeData,
        );
        botsWithRealtimeData.add(botWithRealtimeData);
      }

      return botsWithRealtimeData;
    } catch (e) {
      throw Exception('Failed to load bots with realtime data: $e');
    }
  }

  // Watch bots by owner admin ID with realtime data (real-time stream)
  // NOTE: This only triggers on Firestore changes, not RTDB changes.
  // For true real-time updates on RTDB changes, use RealtimeBotService instead.
  Stream<List<BotModel>> watchBotsByOwner(String ownerAdminId) {
    return _watchBotsWithRTDB(
      FirebaseFirestore.instance
          .collection(collectionName)
          .where('owner_admin_id', isEqualTo: ownerAdminId)
          .snapshots(),
    );
  }

  // Watch all bots with realtime data (real-time stream)
  // NOTE: This only triggers on Firestore changes, not RTDB changes.
  // For true real-time updates on RTDB changes, use RealtimeBotService instead.
  Stream<List<BotModel>> watchAllBots() {
    return _watchBotsWithRTDB(
      FirebaseFirestore.instance
          .collection(collectionName)
          .snapshots(),
    );
  }

  // Helper method to watch bots with RTDB integration
  // This creates a stream that listens to BOTH Firestore AND RTDB changes
  Stream<List<BotModel>> _watchBotsWithRTDB(Stream<QuerySnapshot> firestoreStream) {
    final controller = StreamController<List<BotModel>>();
    
    // Keep track of RTDB subscriptions for each bot
    final Map<String, StreamSubscription<DatabaseEvent>> rtdbSubscriptions = {};
    final Map<String, Map<String, dynamic>> firestoreCache = {};
    final Map<String, Map<String, dynamic>?> rtdbCache = {};
    
    StreamSubscription<QuerySnapshot>? firestoreSubscription;

    void emitBots() {
      final List<BotModel> botsWithRealtimeData = [];
      
      for (final entry in firestoreCache.entries) {
        final botId = entry.key;
        final firestoreData = entry.value;
        final realtimeData = rtdbCache[botId];
        
        final botWithRealtimeData = BotModel.fromMapWithRealtimeData(
          firestoreData,
          botId,
          realtimeData,
        );
        botsWithRealtimeData.add(botWithRealtimeData);
      }
      
      if (!controller.isClosed) {
        controller.add(botsWithRealtimeData);
      }
    }

    firestoreSubscription = firestoreStream.listen(
      (firestoreSnapshot) async {
        // Update Firestore cache
        firestoreCache.clear();
        final currentBotIds = <String>{};
        
        for (final doc in firestoreSnapshot.docs) {
          currentBotIds.add(doc.id);
          final data = doc.data();
          if (data != null && data is Map) {
            firestoreCache[doc.id] = Map<String, dynamic>.from(data);
          }
        }

        // Clean up RTDB subscriptions for bots that no longer exist
        final rtdbBotIds = rtdbSubscriptions.keys.toList();
        for (final botId in rtdbBotIds) {
          if (!currentBotIds.contains(botId)) {
            await rtdbSubscriptions[botId]?.cancel();
            rtdbSubscriptions.remove(botId);
            rtdbCache.remove(botId);
          }
        }

        // Set up RTDB listeners for new bots
        for (final botId in currentBotIds) {
          if (!rtdbSubscriptions.containsKey(botId)) {
            // Fetch initial RTDB data
            final realtimeSnapshot = await _realtimeDb.child('bots/$botId').get();
            rtdbCache[botId] = realtimeSnapshot.exists
                ? Map<String, dynamic>.from(realtimeSnapshot.value as Map)
                : null;
            
            // Listen to RTDB changes for this bot
            rtdbSubscriptions[botId] = _realtimeDb.child('bots/$botId').onValue.listen(
              (event) {
                if (event.snapshot.exists) {
                  rtdbCache[botId] = Map<String, dynamic>.from(event.snapshot.value as Map);
                } else {
                  rtdbCache[botId] = null;
                }
                emitBots(); // Emit updated bots when RTDB changes
              },
            );
          }
        }

        emitBots(); // Emit updated bots when Firestore changes
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );

    // Clean up when stream is cancelled
    controller.onCancel = () async {
      await firestoreSubscription?.cancel();
      for (final subscription in rtdbSubscriptions.values) {
        await subscription.cancel();
      }
      rtdbSubscriptions.clear();
      firestoreCache.clear();
      rtdbCache.clear();
    };

    return controller.stream;
  }

  // Get bots by owner admin ID with realtime data (one-time)
  Future<List<BotModel>> getBotsByOwnerWithRealtimeData(String ownerAdminId) async {
    try {
      print('DEBUG: Querying bots with owner_admin_id: $ownerAdminId');
      
      // Get Firestore documents directly to preserve the original data
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('owner_admin_id', isEqualTo: ownerAdminId)
          .get();
      
      print('DEBUG: Found ${snapshot.docs.length} documents in Firestore');
      
      final List<BotModel> botsWithRealtimeData = [];

      for (final doc in snapshot.docs) {
        final firestoreData = doc.data();
        print('DEBUG: Bot doc ${doc.id} data: $firestoreData');
        
        final realtimeSnapshot = await _realtimeDb.child('bots/${doc.id}').get();
        final realtimeData = realtimeSnapshot.exists 
            ? Map<String, dynamic>.from(realtimeSnapshot.value as Map)
            : null;

        print('DEBUG: Realtime data for ${doc.id}: $realtimeData');

        final botWithRealtimeData = BotModel.fromMapWithRealtimeData(
          firestoreData,
          doc.id,
          realtimeData,
        );
        botsWithRealtimeData.add(botWithRealtimeData);
      }

      return botsWithRealtimeData;
    } catch (e) {
      print('DEBUG: Error in getBotsByOwnerWithRealtimeData: $e');
      throw Exception('Failed to load bots by owner with realtime data: $e');
    }
  }

  // Get bots by organization
  Stream<List<BotModel>> getBotsByOrganization(String organizationId) {
    return getByField('organization_id', organizationId);
  }

  // Get bots by status
  Stream<List<BotModel>> getBotsByStatus(String status) {
    return getByField('status', status);
  }

  // Get bots assigned to user
  Stream<List<BotModel>> getBotsByUser(String userId) {
    return getByField('assigned_to', userId);
  }

  // Get active bots
  Stream<List<BotModel>> getActiveBots() {
    return getByField('status', 'active');
  }

  // Get bot by bot ID
  Future<BotModel?> getBotByBotId(String botId) async {
    try {
      final bots = await getByFieldOnce('bot_id', botId);
      return bots.isNotEmpty ? bots.first : null;
    } catch (e) {
      return null;
    }
  }

  // Update bot status
  Future<void> updateBotStatus(String botId, String status) async {
    try {
      // Update in Realtime Database (this is where status is stored)
      await _realtimeDb.child('bots/$botId').update({
        'status': status,
        'last_updated': ServerValue.timestamp,
      });
      
      // Note: Bot status change logging should be done at the application level
      // with proper user context using LoggingService().logBotStatusChanged()
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'bot_update_status_error',
      );
      rethrow;
    }
  }

  // Assign bot to user
  Future<void> assignBotToUser(String botId, String userId) async {
    await update(botId, {'assigned_to': userId});
  }

  // Unassign bot from user
  Future<void> unassignBot(String botId) async {
    await update(botId, {'assigned_to': null});
  }

  // Update bot location
  Future<void> updateBotLocation(String botId, double latitude, double longitude) async {
    await update(botId, {
      'latitude': latitude,
      'longitude': longitude,
      'last_seen': DateTime.now(),
    });
  }

  // Update bot battery level
  Future<void> updateBotBatteryLevel(String botId, double batteryLevel) async {
    await update(botId, {
      'battery_level': batteryLevel,
      'last_seen': DateTime.now(),
    });
  }

  // Update bot metadata
  Future<void> updateBotMetadata(String botId, Map<String, dynamic> metadata) async {
    await update(botId, {'metadata': metadata});
  }

  // Search bots by name
  Future<List<BotModel>> searchBotsByName(String searchTerm) async {
    try {
      final allBots = await getAllOnce();
      return allBots.where((bot) {
        final name = bot.name.toLowerCase();
        final search = searchTerm.toLowerCase();
        return name.contains(search);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get bots count by organization
  Future<int> getBotsCountByOrganization(String organizationId) async {
    try {
      final bots = await getByFieldOnce('organization_id', organizationId);
      return bots.length;
    } catch (e) {
      return 0;
    }
  }

  // Get bots count by status
  Future<int> getBotsCountByStatus(String status) async {
    try {
      final bots = await getByFieldOnce('status', status);
      return bots.length;
    } catch (e) {
      return 0;
    }
  }

  // Get bots count by user
  Future<int> getBotsCountByUser(String userId) async {
    try {
      final bots = await getByFieldOnce('assigned_to', userId);
      return bots.length;
    } catch (e) {
      return 0;
    }
  }

  // Get offline bots (last seen more than 1 hour ago)
  Future<List<BotModel>> getOfflineBots() async {
    try {
      final allBots = await getAllBotsWithRealtimeData();
      
      return allBots.where((bot) {
        // Check if bot is offline based on active status or last_updated
        if (bot.active == false) return true;
        if (bot.lastUpdated == null) return true;
        
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        return bot.lastUpdated!.isBefore(oneHourAgo);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get bots with low battery (less than 20%)
  Future<List<BotModel>> getBotsWithLowBattery() async {
    try {
      final allBots = await getAllBotsWithRealtimeData();
      return allBots.where((bot) {
        return bot.batteryLevel != null && bot.batteryLevel! < 20.0;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Override delete method to also update bot_registry
  @override
  Future<void> delete(String id) async {
    try {
      // First, update the bot_registry to mark as unregistered
      final botRegistryService = BotRegistryService();
      final botRegistryExists = await botRegistryService.botIdExists(id);
      
      if (botRegistryExists) {
        await botRegistryService.unregisterBot(id);
        await loggingService.logEvent(
          event: 'bot_registry_unregistered',
          parameters: {'bot_id': id},
        );
      }
      
      // Then, delete the bot from the bots collection
      await collection.doc(id).delete();
      
      // Also delete from realtime database if exists
      try {
        await _realtimeDb.child('bots/$id').remove();
      } catch (e) {
        // Ignore realtime db errors, not critical
        await loggingService.logError(
          error: e.toString(),
          context: 'bot_delete_realtime_cleanup',
        );
      }
      
      await loggingService.logEvent(
        event: 'bot_deleted',
        parameters: {'id': id},
      );
    } catch (e) {
      await loggingService.logError(
        error: e.toString(),
        context: 'bot_delete_error',
      );
      rethrow;
    }
  }
}
