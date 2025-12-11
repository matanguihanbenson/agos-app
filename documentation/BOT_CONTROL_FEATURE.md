# Bot Control Feature Documentation

## Overview
The Bot Control feature allows users to remotely control AGOS bots via Bluetooth connection. The feature includes automatic connection simulation, controller locking mechanism to prevent multiple users from controlling the same bot, and a user-friendly joystick interface for navigation.

## Features

### 1. **Bluetooth Connection Simulation**
- Automatic scanning for nearby bot devices
- Connection status indicators (Database & Bluetooth)
- Visual feedback with animated scanning icon
- Progress indicators during connection
- Automatic connection to the bot once detected

### 2. **Controller Locking Mechanism**
- Prevents multiple users from controlling the same bot simultaneously
- Shows alert dialog when another user is controlling the bot
- Displays current controller's name
- Options to retry connection or go back
- **Ready for Firebase integration** (currently using dummy data)

### 3. **Connection States**
- **Disconnected**: Initial state, shows connect button
- **Scanning**: Searching for bot devices
- **Connecting**: Establishing Bluetooth connection
- **Connected**: Successfully connected, control enabled
- **Error**: Connection failed, shows retry option

### 4. **Manual/Automatic Mode Toggle**
- Switch between automatic bot operation and manual control
- Visual indicators for current mode
- Disabled during connection process
- Joystick enabled only in manual mode

### 5. **Navigation Control**
- Circular joystick interface for bot navigation
- Visual feedback when manual mode is enabled
- Drag-to-navigate functionality placeholder
- Boat icon in the center for visual clarity

### 6. **Status Monitoring**
- Database connection status
- Bluetooth connection status
- Battery level indicator (when connected)
- Power/Battery icon display

## File Structure

```
lib/features/control/
├── models/
│   └── bot_control_state.dart          # State model for control management
├── pages/
│   ├── bot_control_page.dart           # New bot control page UI
│   └── control_page.dart               # Old control page (can be removed)
└── providers/
    ├── bot_control_provider.dart       # Riverpod provider for state management
    └── bot_control_provider.g.dart     # Generated provider code
```

## Navigation Integration

The control feature can be accessed from two locations:

### 1. Bot Card (Bots List Page)
- Click the "Control" button on any bot card
- Located in: `lib/features/bots/widgets/bot_card.dart`

### 2. Bot Details Page
- Click the "Control" button in the bottom action bar
- Located in: `lib/features/bots/pages/bot_details_page.dart`

## State Management

### BotControlState
```dart
class BotControlState {
  final String botId;
  final String botName;
  final ConnectionStatus connectionStatus;
  final bool isManualMode;
  final String? currentController;      // User ID of current controller
  final String? currentControllerName;  // Name of current controller
  final bool isScanning;
  final List<BluetoothDevice> availableDevices;
  final String? errorMessage;
}
```

### ConnectionStatus Enum
- `disconnected`
- `scanning`
- `connecting`
- `connected`
- `error`

## UI Components

### 1. Status Card
Displays connection status for:
- Database (currently offline)
- Bluetooth (with battery info when connected)

### 2. Scanning Animation
- Circular animated container
- Bluetooth searching/connected icon
- Status text and progress bar
- Message about scanning for devices

### 3. Manual Control Toggle
- Switch to enable/disable manual control
- Icon changes based on mode (gamepad/sync)
- Description text updates dynamically

### 4. Navigation Control
- Large circular joystick (220x220)
- Inner control button (90x90) with boat icon
- Drag gesture support (placeholder)
- Visual feedback when enabled

### 5. Footer Status
- Blue bar showing connection mode
- Bluetooth connected icon
- "Switched to Manual Mode (Bluetooth)" message

## Controller Conflict Dialog

When another user is already controlling the bot:

```
┌─────────────────────────────────────────┐
│ ⚠️ Bot In Use                           │
├─────────────────────────────────────────┤
│ This bot is currently being controlled  │
│ by another user.                        │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 👤 Current Controller               │ │
│ │ John Doe                            │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Please wait until the bot is available  │
│ or contact the current controller.      │
├─────────────────────────────────────────┤
│          [Go Back]       [Retry]        │
└─────────────────────────────────────────┘
```

## Firebase Integration Points

To integrate with Firebase, update the following methods in `bot_control_provider.dart`:

### 1. Request Control
```dart
Future<bool> requestControl(String userId, String userName) async {
  // TODO: Check Firebase for current controller
  // TODO: If available, set user as controller in Firebase
  // TODO: Listen to changes in Firebase for conflict detection
  
  // Example:
  // final docRef = FirebaseFirestore.instance
  //     .collection('bot_control')
  //     .doc(state.botId);
  // 
  // final doc = await docRef.get();
  // if (doc.exists && doc.data()?['controller'] != null) {
  //   return false; // Already controlled
  // }
  // 
  // await docRef.set({
  //   'controller': userId,
  //   'controllerName': userName,
  //   'timestamp': FieldValue.serverTimestamp(),
  // });
  
  return true;
}
```

### 2. Release Control
```dart
Future<void> releaseControl() async {
  // TODO: Clear controller in Firebase
  
  // Example:
  // await FirebaseFirestore.instance
  //     .collection('bot_control')
  //     .doc(state.botId)
  //     .delete();
}
```

### 3. Listen to Control Status
```dart
void listenToControlStatus() {
  // TODO: Setup Firebase listener
  
  // Example:
  // FirebaseFirestore.instance
  //     .collection('bot_control')
  //     .doc(state.botId)
  //     .snapshots()
  //     .listen((snapshot) {
  //       if (snapshot.exists) {
  //         final data = snapshot.data();
  //         state = state.copyWith(
  //           currentController: data?['controller'],
  //           currentControllerName: data?['controllerName'],
  //         );
  //       }
  //     });
}
```

### 4. Bluetooth Control Commands
The joystick's `onPanUpdate` callback in `_buildControlView` is where you'd send actual Bluetooth commands:

```dart
onPanUpdate: state.isManualMode ? (details) {
  // TODO: Calculate direction and speed from drag
  // TODO: Send Bluetooth command to bot
  
  // Example:
  // final dx = details.localPosition.dx - (220 / 2);
  // final dy = details.localPosition.dy - (220 / 2);
  // final angle = atan2(dy, dx);
  // final distance = sqrt(dx * dx + dy * dy);
  // 
  // BluetoothService.sendNavigationCommand(
  //   botId: widget.botId,
  //   angle: angle,
  //   speed: distance / 110, // Normalize to 0-1
  // );
} : null,
```

## Design Consistency

The bot control page follows the app's design system:

### Colors
- Primary: `AppColors.primary`
- Success: `AppColors.success`
- Error: `AppColors.error`
- Warning: `AppColors.warning`
- Background: `AppColors.background`
- Text: `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.textMuted`
- Border: `AppColors.border`

### Text Styles
- Title: `AppTextStyles.titleMedium`
- Body: `AppTextStyles.bodyMedium`, `AppTextStyles.bodySmall`

### Spacing & Sizing
- Card margin: `16px`
- Card padding: `14-16px`
- Border radius: `12px` for cards, `8px` for buttons
- Icon sizes: `18-20px` for section headers
- Shadow: `BoxShadow` with `alpha: 0.04`

## Testing

### Test Scenarios

1. **Normal Flow**
   - Navigate to bot control
   - Observe automatic scanning animation
   - See connection establishment
   - Switch to manual mode
   - Test joystick interface

2. **Controller Conflict**
   - In `bot_control_provider.dart`, uncomment lines 101-104 in `checkControlStatus()`
   - Navigate to control page
   - Wait 10 seconds
   - Observe conflict alert

3. **Connection Error**
   - Call `setError('Connection failed')` in provider
   - Observe error view
   - Test retry button

4. **Navigation**
   - Test navigation from bot card
   - Test navigation from bot details page
   - Verify back button releases control

## Future Enhancements

1. **Real Bluetooth Integration**
   - Use `flutter_blue_plus` package
   - Implement actual device scanning
   - Handle real connections

2. **Firebase Realtime Sync**
   - Implement Firebase listeners
   - Handle controller conflicts in real-time
   - Show live battery status
   - Track bot location during control

3. **Enhanced Joystick**
   - Implement proper joystick physics
   - Show direction indicators
   - Add haptic feedback
   - Include speed control

4. **Live Camera Feed**
   - Integrate WebRTC or similar
   - Show camera view during control
   - Add picture-in-picture mode

5. **Control History**
   - Log control sessions
   - Track duration and actions
   - Generate reports

6. **Multi-Bot Control**
   - Switch between multiple bots
   - Control bot swarms
   - Coordinate multiple operators

## Notes

- The current implementation uses simulated delays (2-3 seconds) for connection
- All controller locking is currently dummy data for demonstration
- The joystick is visual-only and doesn't send actual commands yet
- Battery level is hard-coded to 75%
- Database connection is always shown as "Offline" (placeholder)

## Support

For questions or issues with the bot control feature, please refer to the main project documentation or contact the development team.
