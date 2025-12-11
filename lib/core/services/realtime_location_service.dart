import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bot_provider.dart';

class RealtimeLocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription<List<BotModel>>? _botsSubscription;
  
  /// Stream of realtime bot locations with role-based filtering
  Stream<List<BotModel>> getRealtimeBotLocations(WidgetRef ref) {
    return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      try {
        final authState = ref.read(authProvider);
        final currentUser = authState.userProfile;
        
        if (currentUser == null) return <BotModel>[];

        // Get all bots from Firestore first
        final botService = ref.read(botServiceProvider);
        List<BotModel> allBots;
        
        if (currentUser.role == 'admin') {
          // For admin: get bots where owner_admin_id matches current user
          allBots = await botService.getBotsByOwnerWithRealtimeData(currentUser.id);
        } else {
          // For field_operator: get bots where assigned_to matches current user
          allBots = await botService.getAllBotsWithRealtimeData();
          allBots = allBots.where((bot) => bot.assignedTo == currentUser.id).toList();
        }

        // Filter out bots that don't have realtime data or are inactive
        final activeBots = <BotModel>[];
        
        for (final bot in allBots) {
          // Check if bot has realtime data and is active
          if (bot.active == true && bot.lat != null && bot.lng != null) {
            activeBots.add(bot);
          }
        }

        return activeBots;
      } catch (e) {
        print('Error getting realtime bot locations: $e');
        return <BotModel>[];
      }
    });
  }

  /// Get realtime location for a specific bot
  Stream<BotModel?> getBotRealtimeLocation(String botId) {
    return _database.ref('bots/$botId').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          // Convert to BotModel with realtime data
          final lat = data['lat'] as double?;
          final lng = data['lng'] as double?;
          final active = data['active'] as bool? ?? false;
          
          if (active && lat != null && lng != null) {
            // Create a minimal BotModel with realtime data
            return BotModel(
              id: botId,
              name: data['name'] as String? ?? 'Unknown Bot',
              organizationId: data['organization_id'] as String?,
              assignedTo: data['assigned_to'] as String?,
              ownerAdminId: data['owner_admin_id'] as String?,
              status: data['status'] as String? ?? 'idle',
              batteryLevel: data['battery_level'] as double?,
              lat: lat,
              lng: lng,
              active: active,
              phLevel: data['ph_level'] as double?,
              temp: data['temp'] as double?,
              turbidity: data['turbidity'] as double?,
              lastUpdated: (data['last_updated'] as int?) != null 
                  ? DateTime.fromMillisecondsSinceEpoch(data['last_updated'] as int)
                  : DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        }
      }
      return null;
    });
  }

  /// Start listening to realtime bot locations
  void startListening(WidgetRef ref, Function(List<BotModel>) onUpdate) {
    _botsSubscription?.cancel();
    
    _botsSubscription = getRealtimeBotLocations(ref).listen(
      onUpdate,
      onError: (error) {
        print('Error in realtime bot locations stream: $error');
      },
    );
  }

  /// Stop listening to realtime bot locations
  void stopListening() {
    _botsSubscription?.cancel();
    _botsSubscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}

// Provider for the realtime location service
final realtimeLocationServiceProvider = Provider((ref) => RealtimeLocationService());
