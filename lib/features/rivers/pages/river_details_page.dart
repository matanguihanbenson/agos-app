import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/river_model.dart';
import '../../../core/models/deployment_model.dart';
import '../../../core/providers/deployment_provider.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';

class RiverDetailsPage extends ConsumerStatefulWidget {
  final RiverModel river;

  const RiverDetailsPage({
    super.key,
    required this.river,
  });

  @override
  ConsumerState<RiverDetailsPage> createState() => _RiverDetailsPageState();
}

class _RiverDetailsPageState extends ConsumerState<RiverDetailsPage> {
  List<DeploymentModel> _riverDeployments = [];
  bool _isLoadingDeployments = true;

  @override
  void initState() {
    super.initState();
    _loadRiverDeployments();
  }

  Future<void> _loadRiverDeployments() async {
    setState(() => _isLoadingDeployments = true);

    try {
      // Fetch all deployments for this river from Firestore
      final deploymentsSnapshot = await FirebaseFirestore.instance
          .collection('deployments')
          .where('river_id', isEqualTo: widget.river.id)
          .get();

      // Sort in memory by created_at to avoid composite index issues
      final deployments = deploymentsSnapshot.docs
          .map((doc) => DeploymentModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _riverDeployments = deployments;
          _isLoadingDeployments = false;
        });
      }
    } catch (e) {
      print('Error loading river deployments: $e');
      if (mounted) {
        setState(() => _isLoadingDeployments = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlobalAppBar(
        title: widget.river.name,
        showDrawer: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRiverDeployments,
        child: ListView(
          children: [
            _buildRiverInfoCard(),
            const SizedBox(height: 12),
            _buildDeploymentHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRiverInfoCard() {
    // Calculate aggregated statistics from deployments
    final totalDeployments = _riverDeployments.length;
    final activeDeployments = _riverDeployments
        .where((d) => d.status.toLowerCase() == 'active' || d.status.toLowerCase() == 'scheduled')
        .length;
    
    // Aggregate trash collected
    double totalTrash = 0.0;
    for (final deployment in _riverDeployments) {
      if (deployment.trashCollection != null) {
        totalTrash += deployment.trashCollection!.totalWeight;
      }
    }

    // Calculate average water quality
    final deploymentsWithWQ = _riverDeployments.where((d) => d.waterQuality != null).toList();
    final avgPh = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgPhLevel) / deploymentsWithWQ.length;
    final avgTemp = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgTemperature) / deploymentsWithWQ.length;
    final avgTurbidity = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgTurbidity) / deploymentsWithWQ.length;
    final avgDO = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgDissolvedOxygen) / deploymentsWithWQ.length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // River header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.water_rounded,
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
                        widget.river.name,
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (widget.river.description != null && widget.river.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.river.description!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Statistics Grid
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Statistics',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (_isLoadingDeployments) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Deployment stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildSquareStat(
                        Icons.event_available_rounded,
                        'Deployments',
                        totalDeployments.toString(),
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSquareStat(
                        Icons.pending_actions_rounded,
                        'Active',
                        activeDeployments.toString(),
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSquareStat(
                        Icons.delete_sweep_rounded,
                        'Trash (kg)',
                        totalTrash.toStringAsFixed(1),
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                if (deploymentsWithWQ.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Water quality stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildSquareStat(
                          Icons.science_rounded,
                          'pH',
                          avgPh.toStringAsFixed(1),
                          Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSquareStat(
                          Icons.thermostat_rounded,
                          'Temp (\u00b0C)',
                          avgTemp.toStringAsFixed(1),
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSquareStat(
                          Icons.opacity_rounded,
                          'Turb (NTU)',
                          avgTurbidity.toStringAsFixed(0),
                          Colors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSquareStat(
                          Icons.air_rounded,
                          'DO (mg/L)',
                          avgDO.toStringAsFixed(1),
                          Colors.cyan,
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox()),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // River metadata
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.calendar_today_rounded,
                  'Created',
                  DateFormat('MMM d, yyyy').format(widget.river.createdAt),
                ),
                if (widget.river.lastDeployment != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.schedule_rounded,
                    'Last Deployment',
                    DateFormat('MMM d, yyyy').format(widget.river.lastDeployment!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareStat(IconData icon, String label, String value, Color color) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                height: 1.1,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDeploymentHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Deployment History',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingDeployments)
            const LoadingIndicator(message: 'Loading deployments...')
          else if (_riverDeployments.isEmpty)
            EmptyState(
              icon: Icons.history,
              title: 'No Deployments Yet',
              message: 'No deployment history for this river.',
            )
          else
            ..._riverDeployments.map((deployment) => _buildDeploymentCard(deployment)),
        ],
      ),
    );
  }

  Widget _buildDeploymentCard(DeploymentModel deployment) {
    final statusColor = _getStatusColor(deployment.status);
    final statusLabel = deployment.status.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with bot name and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deployment.botName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a').format(deployment.createdAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            
            // Operation location
            if (deployment.operationLocation != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      deployment.operationLocation!,
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

            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.3)),
            const SizedBox(height: 10),

            // Trash collection data
            if (deployment.trashCollection != null) ...[
              Row(
                children: [
                  Icon(Icons.delete_sweep_rounded, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Trash: ${deployment.trashCollection!.totalWeight.toStringAsFixed(1)} kg · ${deployment.trashCollection!.totalItems} items',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            // Water quality data
            if (deployment.waterQuality != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildCompactMetric(
                    Icons.science_rounded,
                    'pH',
                    deployment.waterQuality!.avgPhLevel.toStringAsFixed(1),
                    Colors.deepPurple,
                  ),
                  _buildCompactMetric(
                    Icons.thermostat_rounded,
                    'Temp',
                    '${deployment.waterQuality!.avgTemperature.toStringAsFixed(1)}\u00b0C',
                    Colors.red,
                  ),
                  _buildCompactMetric(
                    Icons.opacity_rounded,
                    'Turb',
                    '${deployment.waterQuality!.avgTurbidity.toStringAsFixed(0)} NTU',
                    Colors.brown,
                  ),
                  _buildCompactMetric(
                    Icons.air_rounded,
                    'DO',
                    '${deployment.waterQuality!.avgDissolvedOxygen.toStringAsFixed(1)} mg/L',
                    Colors.cyan,
                  ),
                ],
              ),
            ],

            // Duration
            if (deployment.actualStartTime != null && deployment.actualEndTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Duration: ${_formatDuration(deployment.actualStartTime!, deployment.actualEndTime!)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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

  Widget _buildCompactMetric(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours == 0) {
      return '$minutes min';
    } else if (minutes == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      return '$hours ${hours == 1 ? 'hr' : 'hrs'} $minutes min';
    }
  }
}
