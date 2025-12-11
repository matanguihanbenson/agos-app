import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bot_model.dart';
import '../providers/auth_provider.dart';
import '../constants/telemetry_keys.dart';

class RealtimeBotService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  StreamSubscription<QuerySnapshot>? _schedulesSubscription;
  Map<String, StreamSubscription<DatabaseEvent>> _realtimeSubscriptions = {};
  final StreamController<List<BotModel>> _botsController = StreamController<List<BotModel>>.broadcast();
  
  Map<String, BotModel> _firestoreBots = {};
  Map<String, Map<String, dynamic>> _realtimeData = {};
  
  // Throttle mirror writes per bot (ms)
  final Map<String, int> _lastMirrorWriteMs = {};
  static const int _mirrorIntervalMs = 15000; // 15 seconds
  final Map<String, int> _lastBatteryRecallMs = {}; // to throttle recalls
  final Map<String, String?> _lastScheduleId = {};
  final Map<String, String?> _lastStatus = {};
  
  /// Stream of realtime bot data with role-based filtering
  Stream<List<BotModel>> getRealtimeBots(Ref ref) {
    final authState = ref.read(authProvider);
    final currentUser = authState.userProfile;
    
    if (currentUser == null) {
      _botsController.add([]);
      return _botsController.stream;
    }

    _startListening(currentUser);
    return _botsController.stream;
  }

  void _startListening(dynamic currentUser) {
    // Listen to Firestore changes based on user role
    if (currentUser.role == 'admin') {
      _listenToAdminBots(currentUser.id);
      _listenToSchedulesForAdmin(currentUser.id);
    } else {
      _listenToFieldOperatorBots(currentUser.id);
      _listenToSchedulesForOperator(currentUser.id);
    }
  }

  void _listenToAdminBots(String adminId) {
    _firestoreSubscription?.cancel();
    
    _firestoreSubscription = _firestore
        .collection('bots')
        .where('owner_admin_id', isEqualTo: adminId)
        .snapshots()
        .listen((snapshot) {
      _handleFirestoreChanges(snapshot);
    });
  }

  void _listenToFieldOperatorBots(String userId) {
    _firestoreSubscription?.cancel();
    
    _firestoreSubscription = _firestore
        .collection('bots')
        .where('assigned_to', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _handleFirestoreChanges(snapshot);
    });
  }

  void _handleFirestoreChanges(QuerySnapshot snapshot) {
    // Update Firestore bots
    _firestoreBots.clear();
    
    for (final doc in snapshot.docs) {
      final bot = BotModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      _firestoreBots[doc.id] = bot;
      
      // Start listening to realtime data for this bot
      _startRealtimeListening(doc.id);
    }
    
    // Remove realtime subscriptions for bots that no longer exist in Firestore
    final currentBotIds = _firestoreBots.keys.toSet();
    final realtimeBotIds = _realtimeSubscriptions.keys.toSet();
    
    for (final botId in realtimeBotIds) {
      if (!currentBotIds.contains(botId)) {
        _realtimeSubscriptions[botId]?.cancel();
        _realtimeSubscriptions.remove(botId);
        _realtimeData.remove(botId);
      }
    }
    
    _emitUpdatedBots();
  }

  void _startRealtimeListening(String botId) {
    // Cancel existing subscription if any
    _realtimeSubscriptions[botId]?.cancel();
    
    // Start new subscription
    _realtimeSubscriptions[botId] = _database
        .ref('bots/$botId')
        .onValue
        .listen((event) async {
      if (event.snapshot.exists) {
        final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
        final normalized = Map<String, dynamic>.from(raw);
        final bool isActive = normalized['active'] == true;
        final String? statusStr = (normalized['status'] as String?)?.toLowerCase();
        final hasSchedule = normalized['current_schedule_id'] != null;
        if (isActive) {
          normalized['status'] = 'active';
        } else if (statusStr == 'recalling') {
          normalized['status'] = 'recalling';
        } else if (hasSchedule && statusStr != 'active') {
          normalized['status'] = 'scheduled';
        } else {
          normalized['status'] = statusStr ?? 'idle';
        }
        // Track last known schedule and status for docking completion
        final currentStatus = normalized['status'] as String?;
        final currentScheduleId = normalized['current_schedule_id'] as String?;
        if (currentScheduleId != null && currentScheduleId.isNotEmpty) {
          _lastScheduleId[botId] = currentScheduleId;
        }
        final prevStatus = _lastStatus[botId]?.toLowerCase();
        _lastStatus[botId] = currentStatus?.toLowerCase();
        _realtimeData[botId] = normalized;

        // Safety: Auto-recall if battery critically low and bot is deployed
        await _autoRecallIfLowBattery(botId, normalized);

        // Mirror telemetry to deployments/{id}/readings if active
        await _mirrorTelemetryIfActive(botId, normalized);

        // If bot just docked (recalling -> idle), complete schedule/deployment in Firestore.
        // We intentionally do NOT auto-complete on plain idle transitions,
        // to avoid completing freshly scheduled missions that never actually ran.
        if (prevStatus == 'recalling' && (currentStatus?.toLowerCase() == 'idle')) {
          final scheduleId = _lastScheduleId[botId];
          if (scheduleId != null && scheduleId.isNotEmpty) {
            try {
              await _firestore.collection('schedules').doc(scheduleId).update({
                'status': 'completed',
                'completed_at': DateTime.now(),
              });
              final schedDoc = await _firestore.collection('schedules').doc(scheduleId).get();
              final depId = (schedDoc.data() ?? const {})['deployment_id'] as String?;
              if (depId != null && depId.isNotEmpty) {
                await _firestore.collection('deployments').doc(depId).update({
                  'status': 'completed',
                  'actual_end_time': DateTime.now(),
                });
              }
            } catch (_) {}
          }
          // Clear solar charging flag on docking
          try {
            await _database.ref('bots/$botId').update({
              'solar_charging': false,
              'last_updated': ServerValue.timestamp,
            });
          } catch (_) {}
          _lastScheduleId.remove(botId);
        }
      } else {
        _realtimeData.remove(botId);
      }
      _emitUpdatedBots();
    });
  }

  Future<void> _mirrorTelemetryIfActive(String botId, Map<String, dynamic> data) async {
    try {
      final status = (data[TelemetryKeys.status] as String?)?.toLowerCase();
      final depId = data[TelemetryKeys.currentDeploymentId] as String?;
      if (status != 'active' || depId == null || depId.isEmpty) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final last = _lastMirrorWriteMs[botId] ?? 0;
      if (nowMs - last < _mirrorIntervalMs) return; // throttle
      _lastMirrorWriteMs[botId] = nowMs;

      // Prepare reading payload with fallbacks
      double? ph = (data[TelemetryKeys.ph] as num?)?.toDouble();
      double? turb = (data[TelemetryKeys.turbidity] as num?)?.toDouble();
      double? temp = (data[TelemetryKeys.temp] as num?)?.toDouble();
      double? trash = (data[TelemetryKeys.trash] as num?)?.toDouble();
      double? batt = (data[TelemetryKeys.battery] as num?)?.toDouble();
      double? lat = (data[TelemetryKeys.lat] as num?)?.toDouble();
      double? lng = (data[TelemetryKeys.lng] as num?)?.toDouble();

      final payload = <String, dynamic>{
        'ts': nowMs,
        if (ph != null) 'ph_level': ph,
        if (turb != null) 'turbidity': turb,
        if (temp != null) 'temp': temp,
        if (trash != null) 'trash_collected': trash,
        if (batt != null) 'battery_level': batt,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

      await _database.ref('deployments/$depId/readings/$nowMs').set(payload);
      await _database.ref('deployments/$depId').update({
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      // Swallow errors to not break UI
    }
  }

  void _listenToSchedulesForAdmin(String ownerAdminId) {
    _schedulesSubscription?.cancel();
    _schedulesSubscription = _firestore
        .collection('schedules')
        .where('owner_admin_id', isEqualTo: ownerAdminId)
        .snapshots()
        .listen((snapshot) async {
      try {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final scheduleId = doc.id;
          final botId = data['bot_id'] as String?;
          final status = (data['status'] as String?)?.toLowerCase();
          final deploymentId = data['deployment_id'] as String?; // set during creation
          if (botId == null || status == null) continue;

          final DatabaseReference botRef = _database.ref('bots/$botId');
          if (status == 'scheduled') {
            await botRef.update({
              'status': 'scheduled',
              'current_schedule_id': scheduleId,
              // Align with GAS: use botId for current_deployment_id
              'current_deployment_id': botId,
              'last_updated': ServerValue.timestamp,
            });
            await _database.ref('deployments/$botId').update({
              'status': 'scheduled',
              'scheduled_start_time': (data['scheduled_date'] as Timestamp?)?.millisecondsSinceEpoch,
              'scheduled_end_time': (data['scheduled_end_date'] as Timestamp?)?.millisecondsSinceEpoch,
              'updated_at': ServerValue.timestamp,
            });
          } else if (status == 'active') {
            await botRef.update({
              'status': 'active',
              'active': true,
              'current_schedule_id': scheduleId,
              'current_deployment_id': botId,
              'last_updated': ServerValue.timestamp,
            });
            await _database.ref('deployments/$botId').update({
              'status': 'active',
              'actual_start_time': ServerValue.timestamp,
              'updated_at': ServerValue.timestamp,
            });
          
          } else if (status == 'completed' || status == 'cancelled') {
            await botRef.update({
              'status': 'idle',
              'active': false,
              'current_schedule_id': null,
              'current_deployment_id': null,
              'last_updated': ServerValue.timestamp,
            });
            await _database.ref('deployments/$botId').update({
              'status': 'completed',
              'actual_end_time': ServerValue.timestamp,
              'updated_at': ServerValue.timestamp,
            });
          }
        }
      } catch (e) {
        // Don't break realtime bots stream on schedule sync errors
      }
    });
  }

  void _listenToSchedulesForOperator(String operatorId) {
    _schedulesSubscription?.cancel();
    // Listen to schedules where this operator is assigned
    _schedulesSubscription = _firestore
        .collection('schedules')
        .where('assigned_operator_id', isEqualTo: operatorId)
        .snapshots()
        .listen((snapshot) async {
      try {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final scheduleId = doc.id;
          final botId = data['bot_id'] as String?;
          final status = (data['status'] as String?)?.toLowerCase();
          final deploymentId = data['deployment_id'] as String?;
          if (botId == null || status == null) continue;

          final DatabaseReference botRef = _database.ref('bots/$botId');
          if (status == 'scheduled') {
            await botRef.update({
              'status': 'scheduled',
              'current_schedule_id': scheduleId,
              'current_deployment_id': botId,
              'last_updated': ServerValue.timestamp,
            });
            await _database.ref('deployments/$botId').update({
              'status': 'scheduled',
              'scheduled_start_time': (data['scheduled_date'] as Timestamp?)?.millisecondsSinceEpoch,
              'scheduled_end_time': (data['scheduled_end_date'] as Timestamp?)?.millisecondsSinceEpoch,
              'updated_at': ServerValue.timestamp,
            });
          } else if (status == 'active') {
            await botRef.update({
              'status': 'active',
              'active': true,
              'current_schedule_id': scheduleId,
              'current_deployment_id': botId,
              'last_updated': ServerValue.timestamp,
            });
            await _database.ref('deployments/$botId').update({
              'status': 'active',
              'actual_start_time': ServerValue.timestamp,
              'updated_at': ServerValue.timestamp,
            });
          
          } else if (status == 'completed' || status == 'cancelled') {
            await botRef.update({
              'status': 'idle',
              'active': false,
              'current_schedule_id': null,
              'current_deployment_id': null,
              'last_updated': ServerValue.timestamp,
            });
            await _database.ref('deployments/$botId').update({
              'status': 'completed',
              'actual_end_time': ServerValue.timestamp,
              'updated_at': ServerValue.timestamp,
            });
          }
        }
      } catch (e) {
        // ignore
      }
    });
  }

  Future<void> _autoRecallIfLowBattery(String botId, Map<String, dynamic> data) async {
    try {
      final status = (data['status'] as String?)?.toLowerCase();
      final hasSchedule = data['current_schedule_id'] != null;
      final num? batteryRaw = (data['battery_level'] ?? data['battery'] ?? data['battery_pct']) as num?;
      final battery = batteryRaw?.toDouble();
      if (battery == null) return;

      final deployedLike = status == 'active' || status == 'scheduled' || hasSchedule;
      if (!deployedLike) return;

      if (battery <= 15.0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final last = _lastBatteryRecallMs[botId] ?? 0;
        if (now - last < 60 * 1000) return; // throttle: 1 minute
        _lastBatteryRecallMs[botId] = now;

        final String? scheduleId = data['current_schedule_id'] as String?;
        // 1) Set recalling
        await _database.ref('bots/$botId').update({
          'status': 'recalling',
          'solar_charging': true,
          'last_updated': ServerValue.timestamp,
        });

        // 2) Mark RTDB deployment as returning
        await _database.ref('deployments/$botId').update({
          'status': 'returning',
          'updated_at': ServerValue.timestamp,
        });
      }
    } catch (_) {}
  }

  void _emitUpdatedBots() {
    final List<BotModel> updatedBots = [];
    
    for (final entry in _firestoreBots.entries) {
      final botId = entry.key;
      final firestoreBot = entry.value;
      final realtimeData = _realtimeData[botId];
      
      // Create bot with merged data
      final botWithRealtimeData = BotModel.fromMapWithRealtimeData(
        firestoreBot.toMap(),
        botId,
        realtimeData,
      );
      
      updatedBots.add(botWithRealtimeData);
    }
    
    _botsController.add(updatedBots);
  }

  /// Get active bots (with realtime data where active = true)
  List<BotModel> getActiveBots(List<BotModel> allBots) {
    return allBots.where((bot) => 
        bot.active == true && 
        bot.lat != null && 
        bot.lng != null
    ).toList();
  }

  /// Dispose resources
  void dispose() {
    _firestoreSubscription?.cancel();
    _schedulesSubscription?.cancel();
    for (final subscription in _realtimeSubscriptions.values) {
      subscription.cancel();
    }
    _realtimeSubscriptions.clear();
    _botsController.close();
  }
}

// Provider for the realtime bot service
final realtimeBotServiceProvider = Provider((ref) => RealtimeBotService());
