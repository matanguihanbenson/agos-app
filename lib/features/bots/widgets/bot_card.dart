import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../pages/assign_bot_page.dart';
import '../../../core/services/control_lock_service.dart';
import '../../control/pages/live_stream_page.dart';
import '../../control/pages/bot_control_page.dart';

class BotCard extends ConsumerStatefulWidget {
  final BotModel bot;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onActions;
  final bool showDeleteButton;
  final bool showReassignButton;
  final bool showActionsButton;

  const BotCard({
    super.key,
    required this.bot,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onActions,
    this.showDeleteButton = true,
    this.showReassignButton = true,
    this.showActionsButton = false,
  });

  @override
  ConsumerState<BotCard> createState() => _BotCardState();
}

class _BotCardState extends ConsumerState<BotCard> {
  String? _reverseGeocodedLocation;
  bool _isLoadingLocation = false;
  StreamSubscription<Map<String, dynamic>?>? _lockSub;
  String? _controllerName;
  String? _assignedUserName;
  bool _isLoadingAssignedUser = false;

  @override
  void initState() {
    super.initState();
    _loadReverseGeocodedLocation();
    _loadAssignedUserName();
    final service = ControlLockService();
    _lockSub = service.watchLock(widget.bot.id).listen((data) {
      if (!mounted) return;
      setState(() {
        _controllerName = data != null ? (data['name'] as String?) : null;
      });
    });
  }

  Future<void> _loadReverseGeocodedLocation() async {
    // Use realtime lat/lng if available, otherwise fall back to Firestore values
    final latitude = widget.bot.lat;
    final longitude = widget.bot.lng;
    
    if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) {
      setState(() {
        _isLoadingLocation = true;
      });

      final address = await ReverseGeocodingService.getShortAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        setState(() {
          _reverseGeocodedLocation = address;
          _isLoadingLocation = false;
        });
      }
    } else {
      // No valid location data
      if (mounted) {
        setState(() {
          _reverseGeocodedLocation = null;
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _loadAssignedUserName() async {
    if (!widget.bot.isAssigned || widget.bot.assignedTo == null || widget.bot.assignedTo!.isEmpty) {
      return;
    }

    // Check if user exists in local provider
    final userState = ref.read(userProvider);
    final localUser = userState.users.firstWhere(
      (user) => user.id == widget.bot.assignedTo,
      orElse: () => UserModel(
        id: '',
        firstName: '',
        lastName: '',
        email: '',
        role: 'field_operator',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (localUser.id.isNotEmpty) {
      setState(() {
        _assignedUserName = localUser.fullName;
      });
      return;
    }

    // Fallback: Fetch from Firestore
    setState(() {
      _isLoadingAssignedUser = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.bot.assignedTo)
          .get();

      if (mounted) {
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final firstName = data['first_name'] ?? '';
            final lastName = data['last_name'] ?? '';
            final fullName = (firstName + ' ' + lastName).trim();
            setState(() {
              _assignedUserName = fullName.isNotEmpty ? fullName : 'Unknown User';
              _isLoadingAssignedUser = false;
            });
            return;
          }
        }
        setState(() {
          _assignedUserName = 'Unknown User';
          _isLoadingAssignedUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assignedUserName = 'Unknown User';
          _isLoadingAssignedUser = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _lockSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.bot.isOnline;
    final rawStatus = (widget.bot.status ?? 'idle').toLowerCase();
    // Standardize status labels: Idle, Deployed, Maintenance, Recalling, Scheduled
    final effectiveStatus = _standardizeStatus(rawStatus);
    final isAssigned = widget.bot.isAssigned;
    final batteryLevel = widget.bot.batteryLevel ?? 0;
    // Standardize battery: Fully Charged (>80%), Critical (<=20%)
    final batteryStatus = _getBatteryStatus(batteryLevel);
    
    // Get assigned user name
    String assignedTo = 'None';
    if (isAssigned) {
      if (_isLoadingAssignedUser) {
        assignedTo = 'Loading...';
      } else if (_assignedUserName != null) {
        assignedTo = _assignedUserName!;
      } else {
        assignedTo = 'Unknown User';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Bot icon, name, ID, and online status
              Row(
                children: [
                  Icon(
                    Icons.directions_boat,
                    size: 24,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bot.name,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'ID: ${widget.bot.id}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.success : AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Controller Chip (if any)
              if (_controllerName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Controlled by: $_controllerName',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

              // Status and Battery Level
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Status: ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(effectiveStatus).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _getStatusColor(effectiveStatus).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            effectiveStatus,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _getStatusColor(effectiveStatus),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: batteryLevel > 80 ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: batteryLevel > 80 ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          batteryLevel > 80 ? Icons.battery_full : Icons.battery_alert,
                          size: 14,
                          color: batteryLevel > 80 ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          batteryStatus,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: batteryLevel > 80 ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Assigned to
              Text(
                'Assigned to: $assignedTo',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              
              // Location
              Text(
                'Location: ${_getLocationDisplay()}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              
              // Action buttons - compact layout to prevent overflow
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.videocam,
                      label: 'Live',
                      onPressed: () => _showLiveFeed(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.control_camera,
                      label: 'Control',
                      onPressed: widget.onEdit ?? () => _showControl(context),
                    ),
                  ),
                  if (widget.showActionsButton) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.settings_remote,
                        label: 'Actions',
                        onPressed: widget.onActions ?? () {},
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  if (widget.showReassignButton) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildActionButton(
                        icon: isAssigned ? Icons.swap_horiz : Icons.assignment,
                        label: isAssigned ? 'Reassign' : 'Assign',
                        onPressed: isAssigned ? () => _showReassign(context) : () => _showAssign(context),
                      ),
                    ),
                  ],
                  if (widget.showDeleteButton) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.remove_circle,
                        label: 'Remove',
                        onPressed: widget.onDelete ?? () {},
                        isDestructive: true,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDestructive ? AppColors.error : (color ?? AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDestructive ? AppColors.error : (color ?? AppColors.textPrimary),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveFeed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamPage(
          botId: widget.bot.id,
          botName: widget.bot.name,
        ),
      ),
    );
  }

  void _showControl(BuildContext context) {
    // Navigate to bot control page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotControlPage(
          botId: widget.bot.id,
          botName: widget.bot.name,
        ),
      ),
    );
  }

  void _showAssign(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignBotPage(preSelectedBot: widget.bot),
      ),
    );
  }

  void _showReassign(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reassign bot feature coming soon')),
    );
  }

  /// Standardize status to match user requirements:
  /// Idle, Deployed, Maintenance, Recalling, Scheduled
  String _standardizeStatus(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'idle':
        return 'Idle';
      case 'deployed':
      case 'active':
        return 'Deployed';
      case 'maintenance':
        return 'Maintenance';
      case 'recalling':
        return 'Recalling';
      case 'scheduled':
        return 'Scheduled';
      default:
        return 'Idle'; // Default to Idle if unknown
    }
  }

  /// Standardize battery status: Fully Charged (>80%) or Critical (<=20%)
  String _getBatteryStatus(double level) {
    final intLevel = level.toInt();
    if (level > 80) {
      return 'Fully Charged';
    } else if (level <= 20) {
      return 'Critical';
    } else {
      return '$intLevel%'; // Show percentage for mid-range
    }
  }

  /// Get location display with fallback
  String _getLocationDisplay() {
    if (_isLoadingLocation) {
      return 'Loading...';
    }
    
    if (_reverseGeocodedLocation != null && _reverseGeocodedLocation!.isNotEmpty) {
      return _reverseGeocodedLocation!;
    }
    
    // Fallback to lat/lng if reverse geocoding failed
    if (widget.bot.lat != null && widget.bot.lng != null) {
      return '${widget.bot.lat!.toStringAsFixed(4)}, ${widget.bot.lng!.toStringAsFixed(4)}';
    }
    
    return 'Location unavailable';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return AppColors.success;
      case 'deployed':
      case 'active':
        return AppColors.primary;
      case 'scheduled':
        return AppColors.info;
      case 'recalling':
        return AppColors.warning;
      case 'maintenance':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
