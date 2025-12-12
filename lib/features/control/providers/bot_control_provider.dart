import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/bot_control_state.dart';

part 'bot_control_provider.g.dart';

@riverpod
class BotControl extends _$BotControl {
  // Simulation mode flag - matches the one in bot_control_page
  static const bool simulationMode = true;

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  @override
  BotControlState build(String botId) {
    return BotControlState(
      botId: botId,
      botName: 'Benson Bot', // Replace with actual bot name from database
    );
  }

  // Bluetooth scanning (real or simulated)
  Future<void> startBluetoothScan() async {
    state = state.copyWith(
      connectionStatus: ConnectionStatus.scanning,
      isScanning: true,
      errorMessage: null,
    );

    if (simulationMode) {
      // Simulate scanning delay (shorter for testing)
      await Future.delayed(const Duration(milliseconds: 800));

      // Simulate finding devices
      final devices = [
        BluetoothDevice(id: 'sim-${state.botId}', name: '${state.botName} (Simulated)', signalStrength: 95),
        BluetoothDevice(id: 'sim-other', name: 'Other Bot (Simulated)', signalStrength: 60),
      ];

      state = state.copyWith(
        availableDevices: devices,
        isScanning: false,
      );
    } else {
      // Real Bluetooth scanning would go here
      // TODO: Implement real Bluetooth scanning using flutter_blue_plus or similar
      await Future.delayed(const Duration(seconds: 2));
      
      // For now, return empty list in real mode until implemented
      state = state.copyWith(
        availableDevices: [],
        isScanning: false,
        connectionStatus: ConnectionStatus.error,
        errorMessage: 'Real Bluetooth scanning not yet implemented',
      );
    }
  }

  // Connect to bot via Bluetooth (real or simulated)
  Future<void> connectToBluetooth(String deviceId) async {
    state = state.copyWith(
      connectionStatus: ConnectionStatus.connecting,
      errorMessage: null,
    );

    if (simulationMode) {
      // Simulate connection delay (shorter for testing)
      await Future.delayed(const Duration(milliseconds: 1200));

      // Simulate successful connection
      state = state.copyWith(
        connectionStatus: ConnectionStatus.connected,
      );
    } else {
      // Real Bluetooth connection would go here
      // TODO: Implement real Bluetooth connection using flutter_blue_plus or similar
      await Future.delayed(const Duration(seconds: 3));
      
      // For now, fail in real mode until implemented
      state = state.copyWith(
        connectionStatus: ConnectionStatus.error,
        errorMessage: 'Real Bluetooth connection not yet implemented',
      );
    }
  }

  // Request control of the bot
  Future<bool> requestControl(String userId, String userName) async {
    // Check if bot is already controlled by someone else
    if (state.currentController != null && state.currentController != userId) {
      return false; // Bot is already being controlled
    }

    // In real implementation, update Firebase here
    state = state.copyWith(
      currentController: userId,
      currentControllerName: userName,
    );

    return true;
  }

  // Release control of the bot
  Future<void> releaseControl() async {
    // In real implementation, update Firebase here
    state = state.copyWith(
      currentController: null,
      currentControllerName: null,
    );
  }

  // Toggle manual mode
  Future<void> toggleManualMode(bool enabled) async {
    state = state.copyWith(isManualMode: enabled);

    try {
      final ref = _db.ref('bot_controls/${state.botId}');
      await ref.update({
        'mode': enabled ? 'manual' : 'auto',
        'updatedAt': ServerValue.timestamp,
      });

      if (!enabled) {
        await ref.update({
          'dx': 0.0,
          'dy': 0.0,
        });
      }
    } catch (_) {}
  }

  // Send joystick command (normalized dx, dy in [-1, 1])
  Future<void> sendJoystickCommand(double dx, double dy) async {
    if (!state.isManualMode) return;

    try {
      final ref = _db.ref('bot_controls/${state.botId}');
      await ref.update({
        'mode': 'manual',
        'dx': dx,
        'dy': dy,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  // Disconnect from bot
  Future<void> disconnect() async {
    await releaseControl();
    state = state.copyWith(
      connectionStatus: ConnectionStatus.disconnected,
      isManualMode: false,
      availableDevices: [],
    );
  }

  // Simulate checking if another user is controlling
  Future<void> checkControlStatus() async {
    // In real implementation, listen to Firebase changes
    // For now, randomly simulate another user controlling after 10 seconds
    await Future.delayed(const Duration(seconds: 10));
    
    // Uncomment to test the alert
    // state = state.copyWith(
    //   currentController: 'other_user',
    //   currentControllerName: 'John Doe',
    // );
  }

  // Handle connection errors
  void setError(String error) {
    state = state.copyWith(
      connectionStatus: ConnectionStatus.error,
      errorMessage: error,
    );
  }

  // Helper method to set available devices (for simulation)
  void setAvailableDevices(List<BluetoothDevice> devices) {
    state = state.copyWith(availableDevices: devices);
  }

  // Helper method to set connection status directly (for simulation)
  void setConnectionStatus(ConnectionStatus status) {
    state = state.copyWith(connectionStatus: status);
  }
}
