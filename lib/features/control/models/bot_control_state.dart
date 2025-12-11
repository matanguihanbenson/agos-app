class BotControlState {
  final String botId;
  final String botName;
  final ConnectionStatus connectionStatus;
  final bool isManualMode;
  final String? currentController;
  final String? currentControllerName;
  final bool isScanning;
  final List<BluetoothDevice> availableDevices;
  final String? errorMessage;

  const BotControlState({
    required this.botId,
    required this.botName,
    this.connectionStatus = ConnectionStatus.disconnected,
    this.isManualMode = false,
    this.currentController,
    this.currentControllerName,
    this.isScanning = false,
    this.availableDevices = const [],
    this.errorMessage,
  });

  BotControlState copyWith({
    String? botId,
    String? botName,
    ConnectionStatus? connectionStatus,
    bool? isManualMode,
    String? currentController,
    String? currentControllerName,
    bool? isScanning,
    List<BluetoothDevice>? availableDevices,
    String? errorMessage,
  }) {
    return BotControlState(
      botId: botId ?? this.botId,
      botName: botName ?? this.botName,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isManualMode: isManualMode ?? this.isManualMode,
      currentController: currentController ?? this.currentController,
      currentControllerName: currentControllerName ?? this.currentControllerName,
      isScanning: isScanning ?? this.isScanning,
      availableDevices: availableDevices ?? this.availableDevices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  bool get isConnecting => connectionStatus == ConnectionStatus.connecting;
  bool get isControlledByMe => currentController != null && currentController == 'current_user'; // Replace with actual user ID
  bool get isControlledByOther => currentController != null && !isControlledByMe;
}

enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class BluetoothDevice {
  final String id;
  final String name;
  final int signalStrength;

  const BluetoothDevice({
    required this.id,
    required this.name,
    required this.signalStrength,
  });
}
