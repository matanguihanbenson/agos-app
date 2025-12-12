import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_database/firebase_database.dart';

class PresenceSessionHandle {
  final String uid;
  final String sessionId;
  final DatabaseReference ref;
  final OnDisconnect onDisconnect;
  Timer? _heartbeatTimer;

  PresenceSessionHandle({
    required this.uid,
    required this.sessionId,
    required this.ref,
    required this.onDisconnect,
  });

  void startHeartbeat({int ttlMs = 120000, int intervalMs = 30000}) {
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
        if (data != null && data['sessionId'] == sessionId) {
          return Transaction.success(null);
        }
        return Transaction.success(value);
      });
    } catch (_) {}
  }
}

class PresenceService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  static const int defaultTtlMs = 120000; // 2 minutes
  static const int defaultHeartbeatMs = 30000; // 30 seconds

  DatabaseReference _userPresenceRef(String uid) => _db.ref('presence/users/$uid');

  Map<String, dynamic> _buildDeviceInfo() {
    final platform = kIsWeb
        ? 'web'
        : Platform.isAndroid
            ? 'android'
            : Platform.isIOS
                ? 'ios'
                : Platform.isWindows
                    ? 'windows'
                    : Platform.isMacOS
                        ? 'macos'
                        : Platform.isLinux
                            ? 'linux'
                            : 'unknown';
    return {
      'platform': platform,
    };
  }

  /// Try to claim a session for a user.
  /// For non-admin users: single session across all platforms.
  /// For admin users: allow one session per platform (web + mobile concurrently), but not multiple on the same platform.
  Future<PresenceSessionHandle?> claimUserSession({
    required String uid,
    required String sessionId,
    int ttlMs = defaultTtlMs,
    bool isAdmin = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + ttlMs;
    final device = _buildDeviceInfo();
    final platform = (device['platform'] as String?) ?? 'unknown';

    final rootRef = _userPresenceRef(uid);
    final platformRef = _db.ref('presence/users/$uid/$platform');

    // Determine if this is a mobile platform
    final bool isMobilePlatform = platform == 'android' || platform == 'ios';

    // For non-admin users: always enforce a single active session
    // across all platforms.
    //
    // For admin users on mobile (android/iOS): enforce a single active
    // mobile session across all mobile devices/OSes, but still allow
    // a separate web session.
    if (!isAdmin || isMobilePlatform) {
      try {
        final snap = await rootRef.get();
        if (snap.exists && snap.value is Map) {
          final m = Map<String, dynamic>.from(snap.value as Map);
          for (final entry in m.entries) {
            final val = entry.value;
            if (val is Map) {
              final entryPlatform = entry.key;
              final bool isEntryMobile =
                  entryPlatform == 'android' || entryPlatform == 'ios';

              // Decide whether this existing session should block the
              // current claim.
              // - Non-admins: any active session (web or mobile) blocks.
              // - Admins on mobile: only other active mobile sessions block
              //   so they can still have one web + one mobile session.
              bool shouldCheck;
              if (!isAdmin) {
                shouldCheck = true;
              } else {
                shouldCheck = isMobilePlatform && isEntryMobile;
              }

              if (!shouldCheck) {
                continue;
              }

              final curExpires = (val['expiresAt'] as num?)?.toInt() ?? 0;
              final curSession = val['sessionId'] as String?;
              if (curSession != null && curSession.isNotEmpty && curExpires > now && curSession != sessionId) {
                return null;
              }
            }
          }
        }
      } catch (_) {}
    }

    final result = await platformRef.runTransaction((value) {
      final current = (value as Map?)?.cast<String, dynamic>();
      if (current != null) {
        final curSession = current['sessionId'] as String?;
        final curExpires = (current['expiresAt'] as num?)?.toInt() ?? 0;
        if (curSession != null && curSession.isNotEmpty && curExpires > now && curSession != sessionId) {
          return Transaction.abort();
        }
      }
      return Transaction.success({
        'sessionId': sessionId,
        'device': device,
        'startedAt': now,
        'lastSeen': now,
        'expiresAt': expiresAt,
      });
    });

    if (!result.committed) {
      return null;
    }

    final onDisconnect = platformRef.onDisconnect();
    await onDisconnect.remove();

    final handle = PresenceSessionHandle(uid: uid, sessionId: sessionId, ref: platformRef, onDisconnect: onDisconnect);
    handle.startHeartbeat(ttlMs: ttlMs, intervalMs: defaultHeartbeatMs);
    return handle;
  }

  Future<void> releaseUserSession({
    required String uid,
    required String sessionId,
  }) async {
    final device = _buildDeviceInfo();
    final platform = (device['platform'] as String?) ?? 'unknown';
    final ref = _db.ref('presence/users/$uid/$platform');
    try {
      await ref.runTransaction((value) {
        final data = (value as Map?)?.cast<String, dynamic>();
        if (data != null && data['sessionId'] == sessionId) {
          return Transaction.success(null);
        }
        return Transaction.success(value);
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getActiveSessions(String uid) async {
    final snap = await _userPresenceRef(uid).get();
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String, dynamic>{};
    if (snap.exists && snap.value is Map) {
      final m = Map<String, dynamic>.from(snap.value as Map);
      m.forEach((key, val) {
        if (val is Map) {
          final expires = (val['expiresAt'] as num?)?.toInt() ?? 0;
          if (expires > now) {
            result[key] = val;
          }
        }
      });
    }
    return result;
  }
}

