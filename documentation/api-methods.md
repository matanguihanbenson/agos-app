# API Methods & Functionalities

## 📋 Overview

This document provides a comprehensive list of all available methods, services, and functionalities in the AGOS application. Each method includes parameters, return types, and usage examples.

## 🔐 Authentication Services

### AuthService (`lib/core/services/auth_service.dart`)

#### `signInWithEmailAndPassword(String email, String password)`
- **Purpose**: Authenticate user with email and password
- **Parameters**: 
  - `email`: User's email address
  - `password`: User's password
- **Returns**: `Future<UserCredential>`
- **Usage**: Login functionality

#### `signUpWithEmailAndPassword(String email, String password)`
- **Purpose**: Create new user account
- **Parameters**: 
  - `email`: User's email address
  - `password`: User's password
- **Returns**: `Future<UserCredential>`
- **Usage**: Registration functionality

#### `signOut()`
- **Purpose**: Sign out current user
- **Parameters**: None
- **Returns**: `Future<void>`
- **Usage**: Logout functionality

#### `getCurrentUser()`
- **Purpose**: Get currently authenticated user
- **Parameters**: None
- **Returns**: `User?`
- **Usage**: Check authentication state

#### `resetPassword(String email)`
- **Purpose**: Send password reset email
- **Parameters**: 
  - `email`: User's email address
- **Returns**: `Future<void>`
- **Usage**: Forgot password functionality

## 👥 User Management Services

### UserService (`lib/core/services/user_service.dart`)

#### `createUser(UserModel user)`
- **Purpose**: Create new user in Firestore
- **Parameters**: 
  - `user`: UserModel object with user data
- **Returns**: `Future<String>` (user ID)
- **Usage**: Admin creating new users

#### `getUser(String userId)`
- **Purpose**: Get user by ID
- **Parameters**: 
  - `userId`: User's unique identifier
- **Returns**: `Future<UserModel?>`
- **Usage**: Fetch user details

#### `updateUser(String userId, Map<String, dynamic> data)`
- **Purpose**: Update user information
- **Parameters**: 
  - `userId`: User's unique identifier
  - `data`: Map of fields to update
- **Returns**: `Future<void>`
- **Usage**: Edit user profile

#### `deleteUser(String userId)`
- **Purpose**: Delete user account
- **Parameters**: 
  - `userId`: User's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Remove user from system

#### `updateUserStatus(String userId, String status)`
- **Purpose**: Update user status (active/inactive/archived)
- **Parameters**: 
  - `userId`: User's unique identifier
  - `status`: New status value
- **Returns**: `Future<void>`
- **Usage**: Activate/deactivate users

#### `assignUserToOrganization(String userId, String organizationId)`
- **Purpose**: Assign user to organization
- **Parameters**: 
  - `userId`: User's unique identifier
  - `organizationId`: Organization's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Organization management

#### `getUsersByCreator(String createdBy)`
- **Purpose**: Get users created by specific admin
- **Parameters**: 
  - `createdBy`: Admin's user ID
- **Returns**: `Future<List<UserModel>>`
- **Usage**: Admin viewing their created users

#### `getUserByEmail(String email)`
- **Purpose**: Find user by email address
- **Parameters**: 
  - `email`: User's email address
- **Returns**: `Future<UserModel?>`
- **Usage**: User lookup by email

#### `searchUsersByName(String name)`
- **Purpose**: Search users by name
- **Parameters**: 
  - `name`: Search query
- **Returns**: `Future<List<UserModel>>`
- **Usage**: User search functionality

## 🤖 Bot Management Services

### BotService (`lib/core/services/bot_service.dart`)

#### `createBot(BotModel bot)`
- **Purpose**: Create new bot in Firestore
- **Parameters**: 
  - `bot`: BotModel object with bot data
- **Returns**: `Future<String>` (bot ID)
- **Usage**: Bot registration

#### `createWithId(String botId, BotModel bot)`
- **Purpose**: Create bot with specific ID
- **Parameters**: 
  - `botId`: Desired bot identifier
  - `bot`: BotModel object with bot data
- **Returns**: `Future<String>` (bot ID)
- **Usage**: Bot registration with custom ID

#### `getBot(String botId)`
- **Purpose**: Get bot by ID
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<BotModel?>`
- **Usage**: Fetch bot details

#### `updateBot(String botId, Map<String, dynamic> data)`
- **Purpose**: Update bot information
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `data`: Map of fields to update
- **Returns**: `Future<void>`
- **Usage**: Edit bot details

#### `deleteBot(String botId)`
- **Purpose**: Delete bot from system
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Remove bot

#### `getAllBotsWithRealtimeData()`
- **Purpose**: Get all bots with real-time data merged
- **Parameters**: None
- **Returns**: `Future<List<BotModel>>`
- **Usage**: Display all bots with live status

#### `getBotsByOwnerWithRealtimeData(String ownerAdminId)`
- **Purpose**: Get bots owned by specific admin with real-time data
- **Parameters**: 
  - `ownerAdminId`: Admin's user ID
- **Returns**: `Future<List<BotModel>>`
- **Usage**: Admin viewing their bots

#### `getBotsAssignedToUserWithRealtimeData(String userId)`
- **Purpose**: Get bots assigned to specific user with real-time data
- **Parameters**: 
  - `userId`: User's unique identifier
- **Returns**: `Future<List<BotModel>>`
- **Usage**: Field operator viewing assigned bots

#### `assignBotToUser(String botId, String userId)`
- **Purpose**: Assign bot to user
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `userId`: User's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Bot assignment

#### `updateBotStatus(String botId, String status)`
- **Purpose**: Update bot status
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `status`: New status value
- **Returns**: `Future<void>`
- **Usage**: Status management

## 🏢 Organization Management Services

### OrganizationService (`lib/core/services/organization_service.dart`)

#### `createOrganization(OrganizationModel organization)`
- **Purpose**: Create new organization
- **Parameters**: 
  - `organization`: OrganizationModel object
- **Returns**: `Future<String>` (organization ID)
- **Usage**: Organization creation

#### `getOrganization(String organizationId)`
- **Purpose**: Get organization by ID
- **Parameters**: 
  - `organizationId`: Organization's unique identifier
- **Returns**: `Future<OrganizationModel?>`
- **Usage**: Fetch organization details

#### `updateOrganization(String organizationId, Map<String, dynamic> data)`
- **Purpose**: Update organization information
- **Parameters**: 
  - `organizationId`: Organization's unique identifier
  - `data`: Map of fields to update
- **Returns**: `Future<void>`
- **Usage**: Edit organization details

#### `deleteOrganization(String organizationId)`
- **Purpose**: Delete organization
- **Parameters**: 
  - `organizationId`: Organization's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Remove organization

#### `getOrganizationsByCreator(String creatorUserId)`
- **Purpose**: Get organizations created by specific user
- **Parameters**: 
  - `creatorUserId`: Creator's user ID
- **Returns**: `Future<List<OrganizationModel>>`
- **Usage**: Admin viewing their organizations

## 📝 Bot Registry Services

### BotRegistryService (`lib/core/services/bot_registry_service.dart`)

#### `getBotRegistryByBotId(String botId)`
- **Purpose**: Get bot registry entry by bot ID
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<BotRegistryModel?>`
- **Usage**: Check bot registration status

#### `botIdExists(String botId)`
- **Purpose**: Check if bot ID exists in registry
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<bool>`
- **Usage**: Validate bot ID availability

#### `isBotRegistered(String botId)`
- **Purpose**: Check if bot is registered
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<bool>`
- **Usage**: Registration validation

#### `markBotAsRegistered(String botId, String registeredBy)`
- **Purpose**: Mark bot as registered
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `registeredBy`: User ID who registered the bot
- **Returns**: `Future<void>`
- **Usage**: Complete bot registration

#### `unregisterBot(String botId)`
- **Purpose**: Unregister bot
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Remove bot from registry

## 🔔 Notification Services

### NotificationService (`lib/core/services/notification_service.dart`)

#### `createNotification(NotificationModel notification)`
- **Purpose**: Create new notification
- **Parameters**: 
  - `notification`: NotificationModel object
- **Returns**: `Future<String>` (notification ID)
- **Usage**: Send notifications

#### `getNotificationsForUser(String userId)`
- **Purpose**: Get notifications for specific user
- **Parameters**: 
  - `userId`: User's unique identifier
- **Returns**: `Future<List<NotificationModel>>`
- **Usage**: Display user notifications

#### `markNotificationAsRead(String notificationId)`
- **Purpose**: Mark notification as read
- **Parameters**: 
  - `notificationId`: Notification's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Update read status

#### `markAllNotificationsAsRead(String userId)`
- **Purpose**: Mark all user notifications as read
- **Parameters**: 
  - `userId`: User's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Bulk read status update

#### `createBotAlertNotification(String botId, String message)`
- **Purpose**: Create bot alert notification
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `message`: Alert message
- **Returns**: `Future<String>` (notification ID)
- **Usage**: Bot status alerts

#### `createAssignmentNotification(String botId, String userId)`
- **Purpose**: Create assignment notification
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `userId`: User's unique identifier
- **Returns**: `Future<String>` (notification ID)
- **Usage**: Assignment notifications

## 🗺️ Map & Location Services

### ReverseGeocodingService (`lib/core/services/reverse_geocoding_service.dart`)

#### `getAddressFromCoordinates({required double latitude, required double longitude})`
- **Purpose**: Get detailed address from coordinates
- **Parameters**: 
  - `latitude`: Latitude coordinate
  - `longitude`: Longitude coordinate
- **Returns**: `Future<String?>`
- **Usage**: Convert coordinates to human-readable address

#### `getShortAddressFromCoordinates({required double latitude, required double longitude})`
- **Purpose**: Get short address (city, country) from coordinates
- **Parameters**: 
  - `latitude`: Latitude coordinate
  - `longitude`: Longitude coordinate
- **Returns**: `Future<String?>`
- **Usage**: Get compact address for UI display

#### `calculateDistance(LatLng p1, LatLng p2)`
- **Purpose**: Calculate distance between two points
- **Parameters**: 
  - `p1`: First LatLng point
  - `p2`: Second LatLng point
- **Returns**: `double` (distance in kilometers)
- **Usage**: Distance calculations

### RealtimeBotService (`lib/core/services/realtime_bot_service.dart`)

#### `getRealtimeBots(Ref ref)`
- **Purpose**: Get real-time bot data stream
- **Parameters**: 
  - `ref`: Riverpod reference
- **Returns**: `Stream<List<BotModel>>`
- **Usage**: Live bot monitoring

#### `getActiveBots(List<BotModel> allBots)`
- **Purpose**: Filter active bots from list
- **Parameters**: 
  - `allBots`: List of all bots
- **Returns**: `List<BotModel>`
- **Usage**: Filter online bots

## 🔧 Utility Services

### LoggingService (`lib/core/services/logging_service.dart`)

#### `logUserAction(String action, String details)`
- **Purpose**: Log user actions
- **Parameters**: 
  - `action`: Action description
  - `details`: Additional details
- **Returns**: `Future<void>`
- **Usage**: Audit trail

#### `logError(String error, String context)`
- **Purpose**: Log errors
- **Parameters**: 
  - `error`: Error message
  - `context`: Error context
- **Returns**: `Future<void>`
- **Usage**: Error tracking

#### `logWarning(String message, String context)`
- **Purpose**: Log warnings
- **Parameters**: 
  - `message`: Warning message
  - `context`: Warning context
- **Returns**: `Future<void>`
- **Usage**: Warning tracking

### SnackbarUtil (`lib/core/utils/snackbar_util.dart`)

#### `showSuccess(BuildContext context, String message)`
- **Purpose**: Show success snackbar
- **Parameters**: 
  - `context`: BuildContext
  - `message`: Success message
- **Returns**: `void`
- **Usage**: Success feedback

#### `showError(BuildContext context, String message)`
- **Purpose**: Show error snackbar
- **Parameters**: 
  - `context`: BuildContext
  - `message`: Error message
- **Returns**: `void`
- **Usage**: Error feedback

#### `showInfo(BuildContext context, String message)`
- **Purpose**: Show info snackbar
- **Parameters**: 
  - `context`: BuildContext
  - `message`: Info message
- **Returns**: `void`
- **Usage**: Information display

#### `showWarning(BuildContext context, String message)`
- **Purpose**: Show warning snackbar
- **Parameters**: 
  - `context`: BuildContext
  - `message`: Warning message
- **Returns**: `void`
- **Usage**: Warning display

## 📊 State Management Providers

### AuthProvider (`lib/core/providers/auth_provider.dart`)

#### `signIn(String email, String password)`
- **Purpose**: Sign in user
- **Parameters**: 
  - `email`: User's email
  - `password`: User's password
- **Returns**: `Future<void>`
- **Usage**: Login functionality

#### `signUp(String email, String password, UserModel userProfile)`
- **Purpose**: Sign up new user
- **Parameters**: 
  - `email`: User's email
  - `password`: User's password
  - `userProfile`: User profile data
- **Returns**: `Future<void>`
- **Usage**: Registration functionality

#### `signOut()`
- **Purpose**: Sign out user
- **Parameters**: None
- **Returns**: `Future<void>`
- **Usage**: Logout functionality

### BotProvider (`lib/core/providers/bot_provider.dart`)

#### `loadBots()`
- **Purpose**: Load bots based on user role
- **Parameters**: None
- **Returns**: `Future<void>`
- **Usage**: Initial bot loading

#### `startRealtimeTracking()`
- **Purpose**: Start real-time bot tracking
- **Parameters**: None
- **Returns**: `void`
- **Usage**: Live bot monitoring

#### `createBot(BotModel bot)`
- **Purpose**: Create new bot
- **Parameters**: 
  - `bot`: BotModel object
- **Returns**: `Future<void>`
- **Usage**: Bot creation

#### `updateBot(String botId, Map<String, dynamic> data)`
- **Purpose**: Update bot
- **Parameters**: 
  - `botId`: Bot's unique identifier
  - `data`: Update data
- **Returns**: `Future<void>`
- **Usage**: Bot modification

#### `deleteBot(String botId)`
- **Purpose**: Delete bot
- **Parameters**: 
  - `botId`: Bot's unique identifier
- **Returns**: `Future<void>`
- **Usage**: Bot removal

## 🎯 Usage Examples

### Creating a New User
```dart
final userService = ref.read(userServiceProvider);
final newUser = UserModel(
  id: '',
  firstName: 'John',
  lastName: 'Doe',
  email: 'john.doe@example.com',
  role: 'field_operator',
  status: 'active',
  createdBy: currentAdminId,
  organizationId: organizationId,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

await userService.createUser(newUser);
```

### Registering a New Bot
```dart
final botService = ref.read(botServiceProvider);
final botRegistryService = ref.read(botRegistryServiceProvider);

// Check if bot ID is available
if (await botRegistryService.botIdExists(botId)) {
  throw Exception('Bot ID already exists');
}

// Create bot
final newBot = BotModel(
  id: botId,
  name: 'Bot-001',
  ownerAdminId: currentAdminId,
  organizationId: organizationId,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

await botService.createWithId(botId, newBot);
await botRegistryService.markBotAsRegistered(botId, currentAdminId);
```

### Getting Real-time Bot Data
```dart
final botProvider = ref.read(botProvider.notifier);
botProvider.startRealtimeTracking();

// Listen to changes
ref.listen(botProvider, (previous, next) {
  if (next.bots.isNotEmpty) {
    // Update UI with new bot data
    updateBotList(next.bots);
  }
});
```

---

**Last Updated**: September 2024  
**Version**: 1.0.0
