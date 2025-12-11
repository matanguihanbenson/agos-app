import 'package:cloud_firestore/cloud_firestore.dart';

/// Category of activity log
enum ActivityLogCategory {
  system,
  auth,
  user,
  bot,
}

/// Type of activity log with detailed classification
enum ActivityLogType {
  // Auth types
  login,
  logout,
  loginFailed,
  passwordChanged,
  passwordResetRequested,
  passwordResetCompleted,
  accountLocked,
  accountUnlocked,
  
  // User types
  userCreated,
  userUpdated,
  userDeleted,
  userRoleChanged,
  userStatusChanged,
  userAssignedToOrg,
  userRemovedFromOrg,
  userBotAssigned,
  userBotUnassigned,
  profileUpdated,
  
  // Bot types
  botRegistered,
  botUnregistered,
  botAssigned,
  botReassigned,
  botUnassigned,
  botAddedToOrg,
  botRemovedFromOrg,
  botStatusChanged,
  botUpdated,
  scheduleCreated,
  scheduleCanceled,
  scheduleCompleted,
  deploymentStarted,
  deploymentCompleted,
  deploymentFailed,
  
  // System types
  systemError,
  systemWarning,
  systemInfo,
  configurationChanged,
  maintenanceStarted,
  maintenanceCompleted,
  
  // Other
  other,
}

/// Severity level of the log
enum ActivityLogSeverity {
  info,
  warning,
  error,
  critical,
  success,
}

/// Model for activity log
class ActivityLogModel {
  final String id;
  final ActivityLogCategory category;
  final ActivityLogType type;
  final ActivityLogSeverity severity;
  final String title;
  final String description;
  final String? userId;
  final String? userName;
  final String? targetUserId;
  final String? targetUserName;
  final String? botId;
  final String? botName;
  final String? organizationId;
  final String? organizationName;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? ipAddress;
  final String? deviceInfo;
  final String platform;

  ActivityLogModel({
    required this.id,
    required this.category,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.userId,
    this.userName,
    this.targetUserId,
    this.targetUserName,
    this.botId,
    this.botName,
    this.organizationId,
    this.organizationName,
    required this.metadata,
    required this.timestamp,
    this.ipAddress,
    this.deviceInfo,
    required this.platform,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'user_id': userId,
      'user_name': userName,
      'target_user_id': targetUserId,
      'target_user_name': targetUserName,
      'bot_id': botId,
      'bot_name': botName,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'metadata': metadata,
      'timestamp': FieldValue.serverTimestamp(),
      'ip_address': ipAddress,
      'device_info': deviceInfo,
      'platform': platform,
    };
  }

  /// Create from Firestore map
  factory ActivityLogModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityLogModel(
      id: id,
      category: ActivityLogCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ActivityLogCategory.system,
      ),
      type: ActivityLogType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityLogType.other,
      ),
      severity: ActivityLogSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => ActivityLogSeverity.info,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      userId: map['user_id'],
      userName: map['user_name'],
      targetUserId: map['target_user_id'],
      targetUserName: map['target_user_name'],
      botId: map['bot_id'],
      botName: map['bot_name'],
      organizationId: map['organization_id'],
      organizationName: map['organization_name'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ipAddress: map['ip_address'],
      deviceInfo: map['device_info'],
      platform: map['platform'] ?? 'unknown',
    );
  }

  /// Copy with method
  ActivityLogModel copyWith({
    String? id,
    ActivityLogCategory? category,
    ActivityLogType? type,
    ActivityLogSeverity? severity,
    String? title,
    String? description,
    String? userId,
    String? userName,
    String? targetUserId,
    String? targetUserName,
    String? botId,
    String? botName,
    String? organizationId,
    String? organizationName,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    String? ipAddress,
    String? deviceInfo,
    String? platform,
  }) {
    return ActivityLogModel(
      id: id ?? this.id,
      category: category ?? this.category,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      botId: botId ?? this.botId,
      botName: botName ?? this.botName,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      ipAddress: ipAddress ?? this.ipAddress,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      platform: platform ?? this.platform,
    );
  }
}
