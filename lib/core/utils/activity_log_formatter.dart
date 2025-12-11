import 'package:flutter/material.dart';
import '../models/activity_log_model.dart';
import '../theme/color_palette.dart';

/// Utility class for formatting activity log types and providing icons
class ActivityLogFormatter {
  /// Convert ActivityLogType to human-readable format
  /// e.g., botUpdated -> "Bot Updated", scheduleCreated -> "Schedule Created"
  static String formatLogType(ActivityLogType type) {
    switch (type) {
      // Auth types
      case ActivityLogType.login:
        return 'User Logged In';
      case ActivityLogType.logout:
        return 'User Logged Out';
      case ActivityLogType.loginFailed:
        return 'Login Failed';
      case ActivityLogType.passwordChanged:
        return 'Password Changed';
      case ActivityLogType.passwordResetRequested:
        return 'Password Reset Requested';
      case ActivityLogType.passwordResetCompleted:
        return 'Password Reset Completed';
      case ActivityLogType.accountLocked:
        return 'Account Locked';
      case ActivityLogType.accountUnlocked:
        return 'Account Unlocked';
      
      // User types
      case ActivityLogType.userCreated:
        return 'User Created';
      case ActivityLogType.userUpdated:
        return 'User Updated';
      case ActivityLogType.userDeleted:
        return 'User Deleted';
      case ActivityLogType.userRoleChanged:
        return 'User Role Changed';
      case ActivityLogType.userStatusChanged:
        return 'User Status Changed';
      case ActivityLogType.userAssignedToOrg:
        return 'User Assigned to Organization';
      case ActivityLogType.userRemovedFromOrg:
        return 'User Removed from Organization';
      case ActivityLogType.userBotAssigned:
        return 'Bot Assigned to User';
      case ActivityLogType.userBotUnassigned:
        return 'Bot Unassigned from User';
      case ActivityLogType.profileUpdated:
        return 'Profile Updated';
      
      // Bot types
      case ActivityLogType.botRegistered:
        return 'Bot Registered';
      case ActivityLogType.botUnregistered:
        return 'Bot Unregistered';
      case ActivityLogType.botAssigned:
        return 'Bot Assigned';
      case ActivityLogType.botReassigned:
        return 'Bot Reassigned';
      case ActivityLogType.botUnassigned:
        return 'Bot Unassigned';
      case ActivityLogType.botAddedToOrg:
        return 'Bot Added to Organization';
      case ActivityLogType.botRemovedFromOrg:
        return 'Bot Removed from Organization';
      case ActivityLogType.botStatusChanged:
        return 'Bot Status Changed';
      case ActivityLogType.botUpdated:
        return 'Bot Updated';
      case ActivityLogType.scheduleCreated:
        return 'Schedule Created';
      case ActivityLogType.scheduleCanceled:
        return 'Schedule Canceled';
      case ActivityLogType.scheduleCompleted:
        return 'Schedule Completed';
      case ActivityLogType.deploymentStarted:
        return 'Deployment Started';
      case ActivityLogType.deploymentCompleted:
        return 'Deployment Completed';
      case ActivityLogType.deploymentFailed:
        return 'Deployment Failed';
      
      // System types
      case ActivityLogType.systemError:
        return 'System Error';
      case ActivityLogType.systemWarning:
        return 'System Warning';
      case ActivityLogType.systemInfo:
        return 'System Info';
      case ActivityLogType.configurationChanged:
        return 'Configuration Changed';
      case ActivityLogType.maintenanceStarted:
        return 'Maintenance Started';
      case ActivityLogType.maintenanceCompleted:
        return 'Maintenance Completed';
      
      // Other
      case ActivityLogType.other:
        return 'Activity';
    }
  }

  /// Get icon for activity log type
  static IconData getIconForLogType(ActivityLogType type) {
    switch (type) {
      // Auth types
      case ActivityLogType.login:
        return Icons.login_rounded;
      case ActivityLogType.logout:
        return Icons.logout_rounded;
      case ActivityLogType.loginFailed:
        return Icons.error_outline_rounded;
      case ActivityLogType.passwordChanged:
      case ActivityLogType.passwordResetRequested:
      case ActivityLogType.passwordResetCompleted:
        return Icons.lock_reset_rounded;
      case ActivityLogType.accountLocked:
        return Icons.lock_rounded;
      case ActivityLogType.accountUnlocked:
        return Icons.lock_open_rounded;
      
      // User types
      case ActivityLogType.userCreated:
        return Icons.person_add_rounded;
      case ActivityLogType.userUpdated:
      case ActivityLogType.profileUpdated:
        return Icons.edit_rounded;
      case ActivityLogType.userDeleted:
        return Icons.person_remove_rounded;
      case ActivityLogType.userRoleChanged:
        return Icons.admin_panel_settings_rounded;
      case ActivityLogType.userStatusChanged:
        return Icons.toggle_on_rounded;
      case ActivityLogType.userAssignedToOrg:
      case ActivityLogType.userRemovedFromOrg:
        return Icons.business_rounded;
      case ActivityLogType.userBotAssigned:
      case ActivityLogType.userBotUnassigned:
      case ActivityLogType.botAssigned:
        return Icons.assignment_ind_rounded;
      
      // Bot types
      case ActivityLogType.botRegistered:
        return Icons.add_circle_outline_rounded;
      case ActivityLogType.botUnregistered:
        return Icons.remove_circle_outline_rounded;
      case ActivityLogType.botReassigned:
        return Icons.swap_horiz_rounded;
      case ActivityLogType.botUnassigned:
        return Icons.link_off_rounded;
      case ActivityLogType.botAddedToOrg:
      case ActivityLogType.botRemovedFromOrg:
        return Icons.business_rounded;
      case ActivityLogType.botStatusChanged:
        return Icons.sync_rounded;
      case ActivityLogType.botUpdated:
        return Icons.build_rounded;
      case ActivityLogType.scheduleCreated:
        return Icons.event_available_rounded;
      case ActivityLogType.scheduleCanceled:
        return Icons.event_busy_rounded;
      case ActivityLogType.scheduleCompleted:
        return Icons.event_note_rounded;
      case ActivityLogType.deploymentStarted:
        return Icons.rocket_launch_rounded;
      case ActivityLogType.deploymentCompleted:
        return Icons.check_circle_outline_rounded;
      case ActivityLogType.deploymentFailed:
        return Icons.error_rounded;
      
      // System types
      case ActivityLogType.systemError:
        return Icons.bug_report_rounded;
      case ActivityLogType.systemWarning:
        return Icons.warning_rounded;
      case ActivityLogType.systemInfo:
        return Icons.info_outline_rounded;
      case ActivityLogType.configurationChanged:
        return Icons.settings_rounded;
      case ActivityLogType.maintenanceStarted:
      case ActivityLogType.maintenanceCompleted:
        return Icons.build_circle_rounded;
      
      // Other
      case ActivityLogType.other:
        return Icons.info_outline_rounded;
    }
  }

  /// Get color for activity log severity
  static Color getColorForSeverity(ActivityLogSeverity severity) {
    switch (severity) {
      case ActivityLogSeverity.success:
        return AppColors.success;
      case ActivityLogSeverity.info:
        return AppColors.info;
      case ActivityLogSeverity.warning:
        return AppColors.warning;
      case ActivityLogSeverity.error:
      case ActivityLogSeverity.critical:
        return AppColors.error;
    }
  }

  /// Get color for activity log category
  static Color getColorForCategory(ActivityLogCategory category) {
    switch (category) {
      case ActivityLogCategory.system:
        return AppColors.info;
      case ActivityLogCategory.auth:
        return AppColors.accent;
      case ActivityLogCategory.user:
        return AppColors.secondary;
      case ActivityLogCategory.bot:
        return AppColors.primary;
    }
  }

  /// Format category name
  static String formatCategory(ActivityLogCategory category) {
    switch (category) {
      case ActivityLogCategory.system:
        return 'SYSTEM';
      case ActivityLogCategory.auth:
        return 'AUTH';
      case ActivityLogCategory.user:
        return 'USER';
      case ActivityLogCategory.bot:
        return 'BOT';
    }
  }

  /// Get relative time string (e.g., "5 minutes ago", "2 hours ago")
  static String getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }
}
