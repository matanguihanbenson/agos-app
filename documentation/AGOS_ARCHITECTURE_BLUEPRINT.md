# AGOS Architecture Blueprint
## Complete Guide for Building Scalable, Modular Flutter Applications

### Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture Principles](#architecture-principles)
3. [Project Structure](#project-structure)
4. [State Management with Riverpod](#state-management-with-riverpod)
5. [Theming System](#theming-system)
6. [Naming Conventions](#naming-conventions)
7. [Centralized Utilities](#centralized-utilities)
8. [Data Models & Services](#data-models--services)
9. [UI Components & Patterns](#ui-components--patterns)
10. [Error Handling & Logging](#error-handling--logging)
11. [Implementation Guidelines](#implementation-guidelines)
12. [Code Examples](#code-examples)

---

## Project Overview

The AGOS (Autonomous Garbage Observation System) app is a comprehensive Flutter application for managing river cleaning bots. This blueprint provides a complete architecture guide for building scalable, maintainable, and modular Flutter applications based on the AGOS codebase.

### Core Features
- **Bot Management**: Registration, assignment, monitoring, and control
- **User Management**: Admin and field operator roles with permissions
- **Organization Management**: Multi-tenant organization support
- **Real-time Monitoring**: Live bot status and location tracking
- **Authentication**: Firebase Auth with role-based access control

### Technology Stack
- **Frontend**: Flutter with Material Design 3
- **State Management**: Riverpod (centralized, reactive)
- **Backend**: Firebase (Auth, Firestore, Realtime Database)
- **Fonts**: Google Fonts (Inter family)
- **Additional**: Mobile Scanner (QR codes), Custom theming

---

## Architecture Principles

### 1. **Clean Architecture**
```
Presentation Layer (UI) → Business Logic Layer (Providers) → Data Layer (Services/Repositories)
```

### 2. **Separation of Concerns**
- **Features**: Self-contained modules with their own pages, widgets, and logic
- **Core**: Shared functionality (services, models, themes, utilities)
- **Shared**: Common UI components and navigation logic

### 3. **Modular Design**
- Each feature is independent and reusable
- Components can be easily added, removed, or modified
- Clear interfaces between modules

### 4. **Scalability Principles**
- Centralized state management with Riverpod
- Consistent naming conventions
- Reusable components and utilities
- Standardized error handling and logging

### 5. **Maintainability Focus**
- Single responsibility principle
- DRY (Don't Repeat Yourself) implementation
- Comprehensive documentation
- Consistent code patterns

---

## Project Structure

```
lib/
├── core/                           # Core functionality
│   ├── constants/
│   │   └── app_constants.dart      # Global constants and configurations
│   ├── models/                     # Data models
│   │   ├── user_model.dart
│   │   ├── organization_model.dart
│   │   └── base_model.dart         # Base model with common functionality
│   ├── providers/                  # Riverpod providers (state management)
│   │   ├── auth_provider.dart
│   │   ├── user_provider.dart
│   │   ├── bot_provider.dart
│   │   └── app_state_provider.dart
│   ├── services/                   # Business logic and data operations
│   │   ├── auth_service.dart
│   │   ├── bot_service.dart
│   │   ├── organization_service.dart
│   │   └── logging_service.dart    # Centralized logging
│   ├── theme/
│   │   ├── app_theme.dart          # Main theme configuration
│   │   ├── color_palette.dart      # Color definitions
│   │   └── text_styles.dart        # Typography definitions
│   ├── utils/                      # Utility functions
│   │   ├── snackbar_util.dart      # Centralized snackbar management
│   │   ├── error_handler.dart      # Error processing
│   │   ├── validators.dart         # Input validation
│   │   └── date_formatter.dart     # Date/time utilities
│   ├── widgets/                    # Reusable UI components
│   │   ├── app_bar.dart
│   │   ├── app_sidebar.dart
│   │   ├── page_wrapper.dart
│   │   ├── loading_indicator.dart
│   │   ├── empty_state.dart
│   │   └── error_state.dart
│   └── routes/
│       └── app_routes.dart         # Route definitions and navigation
├── features/                       # Feature modules
│   ├── auth/                       # Authentication feature
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
│   ├── bots/                       # Bot management feature
│   │   ├── providers/
│   │   │   ├── bot_list_provider.dart
│   │   │   └── bot_registration_provider.dart
│   │   ├── pages/
│   │   │   ├── bots_page.dart
│   │   │   └── registration/
│   │   │       ├── method_selection_page.dart
│   │   │       ├── qr_scan_page.dart
│   │   │       ├── manual_entry_page.dart
│   │   │       └── bot_details_page.dart
│   │   ├── widgets/
│   │   │   ├── bot_card.dart
│   │   │   ├── bot_status_indicator.dart
│   │   │   ├── assignment_dialog.dart
│   │   │   └── unregister_dialog.dart
│   │   └── services/
│   │       └── bot_repository.dart
│   ├── management/                 # User & organization management
│   │   ├── providers/
│   │   ├── pages/
│   │   ├── widgets/
│   │   └── services/
│   └── [other features]/
├── shared/                         # Shared components
│   ├── navigation/
│   │   ├── bottom_navigation.dart
│   │   └── main_navigation.dart
│   └── widgets/
│       ├── custom_text_field.dart
│       ├── custom_button.dart
│       └── search_bar.dart
├── main.dart                       # App entry point
└── app.dart                        # Main app widget with providers
```

---

## State Management with Riverpod

### Provider Architecture

#### 1. **State Providers**
```dart
// User state management
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.read(authServiceProvider));
});

class UserState {
  final UserModel? currentUser;
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  const UserState({
    this.currentUser,
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserModel? currentUser,
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      currentUser: currentUser ?? this.currentUser,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
```

#### 2. **Service Providers**
```dart
// Service layer providers
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final botServiceProvider = Provider<BotService>((ref) {
  return BotService();
});

final loggingServiceProvider = Provider<LoggingService>((ref) {
  return LoggingService();
});
```

#### 3. **Stream Providers**
```dart
// Real-time data streams
final botsStreamProvider = StreamProvider.family<List<BotModel>, String>((ref, adminId) {
  final botService = ref.read(botServiceProvider);
  return botService.getBotsStream(adminId);
});

final userAuthStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.authStateChanges();
});
```

#### 4. **Future Providers**
```dart
// Async operations
final organizationsProvider = FutureProvider<List<OrganizationModel>>((ref) {
  final orgService = ref.read(organizationServiceProvider);
  return orgService.getAllOrganizations();
});
```

### State Management Patterns

#### 1. **Centralized State**
```dart
// Global app state
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

class AppState {
  final bool isInitialized;
  final String? currentRoute;
  final Map<String, dynamic> globalData;

  const AppState({
    this.isInitialized = false,
    this.currentRoute,
    this.globalData = const {},
  });
}
```

#### 2. **Feature-Specific State**
```dart
// Bot management state
final botManagementProvider = StateNotifierProvider<BotManagementNotifier, BotManagementState>((ref) {
  return BotManagementNotifier(ref.read(botServiceProvider));
});
```

#### 3. **UI State Management**
```dart
// Search and filter state
final botSearchProvider = StateProvider<String>((ref) => '');
final botFilterProvider = StateProvider<BotFilter>((ref) => BotFilter.all);
```

---

## Theming System

### Color Palette
```dart
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF0160C9);
  static const Color primaryLight = Color(0xFF3380E3);
  static const Color secondary = Color(0xFF1565C0);
  static const Color accent = Color(0xFF1976D2);

  // Background Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFF5F5F5);

  // Status Colors
  static const Color success = Color(0xFF388E3C);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textMuted = Color(0xFF9E9E9E);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFEEEEEE);
}
```

### Typography System
```dart
class AppTextStyles {
  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );
}
```

### Spacing System
```dart
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
```

### Component Styling
```dart
class AppStyles {
  // Card styling
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Input field styling
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}
```

---

## Naming Conventions

### File and Directory Naming
- **Files**: `snake_case` (e.g., `user_management_page.dart`)
- **Directories**: `snake_case` (e.g., `user_management/`)
- **Classes**: `PascalCase` (e.g., `UserManagementPage`)
- **Variables/Functions**: `camelCase` (e.g., `getCurrentUser()`)
- **Constants**: `camelCase` with descriptive names (e.g., `defaultPadding`)

### Database Field Naming
- **Firestore Fields**: `snake_case` (e.g., `first_name`, `created_at`)
- **Model Properties**: `camelCase` (e.g., `firstName`, `createdAt`)
- **Collections**: `snake_case` plural (e.g., `users`, `organizations`)

### Provider Naming
```dart
// State providers
final userProvider = StateNotifierProvider<UserNotifier, UserState>(...);
final botListProvider = StateNotifierProvider<BotListNotifier, BotListState>(...);

// Service providers
final authServiceProvider = Provider<AuthService>(...);
final botServiceProvider = Provider<BotService>(...);

// Stream providers
final userStreamProvider = StreamProvider<UserModel?>(...);
final botsStreamProvider = StreamProvider.family<List<BotModel>, String>(...);

// Future providers
final organizationsProvider = FutureProvider<List<OrganizationModel>>(...);
```

### Widget Naming
```dart
// Pages
class UserManagementPage extends ConsumerWidget { }
class BotRegistrationPage extends ConsumerStatefulWidget { }

// Widgets
class UserCard extends StatelessWidget { }
class BotStatusIndicator extends StatelessWidget { }
class CustomTextField extends StatefulWidget { }

// Dialogs
class ConfirmationDialog extends StatelessWidget { }
class UserSelectionDialog extends StatefulWidget { }
```

---

## Centralized Utilities

### 1. **Snackbar Utility (Minimal & Clean)**
```dart
class SnackbarUtil {
  static ScaffoldMessengerState? _currentMessenger;

  static void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _hideCurrent();
    _currentMessenger = ScaffoldMessenger.of(context);

    _currentMessenger!.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _getSnackbarColor(type),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 80,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.info);
  }

  static void showWarning(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.warning);
  }

  static void _hideCurrent() {
    if (_currentMessenger != null) {
      _currentMessenger!.hideCurrentSnackBar();
      _currentMessenger = null;
    }
  }

  static Color _getSnackbarColor(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return AppColors.success;
      case SnackbarType.error:
        return AppColors.error;
      case SnackbarType.warning:
        return AppColors.warning;
      case SnackbarType.info:
        return AppColors.info;
    }
  }
}

enum SnackbarType { success, error, warning, info }
```

### 2. **Centralized Logging Service**
```dart
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Log user actions
  Future<void> logUserAction({
    required String userId,
    required String action,
    required String feature,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('user_logs').add({
        'user_id': userId,
        'action': action,
        'feature': feature,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
    } catch (e) {
      print('Error logging user action: $e');
    }
  }

  // Log errors
  Future<void> logError({
    required String error,
    required String context,
    String? userId,
    StackTrace? stackTrace,
  }) async {
    try {
      await _firestore.collection('error_logs').add({
        'error': error,
        'context': context,
        'user_id': userId,
        'stack_trace': stackTrace?.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
    } catch (e) {
      print('Error logging error: $e');
    }
  }

  // Log app events
  Future<void> logEvent({
    required String event,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _firestore.collection('app_events').add({
        'event': event,
        'parameters': parameters ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
    } catch (e) {
      print('Error logging event: $e');
    }
  }
}
```

### 3. **Error Handler**
```dart
class ErrorHandler {
  static final LoggingService _loggingService = LoggingService();

  static String getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  static void handleError({
    required BuildContext context,
    required dynamic error,
    required String context,
    String? userId,
    bool showSnackbar = true,
  }) {
    String message = 'An unexpected error occurred.';
    
    if (error is FirebaseAuthException) {
      message = getFirebaseAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      message = getFirestoreErrorMessage(error);
    } else {
      message = error.toString();
    }

    // Log the error
    _loggingService.logError(
      error: error.toString(),
      context: context,
      userId: userId,
      stackTrace: StackTrace.current,
    );

    // Show user feedback
    if (showSnackbar) {
      SnackbarUtil.showError(context, message);
    }
  }

  static String getFirestoreErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action.';
      case 'unavailable':
        return 'Service is currently unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please check your connection.';
      case 'not-found':
        return 'Requested data not found.';
      default:
        return e.message ?? 'A database error occurred.';
    }
  }
}
```

---

## Data Models & Services

### Base Model Pattern
```dart
abstract class BaseModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  BaseModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap();
  BaseModel copyWith();
}
```

### Model Implementation
```dart
class UserModel extends BaseModel {
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String status;
  final String? createdBy;

  UserModel({
    required String id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    this.createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
  bool get isAdmin => role == AppConstants.adminRole;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? AppConstants.fieldOperatorRole,
      status: map['status'] ?? 'active',
      createdBy: map['created_by'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': role,
      'status': status,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    String? status,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
```

### Service Pattern
```dart
abstract class BaseService<T extends BaseModel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggingService _loggingService = LoggingService();
  
  String get collectionName;
  
  T fromMap(Map<String, dynamic> map, String id);
  
  Future<String> create(T model) async {
    try {
      final docRef = await _firestore.collection(collectionName).add(model.toMap());
      await _loggingService.logEvent(
        event: '${collectionName}_created',
        parameters: {'id': docRef.id},
      );
      return docRef.id;
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_create',
      );
      rethrow;
    }
  }
  
  Future<T?> getById(String id) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(id).get();
      if (!doc.exists) return null;
      return fromMap(doc.data()!, doc.id);
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_getById',
      );
      return null;
    }
  }
  
  Stream<List<T>> getAll() {
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromMap(doc.data(), doc.id))
            .toList());
  }
  
  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collectionName).doc(id).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _loggingService.logEvent(
        event: '${collectionName}_updated',
        parameters: {'id': id},
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_update',
      );
      rethrow;
    }
  }
  
  Future<void> delete(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete();
      await _loggingService.logEvent(
        event: '${collectionName}_deleted',
        parameters: {'id': id},
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: '${collectionName}_delete',
      );
      rethrow;
    }
  }
}
```

---

## UI Components & Patterns

### Reusable Components

#### 1. **Custom Text Field**
```dart
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: AppTextStyles.bodyLarge,
          decoration: AppStyles.inputDecoration(
            label: '',
            hint: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
```

#### 2. **Loading Indicator**
```dart
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
```

#### 3. **Empty State**
```dart
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Page Structure Pattern
```dart
class FeaturePage extends ConsumerStatefulWidget {
  const FeaturePage({super.key});

  @override
  ConsumerState<FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends ConsumerState<FeaturePage> {
  @override
  void initState() {
    super.initState();
    // Initialize page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(featureProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(featureProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Title'),
      ),
      body: state.when(
        loading: () => const LoadingIndicator(message: 'Loading...'),
        error: (error, stackTrace) => ErrorState(
          error: error.toString(),
          onRetry: () => ref.refresh(featureProvider),
        ),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(FeatureData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page content
        ],
      ),
    );
  }
}
```

---

## Implementation Guidelines

### 1. **Project Setup**
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_database: ^10.4.0
  
  # UI
  google_fonts: ^6.1.0
  
  # Utilities
  mobile_scanner: ^3.5.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.7
```

### 2. **Main App Setup**
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(
    ProviderScope(
      child: const AgosApp(),
    ),
  );
}

// app.dart
class AgosApp extends ConsumerWidget {
  const AgosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AGOS',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
```

### 3. **Provider Setup**
```dart
// providers/app_providers.dart
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref.read(userServiceProvider));
});
```

### 4. **Feature Implementation Steps**

#### Step 1: Create Feature Structure
```
features/new_feature/
├── providers/
├── pages/
├── widgets/
└── services/
```

#### Step 2: Define Models
```dart
class FeatureModel extends BaseModel {
  // Model implementation
}
```

#### Step 3: Create Service
```dart
class FeatureService extends BaseService<FeatureModel> {
  @override
  String get collectionName => 'features';
  
  @override
  FeatureModel fromMap(Map<String, dynamic> map, String id) {
    return FeatureModel.fromMap(map, id);
  }
}
```

#### Step 4: Setup Providers
```dart
final featureServiceProvider = Provider<FeatureService>((ref) {
  return FeatureService();
});

final featureProvider = StateNotifierProvider<FeatureNotifier, FeatureState>((ref) {
  return FeatureNotifier(ref.read(featureServiceProvider));
});
```

#### Step 5: Create Pages and Widgets
```dart
class FeaturePage extends ConsumerWidget {
  // Page implementation
}
```

### 5. **Testing Strategy**
```dart
// test/providers/feature_provider_test.dart
void main() {
  group('FeatureProvider', () {
    testWidgets('should load data correctly', (tester) async {
      final container = ProviderContainer();
      
      // Test implementation
    });
  });
}
```

---

## Code Examples

### Complete Feature Implementation Example

#### 1. **Model**
```dart
// models/task_model.dart
class TaskModel extends BaseModel {
  final String title;
  final String description;
  final String status;
  final String assignedTo;
  final DateTime dueDate;

  TaskModel({
    required String id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedTo,
    required this.dueDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(id: id, createdAt: createdAt, updatedAt: updatedAt);

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      assignedTo: map['assigned_to'] ?? '',
      dueDate: (map['due_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'assigned_to': assignedTo,
      'due_date': Timestamp.fromDate(dueDate),
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  TaskModel copyWith({
    String? title,
    String? description,
    String? status,
    String? assignedTo,
    DateTime? dueDate,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
```

#### 2. **Service**
```dart
// services/task_service.dart
class TaskService extends BaseService<TaskModel> {
  @override
  String get collectionName => 'tasks';

  @override
  TaskModel fromMap(Map<String, dynamic> map, String id) {
    return TaskModel.fromMap(map, id);
  }

  Stream<List<TaskModel>> getTasksByUser(String userId) {
    return _firestore
        .collection(collectionName)
        .where('assigned_to', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await update(taskId, {'status': status});
  }
}
```

#### 3. **Provider**
```dart
// providers/task_provider.dart
@riverpod
class TaskNotifier extends _$TaskNotifier {
  @override
  AsyncValue<List<TaskModel>> build() {
    return const AsyncValue.loading();
  }

  Future<void> loadTasks(String userId) async {
    state = const AsyncValue.loading();
    
    try {
      final taskService = ref.read(taskServiceProvider);
      final tasks = await taskService.getTasksByUser(userId).first;
      state = AsyncValue.data(tasks);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createTask(TaskModel task) async {
    try {
      final taskService = ref.read(taskServiceProvider);
      await taskService.create(task);
      
      // Refresh the list
      final currentUser = ref.read(authProvider).currentUser;
      if (currentUser != null) {
        await loadTasks(currentUser.uid);
      }
    } catch (error) {
      // Handle error
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      final taskService = ref.read(taskServiceProvider);
      await taskService.updateTaskStatus(taskId, status);
      
      // Update local state
      state = state.whenData((tasks) {
        return tasks.map((task) {
          if (task.id == taskId) {
            return task.copyWith(status: status);
          }
          return task;
        }).toList();
      });
    } catch (error) {
      // Handle error
    }
  }
}

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService();
});
```

#### 4. **Page**
```dart
// pages/tasks_page.dart
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authProvider).currentUser;
      if (currentUser != null) {
        ref.read(taskNotifierProvider.notifier).loadTasks(currentUser.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            onPressed: _showCreateTaskDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading tasks...'),
        error: (error, stackTrace) => ErrorState(
          error: error.toString(),
          onRetry: () => ref.refresh(taskNotifierProvider),
        ),
        data: (tasks) => tasks.isEmpty
            ? const EmptyState(
                icon: Icons.task_outlined,
                title: 'No Tasks',
                message: 'You don\'t have any tasks yet.',
                actionLabel: 'Create Task',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  return TaskCard(
                    task: tasks[index],
                    onStatusChanged: (status) {
                      ref
                          .read(taskNotifierProvider.notifier)
                          .updateTaskStatus(tasks[index].id, status);
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateTaskDialog(),
    );
  }
}
```

This blueprint provides a complete architecture guide for building scalable, maintainable Flutter applications following the AGOS app patterns. The modular structure, centralized state management with Riverpod, consistent theming, and comprehensive utilities ensure that your application will be cohesive, maintainable, and easy to scale.
