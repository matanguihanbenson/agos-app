import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../../control/pages/bot_control_page.dart';
import '../../control/pages/live_stream_page.dart';
import '../../../core/models/deployment_model.dart';
import '../../../core/providers/deployment_provider.dart';
import 'deployment_details_page.dart';

class BotDetailsPage extends ConsumerStatefulWidget {
  final BotModel bot;

  const BotDetailsPage({
    super.key,
    required this.bot,
  });

  @override
  ConsumerState<BotDetailsPage> createState() => _BotDetailsPageState();
}

class _BotDetailsPageState extends ConsumerState<BotDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MapController _mapController;
  String? _reverseGeocodedLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _mapController = MapController();
    
    // Load organizations to display organization names
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(organizationProvider.notifier).loadOrganizations();
      _loadReverseGeocodedLocation();
      _centerMapOnBot();
    });
  }

  void _centerMapOnBot() {
    if (widget.bot.lat != null && widget.bot.lng != null) {
      _mapController.move(
        LatLng(widget.bot.lat!, widget.bot.lng!),
        15.0, // Zoom level
      );
    }
  }

  Future<void> _loadReverseGeocodedLocation() async {
    if (widget.bot.lat != null && widget.bot.lng != null) {
      setState(() {
        _isLoadingLocation = true;
      });

      final address = await ReverseGeocodingService.getAddressFromCoordinates(
        latitude: widget.bot.lat!,
        longitude: widget.bot.lng!,
      );

      if (mounted) {
        setState(() {
          _reverseGeocodedLocation = address;
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final organizationState = ref.watch(organizationProvider);
    
    // Get assigned user
    UserModel? assignedUser;
    if (widget.bot.isAssigned) {
      try {
        assignedUser = userState.users.firstWhere(
          (user) => user.id == widget.bot.assignedTo,
        );
      } catch (e) {
        assignedUser = null;
      }
    }
    
    // Get organization name
    String organizationName = 'None';
    if (widget.bot.organizationId != null) {
      try {
        final organization = organizationState.organizations.firstWhere(
          (org) => org.id == widget.bot.organizationId,
        );
        organizationName = organization.name;
      } catch (e) {
        organizationName = 'Unknown';
      }
    }

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Bot Details',
        showDrawer: false,
      ),
      body: Column(
        children: [
          // Quick Summary Section
          _buildQuickSummary(assignedUser, organizationName),
          
          const SizedBox(height: 8),
          
          // Tab Bar
          _buildTabBar(),
          
          const SizedBox(height: 4),
        
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentLocationTab(),
                _buildDeploymentHistoryTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildQuickSummary(UserModel? assignedUser, String organizationName) {
    final isOnline = widget.bot.isOnline;
    final status = widget.bot.displayStatus.toUpperCase();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.primary.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with bot name and online status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.directions_boat,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bot.name,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${widget.bot.id}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOnline ? 'Online' : 'Offline',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Summary details in a more compact grid
          Column(
            children: [
              // Three main details: Status, Assigned to, Organization
              Row(
                children: [
                  Expanded(child: _buildSummaryRow('Status', status)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryRow('Assigned to', assignedUser?.fullName ?? 'None')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryRow('Organization', organizationName)),
                ],
              ),
              const SizedBox(height: 6),
              // Location below, left aligned
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location:',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoadingLocation 
                          ? 'Loading...' 
                          : (_reverseGeocodedLocation ?? widget.bot.displayLocation),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    if (widget.bot.lat != null && widget.bot.lng != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${widget.bot.lat!.toStringAsFixed(6)}, ${widget.bot.lng!.toStringAsFixed(6)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              if (widget.bot.batteryLevel != null || widget.bot.phLevel != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (widget.bot.batteryLevel != null)
                      Expanded(child: _buildSummaryRow('Battery', '${widget.bot.batteryLevel}%')),
                    if (widget.bot.batteryLevel != null && widget.bot.phLevel != null)
                      const SizedBox(width: 8),
                    if (widget.bot.phLevel != null)
                      Expanded(child: _buildSummaryRow('pH Level', widget.bot.phLevel!.toStringAsFixed(1))),
                  ],
                ),
              ],
              
              if (widget.bot.temp != null || widget.bot.turbidity != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (widget.bot.temp != null)
                      Expanded(child: _buildSummaryRow('Temperature', '${widget.bot.temp!.toStringAsFixed(1)}°C')),
                    if (widget.bot.temp != null && widget.bot.turbidity != null)
                      const SizedBox(width: 8),
                    if (widget.bot.turbidity != null)
                      Expanded(child: _buildSummaryRow('Turbidity', widget.bot.turbidity!.toStringAsFixed(1))),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.background, AppColors.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(text: 'Location'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationTab() {
    if (widget.bot.lat == null || widget.bot.lng == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  'No Location Data',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Bot location is not available',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.bot.lat!, widget.bot.lng!),
              initialZoom: 15.0,
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
              
              // Bot marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.bot.lat!, widget.bot.lng!),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.bot.isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_boat,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeploymentHistoryTab() {
    final deploymentsAsync = ref.watch(deploymentsByBotStreamProvider(widget.bot.id));
    
    return deploymentsAsync.when(
      data: (deployments) {
        // Sort by scheduled start time descending (most recent first)
        final sortedDeployments = List<DeploymentModel>.from(deployments)
          ..sort((a, b) => b.scheduledStartTime.compareTo(a.scheduledStartTime));
        
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Deployments',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Real deployment history
              Expanded(
                child: sortedDeployments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: sortedDeployments.length > 10 ? 10 : sortedDeployments.length,
                        itemBuilder: (context, index) {
                          return _buildDeploymentCard(sortedDeployments[index]);
                        },
                      ),
              ),
          
              if (sortedDeployments.length > 10) ...[
                const SizedBox(height: 12),
                CustomButton(
                  text: 'View Full History',
                  onPressed: () {
                    // TODO: Navigate to full deployment history page
                  },
                  isOutlined: true,
                  icon: Icons.history,
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text('Error loading deployments: $error'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            'No Deployment History',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This bot has not been deployed yet',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploymentCard(DeploymentModel deployment) {
    // Calculate time ago
    final now = DateTime.now();
    final scheduledTime = deployment.scheduledStartTime;
    final difference = now.difference(scheduledTime);
    
    String timeAgo;
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      timeAgo = 'Just now';
    }
    
    // Calculate duration
    String duration = 'N/A';
    if (deployment.actualStartTime != null && deployment.actualEndTime != null) {
      final durationDiff = deployment.actualEndTime!.difference(deployment.actualStartTime!);
      if (durationDiff.inHours > 0) {
        duration = '${durationDiff.inHours}h ${durationDiff.inMinutes % 60}m';
      } else {
        duration = '${durationDiff.inMinutes}m';
      }
    } else {
      final durationDiff = deployment.scheduledEndTime.difference(deployment.scheduledStartTime);
      if (durationDiff.inHours > 0) {
        duration = '${durationDiff.inHours}h ${durationDiff.inMinutes % 60}m (scheduled)';
      } else {
        duration = '${durationDiff.inMinutes}m (scheduled)';
      }
    }
    
    // Get status color
    Color statusColor;
    switch (deployment.status) {
      case 'scheduled':
        statusColor = Colors.blue;
        break;
      case 'active':
        statusColor = Colors.green;
        break;
      case 'completed':
        statusColor = Colors.grey;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = AppColors.textMuted;
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeploymentDetailsPage(
              deployment: deployment,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 14,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deployment.scheduleName,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        deployment.operationLocation ?? 'Unknown location',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        deployment.status.toUpperCase(),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeAgo,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDeploymentDetail(
                    Icons.schedule,
                    'Duration',
                    duration,
                  ),
                ),
                Expanded(
                  child: _buildDeploymentDetail(
                    Icons.delete,
                    'Trash',
                    '${(deployment.trashCollection?.totalWeight ?? 0).toStringAsFixed(1)} kg',
                  ),
                ),
                Expanded(
                  child: _buildDeploymentDetail(
                    Icons.route,
                    'Distance',
                    '${((deployment.distanceTraveled ?? 0) / 1000).toStringAsFixed(1)} km',
                  ),
                ),
              ],
            ),
            if (deployment.waterQuality != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDeploymentDetail(
                      Icons.water_drop,
                      'pH',
                      deployment.waterQuality!.avgPhLevel.toStringAsFixed(2),
                    ),
                  ),
                  Expanded(
                    child: _buildDeploymentDetail(
                      Icons.blur_on,
                      'Turbidity',
                      deployment.waterQuality!.avgTurbidity.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(
                    child: _buildDeploymentDetail(
                      Icons.thermostat,
                      'Temp',
                      '${deployment.waterQuality!.avgTemperature.toStringAsFixed(1)}°C',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeploymentDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 8,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    final isAssigned = widget.bot.isAssigned;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).padding.bottom, // Add bottom safe area padding
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
                     Expanded(
                       child: CustomButton(
                         text: 'Edit',
                         onPressed: () {
                           Navigator.pushNamed(
                             context,
                             AppRoutes.editBot,
                             arguments: widget.bot,
                           );
                         },
                         isOutlined: true,
                         icon: Icons.edit,
                       ),
                     ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: 'Live Feed',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveStreamPage(
                          botId: widget.bot.id,
                          botName: widget.bot.name,
                        ),
                      ),
                    );
                  },
                  isOutlined: true,
                  icon: Icons.videocam,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Control',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BotControlPage(
                          botId: widget.bot.id,
                          botName: widget.bot.name,
                        ),
                      ),
                    );
                  },
                  isOutlined: true,
                  icon: Icons.settings_remote,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: isAssigned ? 'Reassign' : 'Assign',
                  onPressed: () {
                    // TODO: Navigate to assign/reassign page
                  },
                  icon: Icons.person_add,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
