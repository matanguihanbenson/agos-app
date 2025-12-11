import 'package:flutter/material.dart';
import '../theme/color_palette.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/bots/pages/bots_page.dart';
import '../../features/bots/pages/registration/method_selection_page.dart';
import '../../features/bots/pages/registration/qr_scan_page.dart';
import '../../features/schedule/pages/schedule_page.dart';
import '../../features/schedule/pages/create_schedule_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/change_password_page.dart';
import '../../features/profile/pages/activity_logs_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/bots/pages/assign_bot_page.dart';
import '../../features/bots/pages/reassign_bot_page.dart';
import '../../features/bots/pages/unregister_bot_page.dart';
import '../../features/bots/pages/bot_details_page.dart' as bot_view;
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/management/pages/add_user_page.dart';
import '../../features/management/pages/edit_user_page.dart';
import '../../features/management/pages/add_organization_page.dart';
import '../../features/management/pages/edit_organization_page.dart';
import '../../features/profile/pages/deployment_history_page.dart';
import '../../features/bots/pages/edit_bot_page.dart';
import '../../features/rivers/pages/rivers_management_page.dart';
import '../../features/schedule/pages/admin_schedules_page.dart';
import '../../features/map/pages/map_page.dart';
import '../../features/control/pages/control_page.dart';
import '../../features/management/pages/management_page.dart';
import '../../features/monitoring/pages/monitoring_page.dart';
import '../../features/monitoring/pages/waste_mapping_page.dart';
import '../../features/monitoring/pages/environmental_monitoring_page.dart';
import '../../features/monitoring/pages/waste_analytics_page.dart';
import '../../features/monitoring/pages/detection_events_page.dart';
import '../../core/models/bot_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/organization_model.dart';
import '../../core/models/activity_log_model.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/profile/pages/activity_log_details_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String bots = '/bots';
  static const String users = '/users';
  static const String profile = '/profile';
  static const String botRegistration = '/bot-registration';
  static const String qrScan = '/qr-scan';
  static const String manualEntry = '/manual-entry';
  static const String botDetails = '/bot-details';
  static const String botView = '/bot-view';
  static const String map = '/map';
  static const String control = '/control';
  static const String management = '/management';
  static const String monitoring = '/monitoring';
  static const String schedule = '/schedule';
  static const String createSchedule = '/create-schedule';
  static const String changePassword = '/change-password';
  static const String activityLogs = '/activity-logs';
  static const String settings = '/settings';
  static const String assignBot = '/assign-bot';
  static const String reassignBot = '/reassign-bot';
  static const String unregisterBot = '/unregister-bot';
  static const String notifications = '/notifications';
  static const String addUser = '/add-user';
  static const String editUser = '/edit-user';
  static const String addOrganization = '/add-organization';
  static const String editOrganization = '/edit-organization';
  static const String editBot = '/edit-bot';
  static const String deploymentHistory = '/deployment-history';
  static const String rivers = '/rivers';
  static const String schedulesAdmin = '/schedules-admin';
  static const String activityLogDetails = '/activity-log-details';
  static const String wasteMapping = '/waste-mapping';
  static const String environmentalMonitoring = '/environmental-monitoring';
  static const String wasteAnalytics = '/waste-analytics';
  static const String detectionEvents = '/detection-events';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      
      case AppRoutes.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordPage(),
          settings: settings,
        );
      
      case AppRoutes.dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardPage(),
          settings: settings,
        );
      
      case AppRoutes.bots:
        return MaterialPageRoute(
          builder: (_) => const BotsPage(),
          settings: settings,
        );
      
      case AppRoutes.users:
        return MaterialPageRoute(
          builder: (_) => const ManagementPage(),
          settings: settings,
        );
      
      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const ProfilePage(),
          settings: settings,
        );
      
      case AppRoutes.botRegistration:
        return MaterialPageRoute(
          builder: (_) => const MethodSelectionPage(),
          settings: settings,
        );
      
      case AppRoutes.qrScan:
        return MaterialPageRoute(
          builder: (_) => const QRScanPage(),
          settings: settings,
        );
      
      case AppRoutes.manualEntry:
        // Manual entry is now integrated into method selection page
        return MaterialPageRoute(
          builder: (_) => const MethodSelectionPage(),
          settings: settings,
        );
      
      case AppRoutes.botDetails:
        final bot = settings.arguments as BotModel?;
        if (bot == null) {
          return _errorRoute('Bot data is required');
        }
        return MaterialPageRoute(
          builder: (_) => bot_view.BotDetailsPage(bot: bot),
          settings: settings,
        );
      
      case AppRoutes.botView:
        final bot = settings.arguments as BotModel?;
        if (bot == null) {
          return _errorRoute('Bot data is required');
        }
        return MaterialPageRoute(
          builder: (_) => bot_view.BotDetailsPage(bot: bot),
          settings: settings,
        );
      
      case AppRoutes.map:
        return MaterialPageRoute(
          builder: (_) => const MapPage(),
          settings: settings,
        );
      
      case AppRoutes.control:
        return MaterialPageRoute(
          builder: (_) => const ControlPage(),
          settings: settings,
        );
      
      case AppRoutes.management:
        return MaterialPageRoute(
          builder: (_) => const ManagementPage(),
          settings: settings,
        );
      
      case AppRoutes.monitoring:
        return MaterialPageRoute(
          builder: (_) => const MonitoringPage(),
          settings: settings,
        );
      
      case AppRoutes.schedule:
        return MaterialPageRoute(
          builder: (_) => const SchedulePage(),
          settings: settings,
        );
      case AppRoutes.createSchedule:
        return MaterialPageRoute(
          builder: (_) => const CreateSchedulePage(),
          settings: settings,
        );
      
      case AppRoutes.changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordPage(),
          settings: settings,
        );
      
      case AppRoutes.activityLogs:
        return MaterialPageRoute(
          builder: (_) => const ActivityLogsPage(),
          settings: settings,
        );
      
      case AppRoutes.activityLogDetails:
        final log = settings.arguments as ActivityLogModel?;
        if (log == null) {
          return _errorRoute('Activity log data is required');
        }
        return MaterialPageRoute(
          builder: (_) => ActivityLogDetailsPage(log: log),
          settings: settings,
        );
      
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );
      
      case AppRoutes.assignBot:
        return MaterialPageRoute(
          builder: (_) => const AssignBotPage(),
          settings: settings,
        );
      
      case AppRoutes.reassignBot:
        return MaterialPageRoute(
          builder: (_) => const ReassignBotPage(),
          settings: settings,
        );
      
      case AppRoutes.unregisterBot:
        return MaterialPageRoute(
          builder: (_) => const UnregisterBotPage(),
          settings: settings,
        );
      case AppRoutes.notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsPage(),
          settings: settings,
        );

      case AppRoutes.addUser:
        return MaterialPageRoute(
          builder: (_) => const AddUserPage(),
          settings: settings,
        );

      case AppRoutes.editUser:
        final user = settings.arguments as UserModel?;
        if (user == null) {
          return _errorRoute('User data is required');
        }
        return MaterialPageRoute(
          builder: (_) => EditUserPage(user: user),
          settings: settings,
        );

      case AppRoutes.addOrganization:
        return MaterialPageRoute(
          builder: (_) => const AddOrganizationPage(),
          settings: settings,
        );

      case AppRoutes.editOrganization:
        final organization = settings.arguments as OrganizationModel?;
        if (organization == null) {
          return _errorRoute('Organization data is required');
        }
        return MaterialPageRoute(
          builder: (_) => EditOrganizationPage(organization: organization),
          settings: settings,
        );

      case AppRoutes.editBot:
        final bot = settings.arguments as BotModel?;
        if (bot == null) {
          return _errorRoute('Bot data is required');
        }
        return MaterialPageRoute(
          builder: (_) => EditBotPage(bot: bot),
          settings: settings,
        );
      case AppRoutes.deploymentHistory:
        return MaterialPageRoute(
          builder: (_) => const DeploymentHistoryPage(),
          settings: settings,
        );

      case AppRoutes.rivers:
        return MaterialPageRoute(
          builder: (_) => const RiversManagementPage(),
          settings: settings,
        );

      case AppRoutes.schedulesAdmin:
        return MaterialPageRoute(
          builder: (_) => const AdminSchedulesPage(),
          settings: settings,
        );

      case AppRoutes.wasteMapping:
        return MaterialPageRoute(
          builder: (_) => const WasteMappingPage(),
          settings: settings,
        );

      case AppRoutes.environmentalMonitoring:
        return MaterialPageRoute(
          builder: (_) => const EnvironmentalMonitoringPage(),
          settings: settings,
        );

      case AppRoutes.wasteAnalytics:
        return MaterialPageRoute(
          builder: (_) => const WasteAnalyticsPage(),
          settings: settings,
        );

      case AppRoutes.detectionEvents:
        return MaterialPageRoute(
          builder: (_) => const DetectionEventsPage(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const NotFoundPage(),
          settings: settings,
        );
    }
  }

  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}


class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: const Center(
        child: Text('The requested page was not found.'),
      ),
    );
  }
}
