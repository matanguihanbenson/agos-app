# AGOS App - Codebase Index & Structure

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Project Structure](#project-structure)
4. [Core Architecture](#core-architecture)
5. [Features Overview](#features-overview)
6. [Key Components](#key-components)
7. [State Management](#state-management)
8. [Services & Repositories](#services--repositories)
9. [Models & Data](#models--data)
10. [Utilities & Helpers](#utilities--helpers)
11. [Development Guidelines](#development-guidelines)

---

## 🎯 Project Overview

**AGOS (Autonomous Garbage Observation System)** is a comprehensive Flutter application for managing river cleaning bots with real-time monitoring capabilities.

### Key Features
- ✅ Bot Management (Registration, Assignment, Monitoring)
- ✅ Real-time Bot Control with Joystick
- ✅ Live Video Streaming
- ✅ User Management (Admin & Field Operator roles)
- ✅ Organization Management
- ✅ Real-time Location Tracking
- ✅ QR Code Bot Registration
- ✅ Water Quality Monitoring
- ✅ Deployment History & Activity Logs

---

## 🛠 Technology Stack

### Frontend
- **Framework**: Flutter 3.0+
- **Language**: Dart
- **State Management**: Riverpod 3.0.0
- **UI**: Material Design 3, Google Fonts (Inter)

### Backend
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore (structured data)
- **Real-time Database**: Firebase Realtime Database (bot telemetry)
- **Storage**: Firebase Storage (future use)

### Additional Libraries
- `flutter_map` - Map visualization
- `mobile_scanner` - QR code scanning
- `geolocator` - Location services
- `http` - HTTP requests
- `fl_chart` - Data visualization

---

## 📁 Project Structure

```
lib/
├── core/                          # Core functionality & shared code
│   ├── constants/
│   │   └── app_constants.dart     # Global constants
│   ├── models/                    # Data models
│   │   ├── base_model.dart        # Base model with common functionality
│   │   ├── bot_model.dart         # Bot data model (Firestore + Realtime)
│   │   ├── user_model.dart        # User data model
│   │   ├── organization_model.dart
│   │   ├── notification_model.dart
│   │   └── bot_registry_model.dart
│   ├── providers/                 # Riverpod providers
│   │   ├── app_state_provider.dart
│   │   ├── auth_provider.dart     # Authentication state
│   │   ├── bot_provider.dart      # Bot management state
│   │   ├── user_provider.dart
│   │   ├── organization_provider.dart
│   │   └── notification_provider.dart
│   ├── services/                  # Business logic & data operations
│   │   ├── base_service.dart      # Base service with CRUD operations
│   │   ├── auth_service.dart      # Firebase Auth operations
│   │   ├── bot_service.dart       # Bot CRUD + Realtime integration
│   │   ├── user_service.dart
│   │   ├── organization_service.dart
│   │   ├── notification_service.dart
│   │   ├── logging_service.dart   # Centralized logging
│   │   ├── realtime_bot_service.dart
│   │   ├── realtime_location_service.dart
│   │   ├── realtime_clock_service.dart
│   │   ├── location_service.dart
│   │   └── reverse_geocoding_service.dart
│   ├── theme/                     # Theming system
│   │   ├── app_theme.dart         # Main theme configuration
│   │   ├── color_palette.dart     # Color definitions
│   │   └── text_styles.dart       # Typography system
│   ├── utils/                     # Utility functions
│   │   ├── snackbar_util.dart     # Centralized snackbar management
│   │   ├── error_handler.dart     # Error processing
│   │   ├── validators.dart        # Input validation
│   │   └── date_formatter.dart    # Date/time utilities
│   ├── widgets/                   # Reusable UI components
│   │   ├── app_bar.dart
│   │   ├── app_sidebar.dart
│   │   ├── page_wrapper.dart
│   │   ├── auth_wrapper.dart      # Authentication wrapper
│   │   ├── loading_indicator.dart
│   │   ├── empty_state.dart
│   │   ├── error_state.dart
│   │   ├── custom_button.dart
│   │   ├── custom_text_field.dart
│   │   └── splash_screen.dart
│   └── routes/
│       └── app_routes.dart        # Navigation & routing
│
├── features/                      # Feature modules
│   ├── auth/                      # Authentication
│   │   ├── providers/
│   │   │   └── auth_state_provider.dart
│   │   ├── pages/
│   │   │   ├── login_page.dart
│   │   │   └── forgot_password_page.dart
│   │   ├── widgets/
│   │   │   ├── login_form.dart
│   │   │   └── auth_text_field.dart
│   │   └── services/
│   │       └── auth_repository.dart
│   │
│   ├── bots/                      # Bot Management
│   │   ├── providers/
│   │   │   ├── bot_list_provider.dart
│   │   │   └── bot_registration_provider.dart
│   │   ├── pages/
│   │   │   ├── bots_page.dart     # Main bot list page
│   │   │   ├── bot_details_page.dart
│   │   │   ├── edit_bot_page.dart
│   │   │   ├── assign_bot_page.dart
│   │   │   ├── reassign_bot_page.dart
│   │   │   ├── unregister_bot_page.dart
│   │   │   └── registration/
│   │   │       ├── method_selection_page.dart
│   │   │       ├── qr_scan_page.dart
│   │   │       └── bot_details_page.dart
│   │   ├── widgets/
│   │   │   ├── bot_card.dart      # Bot card component
│   │   │   ├── bot_status_indicator.dart
│   │   │   ├── assignment_dialog.dart
│   │   │   └── unregister_dialog.dart
│   │   └── services/
│   │       └── bot_repository.dart
│   │
│   ├── control/                   # Bot Control (NEW FEATURE)
│   │   ├── models/
│   │   │   └── bot_control_state.dart
│   │   ├── providers/
│   │   │   ├── bot_control_provider.dart
│   │   │   └── bot_control_provider.g.dart (generated)
│   │   ├── pages/
│   │   │   ├── control_page.dart  # Main control interface
│   │   │   ├── bot_control_page.dart
│   │   │   └── live_stream_page.dart
│   │   └── widgets/
│   │       └── draggable_joystick.dart # Custom joystick widget
│   │
│   ├── dashboard/                 # Dashboard
│   │   └── pages/
│   │       └── dashboard_page.dart
│   │
│   ├── management/                # User & Organization Management
│   │   └── pages/
│   │       ├── management_page.dart
│   │       ├── add_user_page.dart
│   │       ├── add_organization_page.dart
│   │       └── organization_details_page.dart
│   │
│   ├── map/                       # Map & Location
│   │   └── pages/
│   │       ├── map_page.dart
│   │       └── realtime_map_page.dart
│   │
│   ├── monitoring/                # Monitoring & Analytics
│   │   ├── models/
│   │   │   ├── monitoring_filters.dart
│   │   │   ├── trash_collection_data.dart
│   │   │   └── water_quality_data.dart
│   │   ├── providers/
│   │   │   └── monitoring_provider.dart
│   │   └── pages/
│   │       └── monitoring_page.dart
│   │
│   ├── notifications/             # Notifications
│   │   └── pages/
│   │       └── notifications_page.dart
│   │
│   ├── profile/                   # User Profile
│   │   └── pages/
│   │       ├── profile_page.dart
│   │       ├── activity_logs_page.dart
│   │       ├── deployment_history_page.dart
│   │       └── change_password_page.dart
│   │
│   ├── schedule/                  # Schedule Management
│   │   └── pages/
│   │       └── schedule_page.dart
│   │
│   └── settings/                  # Settings
│       └── pages/
│           └── settings_page.dart
│
├── shared/                        # Shared components
│   ├── navigation/
│   │   ├── main_navigation.dart   # Main app navigation
│   │   └── bottom_navigation.dart
│   └── widgets/
│       └── search_bar.dart
│
├── main.dart                      # App entry point
└── app.dart                       # Main app widget with providers
```

---

## 🏗 Core Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────┐
│     PRESENTATION LAYER (UI)             │
│  - Pages, Widgets, Dialogs              │
│  - ConsumerWidget, ConsumerStatefulWidget│
└──────────────┬──────────────────────────┘
               │ uses
┌──────────────▼──────────────────────────┐
│     BUSINESS LOGIC LAYER                │
│  - Riverpod Providers                   │
│  - StateNotifiers, State Classes        │
└──────────────┬──────────────────────────┘
               │ uses
┌──────────────▼──────────────────────────┐
│     DATA LAYER                          │
│  - Services (Firestore, Auth, Realtime) │
│  - Repositories                         │
│  - Models                               │
└─────────────────────────────────────────┘
```

### Key Principles
1. **Separation of Concerns**: Each layer has distinct responsibility
2. **Modularity**: Features are self-contained modules
3. **Reusability**: Common components in core/ and shared/
4. **Scalability**: Easy to add new features following existing patterns
5. **Maintainability**: Consistent code structure and naming

---

## ⚡ Features Overview

### 1. Authentication (`features/auth/`)
- Email/Password authentication
- Role-based access (Admin, Field Operator)
- Password reset
- Session management

### 2. Bot Management (`features/bots/`)
- Bot registration (QR code or manual)
- Bot assignment to field operators
- Bot status tracking (idle, deployed, maintenance)
- Real-time bot data integration
- Bot editing and unregistration

### 3. Bot Control (`features/control/`) ⭐ NEW
- Real-time joystick control
- Live video streaming
- Bot command interface
- Control history

### 4. Dashboard (`features/dashboard/`)
- System overview
- Key metrics
- Quick actions

### 5. Management (`features/management/`)
- User management (CRUD)
- Organization management
- Role assignment

### 6. Map & Location (`features/map/`)
- Real-time bot location tracking
- Map visualization with flutter_map
- Location history

### 7. Monitoring (`features/monitoring/`)
- Water quality data
- Trash collection metrics
- Performance analytics
- Filtering and reporting

### 8. Profile (`features/profile/`)
- User profile management
- Activity logs
- Deployment history
- Password change

### 9. Notifications (`features/notifications/`)
- System notifications
- Alert management

### 10. Schedule (`features/schedule/`)
- Bot deployment scheduling
- Task planning

---

## 🔑 Key Components

### Base Model Pattern
```dart
abstract class BaseModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Map<String, dynamic> toMap();
  BaseModel copyWith();
}
```

All models extend `BaseModel` for consistency:
- `BotModel` - Bot data with Firestore + Realtime DB integration
- `UserModel` - User data with role-based properties
- `OrganizationModel` - Organization data
- `NotificationModel` - Notification data

### Base Service Pattern
```dart
abstract class BaseService<T extends BaseModel> {
  String get collectionName;
  T fromMap(Map<String, dynamic> map, String id);
  
  Future<String> create(T model);
  Future<T?> getById(String id);
  Future<void> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Stream<List<T>> getAll();
}
```

All services extend `BaseService` for CRUD operations:
- `BotService` - Bot operations + Realtime DB integration
- `UserService` - User operations
- `OrganizationService` - Organization operations
- `NotificationService` - Notification operations

---

## 🔄 State Management

### Provider Architecture

#### 1. State Providers (Centralized State)
```dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>
final botProvider = NotifierProvider<BotNotifier, BotState>
final userProvider = StateNotifierProvider<UserNotifier, UserState>
```

#### 2. Service Providers (Dependency Injection)
```dart
final authServiceProvider = Provider<AuthService>
final botServiceProvider = Provider<BotService>
final loggingServiceProvider = Provider<LoggingService>
```

#### 3. Stream Providers (Real-time Data)
```dart
final botsStreamProvider = StreamProvider.family<List<BotModel>, String>
final userAuthStateProvider = StreamProvider<User?>
```

### State Flow Example
```
User Action (UI)
    ↓
Provider Method (ref.read(provider.notifier).method())
    ↓
Service Call (ref.read(serviceProvider).operation())
    ↓
Firestore/Realtime DB Operation
    ↓
State Update (state = state.copyWith(...))
    ↓
UI Rebuild (ref.watch(provider))
```

---

## 🔧 Services & Repositories

### Core Services

#### 1. **AuthService** (`core/services/auth_service.dart`)
- User authentication
- Session management
- Role verification

#### 2. **BotService** (`core/services/bot_service.dart`)
- Bot CRUD operations
- Firestore + Realtime DB integration
- Bot status management
- Bot assignment

Key Methods:
```dart
Future<List<BotModel>> getAllBotsWithRealtimeData()
Future<List<BotModel>> getBotsByOwnerWithRealtimeData(String ownerAdminId)
Future<void> createWithId(BotModel bot, String documentId)
Future<void> assignBotToUser(String botId, String userId)
```

#### 3. **UserService** (`core/services/user_service.dart`)
- User CRUD operations
- User profile management
- Role-based queries

#### 4. **OrganizationService** (`core/services/organization_service.dart`)
- Organization CRUD operations
- Organization membership

#### 5. **LoggingService** (`core/services/logging_service.dart`)
- Centralized logging
- User action tracking
- Error logging
- Event logging

#### 6. **Realtime Services**
- `RealtimeBotService` - Real-time bot data
- `RealtimeLocationService` - Real-time location tracking
- `RealtimeClockService` - Time synchronization

---

## 📊 Models & Data

### Bot Model Structure

#### Firestore Data (`bots` collection)
```dart
{
  name: String,
  assigned_to: String?,
  assigned_at: Timestamp?,
  organization_id: String?,
  owner_admin_id: String,
  created_at: Timestamp,
  updated_at: Timestamp
}
```

#### Realtime Database Data (`bots/{botId}`)
```dart
{
  status: String,          // idle, deployed, maintenance
  battery_level: double,
  lat: double,
  lng: double,
  active: bool,
  ph_level: double,
  temp: double,
  turbidity: double,
  last_updated: int        // timestamp
}
```

#### Merged BotModel
```dart
class BotModel {
  // Firestore fields
  final String name;
  final String? assignedTo;
  final String? ownerAdminId;
  
  // Realtime fields
  final String? status;
  final double? batteryLevel;
  final double? lat;
  final double? lng;
  final bool? active;
  
  // Computed properties
  bool get isDeployed;
  bool get isOnline;
  bool get hasLocation;
}
```

### User Model
```dart
class UserModel {
  final String firstName;
  final String lastName;
  final String email;
  final String role;        // 'admin' or 'field_operator'
  final String status;      // 'active', 'inactive', 'pending'
  final String? organizationId;
  
  // Computed properties
  String get fullName;
  String get initials;
  bool get isAdmin;
  bool get isFieldOperator;
}
```

---

## 🎨 Theming System

### Color Palette (`core/theme/color_palette.dart`)
```dart
class AppColors {
  // Primary
  static const primary = Color(0xFF0160C9);
  static const primaryLight = Color(0xFF3380E3);
  
  // Status
  static const success = Color(0xFF388E3C);
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFF57C00);
  
  // Bot Status
  static const botActive = Color(0xFF4CAF50);
  static const botInactive = Color(0xFF9E9E9E);
  static const botMaintenance = Color(0xFFFF9800);
  static const botOffline = Color(0xFFF44336);
}
```

### Typography (`core/theme/text_styles.dart`)
- Uses Google Fonts (Inter family)
- Consistent text styles across app
- Responsive sizing

---

## 🛠 Utilities & Helpers

### 1. **SnackbarUtil** (`core/utils/snackbar_util.dart`)
Centralized snackbar management:
```dart
SnackbarUtil.showSuccess(context, 'Bot registered successfully');
SnackbarUtil.showError(context, 'Failed to connect');
SnackbarUtil.showWarning(context, 'Battery low');
SnackbarUtil.showInfo(context, 'Bot is now online');
```

### 2. **ErrorHandler** (`core/utils/error_handler.dart`)
Centralized error handling:
```dart
ErrorHandler.handleError(
  context: context,
  error: error,
  context: 'bot_registration',
  userId: currentUserId,
);
```

### 3. **Validators** (`core/utils/validators.dart`)
Input validation functions:
```dart
Validators.validateEmail(email)
Validators.validatePassword(password)
Validators.validateRequired(value)
```

### 4. **DateFormatter** (`core/utils/date_formatter.dart`)
Date formatting utilities

---

## 📝 Development Guidelines

### Adding a New Feature

#### Step 1: Create Feature Directory
```
features/new_feature/
├── models/
├── providers/
├── pages/
├── widgets/
└── services/
```

#### Step 2: Define Models
```dart
class NewFeatureModel extends BaseModel {
  // Model implementation
  
  factory NewFeatureModel.fromMap(Map<String, dynamic> map, String id);
  Map<String, dynamic> toMap();
  NewFeatureModel copyWith(...);
}
```

#### Step 3: Create Service
```dart
class NewFeatureService extends BaseService<NewFeatureModel> {
  @override
  String get collectionName => 'new_features';
  
  @override
  NewFeatureModel fromMap(Map<String, dynamic> map, String id) {
    return NewFeatureModel.fromMap(map, id);
  }
  
  // Additional methods...
}
```

#### Step 4: Setup Providers
```dart
// Service provider
final newFeatureServiceProvider = Provider<NewFeatureService>((ref) {
  return NewFeatureService();
});

// State provider
final newFeatureProvider = StateNotifierProvider<NewFeatureNotifier, NewFeatureState>((ref) {
  return NewFeatureNotifier(ref.read(newFeatureServiceProvider));
});
```

#### Step 5: Create Pages & Widgets
```dart
class NewFeaturePage extends ConsumerStatefulWidget {
  @override
  ConsumerState<NewFeaturePage> createState() => _NewFeaturePageState();
}

class _NewFeaturePageState extends ConsumerState<NewFeaturePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newFeatureProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('New Feature')),
      body: // UI implementation
    );
  }
}
```

### Code Style Guidelines

#### Naming Conventions
- **Files**: `snake_case` (e.g., `bot_details_page.dart`)
- **Classes**: `PascalCase` (e.g., `BotDetailsPage`)
- **Variables/Functions**: `camelCase` (e.g., `getCurrentUser()`)
- **Constants**: `camelCase` (e.g., `defaultPadding`)
- **Firestore Fields**: `snake_case` (e.g., `first_name`)

#### Best Practices
1. **Check Before Creating**: Always search for existing methods before creating new ones
2. **Follow Structure**: Maintain the existing folder structure
3. **Use Base Classes**: Extend `BaseModel` and `BaseService` when applicable
4. **State Management**: Use Riverpod providers consistently
5. **Error Handling**: Use `ErrorHandler.handleError()` for errors
6. **Logging**: Use `LoggingService` for important events
7. **UI Feedback**: Use `SnackbarUtil` for user feedback
8. **Validation**: Use `Validators` for input validation
9. **Theming**: Use `AppColors` and `AppTextStyles` consistently
10. **Reusability**: Create reusable widgets in `core/widgets/` or `shared/widgets/`

### Database Structure

#### Firestore Collections
- `users` - User profiles and roles
- `organizations` - Organization data
- `bots` - Bot registration data (static)
- `user_logs` - User activity tracking
- `error_logs` - Error logging
- `app_events` - Application events

#### Realtime Database Structure
```
bots/
  {botId}/
    status: String
    battery_level: double
    lat: double
    lng: double
    active: bool
    ph_level: double
    temp: double
    turbidity: double
    last_updated: int
```

### Testing Strategy
1. Unit tests for services
2. Widget tests for UI components
3. Integration tests for features
4. Provider tests for state management

---

## 🚀 Quick Reference

### Common Tasks

#### 1. Add a New Bot
```dart
final botService = ref.read(botServiceProvider);
await botService.createWithId(bot, botId);
```

#### 2. Get Bots with Realtime Data
```dart
final botService = ref.read(botServiceProvider);
final bots = await botService.getAllBotsWithRealtimeData();
```

#### 3. Show User Feedback
```dart
SnackbarUtil.showSuccess(context, 'Operation successful');
```

#### 4. Handle Errors
```dart
try {
  // operation
} catch (e) {
  ErrorHandler.handleError(
    context: context,
    error: e,
    context: 'operation_name',
  );
}
```

#### 5. Navigate to Page
```dart
Navigator.pushNamed(context, '/bot-details', arguments: botId);
```

---

## 📚 Additional Resources

- [AGOS Architecture Blueprint](AGOS_ARCHITECTURE_BLUEPRINT.md)
- [Bot Control Feature Documentation](BOT_CONTROL_FEATURE.md)
- [Bot Control Quick Start](BOT_CONTROL_QUICK_START.md)
- [Monitoring Update Summary](MONITORING_UPDATE_SUMMARY.md)
- [Updates: Joystick and Live Stream](UPDATES_JOYSTICK_AND_LIVE_STREAM.md)

---

## 🎯 Summary

This AGOS codebase follows **clean architecture principles** with:

✅ **Modular Structure** - Feature-based organization  
✅ **Scalable Design** - Easy to add new features  
✅ **Maintainable Code** - Consistent patterns and naming  
✅ **Reusable Components** - DRY principle  
✅ **Centralized State** - Riverpod state management  
✅ **Type Safety** - Strong typing with Dart  
✅ **Real-time Capabilities** - Firestore + Realtime DB integration  
✅ **Comprehensive Logging** - Centralized error and event tracking  

**Key Reminder**: Always check if a method or component exists before creating a new one to prevent redundancy and maintain modularity!

---

**Last Updated**: 2025-09-30  
**Version**: 1.0.0
