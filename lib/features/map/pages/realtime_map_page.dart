import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/routes/app_routes.dart';

class RealtimeMapPage extends ConsumerStatefulWidget {
  const RealtimeMapPage({super.key});

  @override
  ConsumerState<RealtimeMapPage> createState() => _RealtimeMapPageState();
}

class _RealtimeMapPageState extends ConsumerState<RealtimeMapPage> {
  final MapController _mapController = MapController();
  
  List<BotModel> _activeBots = [];
  List<WasteDetection> _wasteDetections = [];
  bool _isLoading = true;
  String? _error;
  String _mapView = 'bots'; // 'bots' or 'waste'
  StreamSubscription<DatabaseEvent>? _wasteSubscription;
  Map<String, dynamic>? _botsCache;

  @override
  void initState() {
    super.initState();
    _startRealtimeTracking();
    _subscribeWasteDetections();
  }

  @override
  void dispose() {
    _wasteSubscription?.cancel();
    super.dispose();
  }

  void _startRealtimeTracking() {
    ref.read(botProvider.notifier).startRealtimeTracking();
  }

  void _showActiveBotsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_boat,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Bots (${_activeBots.length})',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Bot list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _activeBots.length,
                itemBuilder: (context, index) {
                  final bot = _activeBots[index];
                  return _buildBotListItem(bot);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotListItem(BotModel bot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(bot.status ?? 'idle'),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_boat,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          bot.name,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'ID: ${bot.id}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bot.isOnline ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                bot.isOnline ? 'Online' : 'Offline',
                style: AppTextStyles.bodySmall.copyWith(
                  color: bot.isOnline ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.navigation,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          _navigateToBot(bot);
        },
      ),
    );
  }

  /// Status colors matching app standard:
  /// Deployed (green), Idle (orange), Maintenance (blue), Recalling (yellow), Scheduled (light blue)
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'deployed':
      case 'active':
        return Colors.green; // Deployed
      case 'idle':
        return Colors.orange; // Idle  
      case 'maintenance':
        return Colors.blue; // Maintenance
      case 'recalling':
        return Colors.yellow; // Recalling
      case 'scheduled':
        return Colors.lightBlue; // Scheduled
      default:
        return Colors.grey;
    }
  }

  void _navigateToBot(BotModel bot) {
    if (bot.lat != null && bot.lng != null) {
      _mapController.move(
        LatLng(bot.lat!, bot.lng!),
        16.0, // Higher zoom level
      );
    }
  }

  void _recenterToNearestBot() {
    if (_activeBots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active bots found'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Find the nearest bot to current map center
    final currentCenter = _mapController.camera.center;
    BotModel? nearestBot;
    double minDistance = double.infinity;

    for (final bot in _activeBots) {
      if (bot.lat != null && bot.lng != null) {
        final botLocation = LatLng(bot.lat!, bot.lng!);
        final distance = const Distance().as(LengthUnit.Meter, currentCenter, botLocation);
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestBot = bot;
        }
      }
    }

    if (nearestBot != null && nearestBot.lat != null && nearestBot.lng != null) {
      _mapController.move(
        LatLng(nearestBot.lat!, nearestBot.lng!),
        16.0,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recentered to ${nearestBot.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onBotTap(BotModel bot) async {
    if (bot.lat != null && bot.lng != null) {
      // Get reverse geocoded address
      final address = await ReverseGeocodingService.getAddressFromCoordinates(
        latitude: bot.lat!,
        longitude: bot.lng!,
      );
      
      if (mounted) {
        // Show bot details
        _showBotDetails(bot, address);
      }
    }
  }

  void _showBotDetails(BotModel bot, String? address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Bot details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.directions_boat,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bot.name,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'ID: ${bot.id}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: bot.isOnline ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          bot.isOnline ? 'Online' : 'Offline',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: bot.isOnline ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Location details
                  if (address != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Coordinates
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        color: AppColors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${bot.lat!.toStringAsFixed(6)}, ${bot.lng!.toStringAsFixed(6)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  
                  if (bot.batteryLevel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.battery_std,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Battery: ${bot.batteryLevel!.toStringAsFixed(0)}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Navigate to bot control
                          },
                          icon: const Icon(Icons.settings_remote, size: 16),
                          label: const Text('Control'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Navigate to live feed
                          },
                          icon: const Icon(Icons.videocam, size: 16),
                          label: const Text('Live Feed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final botsAsync = ref.watch(botsStreamProvider);
    
    return botsAsync.when(
      data: (bots) {
        // Update active bots from the stream
        _activeBots = bots.where((bot) => 
            ((bot.active == true) || ((bot.status ?? '').toLowerCase() == 'recalling')) &&
            bot.lat != null && bot.lng != null).toList();
        _isLoading = false;
        _error = null;
        
        return _buildMapScaffold();
      },
      loading: () {
        _isLoading = true;
        return _buildMapScaffold();
      },
      error: (error, stack) {
        _error = error.toString();
        _isLoading = false;
        return _buildMapScaffold();
      },
    );
  }

  Widget _buildMapScaffold() {

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(14.5995, 120.9842), // Manila, Philippines
              initialZoom: 10.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agos.app',
                maxZoom: 18,
              ),
              
              // Bot markers
              MarkerLayer(
                markers: _mapView == 'bots' 
                    ? _activeBots.map((bot) {
                        if (bot.lat == null || bot.lng == null) return null;
                        
                        return Marker(
                          point: LatLng(bot.lat!, bot.lng!),
                          width: 100.0,
                          height: 100.0,
                          child: GestureDetector(
                            onTap: () => _onBotTap(bot),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Status color indicator
                                Container(
                                  width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(bot.status ?? 'idle'),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Bot icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: bot.isOnline ? AppColors.primary : AppColors.textMuted,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_boat,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Bot name label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              bot.name,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                          );
                        }).where((marker) => marker != null).cast<Marker>().toList()
                    : _wasteDetections.map((detection) {
                        return Marker(
                          point: LatLng(detection.latitude, detection.longitude),
                          width: 50.0,
                          height: 50.0,
                          child: GestureDetector(
                            onTap: () => _onWasteTap(detection),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _getWasteColor(detection.type),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
              ),
            ],
          ),
          
          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Error message
          if (_error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading map data',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _startRealtimeTracking();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Bot count indicator
          if (!_isLoading && _error == null)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _showActiveBotsList,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_boat,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_activeBots.length} active bots',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // View toggle button (Bots / Waste)
          if (!_isLoading && _error == null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggleButton(
                      icon: Icons.directions_boat,
                      label: 'Bots',
                      isSelected: _mapView == 'bots',
                      onTap: () {
                        setState(() => _mapView = 'bots');
                      },
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.border,
                    ),
                    _buildViewToggleButton(
                      icon: Icons.delete_outline,
                      label: 'Waste',
                      isSelected: _mapView == 'waste',
                      onTap: () {
                        setState(() => _mapView = 'waste');
                        _loadWasteDetections();
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Zoom controls and recenter button
          if (!_isLoading && _error == null)
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  // Recenter button
                  FloatingActionButton.small(
                    onPressed: _recenterToNearestBot,
                    heroTag: 'recenter',
                    backgroundColor: AppColors.primary,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zoom in
                  FloatingActionButton.small(
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                    heroTag: 'zoom_in',
                    child: const Icon(Icons.zoom_in),
                  ),
                  const SizedBox(height: 8),
                  // Zoom out
                  FloatingActionButton.small(
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                    heroTag: 'zoom_out',
                    child: const Icon(Icons.zoom_out),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getWasteColor(String type) {
    final colors = {
      'plastic': Colors.orange,
      'metal': Colors.grey,
      'paper': Colors.brown,
      'glass': Colors.cyan,
      'organic': Colors.green,
      'fabric': Colors.purple,
      'rubber': Colors.black87,
      'electronic': Colors.red,
    };
    return colors[type.toLowerCase()] ?? Colors.blueGrey;
  }

  void _onWasteTap(WasteDetection detection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getWasteColor(detection.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: _getWasteColor(detection.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waste Detection',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        detection.type.toUpperCase(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _getWasteColor(detection.type),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildWasteDetailRow('Location', '${detection.latitude.toStringAsFixed(6)}, ${detection.longitude.toStringAsFixed(6)}'),
            if (detection.confidence != null)
              _buildWasteDetailRow('Confidence', '${(detection.confidence! * 100).toStringAsFixed(1)}%'),
            if (detection.weight != null)
              _buildWasteDetailRow('Weight', '${detection.weight!.toStringAsFixed(2)} kg'),
            _buildWasteDetailRow('Detected', _formatTimestamp(detection.timestamp)),
            const SizedBox(height: 16),
            CustomButton(
              text: 'View on Full Map',
              onPressed: () {
                Navigator.pop(context);
                // Navigate to waste mapping page with this detection pre-selected
                Navigator.pushNamed(context, AppRoutes.wasteMapping);
              },
              icon: Icons.map,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _subscribeWasteDetections() {
    final db = FirebaseDatabase.instance.ref('bots');
    _wasteSubscription?.cancel();
    _wasteSubscription = db.onValue.listen((event) {
      try {
        final raw = event.snapshot.value;
        if (raw != null && raw is Map) {
          _botsCache = Map<String, dynamic>.from(raw as Map);
        } else {
          _botsCache = {};
        }
        _rebuildWasteDetectionsFromCache();
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    });
  }

  void _rebuildWasteDetectionsFromCache() {
    try {
      final auth = ref.read(authProvider);
      final userId = auth.currentUser?.uid;
      final isAdmin = auth.userProfile?.isAdmin ?? false;

      if (userId == null) {
        if (mounted) {
          setState(() {
            _wasteDetections = [];
          });
        }
        return;
      }

      final botsData = _botsCache ?? {};
      final List<WasteDetection> allDetections = [];

      for (var botEntry in botsData.entries) {
        final botId = botEntry.key;
        final value = botEntry.value;
        if (value is! Map) continue;
        final botData = Map<String, dynamic>.from(value as Map);

        // Role-based filtering
        if (!isAdmin) {
          final assignedTo = botData['assigned_to'] as String?;
          if (assignedTo != userId) continue;
        }

        // Check for trash_collection map
        if (botData.containsKey('trash_collection') && botData['trash_collection'] is Map) {
          final trashData = Map<String, dynamic>.from(botData['trash_collection'] as Map);

          for (var trashEntry in trashData.entries) {
            final itemRaw = trashEntry.value;
            if (itemRaw is! Map) continue;
            final item = Map<String, dynamic>.from(itemRaw as Map);

            final type = (item['type'] as String?)?.toLowerCase() ?? 'other';
            final latNum = (item['latitude'] ?? item['lat']);
            final lngNum = (item['longitude'] ?? item['lng']);
            final timestamp = item['timestamp'] as int?;
            final confidenceNum = (item['confidence_level'] ?? item['confidence']);
            final weightNum = (item['weight'] ?? item['weight_kg']);

            final lat = latNum is num ? latNum.toDouble() : null;
            final lng = lngNum is num ? lngNum.toDouble() : null;
            final confidence = confidenceNum is num ? confidenceNum.toDouble() : null;
            final weight = weightNum is num ? weightNum.toDouble() : null;

            if (lat != null && lng != null) {
              final detectionTime = timestamp != null
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                  : DateTime.now();

              allDetections.add(WasteDetection(
                id: trashEntry.key,
                botId: botId,
                type: type,
                latitude: lat,
                longitude: lng,
                timestamp: detectionTime,
                confidence: confidence,
                weight: weight,
              ));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _wasteDetections = allDetections;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadWasteDetections() async {
    // This method is now called when switching to waste view
    // The subscription already handles real-time updates
    // Just trigger a rebuild from cache if needed
    if (_botsCache != null) {
      _rebuildWasteDetectionsFromCache();
    }
  }
}

// Waste Detection Model
class WasteDetection {
  final String id;
  final String botId;
  final String type;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? confidence;
  final double? weight;

  WasteDetection({
    required this.id,
    required this.botId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.confidence,
    this.weight,
  });
}
