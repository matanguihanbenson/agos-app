import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../models/bot_control_state.dart';
import '../providers/bot_control_provider.dart';
import '../widgets/draggable_joystick.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/control_lock_service.dart';

class BotControlPage extends ConsumerStatefulWidget {
  final String botId;
  final String botName;

  const BotControlPage({
    super.key,
    required this.botId,
    required this.botName,
  });

  @override
  ConsumerState<BotControlPage> createState() => _BotControlPageState();
}

class _BotControlPageState extends ConsumerState<BotControlPage> {
  ControlLockHandle? _lockHandle;
  StreamSubscription<Map<String, dynamic>?>? _lockSub;
  String? _currentControllerName;
  Map<String, dynamic>? _takeover;
  int _takeoverRemaining = 0;
  Timer? _takeoverTimer;
  bool _takeoverDialogShown = false;
  
  // Simulation mode flag - set to true to bypass real Bluetooth
  static const bool _simulationMode = true;

  @override
  void initState() {
    super.initState();
    // Start connection process automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWatchLock();
      _initiateConnection();
    });
  }

  void _startWatchLock() {
    final lockService = ControlLockService();
    _lockSub?.cancel();
    _lockSub = lockService.watchLock(widget.botId).listen((data) {
      if (!mounted) return;
      final oldTakeover = _takeover;
      setState(() {
        _currentControllerName = data != null ? (data['name'] as String?) : null;
        _takeover = data != null ? (data['takeover'] as Map?)?.cast<String, dynamic>() : null;
      });
      
      // Check if takeover just started
      if (_takeover != null && oldTakeover == null) {
        _startTakeoverCountdown();
        _showTakeoverNotification();
      } else if (_takeover == null && oldTakeover != null) {
        _stopTakeoverCountdown();
        _takeoverDialogShown = false;
      }
    });
  }

  void _startTakeoverCountdown() {
    _takeoverTimer?.cancel();
    _updateTakeoverCountdown();
    
    _takeoverTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateTakeoverCountdown();
      if (_takeoverRemaining <= 0) {
        timer.cancel();
      }
    });
  }

  void _stopTakeoverCountdown() {
    _takeoverTimer?.cancel();
    _takeoverTimer = null;
    setState(() {
      _takeoverRemaining = 0;
    });
  }

  void _updateTakeoverCountdown() {
    if (_takeover == null) {
      setState(() {
        _takeoverRemaining = 0;
      });
      return;
    }
    final executeAt = (_takeover!['executeAt'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remMs = executeAt - now;
    setState(() {
      _takeoverRemaining = remMs > 0 ? (remMs / 1000).ceil() : 0;
    });
  }

  void _showTakeoverNotification() {
    if (_takeoverDialogShown) return;
    if (_takeover == null) return;
    
    final requestedByName = _takeover!['requestedByName'] as String? ?? 'An administrator';
    _takeoverDialogShown = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Takeover Request',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$requestedByName has requested to take control of this bot.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Control will be transferred in approximately $_takeoverRemaining seconds.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can surrender control now or wait for automatic transfer.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Wait', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _releaseLockAndCleanup();
              if (mounted && context.mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Surrender Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateConnection() async {
    final notifier = ref.read(botControlProvider(widget.botId).notifier);

    // Resolve current user details
    final authState = ref.read(authProvider);
    final profile = authState.userProfile;
    final uid = profile?.id;
    final displayName = profile != null ? '${profile.firstName} ${profile.lastName}'.trim() : 'Unknown User';
    final role = profile?.role ?? 'user';

    // Try to claim control lock via RTDB
    if (uid == null) {
      _showControllerConflictDialog(currentControllerName: 'Unknown');
      return;
    }

    final lockService = ControlLockService();
    final sessionId = uid; // reuse uid or later integrate with presence session id
    final handle = await lockService.claimLock(
      botId: widget.botId,
      uid: uid,
      sessionId: sessionId,
      displayName: displayName,
      role: role,
    );

    if (handle == null) {
      // Someone else is controlling
      final current = await lockService.getCurrentLock(widget.botId);
      final name = current != null ? (current['name'] as String? ?? 'Another user') : 'Another user';
      _showControllerConflictDialog(currentControllerName: name);
      return;
    }

    _lockHandle = handle;

    if (_simulationMode) {
      // Simulation mode: fake Bluetooth connection
      await _simulateBluetoothConnection(notifier);
    } else {
      // Real mode: Start Bluetooth scanning
      await notifier.startBluetoothScan();

      // Auto-connect to the first device (Benson Bot)
      final state = ref.read(botControlProvider(widget.botId));
      if (state.availableDevices.isNotEmpty && mounted) {
        await notifier.connectToBluetooth(state.availableDevices.first.id);
      }
    }
  }

  Future<void> _simulateBluetoothConnection(dynamic notifier) async {
    // Simulate scanning delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Simulate setting connection to connected state
    // Since we don't have direct access to the notifier's internal state setter,
    // we'll just wait and let the UI show the connected state
    // In a real implementation, you'd need to modify the provider to support simulation mode
    
    // For now, trigger a fake scan that immediately succeeds
    try {
      await notifier.startBluetoothScan();
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Simulate successful connection by calling connectToBluetooth with a fake device
      // The provider should handle this gracefully in simulation mode
      await notifier.connectToBluetooth('simulated-device-${widget.botId}');
    } catch (e) {
      // If the provider doesn't support simulation, just log and continue
      // The UI will show disconnected state, but at least won't crash
      print('Simulation mode: Bluetooth provider does not support fake connections');
    }
  }

  void _showControllerConflictDialog({String currentControllerName = 'Another user'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            const SizedBox(width: 12),
            Text('Bot In Use', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This bot is currently being controlled by another user.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Controller',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
currentControllerName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait until the bot is available or contact the current controller.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: Text('Go Back', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if ((ref.read(authProvider).userProfile?.isAdmin ?? false))
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _requestTakeover(currentControllerName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Request Takeover'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initiateConnection(); // Retry connection
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Stop takeover timer
    _takeoverTimer?.cancel();
    // Release lock and cleanup
    _releaseLockAndCleanup();
    super.dispose();
  }

  Future<void> _releaseLockAndCleanup() async {
    try {
      // Disconnect from bot control
      await ref.read(botControlProvider(widget.botId).notifier).disconnect();
    } catch (e) {
      print('Error disconnecting bot control: $e');
    }

    try {
      // Release the control lock
      await _lockHandle?.release();
      _lockHandle = null;
    } catch (e) {
      print('Error releasing lock: $e');
    }

    try {
      // Cancel lock subscription
      await _lockSub?.cancel();
      _lockSub = null;
    } catch (e) {
      print('Error canceling lock subscription: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlState = ref.watch(botControlProvider(widget.botId));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Cleanup already happened in dispose
          return;
        }
        // Release control when back is pressed
        await _releaseLockAndCleanup();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () async {
              // Release control when leaving
              await _releaseLockAndCleanup();
              if (mounted && context.mounted) Navigator.of(context).pop();
            },
          ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_boat, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              widget.botName,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_currentControllerName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Currently controlled by: ${_currentControllerName!}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          if (_takeover != null && _takeoverRemaining > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_takeover!['requestedByName']} will take control in $_takeoverRemaining s',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody(controlState)),
        ],
      ),
      ),
    );
  }

  Future<void> _requestTakeover(String currentControllerName) async {
    final profile = ref.read(authProvider).userProfile;
    if (!(profile?.isAdmin ?? false)) return;
    final lockService = ControlLockService();
    await lockService.requestTakeover(
      botId: widget.botId,
      requestedByUid: profile!.id,
      requestedByName: '${profile.firstName} ${profile.lastName}'.trim(),
      requestedByRole: profile.role,
      graceSeconds: 10,
    );

    // Show countdown dialog
    if (!mounted) return;
    int remaining = 10;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future.delayed(const Duration(seconds: 1), () async {
            if (!mounted || !Navigator.of(context).canPop()) return;
            setState(() {
              remaining = remaining - 1;
            });
            if (remaining <= 0) {
              // Try to claim with override
              Navigator.of(context).pop();
              final handle = await lockService.claimLock(
                botId: widget.botId,
                uid: profile.id,
                sessionId: profile.id,
                displayName: '${profile.firstName} ${profile.lastName}'.trim(),
                role: profile.role,
              );
              if (handle != null) {
                setState(() {
                  _lockHandle = handle;
                });
                _initiateConnection();
              } else {
                _showSnackBar('Takeover failed: bot still in use', isError: true);
              }
            }
          });
          return AlertDialog(
            title: Text('Takeover Scheduled', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600)),
            content: Text('Informing $currentControllerName... Taking control in $remaining seconds.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Dismiss'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildBody(BotControlState state) {
    if (state.connectionStatus == ConnectionStatus.scanning ||
        state.connectionStatus == ConnectionStatus.connecting) {
      return _buildConnectingView(state);
    } else if (state.connectionStatus == ConnectionStatus.connected) {
      return _buildControlView(state);
    } else if (state.connectionStatus == ConnectionStatus.error) {
      return _buildErrorView(state);
    } else {
      return _buildDisconnectedView(state);
    }
  }

  Widget _buildConnectingView(BotControlState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatusRow(
                  icon: Icons.storage,
                  label: 'Database',
                  status: 'Offline',
                  statusColor: AppColors.error,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  status: state.connectionStatus == ConnectionStatus.scanning
                      ? 'Disconnected'
                      : 'Connected',
                  statusColor: state.connectionStatus == ConnectionStatus.scanning
                      ? AppColors.error
                      : AppColors.success,
                ),
                if (state.connectionStatus == ConnectionStatus.connecting)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bluetooth required for control (works offline)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Scanning Animation
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Animated scanning icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: Icon(
                            state.connectionStatus == ConnectionStatus.scanning
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth_connected,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    setState(() {}); // Loop animation
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  state.connectionStatus == ConnectionStatus.scanning
                      ? 'Scanning for Bot'
                      : 'Connecting to Bot',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.connectionStatus == ConnectionStatus.scanning
                      ? 'Scanning for bot devices...'
                      : 'Establishing connection...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.border.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                if (state.connectionStatus == ConnectionStatus.connecting)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Scanning for nearby bot devices...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Automatic Mode Toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sync, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatic Mode',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Bot operates automatically',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: !state.isManualMode,
                  onChanged: null, // Disabled during connection
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // Navigation Control (disabled)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.navigation, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Navigation Control',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: 0.3,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(
                          Icons.directions_boat,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlView(BotControlState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatusRow(
                  icon: Icons.storage,
                  label: 'Database',
                  status: 'Offline',
                  statusColor: AppColors.error,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  status: 'Connected',
                  statusColor: AppColors.success,
                  trailing: Row(
                    children: [
                      Icon(Icons.power, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Battery 75',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Manual Control Toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    state.isManualMode ? Icons.gamepad : Icons.sync,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Control',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        state.isManualMode
                            ? 'You can control the bot'
                            : 'Bot operates automatically',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.isManualMode,
                  onChanged: (value) {
                    ref.read(botControlProvider(widget.botId).notifier).toggleManualMode(value);
                  },
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // Navigation Control
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.navigation, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Navigation Control',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Joystick Control
                DraggableJoystick(
                  enabled: state.isManualMode,
                  size: 220,
                  innerSize: 90,
                  onPositionChanged: (dx, dy) {
                    // Handle joystick movement
                    // dx and dy are normalized values between -1 and 1
                    // Implement actual bot control here
                    // Example:
                    // print('Joystick position: dx=$dx, dy=$dy');
                    // BluetoothService.sendNavigationCommand(
                    //   botId: widget.botId,
                    //   dx: dx,
                    //   dy: dy,
                    // );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  state.isManualMode
                      ? 'Drag to navigate the bot'
                      : 'Enable manual mode to control',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Connection Status Footer
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bluetooth_connected, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Switched to Manual Mode (Bluetooth)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BotControlState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'Unable to connect to the bot',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initiateConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedView(BotControlState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Disconnected',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to the bot to start controlling',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initiateConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Connect to Bot'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String status,
    required Color statusColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (trailing != null) ...[
          trailing,
          const SizedBox(width: 12),
        ],
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: AppTextStyles.bodySmall.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
