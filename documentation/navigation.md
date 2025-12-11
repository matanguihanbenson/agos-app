# Navigation System

## 🧭 Overview

AGOS implements a comprehensive navigation system with role-based routing, deep linking support, and consistent navigation patterns. This document covers all navigation components, routes, and navigation flows.

## 🏗️ Navigation Architecture

### Navigation Stack
```
App
├── AuthWrapper
│   ├── SplashScreen
│   ├── LoginPage
│   └── MainApp
└── MainApp
    ├── MainNavigation (Scaffold)
    │   ├── GlobalAppBar
    │   ├── AppSidebar (Drawer)
    │   ├── PageContent
    │   └── RoleBasedBottomNavigation
    └── Modal Routes
        ├── BotDetailsPage
        ├── EditBotPage
        ├── AddUserPage
        └── OrganizationDetailsPage
```

### Navigation Components
- **AuthWrapper**: Handles authentication state
- **MainNavigation**: Main app scaffold with navigation
- **GlobalAppBar**: Consistent app bar across screens
- **AppSidebar**: Navigation drawer
- **RoleBasedBottomNavigation**: Bottom navigation based on user role

## 🛣️ Route Definitions

### App Routes (`lib/core/routes/app_routes.dart`)

```dart
class AppRoutes {
  // Authentication Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  
  // Main App Routes
  static const String home = '/home';
  static const String map = '/map';
  static const String bots = '/bots';
  static const String control = '/control';
  static const String dashboard = '/dashboard';
  static const String management = '/management';
  static const String monitoring = '/monitoring';
  static const String schedule = '/schedule';
  static const String profile = '/profile';
  static const String settings = '/settings';
  
  // Bot Management Routes
  static const String botDetails = '/bot-details';
  static const String editBot = '/edit-bot';
  static const String registerBot = '/register-bot';
  static const String methodSelection = '/method-selection';
  static const String qrScan = '/qr-scan';
  static const String botDetailsForm = '/bot-details-form';
  static const String assignBot = '/assign-bot';
  static const String reassignBot = '/reassign-bot';
  static const String unregisterBot = '/unregister-bot';
  
  // User Management Routes
  static const String addUser = '/add-user';
  static const String editUser = '/edit-user';
  static const String userDetails = '/user-details';
  
  // Organization Management Routes
  static const String addOrganization = '/add-organization';
  static const String editOrganization = '/edit-organization';
  static const String organizationDetails = '/organization-details';
  
  // Other Routes
  static const String notifications = '/notifications';
  static const String changePassword = '/change-password';
  static const String activityLogs = '/activity-logs';
}
```

## 🔐 Authentication Navigation

### AuthWrapper (`lib/core/widgets/auth_wrapper.dart`)

**Purpose**: Handle authentication state and route accordingly

**Navigation Flow**:
1. **SplashScreen**: Show loading animation
2. **LoginPage**: If not authenticated
3. **MainApp**: If authenticated

**Implementation**:
```dart
class AuthWrapper extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    if (authState.isLoading) {
      return const SplashScreen();
    } else if (authState.isAuthenticated) {
      return const MainApp();
    } else {
      return const LoginPage();
    }
  }
}
```

### SplashScreen (`lib/core/widgets/splash_screen.dart`)

**Purpose**: Show app loading with branding

**Features**:
- Ocean gradient background
- App logo and name
- Animated progress bar
- Percentage display
- Smooth transitions

**Navigation**: Automatically navigates to next screen after completion

## 🏠 Main App Navigation

### MainNavigation (`lib/shared/navigation/main_navigation.dart`)

**Purpose**: Main app scaffold with navigation components

**Structure**:
```dart
Scaffold(
  appBar: GlobalAppBar(
    title: _getPageTitle(currentIndex, userRole),
    showDrawer: true,
    showNotifications: true,
  ),
  drawer: AppSidebar(),
  body: PageView(
    controller: _pageController,
    children: _getPagesForRole(userRole),
  ),
  bottomNavigationBar: RoleBasedBottomNavigation(
    currentIndex: _currentIndex,
    onTap: _onTabTapped,
  ),
)
```

### Page Management

**Admin Pages**:
- Map (index 0)
- Bots (index 1)
- Dashboard (index 2)
- Management (index 3)
- Monitoring (index 4)

**Field Operator Pages**:
- Map (index 0)
- Control (index 1)
- Dashboard (index 2)
- Schedule (index 3)
- Monitoring (index 4)

## 🧭 Bottom Navigation

### RoleBasedBottomNavigation (`lib/shared/navigation/bottom_navigation.dart`)

**Purpose**: Role-specific bottom navigation

**Admin Navigation Items**:
```dart
static const List<BottomNavigationItem> adminNavItems = [
  BottomNavigationItem(
    icon: Icons.map,
    activeIcon: Icons.map,
    label: 'Map',
    route: AppRoutes.map,
  ),
  BottomNavigationItem(
    icon: Icons.directions_boat,
    activeIcon: Icons.directions_boat,
    label: 'Bots',
    route: AppRoutes.bots,
  ),
  BottomNavigationItem(
    icon: Icons.dashboard,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
    route: AppRoutes.dashboard,
  ),
  BottomNavigationItem(
    icon: Icons.people,
    activeIcon: Icons.people,
    label: 'Management',
    route: AppRoutes.management,
  ),
  BottomNavigationItem(
    icon: Icons.monitor,
    activeIcon: Icons.monitor,
    label: 'Monitoring',
    route: AppRoutes.monitoring,
  ),
];
```

**Field Operator Navigation Items**:
```dart
static const List<BottomNavigationItem> fieldOperatorNavItems = [
  BottomNavigationItem(
    icon: Icons.map,
    activeIcon: Icons.map,
    label: 'Map',
    route: AppRoutes.map,
  ),
  BottomNavigationItem(
    icon: Icons.gamepad,
    activeIcon: Icons.gamepad,
    label: 'Control',
    route: AppRoutes.control,
  ),
  BottomNavigationItem(
    icon: Icons.dashboard,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
    route: AppRoutes.dashboard,
  ),
  BottomNavigationItem(
    icon: Icons.schedule,
    activeIcon: Icons.schedule,
    label: 'Schedule',
    route: AppRoutes.schedule,
  ),
  BottomNavigationItem(
    icon: Icons.monitor,
    activeIcon: Icons.monitor,
    label: 'Monitoring',
    route: AppRoutes.monitoring,
  ),
];
```

## 🗂️ Sidebar Navigation

### AppSidebar (`lib/core/widgets/app_sidebar.dart`)

**Purpose**: Main navigation drawer

**Structure**:
```
┌─────────────────────────────────┐
│ [Logo] AGOS                    │
│      Ocean Guardian System     │
├─────────────────────────────────┤
│ [Avatar] John Doe              │
│         Field Operator         │
├─────────────────────────────────┤
│ 👤 View Profile                │
│ 🔒 Change Password             │
│ 📋 Activity Logs               │
├─────────────────────────────────┤
│ ⚙️  Settings                   │
│ 🚪 Sign Out                    │
└─────────────────────────────────┘
```

**Navigation Items**:
- **View Profile**: Navigate to profile page
- **Change Password**: Navigate to change password page
- **Activity Logs**: Navigate to activity logs page
- **Settings**: Navigate to settings page
- **Sign Out**: Sign out and return to login

## 🚀 Modal Navigation

### Bot Management Modals

#### BotDetailsPage
**Route**: `/bot-details`
**Purpose**: View detailed bot information
**Navigation**: 
- From: Bot card tap
- To: Edit bot page, back to bots list

#### EditBotPage
**Route**: `/edit-bot`
**Purpose**: Edit bot information
**Navigation**:
- From: Bot details page
- To: Back to bot details page

#### AddUserPage
**Route**: `/add-user`
**Purpose**: Create new user
**Navigation**:
- From: Management page
- To: Back to management page

#### OrganizationDetailsPage
**Route**: `/organization-details`
**Purpose**: View organization details
**Navigation**:
- From: Organization card tap
- To: Back to management page

### Registration Flow Navigation

#### Bot Registration Flow
```
MethodSelectionPage
    ↓ (QR Scan)
QRScanPage
    ↓ (Manual Entry)
BotDetailsPage
    ↓ (Success)
BotsPage
```

#### Method Selection
**Route**: `/method-selection`
**Purpose**: Choose registration method
**Options**:
- QR Code Scan
- Manual Entry (inline form)

#### QR Scan
**Route**: `/qr-scan`
**Purpose**: Scan bot QR code
**Navigation**:
- Success: Navigate to bot details
- Cancel: Return to method selection

#### Bot Details Form
**Route**: `/bot-details-form`
**Purpose**: Enter bot information
**Navigation**:
- Success: Navigate to bots page
- Cancel: Return to method selection

## 🔗 Deep Linking

### URL Structure
```
agos://app/
├── /login
├── /map
├── /bots
├── /bot-details/{botId}
├── /user-details/{userId}
└── /organization-details/{orgId}
```

### Deep Link Handling
```dart
// Handle deep links
void _handleDeepLink(String link) {
  final uri = Uri.parse(link);
  
  switch (uri.path) {
    case '/bot-details':
      final botId = uri.pathSegments.last;
      Navigator.pushNamed(context, AppRoutes.botDetails, arguments: botId);
      break;
    case '/user-details':
      final userId = uri.pathSegments.last;
      Navigator.pushNamed(context, AppRoutes.userDetails, arguments: userId);
      break;
    // ... other cases
  }
}
```

## 📱 Page Transitions

### Transition Types
- **Slide**: Horizontal slide for tab navigation
- **Fade**: Fade in/out for modal presentations
- **Scale**: Scale animation for popups
- **None**: Instant transition for real-time updates

### Custom Transitions
```dart
// Custom page route
class CustomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final String transitionType;
  
  CustomPageRoute({
    required this.child,
    this.transitionType = 'slide',
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transitionType) {
        case 'slide':
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        case 'fade':
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        default:
          return child;
      }
    },
  );
}
```

## 🎯 Navigation Patterns

### 1. Tab Navigation
**Use Case**: Main app sections
**Implementation**: `PageView` with `BottomNavigationBar`
**Behavior**: Horizontal swipe between tabs

### 2. Stack Navigation
**Use Case**: Modal pages and forms
**Implementation**: `Navigator.push()` and `Navigator.pop()`
**Behavior**: Stack-based navigation with back button

### 3. Drawer Navigation
**Use Case**: Secondary navigation and settings
**Implementation**: `Drawer` widget
**Behavior**: Slide-in from left side

### 4. Modal Navigation
**Use Case**: Quick actions and forms
**Implementation**: `showModalBottomSheet()` and `showDialog()`
**Behavior**: Overlay on current screen

## 🔄 Navigation State Management

### Current Page Tracking
```dart
class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late PageController _pageController;
  
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
```

### Page Title Management
```dart
String _getPageTitle(int index, String userRole) {
  if (userRole == 'admin') {
    switch (index) {
      case 0: return 'Map';
      case 1: return 'Bots';
      case 2: return 'Dashboard';
      case 3: return 'Management';
      case 4: return 'Monitoring';
      default: return 'AGOS';
    }
  } else {
    switch (index) {
      case 0: return 'Map';
      case 1: return 'Control';
      case 2: return 'Dashboard';
      case 3: return 'Schedule';
      case 4: return 'Monitoring';
      default: return 'AGOS';
    }
  }
}
```

## 🚨 Navigation Guards

### Authentication Guard
```dart
// Check authentication before navigation
void _navigateToPage(String route) {
  final authState = ref.read(authProvider);
  
  if (!authState.isAuthenticated) {
    Navigator.pushNamed(context, AppRoutes.login);
    return;
  }
  
  Navigator.pushNamed(context, route);
}
```

### Role-Based Guard
```dart
// Check user role before navigation
void _navigateToAdminPage(String route) {
  final user = ref.read(authProvider).userProfile;
  
  if (user?.role != 'admin') {
    SnackbarUtil.showError(context, 'Access denied');
    return;
  }
  
  Navigator.pushNamed(context, route);
}
```

## 📊 Navigation Analytics

### Page View Tracking
```dart
// Track page views
void _trackPageView(String pageName) {
  analytics.logEvent(
    name: 'page_view',
    parameters: {
      'page_name': pageName,
      'user_role': userRole,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
}
```

### Navigation Flow Analysis
```dart
// Track navigation flows
void _trackNavigationFlow(String from, String to) {
  analytics.logEvent(
    name: 'navigation_flow',
    parameters: {
      'from_page': from,
      'to_page': to,
      'flow_duration': _getFlowDuration(),
    },
  );
}
```

## 🧪 Navigation Testing

### Widget Tests
```dart
testWidgets('should navigate to bot details on bot card tap', (tester) async {
  // Arrange
  await tester.pumpWidget(MyApp());
  
  // Act
  await tester.tap(find.byType(BotCard));
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.byType(BotDetailsPage), findsOneWidget);
});
```

### Integration Tests
```dart
testWidgets('should complete bot registration flow', (tester) async {
  // Test complete registration flow
  await tester.pumpWidget(MyApp());
  
  // Navigate to registration
  await tester.tap(find.text('Register Bot'));
  await tester.pumpAndSettle();
  
  // Fill form
  await tester.enterText(find.byType(TextField), 'Bot-001');
  await tester.tap(find.text('Register'));
  await tester.pumpAndSettle();
  
  // Verify navigation
  expect(find.byType(BotsPage), findsOneWidget);
});
```

## 🚀 Performance Optimization

### Lazy Loading
```dart
// Load pages only when needed
Widget _buildPage(int index) {
  switch (index) {
    case 0: return const MapPage();
    case 1: return const BotsPage();
    case 2: return const DashboardPage();
    case 3: return const ManagementPage();
    case 4: return const MonitoringPage();
    default: return const SizedBox();
  }
}
```

### Page Caching
```dart
// Cache pages for better performance
class PageCache {
  static final Map<String, Widget> _cache = {};
  
  static Widget getPage(String route) {
    if (!_cache.containsKey(route)) {
      _cache[route] = _createPage(route);
    }
    return _cache[route]!;
  }
}
```

---

**Last Updated**: September 2024  
**Version**: 1.0.0
