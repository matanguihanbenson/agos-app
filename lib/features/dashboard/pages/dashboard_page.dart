import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/activity_log_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/realtime_clock_service.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/activity_log_formatter.dart';
import '../../../core/widgets/storm_alert_widget.dart';
import '../providers/dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> with WidgetsBindingObserver {
  StreamSubscription<DateTime>? _clockSubscription;
  DateTime _currentTime = DateTime.now();
  String _currentLocation = 'Getting location...';
  bool _isLoadingLocation = true;
  bool _locationPermissionGranted = false;
  bool _showAllQuickActions = false;
  Timer? _statsRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeRealtimeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockSubscription?.cancel();
    _statsRefreshTimer?.cancel();
    RealtimeClockService.stopClock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permission and update location when returning from Settings
      _getCurrentLocation();
    }
    super.didChangeAppLifecycleState(state);
  }

  void _initializeRealtimeData() {
    // Start real-time clock
    RealtimeClockService.startClock();
    _clockSubscription = RealtimeClockService.clockStream.listen((time) {
      if (mounted) {
        setState(() {
          _currentTime = time;
        });
      }
    });

    // Get current location
    _getCurrentLocation();
  }

  void _initializeStatsAutoRefresh() {
    // Debounced refresh: when live deployments change, refresh
    // dashboard overview stats after a short delay. This keeps
    // "Trash Today" close to real-time without constant polling.
    ref.listen(activeDeploymentsStreamProvider, (previous, next) {
      if (!mounted) return;
      if (!next.hasValue) return;

      // Debounce: wait a few seconds after a change before recomputing
      _statsRefreshTimer?.cancel();
      _statsRefreshTimer = Timer(const Duration(seconds: 6), () {
        if (!mounted) return;
        ref.refresh(dashboardStatsProvider);
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // First check if location services are enabled
      final serviceEnabled = await LocationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _currentLocation = 'Location services disabled';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // Check current permission status
      LocationPermission permission = await LocationService.checkPermission();
      
      // If permission is denied, request it (this will show the system dialog)
      if (permission == LocationPermission.denied) {
        permission = await LocationService.requestPermission();
        
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationPermissionGranted = false;
              _currentLocation = 'Location permission denied';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      // Check if permission is permanently denied
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _currentLocation = 'Tap Enable to allow location';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // At this point, we should have permission (whileInUse or always)
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = true;
          });
        }

        // Get current position
        final position = await LocationService.getCurrentPosition();
        
        if (position != null) {
          // Get reverse geocoded address
          final address = await ReverseGeocodingService.getShortAddressFromCoordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          
          if (mounted) {
            setState(() {
              _currentLocation = address ?? 'Location unavailable';
              _isLoadingLocation = false;
              _locationPermissionGranted = true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentLocation = 'Unable to get location';
              _isLoadingLocation = false;
            });
          }
        }
      } else {
        // Permission not granted
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _currentLocation = 'Location permission required';
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = 'Location error';
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set up debounced stats refresh based on live deployments.
    _initializeStatsAutoRefresh();

    final authState = ref.watch(authProvider);
    final isAdmin = authState.userProfile?.isAdmin ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weather Card
          _buildWeatherCard(),
          const SizedBox(height: 20),

          // Storm Alert Widget
          const StormAlertWidget(),
          const SizedBox(height: 20),
          
          // Quick Actions Section
          _buildQuickActionsSection(isAdmin),
          const SizedBox(height: 20),
          
          // Summary Cards Section (Overview)
          _buildSummaryCardsSection(),
          const SizedBox(height: 20),
          
          // Live River Deployment Data
          _buildLiveRiverData(),
          const SizedBox(height: 20),
          
          // Recent Activity Section
          _buildRecentActivitySection(),
        ],
      ),
    );
  }

  Widget _buildLiveRiverData() {
    final activeDeploymentsAsync = ref.watch(activeDeploymentsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.water, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Live River Deployments',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        activeDeploymentsAsync.when(
          data: (deployments) {
            if (deployments.isEmpty) {
              return Container(
                height: 200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.water_drop_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No active deployments',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return SizedBox(
              height: 240,
              child: PageView.builder(
                itemCount: deployments.length,
                padEnds: false,
                controller: PageController(viewportFraction: 0.92),
                itemBuilder: (context, index) {
                  final deployment = deployments[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildRiverCardFromDeployment(deployment),
                  );
                },
              ),
            );
          },
          loading: () => Container(
            height: 240,
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, stack) => Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Error loading deployments',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiverCardFromDeployment(deployment) {
    final riverName = deployment.riverName;
    final location = deployment.operationLocation ?? 'Location unavailable';
    final botStatus = deployment.status ?? 'idle';
    final temperature = deployment.temperature ?? 0.0;
    final ph = deployment.phLevel ?? 0.0;
    final turbidity = deployment.turbidity ?? 0.0;
    final trashToday = deployment.riverTotalToday ?? 0.0; // Use river's total today instead of bot's trash collected
    final currentLoad = deployment.currentLoad ?? 0.0;
    final maxLoad = deployment.maxLoad ?? 10.0;
    final batteryLevel = deployment.battery ?? 0;
    final loadPercentage = (currentLoad / maxLoad * 100).clamp(0, 100);

    Color statusColor = AppColors.textSecondary;
    String statusText = 'Idle';
    IconData statusIcon = Icons.pause_circle;

    switch (botStatus.toLowerCase()) {
      case 'active':
      case 'deployed':
        statusColor = AppColors.success;
        statusText = 'Active';
        statusIcon = Icons.play_circle;
        break;
      case 'returning':
      case 'recalling':
        statusColor = AppColors.warning;
        statusText = 'Returning';
        statusIcon = Icons.home;
        break;
      case 'charging':
        statusColor = AppColors.info;
        statusText = 'Charging';
        statusIcon = Icons.battery_charging_full;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // River Info Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.water, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riverName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Real-time Sensor Data
          Row(
            children: [
              Expanded(
                child: _buildSensorMini(
                  icon: Icons.thermostat,
                  label: 'Temp',
                  value: '${temperature.toStringAsFixed(1)}°C',
                  color: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorMini(
                  icon: Icons.water_drop,
                  label: 'pH',
                  value: ph.toStringAsFixed(1),
                  color: const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorMini(
                  icon: Icons.remove_red_eye,
                  label: 'Turbidity',
                  value: '${turbidity.toStringAsFixed(1)} NTU',
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Trash Collection Data
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Today',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${trashToday.toStringAsFixed(1)} kg',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.border,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Load',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currentLoad.toStringAsFixed(1),
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: loadPercentage >= 90
                                    ? AppColors.error
                                    : loadPercentage >= 70
                                        ? AppColors.warning
                                        : AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              ' / ${maxLoad.toStringAsFixed(0)} kg',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (deployment.solarCharging == true || batteryLevel <= 15)
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (deployment.solarCharging == true || batteryLevel <= 15)
                                ? Icons.battery_charging_full
                                : (batteryLevel > 80
                                    ? Icons.battery_full
                                    : batteryLevel > 50
                                        ? Icons.battery_5_bar
                                        : batteryLevel > 20
                                            ? Icons.battery_3_bar
                                            : Icons.battery_1_bar),
                            size: 16,
                            color: (deployment.solarCharging == true || batteryLevel <= 15)
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$batteryLevel%',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: (deployment.solarCharging == true || batteryLevel <= 15)
                                      ? AppColors.warning
                                      : AppColors.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              if (deployment.solarCharging == true || batteryLevel <= 15)
                                Text(
                                  'Solar',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 8,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Load Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: loadPercentage / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.border.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      loadPercentage >= 90
                          ? AppColors.error
                          : loadPercentage >= 70
                              ? AppColors.warning
                              : AppColors.success,
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

  // Keep the old method for backward compatibility if needed
  Widget _buildRiverCard(Map<String, dynamic> deployment) {
    final riverName = deployment['riverName'] ?? 'Unknown River';
    final location = deployment['location'] ?? '';
    final botStatus = deployment['botStatus'] ?? 'idle';
    final temperature = deployment['temperature'] ?? 0.0;
    final ph = deployment['ph'] ?? 0.0;
    final turbidity = deployment['turbidity'] ?? 0.0;
    final trashToday = deployment['trashToday'] ?? 0.0;
    final currentLoad = deployment['currentLoad'] ?? 0.0;
    final maxLoad = deployment['maxLoad'] ?? 10.0;
    final batteryLevel = deployment['batteryLevel'] ?? 0;
    final loadPercentage = (currentLoad / maxLoad * 100).clamp(0, 100);

    Color statusColor = AppColors.textSecondary;
    String statusText = 'Idle';
    IconData statusIcon = Icons.pause_circle;

    switch (botStatus) {
      case 'active':
        statusColor = AppColors.success;
        statusText = 'Active';
        statusIcon = Icons.play_circle;
        break;
      case 'returning':
        statusColor = AppColors.warning;
        statusText = 'Returning';
        statusIcon = Icons.home;
        break;
      case 'charging':
        statusColor = AppColors.info;
        statusText = 'Charging';
        statusIcon = Icons.battery_charging_full;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // River Info Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.water, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riverName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Real-time Sensor Data
          Row(
            children: [
              Expanded(
                child: _buildSensorMini(
                  icon: Icons.thermostat,
                  label: 'Temp',
                  value: '${temperature.toStringAsFixed(1)}°C',
                  color: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorMini(
                  icon: Icons.water_drop,
                  label: 'pH',
                  value: ph.toStringAsFixed(1),
                  color: const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSensorMini(
                  icon: Icons.remove_red_eye,
                  label: 'Turbidity',
                  value: '${turbidity.toStringAsFixed(1)} NTU',
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Trash Collection Data
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Today',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${trashToday.toStringAsFixed(1)} kg',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.border,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Load',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currentLoad.toStringAsFixed(1),
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: loadPercentage >= 90
                                    ? AppColors.error
                                    : loadPercentage >= 70
                                        ? AppColors.warning
                                        : AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              ' / ${maxLoad.toStringAsFixed(0)} kg',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: batteryLevel > 20
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            batteryLevel > 80
                                ? Icons.battery_full
                                : batteryLevel > 50
                                    ? Icons.battery_5_bar
                                    : batteryLevel > 20
                                        ? Icons.battery_3_bar
                                        : Icons.battery_1_bar,
                            size: 16,
                            color: batteryLevel > 20 ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$batteryLevel%',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: batteryLevel > 20 ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Load Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: loadPercentage / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.border.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      loadPercentage >= 90
                          ? AppColors.error
                          : loadPercentage >= 70
                              ? AppColors.warning
                              : AppColors.success,
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

  Widget _buildSensorMini({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsSection() {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Overview',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Live Data',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        statsAsync.when(
          data: (stats) => SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSummaryCard(
                  title: 'Total Bots',
                  value: '${stats.totalBots}',
                  icon: Icons.directions_boat,
                  color: Colors.blue,
                  trend: '',
                  subtitle: 'Registered',
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  title: 'Active Bots',
                  value: '${stats.activeBots}',
                  icon: Icons.play_circle,
                  color: Colors.green,
                  trend: '',
                  subtitle: 'Currently active',
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  title: 'Trash Today',
                  value: '${stats.totalTrashToday.toStringAsFixed(1)}kg',
                  icon: Icons.eco,
                  color: Colors.teal,
                  trend: '',
                  subtitle: 'Collected',
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  title: 'Rivers',
                  value: '${stats.uniqueRiversToday}',
                  icon: Icons.water,
                  color: Colors.cyan,
                  trend: '${stats.riversMonitoredToday}',
                  subtitle: '${stats.uniqueRiversToday} unique (${stats.riversMonitoredToday} total)',
                ),
              ],
            ),
          ),
          loading: () => SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (error, stack) => SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Error loading stats',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required String subtitle,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trend,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    final weatherCondition = RealtimeClockService.getWeatherCondition(_currentTime);
    final temperature = RealtimeClockService.getTemperature(_currentTime);
    final dailyRange = RealtimeClockService.getDailyTemperatureRange(_currentTime);
    final weatherIcon = RealtimeClockService.getWeatherIcon(weatherCondition);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0066CC), // Deep ocean blue
            Color(0xFF4DA6FF), // Light ocean blue
            Color(0xFF87CEEB), // Darker sky blue for better contrast
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066CC).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with weather icon and time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  weatherIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weatherCondition,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Current Weather',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    RealtimeClockService.formatTime(_currentTime),
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    RealtimeClockService.formatDate(_currentTime),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Temperature and details
          Row(
            children: [
              // Main temperature
              Text(
                '$temperature°',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 48,
                ),
              ),
              const SizedBox(width: 16),
              
              // Temperature range
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dailyRange['high']}°/${dailyRange['low']}°',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'High/Low',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Location
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _isLoadingLocation 
                        ? 'Getting location...' 
                        : _currentLocation,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Current Location',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Location permission button if needed
          if (!_locationPermissionGranted && !_isLoadingLocation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location permission required for current location',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final permission = await LocationService.checkPermission();
                      if (permission == LocationPermission.deniedForever) {
                        // Open app settings if permanently denied
                        await LocationService.openAppSettings();
                      } else {
                        // Request permission again
                        await _getCurrentLocation();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      'Enable',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // 4-day forecast
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildForecastDay('TUE', Icons.wb_sunny, '32°'),
                  _buildForecastDay('WED', Icons.wb_cloudy, '28°'),
                  _buildForecastDay('THU', Icons.wb_sunny, '31°'),
                  _buildForecastDay('FRI', Icons.wb_sunny, '29°'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForecastDay(String day, IconData icon, String temp) {
    return Column(
      children: [
        Text(
          day,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          temp,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(bool isAdmin) {
    final actions = isAdmin ? _getAdminActions() : _getFieldOperatorActions();
    final displayedActions = _showAllQuickActions ? actions : actions.take(4).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Actions Header with See More button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showAllQuickActions = !_showAllQuickActions;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showAllQuickActions ? 'See Less' : 'See More',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showAllQuickActions ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Quick Actions Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.1,
          ),
          itemCount: displayedActions.length,
          itemBuilder: (context, index) {
            final action = displayedActions[index];
            return _buildQuickActionCard(action);
          },
        ),
      ],
    );
  }

  List<QuickAction> _getAdminActions() {
    return [
      QuickAction(
        icon: Icons.videocam,
        label: 'Live Feed',
        onTap: () {
          // Navigate to live map/monitoring of bots
          Navigator.pushNamed(context, AppRoutes.map);
        },
      ),
      QuickAction(
        icon: Icons.emergency,
        label: 'Emergency Recall',
        onTap: () {
          // Open Control page where recall can be triggered
          Navigator.pushNamed(context, AppRoutes.control);
        },
      ),
      QuickAction(
        icon: Icons.person_add,
        label: 'Add User',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.addUser);
        },
      ),
      QuickAction(
        icon: Icons.gamepad,
        label: 'Control',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.control);
        },
      ),
      QuickAction(
        icon: Icons.eco,
        label: 'Impact',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.monitoring);
        },
      ),
      QuickAction(
        icon: Icons.business,
        label: 'Add Org',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.addOrganization);
        },
      ),
      QuickAction(
        icon: Icons.assignment,
        label: 'Logs',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.activityLogs);
        },
      ),
      QuickAction(
        icon: Icons.settings,
        label: 'Settings',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.settings);
        },
      ),
    ];
  }

  List<QuickAction> _getFieldOperatorActions() {
    return [
      QuickAction(
        icon: Icons.videocam,
        label: 'Live Feed',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.map);
        },
      ),
      QuickAction(
        icon: Icons.emergency,
        label: 'Emergency Recall',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.control);
        },
      ),
      QuickAction(
        icon: Icons.schedule,
        label: 'Create Schedule',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.createSchedule);
        },
      ),
      QuickAction(
        icon: Icons.gamepad,
        label: 'Control',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.control);
        },
      ),
      QuickAction(
        icon: Icons.eco,
        label: 'Impact',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.monitoring);
        },
      ),
      QuickAction(
        icon: Icons.work,
        label: 'Field Tasks',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.schedule);
        },
      ),
      QuickAction(
        icon: Icons.assignment,
        label: 'Logs',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.activityLogs);
        },
      ),
      QuickAction(
        icon: Icons.settings,
        label: 'Settings',
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.settings);
        },
      ),
    ];
  }

  Widget _buildQuickActionCard(QuickAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(height: 3),
            Text(
              action.label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 8,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final recentLogsAsync = ref.watch(recentActivityLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Recent Activity',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.activityLogs);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: AppColors.primary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recentLogsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No recent activity',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show max 4 recent activities
            final displayLogs = logs.take(4).toList();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayLogs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = displayLogs[index];
                final iconData = ActivityLogFormatter.getIconForLogType(log.type);
                final iconColor = ActivityLogFormatter.getColorForSeverity(log.severity);
                final relativeTime = ActivityLogFormatter.getRelativeTime(log.timestamp);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          iconData,
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (log.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                log.description,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        relativeTime,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (error, stack) => Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Error loading activity',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
