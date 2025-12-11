# State Management with Riverpod

## 🔄 Overview

AGOS uses **Riverpod** as the primary state management solution, providing a reactive, type-safe, and testable approach to managing application state. This document covers all providers, state patterns, and best practices.

## 🏗️ Architecture Pattern

### Provider Hierarchy
```
App
├── AuthProvider (Global)
├── UserProvider (Global)
├── BotProvider (Global)
├── OrganizationProvider (Global)
├── NotificationProvider (Global)
└── Feature-specific Providers
    ├── BotRegistrationProvider
    ├── RealtimeBotService
    └── MapProvider
```

### State Flow
1. **UI** triggers action
2. **Provider** processes business logic
3. **Service** handles data operations
4. **State** updates automatically
5. **UI** rebuilds reactively

## 🔐 Authentication State

### AuthProvider (`lib/core/providers/auth_provider.dart`)

**Purpose**: Manage user authentication state

**State Structure**:
```dart
class AuthState {
  final UserModel? userProfile;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
}
```

**Key Methods**:
```dart
// Sign in user
Future<void> signIn(String email, String password)

// Sign up new user
Future<void> signUp(String email, String password, UserModel userProfile)

// Sign out user
Future<void> signOut()

// Get current user
UserModel? get currentUser
```

**Usage Example**:
```dart
// Watch authentication state
final authState = ref.watch(authProvider);

// Read current user
final user = ref.read(authProvider).userProfile;

// Listen to changes
ref.listen(authProvider, (previous, next) {
  if (next.isAuthenticated) {
    // Navigate to main app
  } else {
    // Navigate to login
  }
});
```

## 👥 User Management State

### UserProvider (`lib/core/providers/user_provider.dart`)

**Purpose**: Manage user data and operations

**State Structure**:
```dart
class UserState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;
}
```

**Key Methods**:
```dart
// Load all users
Future<void> loadUsers()

// Load users by creator
Future<void> loadUsersByCreator(String createdBy)

// Create new user
Future<void> createUser(UserModel user)

// Update user
Future<void> updateUser(String userId, Map<String, dynamic> data)

// Delete user
Future<void> deleteUser(String userId)

// Update user status
Future<void> updateUserStatus(String userId, String status)
```

**Usage Example**:
```dart
// Watch user state
final userState = ref.watch(userProvider);

// Load users for admin
ref.read(userProvider.notifier).loadUsersByCreator(adminId);

// Create new user
await ref.read(userProvider.notifier).createUser(newUser);
```

## 🤖 Bot Management State

### BotProvider (`lib/core/providers/bot_provider.dart`)

**Purpose**: Manage bot data and real-time updates

**State Structure**:
```dart
class BotState {
  final List<BotModel> bots;
  final bool isLoading;
  final String? error;
}
```

**Key Methods**:
```dart
// Load bots (role-based)
Future<void> loadBots()

// Start real-time tracking
void startRealtimeTracking()

// Create bot
Future<void> createBot(BotModel bot)

// Update bot
Future<void> updateBot(String botId, Map<String, dynamic> data)

// Delete bot
Future<void> deleteBot(String botId)

// Assign bot to user
Future<void> assignBotToUser(String botId, String userId)
```

**Real-time Updates**:
```dart
// Start real-time tracking
ref.read(botProvider.notifier).startRealtimeTracking();

// Watch for changes
ref.listen(botProvider, (previous, next) {
  if (next.bots.isNotEmpty) {
    // Update UI with new bot data
    updateBotList(next.bots);
  }
});
```

## 🏢 Organization State

### OrganizationProvider (`lib/core/providers/organization_provider.dart`)

**Purpose**: Manage organization data

**State Structure**:
```dart
class OrganizationState {
  final List<OrganizationModel> organizations;
  final bool isLoading;
  final String? error;
}
```

**Key Methods**:
```dart
// Load all organizations
Future<void> loadOrganizations()

// Load organizations by creator
Future<void> loadOrganizationsByCreator(String creatorUserId)

// Create organization
Future<void> createOrganization(OrganizationModel organization)

// Update organization
Future<void> updateOrganization(String orgId, Map<String, dynamic> data)

// Delete organization
Future<void> deleteOrganization(String orgId)
```

## 🔔 Notification State

### NotificationProvider (`lib/core/providers/notification_provider.dart`)

**Purpose**: Manage notification data

**State Structure**:
```dart
class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;
}
```

**Key Methods**:
```dart
// Load notifications for user
Future<void> loadNotifications(String userId)

// Mark notification as read
Future<void> markNotificationAsRead(String notificationId)

// Mark all notifications as read
Future<void> markAllNotificationsAsRead(String userId)

// Create notification
Future<void> createNotification(NotificationModel notification)
```

## 🔄 Real-time State Management

### RealtimeBotService (`lib/core/services/realtime_bot_service.dart`)

**Purpose**: Handle real-time bot data synchronization

**Features**:
- Firestore listeners for bot data
- Realtime Database listeners for live status
- Data merging and synchronization
- Role-based filtering

**Implementation**:
```dart
class RealtimeBotService {
  // Stream of realtime bot data
  Stream<List<BotModel>> getRealtimeBots(Ref ref) {
    // Listen to Firestore changes
    _firestoreSubscription = _firestore
        .collection('bots')
        .where('owner_admin_id', isEqualTo: adminId)
        .snapshots()
        .listen((snapshot) {
      _handleFirestoreChanges(snapshot);
    });
    
    // Listen to Realtime Database changes
    _realtimeSubscriptions[botId] = _database
        .ref('bots/$botId')
        .onValue
        .listen((event) {
      _handleRealtimeChanges(botId, event);
    });
    
    return _botsController.stream;
  }
}
```

## 🎯 Feature-Specific Providers

### Bot Registration Provider

**Purpose**: Handle bot registration flow

**State Structure**:
```dart
class BotRegistrationState {
  final bool isLoading;
  final String? error;
  final String? botId;
  final Map<String, String>? preFilledData;
}
```

**Key Methods**:
```dart
// Register bot
Future<bool> registerBot({
  required String botId,
  required String name,
  String? organizationId,
  String? description,
})

// Validate bot ID
Future<bool> validateBotId(String botId)

// Clear state
void clearState()
```

### App State Provider

**Purpose**: Manage global app state

**State Structure**:
```dart
class AppState {
  final bool isOnline;
  final String currentRoute;
  final Map<String, dynamic> settings;
  final bool isDarkMode;
}
```

## 🔧 Service Providers

### Service Provider Pattern

All services are provided through Riverpod providers:

```dart
// Service providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final userServiceProvider = Provider<UserService>((ref) => UserService());
final botServiceProvider = Provider<BotService>((ref) => BotService());
final organizationServiceProvider = Provider<OrganizationService>((ref) => OrganizationService());
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
final realtimeBotServiceProvider = Provider<RealtimeBotService>((ref) => RealtimeBotService());
```

## 📊 State Patterns

### 1. Loading States

**Pattern**: Use `isLoading` boolean in state

```dart
class MyState {
  final bool isLoading;
  final String? error;
  final List<Data> data;
}

// Usage
if (state.isLoading) {
  return LoadingIndicator();
} else if (state.error != null) {
  return ErrorState(error: state.error!);
} else {
  return DataList(data: state.data);
}
```

### 2. Error Handling

**Pattern**: Centralized error handling with user feedback

```dart
try {
  await someOperation();
} catch (e) {
  state = state.copyWith(
    isLoading: false,
    error: e.toString(),
  );
  
  // Show user-friendly error
  SnackbarUtil.showError(context, 'Operation failed: ${e.toString()}');
}
```

### 3. Optimistic Updates

**Pattern**: Update UI immediately, rollback on error

```dart
// Optimistic update
state = state.copyWith(
  bots: [...state.bots, newBot],
);

try {
  await botService.createBot(newBot);
} catch (e) {
  // Rollback on error
  state = state.copyWith(
    bots: state.bots.where((bot) => bot.id != newBot.id).toList(),
    error: e.toString(),
  );
}
```

### 4. Caching Strategy

**Pattern**: Cache data locally, refresh when needed

```dart
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() {
    // Load cached data immediately
    _loadCachedData();
    
    // Refresh from server
    _refreshData();
    
    return const MyState();
  }
  
  void _loadCachedData() {
    // Load from local storage
  }
  
  void _refreshData() {
    // Load from server
  }
}
```

## 🔄 State Synchronization

### Real-time Updates

**Pattern**: Use streams for live data

```dart
// Listen to real-time changes
ref.listen(botProvider, (previous, next) {
  if (previous?.bots != next.bots) {
    // Update UI with new data
    _updateBotList(next.bots);
  }
});
```

### Cross-Provider Communication

**Pattern**: Use ref.read() to access other providers

```dart
class BotNotifier extends Notifier<BotState> {
  Future<void> createBot(BotModel bot) async {
    try {
      await ref.read(botServiceProvider).createBot(bot);
      
      // Update bot list
      await loadBots();
      
      // Create notification
      await ref.read(notificationProvider.notifier)
          .createNotification(notification);
          
    } catch (e) {
      // Handle error
    }
  }
}
```

## 🧪 Testing State

### Provider Testing

```dart
void main() {
  group('BotProvider Tests', () {
    test('should load bots successfully', () async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          botServiceProvider.overrideWithValue(mockBotService),
        ],
      );
      
      // Act
      await container.read(botProvider.notifier).loadBots();
      
      // Assert
      final state = container.read(botProvider);
      expect(state.bots, isNotEmpty);
      expect(state.isLoading, false);
    });
  });
}
```

### Mock Services

```dart
class MockBotService extends BotService {
  @override
  Future<List<BotModel>> getAllBotsWithRealtimeData() async {
    return [
      BotModel(
        id: 'bot-1',
        name: 'Test Bot',
        // ... other fields
      ),
    ];
  }
}
```

## 🚀 Performance Optimization

### 1. Provider Scope

**Minimize provider scope**:
```dart
// Good: Scoped to specific feature
final featureProvider = Provider<FeatureService>((ref) => FeatureService());

// Bad: Global scope for feature-specific service
final globalProvider = Provider<FeatureService>((ref) => FeatureService());
```

### 2. State Immutability

**Use copyWith pattern**:
```dart
class MyState {
  final List<Data> data;
  final bool isLoading;
  
  MyState copyWith({
    List<Data>? data,
    bool? isLoading,
  }) {
    return MyState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
```

### 3. Selective Rebuilds

**Use select() for specific fields**:
```dart
// Good: Only rebuilds when isLoading changes
final isLoading = ref.watch(botProvider.select((state) => state.isLoading));

// Bad: Rebuilds on any state change
final state = ref.watch(botProvider);
final isLoading = state.isLoading;
```

## 🔧 Best Practices

### 1. State Structure
- Keep state flat and simple
- Use immutable data structures
- Separate loading and error states
- Include metadata when needed

### 2. Provider Organization
- Group related providers together
- Use descriptive names
- Keep providers focused on single responsibility
- Document provider purposes

### 3. Error Handling
- Always handle errors gracefully
- Provide user-friendly error messages
- Log errors for debugging
- Implement retry mechanisms

### 4. Performance
- Use `select()` for specific field watching
- Implement proper caching strategies
- Avoid unnecessary provider rebuilds
- Use `const` constructors where possible

### 5. Testing
- Write unit tests for all providers
- Mock external dependencies
- Test error scenarios
- Verify state transitions

---

**Last Updated**: September 2024  
**Version**: 1.0.0
