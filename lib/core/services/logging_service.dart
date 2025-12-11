import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_log_model.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _platform => Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');

  // Main logging method
  Future<void> logActivity(ActivityLogModel log) async {
    try {
      await _firestore.collection('activity_logs').add(log.toMap());
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // ==================== AUTH LOGS ====================

  Future<void> logLogin({
    required String userId,
    required String userName,
    required String email,
    String? ipAddress,
    String? deviceInfo,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.auth,
      type: ActivityLogType.login,
      severity: ActivityLogSeverity.success,
      title: 'User Logged In',
      description: '$userName successfully logged into the system',
      userId: userId,
      userName: userName,
      metadata: {'email': email},
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      platform: _platform,
    ));
  }

  Future<void> logLogout({
    required String userId,
    required String userName,
    String? ipAddress,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.auth,
      type: ActivityLogType.logout,
      severity: ActivityLogSeverity.info,
      title: 'User Logged Out',
      description: '$userName logged out of the system',
      userId: userId,
      userName: userName,
      metadata: {},
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      platform: _platform,
    ));
  }

  Future<void> logLoginFailed({
    required String email,
    required String reason,
    String? ipAddress,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.auth,
      type: ActivityLogType.loginFailed,
      severity: ActivityLogSeverity.warning,
      title: 'Login Attempt Failed',
      description: 'Failed login attempt for $email: $reason',
      metadata: {'email': email, 'reason': reason},
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      platform: _platform,
    ));
  }

  Future<void> logPasswordChanged({
    required String userId,
    required String userName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.auth,
      type: ActivityLogType.passwordChanged,
      severity: ActivityLogSeverity.success,
      title: 'Password Changed',
      description: '$userName successfully changed their password',
      userId: userId,
      userName: userName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logPasswordResetRequested({
    required String email,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.auth,
      type: ActivityLogType.passwordResetRequested,
      severity: ActivityLogSeverity.info,
      title: 'Password Reset Requested',
      description: 'Password reset email sent to $email',
      metadata: {'email': email},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  // ==================== USER LOGS ====================

  Future<void> logUserCreated({
    required String creatorUserId,
    required String creatorUserName,
    required String newUserId,
    required String newUserName,
    required String newUserEmail,
    required String role,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.userCreated,
      severity: ActivityLogSeverity.success,
      title: 'New User Created',
      description: '$creatorUserName created new user: $newUserName ($role)',
      userId: creatorUserId,
      userName: creatorUserName,
      targetUserId: newUserId,
      targetUserName: newUserName,
      metadata: {'email': newUserEmail, 'role': role},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logUserUpdated({
    required String updaterUserId,
    required String updaterUserName,
    required String targetUserId,
    required String targetUserName,
    required Map<String, dynamic> changes,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.userUpdated,
      severity: ActivityLogSeverity.info,
      title: 'User Profile Updated',
      description: '$updaterUserName updated profile for $targetUserName',
      userId: updaterUserId,
      userName: updaterUserName,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      metadata: {'changes': changes},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logProfileUpdated({
    required String userId,
    required String userName,
    required Map<String, dynamic> changes,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.profileUpdated,
      severity: ActivityLogSeverity.info,
      title: 'Profile Updated',
      description: '$userName updated their profile',
      userId: userId,
      userName: userName,
      metadata: {'changes': changes},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logUserDeleted({
    required String deleterUserId,
    required String deleterUserName,
    required String deletedUserId,
    required String deletedUserName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.userDeleted,
      severity: ActivityLogSeverity.warning,
      title: 'User Deleted',
      description: '$deleterUserName deleted user: $deletedUserName',
      userId: deleterUserId,
      userName: deleterUserName,
      targetUserId: deletedUserId,
      targetUserName: deletedUserName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logUserAssignedToOrg({
    required String assignerUserId,
    required String assignerUserName,
    required String userId,
    required String userName,
    required String organizationId,
    required String organizationName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.userAssignedToOrg,
      severity: ActivityLogSeverity.info,
      title: 'User Assigned to Organization',
      description: '$assignerUserName assigned $userName to $organizationName',
      userId: assignerUserId,
      userName: assignerUserName,
      targetUserId: userId,
      targetUserName: userName,
      organizationId: organizationId,
      organizationName: organizationName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logUserBotAssigned({
    required String assignerUserId,
    required String assignerUserName,
    required String userId,
    required String userName,
    required String botId,
    required String botName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.userBotAssigned,
      severity: ActivityLogSeverity.info,
      title: 'Bot Assigned to User',
      description: '$assignerUserName assigned bot "$botName" to $userName',
      userId: assignerUserId,
      userName: assignerUserName,
      targetUserId: userId,
      targetUserName: userName,
      botId: botId,
      botName: botName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  // ==================== BOT LOGS ====================

  Future<void> logBotRegistered({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    String? serialNumber,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.botRegistered,
      severity: ActivityLogSeverity.success,
      title: 'Bot Registered',
      description: '$userName registered new bot: $botName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      metadata: {'serial_number': serialNumber},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logBotUnregistered({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.botUnregistered,
      severity: ActivityLogSeverity.warning,
      title: 'Bot Unregistered',
      description: '$userName unregistered bot: $botName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logBotAssigned({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    required String operatorId,
    required String operatorName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.botAssigned,
      severity: ActivityLogSeverity.info,
      title: 'Bot Assigned',
      description: '$userName assigned bot "$botName" to $operatorName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      targetUserId: operatorId,
      targetUserName: operatorName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logBotReassigned({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    required String oldOperatorId,
    required String oldOperatorName,
    required String newOperatorId,
    required String newOperatorName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.botReassigned,
      severity: ActivityLogSeverity.info,
      title: 'Bot Reassigned',
      description: '$userName reassigned bot "$botName" from $oldOperatorName to $newOperatorName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      targetUserId: newOperatorId,
      targetUserName: newOperatorName,
      metadata: {'old_operator_id': oldOperatorId, 'old_operator_name': oldOperatorName},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logBotUnassigned({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    required String operatorId,
    required String operatorName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.botUnassigned,
      severity: ActivityLogSeverity.info,
      title: 'Bot Unassigned',
      description: '$userName unassigned bot "$botName" from $operatorName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      targetUserId: operatorId,
      targetUserName: operatorName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logBotAddedToOrg({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    required String organizationId,
    required String organizationName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.botAddedToOrg,
      severity: ActivityLogSeverity.info,
      title: 'Bot Added to Organization',
      description: '$userName added bot "$botName" to $organizationName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      organizationId: organizationId,
      organizationName: organizationName,
      metadata: {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logScheduleCreated({
    required String userId,
    required String userName,
    required String scheduleId,
    required String scheduleName,
    required String botId,
    required String botName,
    required DateTime scheduledTime,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.scheduleCreated,
      severity: ActivityLogSeverity.info,
      title: 'Schedule Created',
      description: '$userName created schedule "$scheduleName" for bot "$botName"',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      metadata: {
        'schedule_id': scheduleId,
        'schedule_name': scheduleName,
        'scheduled_time': scheduledTime.toIso8601String(),
      },
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logScheduleCanceled({
    required String userId,
    required String userName,
    required String scheduleId,
    required String scheduleName,
    required String botId,
    required String botName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.scheduleCanceled,
      severity: ActivityLogSeverity.warning,
      title: 'Schedule Canceled',
      description: '$userName canceled schedule "$scheduleName" for bot "$botName"',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      metadata: {'schedule_id': scheduleId, 'schedule_name': scheduleName},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logDeploymentStarted({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    required String riverId,
    required String riverName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.deploymentStarted,
      severity: ActivityLogSeverity.info,
      title: 'Deployment Started',
      description: '$userName started deployment of bot "$botName" to $riverName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      metadata: {'river_id': riverId, 'river_name': riverName},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logDeploymentCompleted({
    required String userId,
    required String userName,
    required String botId,
    required String botName,
    required String riverId,
    required String riverName,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.deploymentCompleted,
      severity: ActivityLogSeverity.success,
      title: 'Deployment Completed',
      description: 'Bot "$botName" successfully completed deployment to $riverName',
      userId: userId,
      userName: userName,
      botId: botId,
      botName: botName,
      metadata: {'river_id': riverId, 'river_name': riverName},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  // ==================== SYSTEM LOGS ====================

  Future<void> logError({
    required String error,
    required String context,
    String? userId,
    String? userName,
    StackTrace? stackTrace,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.system,
      type: ActivityLogType.systemError,
      severity: ActivityLogSeverity.error,
      title: 'System Error',
      description: 'Error in $context: $error',
      userId: userId,
      userName: userName,
      metadata: {
        'error': error,
        'context': context,
        'stack_trace': stackTrace?.toString(),
      },
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logSystemWarning({
    required String message,
    required String context,
    Map<String, dynamic>? metadata,
  }) async {
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.system,
      type: ActivityLogType.systemWarning,
      severity: ActivityLogSeverity.warning,
      title: 'System Warning',
      description: message,
      metadata: {'context': context, ...?metadata},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  // ==================== LEGACY METHODS (Backward Compatibility) ====================

  Future<void> logUserAction({
    required String userId,
    required String action,
    required String feature,
    Map<String, dynamic>? metadata,
  }) async {
    // Legacy method - maps to new system
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.user,
      type: ActivityLogType.other,
      severity: ActivityLogSeverity.info,
      title: action,
      description: '$action in $feature',
      userId: userId,
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logAuthEvent({
    required String userId,
    required String event,
    Map<String, dynamic>? metadata,
  }) async {
    // Legacy method - maps to new system
    ActivityLogType type = ActivityLogType.other;
    ActivityLogSeverity severity = ActivityLogSeverity.info;
    String title = event;
    String description = event;

    if (event == 'sign_in') {
      type = ActivityLogType.login;
      severity = ActivityLogSeverity.success;
      title = 'User Logged In';
      description = 'User successfully logged into the system';
    } else if (event == 'sign_out') {
      type = ActivityLogType.logout;
      title = 'User Logged Out';
      description = 'User logged out of the system';
    } else if (event == 'password_updated') {
      type = ActivityLogType.passwordChanged;
      severity = ActivityLogSeverity.success;
      title = 'Password Changed';
      description = 'User successfully changed their password';
    }

    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.auth,
      type: type,
      severity: severity,
      title: title,
      description: description,
      userId: userId,
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logBotOperation({
    required String botId,
    required String operation,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    // Legacy method - maps to new system
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.bot,
      type: ActivityLogType.other,
      severity: ActivityLogSeverity.info,
      title: operation,
      description: 'Bot operation: $operation',
      userId: userId,
      botId: botId,
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }

  Future<void> logEvent({
    required String event,
    Map<String, dynamic>? parameters,
  }) async {
    // Legacy method - maps to new system
    await logActivity(ActivityLogModel(
      id: '',
      category: ActivityLogCategory.system,
      type: ActivityLogType.systemInfo,
      severity: ActivityLogSeverity.info,
      title: event,
      description: event,
      metadata: parameters ?? {},
      timestamp: DateTime.now(),
      platform: _platform,
    ));
  }
}
