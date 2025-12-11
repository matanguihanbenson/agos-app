class AppConstants {
  // User Roles
  static const String adminRole = 'admin';
  static const String fieldOperatorRole = 'field_operator';

  // Bot Status
  static const String botStatusActive = 'active';
  static const String botStatusInactive = 'inactive';
  static const String botStatusMaintenance = 'maintenance';
  static const String botStatusOffline = 'offline';

  // User Status
  static const String userStatusActive = 'active';
  static const String userStatusInactive = 'inactive';
  static const String userStatusPending = 'pending';

  // Organization Status
  static const String orgStatusActive = 'active';
  static const String orgStatusInactive = 'inactive';

  // Collections
  static const String usersCollection = 'users';
  static const String organizationsCollection = 'organizations';
  static const String botsCollection = 'bots';
  static const String userLogsCollection = 'user_logs';
  static const String errorLogsCollection = 'error_logs';
  static const String appEventsCollection = 'app_events';

  // App Configuration
  static const String appName = 'AGOS';
  static const String appVersion = '1.0.0';

  // Default Values
  static const int defaultPageSize = 20;
  static const int maxRetryAttempts = 3;
  static const Duration defaultTimeout = Duration(seconds: 30);

  // Validation
  static const int minPasswordLength = 8;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;

  // UI Constants
  static const double defaultBorderRadius = 12.0;
  static const double defaultElevation = 4.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
}
