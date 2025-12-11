import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'logging_service.dart';

class ControlLockHandle {
  final String botId;
  final String uid;
  final String sessionId;
  final DatabaseReference ref;
  final OnDisconnect onDisconnect;
  Timer? _heartbeatTimer;

  ControlLockHandle({
    required this.botId,
    required this.uid,
    required this.sessionId,
    required this.ref,
    required this.onDisconnect,
  });

  void startHeartbeat({int ttlMs = 60000, int intervalMs = 15000}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      try {
        await ref.update({
          'lastSeen': now,
          'expiresAt': now + ttlMs,
        });
      } catch (_) {}
    });
  }

  Future<void> release() async {
    _heartbeatTimer?.cancel();
    try {
      await ref.runTransaction((value) {
        final data = (value as Map?)?.cast<String, dynamic>();
        if (data != null && data['sessionId'] == sessionId && data['uid'] == uid) {
          return Transaction.success(null);
        }
        return Transaction.success(value);
      });
    } catch (_) {}
  }
}

class ControlLockService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final LoggingService _logging = LoggingService();
  static const int defaultTtlMs = 60000; // 60 seconds
  static const int defaultHeartbeatMs = 15000; // 15 seconds

  DatabaseReference _lockRef(String botId) => _db.ref('control_locks/$botId');

  /// Try to claim control for a bot. Returns a handle if success; otherwise returns null.
  Future<ControlLockHandle?> claimLock({
    required String botId,
    required String uid,
    required String sessionId,
    required String displayName,
    required String role,
    int ttlMs = defaultTtlMs,
  }) async {
    final ref = _lockRef(botId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + ttlMs;
    String? prevUidOverridden;

    final result = await ref.runTransaction((value) {
      final current = (value as Map?)?.cast<String, dynamic>();
      if (current != null) {
        final curUid = current['uid'] as String?;
        final curSession = current['sessionId'] as String?;
        final curExpires = (current['expiresAt'] as num?)?.toInt() ?? 0;
        final takeover = (current['takeover'] as Map?)?.cast<String, dynamic>();
        final requestedBy = takeover != null ? takeover['requestedByUid'] as String? : null;
        final executeAt = takeover != null ? (takeover['executeAt'] as num?)?.toInt() ?? 0 : 0;

        // If lock belongs to someone else and still valid
        if (curUid != uid && curSession != sessionId && curExpires > now) {
          // Allow override if takeover scheduled by this uid and grace period passed
          if (requestedBy == uid && now >= executeAt) {
            prevUidOverridden = curUid;
            return Transaction.success({
              'uid': uid,
              'name': displayName,
              'role': role,
              'sessionId': sessionId,
              'startedAt': now,
              'lastSeen': now,
              'expiresAt': expiresAt,
              'takeover': null,
            });
          }
          return Transaction.abort();
        }
      }
      return Transaction.success({
        'uid': uid,
        'name': displayName,
        'role': role,
        'sessionId': sessionId,
        'startedAt': now,
        'lastSeen': now,
        'expiresAt': expiresAt,
      });
    });

    if (!result.committed) {
      return null; // occupied
    }

    // Log takeover execution if happened
    if (prevUidOverridden != null) {
      try {
        await _logging.logBotOperation(
          botId: botId,
          operation: 'control_takeover_executed',
          userId: uid,
          metadata: {
            'previous_controller_uid': prevUidOverridden,
            'timestamp_ms': now,
          },
        );
      } catch (_) {}
    }

    final onDisconnect = ref.onDisconnect();
    await onDisconnect.remove();

    final handle = ControlLockHandle(botId: botId, uid: uid, sessionId: sessionId, ref: ref, onDisconnect: onDisconnect);
    handle.startHeartbeat(ttlMs: ttlMs, intervalMs: defaultHeartbeatMs);
    return handle;
  }

  /// Release the lock if owned by the caller
  Future<void> releaseLock({
    required String botId,
    required String uid,
    required String sessionId,
  }) async {
    final ref = _lockRef(botId);
    try {
      await ref.runTransaction((value) {
        final cur = (value as Map?)?.cast<String, dynamic>();
        if (cur != null && cur['uid'] == uid && cur['sessionId'] == sessionId) {
          return Transaction.success(null);
        }
        return Transaction.success(value);
      });
    } catch (_) {}
  }

  /// Request takeover with a grace period. Notifies the current controller.
  Future<void> requestTakeover({
    required String botId,
    required String requestedByUid,
    required String requestedByName,
    required String requestedByRole,
    int graceSeconds = 10,
  }) async {
    final ref = _lockRef(botId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final executeAt = now + (graceSeconds * 1000);
    try {
      await ref.update({
        'takeover': {
          'requestedByUid': requestedByUid,
          'requestedByName': requestedByName,
          'requestedByRole': requestedByRole,
          'requestedAt': now,
          'executeAt': executeAt,
        }
      });
      await _logging.logBotOperation(
        botId: botId,
        operation: 'control_takeover_requested',
        userId: requestedByUid,
        metadata: {
          'requested_by_name': requestedByName,
          'grace_seconds': graceSeconds,
          'execute_at_ms': executeAt,
        },
      );
    } catch (_) {}
  }

  /// Read current lock holder (if any). Returns map or null.
  Future<Map<String, dynamic>?> getCurrentLock(String botId) async {
    final snap = await _lockRef(botId).get();
    if (!snap.exists) return null;
    final data = (snap.value as Map?)?.cast<String, dynamic>();
    if (data == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = (data['expiresAt'] as num?)?.toInt() ?? 0;
    if (expires <= now) return null; // stale
    return data;
  }

  /// Cancel a scheduled takeover.
  Future<void> cancelTakeover({
    required String botId,
    required String requestedByUid,
  }) async {
    final ref = _lockRef(botId);
    try {
      await ref.child('takeover').remove();
      await _logging.logBotOperation(
        botId: botId,
        operation: 'control_takeover_canceled',
        userId: requestedByUid,
      );
    } catch (_) {}
  }

  /// Surrender control by releasing the lock.
  Future<void> surrenderControl({
    required String botId,
    required String currentControllerUid,
  }) async {
    final ref = _lockRef(botId);
    try {
      await ref.remove();
      await _logging.logBotOperation(
        botId: botId,
        operation: 'control_surrendered',
        userId: currentControllerUid,
      );
    } catch (_) {}
  }

  /// Watch lock changes for a bot.
  Stream<Map<String, dynamic>?> watchLock(String botId) {
    return _lockRef(botId).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = (event.snapshot.value as Map?)?.cast<String, dynamic>();
      if (data == null) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expires = (data['expiresAt'] as num?)?.toInt() ?? 0;
      if (expires <= now) return null; // stale
      return data;
    });
  }
}

// Provider pattern can be added in your DI if needed
