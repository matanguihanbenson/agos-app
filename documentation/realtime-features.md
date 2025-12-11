# Real-time Features & Synchronization

## ⚡ Overview

AGOS implements comprehensive real-time features for live data synchronization, providing instant updates across all connected devices. This document covers real-time data flows, synchronization patterns, and live monitoring capabilities.

## 🔄 Real-time Architecture

### Data Flow Architecture
```
Firebase Realtime Database
    ↓ (Live Updates)
RealtimeBotService
    ↓ (Data Merging)
BotProvider
    ↓ (State Updates)
UI Components
    ↓ (User Interaction)
```

### Synchronization Layers
1. **Firebase Realtime Database**: Live sensor data and bot status
2. **Cloud Firestore**: Persistent data and user management
3. **RealtimeBotService**: Data merging and synchronization
4. **Riverpod Providers**: State management and UI updates
5. **UI Components**: Real-time display and interaction

## 🤖 Bot Real-time Data

### Realtime Database Structure

**Path**: `bots/{botId}`

```javascript
{
  "status": "deployed",           // Current operational status
  "battery_level": 85,            // Battery percentage (0-100)
  "lat": 14.5995,                // Latitude coordinate
  "lng": 120.9842,               // Longitude coordinate
  "active": true,                 // Online/offline status
  "ph_level": 7.2,               // Water pH level
  "temp": 25.5,                  // Water temperature (°C)
  "turbidity": 12.3,             // Water turbidity (NTU)
  "last_updated": 1695847200000   // Unix timestamp
}
```

### Data Synchronization

#### RealtimeBotService (`lib/core/services/realtime_bot_service.dart`)

**Purpose**: Handle real-time bot data synchronization

**Key Features**:
- Firestore listeners for bot metadata
- Realtime Database listeners for live status
- Data merging and validation
- Role-based filtering
- Automatic reconnection

**Implementation**:
```dart
class RealtimeBotService {
  // Listen to Firestore changes
  void _listenToAdminBots(String adminId) {
    _firestoreSubscription = _firestore
        .collection('bots')
        .where('owner_admin_id', isEqualTo: adminId)
        .snapshots()
        .listen((snapshot) {
      _handleFirestoreChanges(snapshot);
    });
  }
  
  // Listen to Realtime Database changes
  void _startRealtimeListening(String botId) {
    _realtimeSubscriptions[botId] = _database
        .ref('bots/$botId')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _realtimeData[botId] = data;
      } else {
        _realtimeData.remove(botId);
      }
      _emitUpdatedBots();
    });
  }
}
```

### Bot Status Updates

#### Status Types
- **Deployed**: Bot is actively cleaning
- **Idle**: Bot is waiting for commands
- **Maintenance**: Bot requires maintenance
- **Offline**: Bot is not connected

#### Status Transitions
```dart
// Status change detection
void _handleStatusChange(String botId, String newStatus) {
  final bot = _firestoreBots[botId];
  if (bot != null) {
    // Update UI immediately
    _updateBotStatus(botId, newStatus);
    
    // Log status change
    _loggingService.logUserAction(
      'bot_status_change',
      'Bot $botId status changed to $newStatus',
    );
    
    // Send notification if needed
    if (newStatus == 'maintenance') {
      _sendMaintenanceNotification(botId);
    }
  }
}
```

## 🗺️ Real-time Map Updates

### Map Synchronization

**Purpose**: Display live bot locations on interactive map

**Features**:
- Real-time marker updates
- Status-based color coding
- Bot name labels
- Zoom and pan controls
- Tap interactions for details

**Implementation**:
```dart
// Real-time map updates
Stream<List<BotModel>> getRealtimeBots(Ref ref) {
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
    final currentUser = ref.read(authProvider).userProfile;
    if (currentUser == null) return [];
    
    List<BotModel> allBots = [];
    
    if (currentUser.role == 'admin') {
      allBots = await botService.getBotsByOwnerWithRealtimeData(currentUser.id);
    } else if (currentUser.role == 'field_operator') {
      allBots = await botService.getBotsAssignedToUserWithRealtimeData(currentUser.id);
    }
    
    // Filter for active bots with valid coordinates
    return allBots.where((bot) =>
        bot.active == true &&
        bot.lat != null && bot.lat! >= -90 && bot.lat! <= 90 &&
        bot.lng != null && bot.lng! >= -180 && bot.lng! <= 180
    ).toList();
  });
}
```

### Marker Updates

**Real-time Marker Properties**:
- **Position**: Updates when lat/lng changes
- **Color**: Changes based on status
- **Visibility**: Shows/hides based on active status
- **Label**: Updates with bot name and status

**Marker Color Coding**:
```dart
Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'deployed': return Colors.green;
    case 'maintenance': return Colors.blue;
    case 'idle': return Colors.orange;
    default: return Colors.grey;
  }
}
```

## 📊 Live Dashboard Updates

### Dashboard Metrics

**Real-time Metrics**:
- Total active bots
- Bot status distribution
- Battery levels
- Environmental data
- Performance metrics

**Update Frequency**: Every 5 seconds

**Implementation**:
```dart
// Dashboard real-time updates
void _updateDashboardMetrics(List<BotModel> bots) {
  setState(() {
    _totalBots = bots.length;
    _activeBots = bots.where((bot) => bot.active == true).length;
    _deployedBots = bots.where((bot) => bot.status == 'deployed').length;
    _idleBots = bots.where((bot) => bot.status == 'idle').length;
    _maintenanceBots = bots.where((bot) => bot.status == 'maintenance').length;
    
    // Calculate average battery level
    final batteryLevels = bots
        .where((bot) => bot.batteryLevel != null)
        .map((bot) => bot.batteryLevel!)
        .toList();
    _averageBattery = batteryLevels.isNotEmpty
        ? batteryLevels.reduce((a, b) => a + b) / batteryLevels.length
        : 0.0;
  });
}
```

## 🔔 Real-time Notifications

### Notification Types

#### Bot Alerts
- **Low Battery**: When battery level < 20%
- **Maintenance Required**: When status changes to maintenance
- **Offline Alert**: When bot goes offline
- **Location Update**: When bot moves significantly

#### System Notifications
- **User Assignment**: When bot is assigned to user
- **User Unassignment**: When bot is unassigned
- **Organization Changes**: When bot organization changes
- **System Updates**: Important system announcements

### Notification Implementation

```dart
// Real-time notification creation
Future<void> createBotAlertNotification(String botId, String message) async {
  final notification = NotificationModel(
    id: '',
    title: 'Bot Alert',
    message: message,
    type: NotificationType.botAlert,
    isRead: false,
    timestamp: DateTime.now(),
    userId: _getBotOwnerId(botId),
    relatedEntityId: botId,
    relatedEntityType: 'bot',
    metadata: {'bot_id': botId},
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  
  await _notificationService.createNotification(notification);
}
```

## 📱 Live UI Updates

### Component Updates

#### Bot Cards
- **Status Indicators**: Update in real-time
- **Battery Levels**: Show current battery percentage
- **Location**: Update with reverse geocoded addresses
- **Online/Offline**: Visual status indicators

#### Bot Lists
- **Sorting**: Maintain sort order during updates
- **Filtering**: Apply filters to live data
- **Search**: Real-time search results
- **Pagination**: Handle dynamic list updates

#### Map Views
- **Marker Positions**: Smooth position updates
- **Status Colors**: Dynamic color changes
- **Labels**: Update bot names and status
- **Clustering**: Handle marker clustering

### Update Patterns

#### Optimistic Updates
```dart
// Update UI immediately, sync with server
void _updateBotStatus(String botId, String status) {
  // Update local state immediately
  setState(() {
    _bots = _bots.map((bot) {
      if (bot.id == botId) {
        return bot.copyWith(status: status);
      }
      return bot;
    }).toList();
  });
  
  // Sync with server
  _syncWithServer(botId, status);
}
```

#### Batch Updates
```dart
// Batch multiple updates for performance
void _batchUpdateBots(List<BotUpdate> updates) {
  final updatedBots = Map<String, BotModel>.from(_bots.asMap());
  
  for (final update in updates) {
    if (updatedBots.containsKey(update.botId)) {
      updatedBots[update.botId] = updatedBots[update.botId]!.copyWith(
        status: update.status,
        batteryLevel: update.batteryLevel,
        lat: update.lat,
        lng: update.lng,
      );
    }
  }
  
  setState(() {
    _bots = updatedBots.values.toList();
  });
}
```

## 🔄 Data Synchronization Patterns

### 1. Firestore + Realtime Database Sync

**Pattern**: Merge persistent data with live data

```dart
// Merge Firestore and Realtime Database data
BotModel _mergeBotData(
  Map<String, dynamic> firestoreData,
  String botId,
  Map<String, dynamic>? realtimeData,
) {
  return BotModel.fromMapWithRealtimeData(
    firestoreData,
    botId,
    realtimeData,
  );
}
```

### 2. Conflict Resolution

**Pattern**: Handle data conflicts gracefully

```dart
// Resolve conflicts between data sources
Map<String, dynamic> _resolveConflicts(
  Map<String, dynamic> firestoreData,
  Map<String, dynamic> realtimeData,
) {
  final merged = Map<String, dynamic>.from(firestoreData);
  
  // Realtime data takes precedence for live fields
  final liveFields = ['status', 'battery_level', 'lat', 'lng', 'active'];
  for (final field in liveFields) {
    if (realtimeData.containsKey(field)) {
      merged[field] = realtimeData[field];
    }
  }
  
  return merged;
}
```

### 3. Offline Support

**Pattern**: Handle offline scenarios

```dart
// Handle offline data
void _handleOfflineData() {
  if (!_isOnline) {
    // Use cached data
    _loadCachedBots();
    
    // Show offline indicator
    _showOfflineIndicator();
    
    // Queue updates for when online
    _queueOfflineUpdates();
  } else {
    // Sync with server
    _syncWithServer();
  }
}
```

## ⚡ Performance Optimization

### 1. Update Throttling

**Pattern**: Limit update frequency

```dart
// Throttle updates to prevent excessive UI updates
Timer? _updateTimer;

void _throttledUpdate() {
  _updateTimer?.cancel();
  _updateTimer = Timer(const Duration(milliseconds: 500), () {
    _updateUI();
  });
}
```

### 2. Selective Updates

**Pattern**: Update only changed components

```dart
// Update only specific bot data
void _updateBotData(String botId, Map<String, dynamic> data) {
  final index = _bots.indexWhere((bot) => bot.id == botId);
  if (index != -1) {
    setState(() {
      _bots[index] = _bots[index].copyWith(
        status: data['status'],
        batteryLevel: data['battery_level'],
        // ... other fields
      );
    });
  }
}
```

### 3. Memory Management

**Pattern**: Clean up resources

```dart
// Clean up subscriptions
@override
void dispose() {
  _firestoreSubscription?.cancel();
  for (final subscription in _realtimeSubscriptions.values) {
    subscription.cancel();
  }
  _realtimeSubscriptions.clear();
  _botsController.close();
  super.dispose();
}
```

## 🧪 Testing Real-time Features

### Unit Tests

```dart
test('should update bot status in real-time', () async {
  // Arrange
  final service = RealtimeBotService();
  final botId = 'bot-1';
  
  // Act
  await service.updateBotStatus(botId, 'deployed');
  
  // Assert
  expect(service.getBotStatus(botId), 'deployed');
});
```

### Integration Tests

```dart
testWidgets('should display real-time bot updates', (tester) async {
  // Arrange
  await tester.pumpWidget(MyApp());
  
  // Act - Simulate real-time update
  await tester.pump(Duration(seconds: 1));
  
  // Assert
  expect(find.text('Online'), findsOneWidget);
  expect(find.text('Battery: 85%'), findsOneWidget);
});
```

## 🚨 Error Handling

### Connection Errors

```dart
// Handle connection errors
void _handleConnectionError(dynamic error) {
  if (error is SocketException) {
    _showOfflineMessage();
  } else if (error is TimeoutException) {
    _showTimeoutMessage();
  } else {
    _showGenericErrorMessage();
  }
  
  // Attempt reconnection
  _scheduleReconnection();
}
```

### Data Validation

```dart
// Validate real-time data
bool _isValidBotData(Map<String, dynamic> data) {
  // Check required fields
  if (!data.containsKey('status') || !data.containsKey('active')) {
    return false;
  }
  
  // Validate status
  final validStatuses = ['deployed', 'idle', 'maintenance'];
  if (!validStatuses.contains(data['status'])) {
    return false;
  }
  
  // Validate coordinates
  if (data.containsKey('lat') && data.containsKey('lng')) {
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    if (lat == null || lng == null || 
        lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return false;
    }
  }
  
  return true;
}
```

## 📊 Monitoring & Analytics

### Real-time Metrics

**Tracked Metrics**:
- Update frequency
- Data accuracy
- Connection stability
- UI responsiveness
- Error rates

**Implementation**:
```dart
// Track real-time metrics
void _trackRealtimeMetrics() {
  _analytics.logEvent(
    name: 'realtime_update',
    parameters: {
      'update_count': _updateCount,
      'error_count': _errorCount,
      'avg_response_time': _avgResponseTime,
      'connection_quality': _connectionQuality,
    },
  );
}
```

---

**Last Updated**: September 2024  
**Version**: 1.0.0
