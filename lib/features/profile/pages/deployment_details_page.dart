import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../core/models/deployment_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';

class DeploymentDetailsPage extends StatelessWidget {
  final DeploymentModel deployment;

  const DeploymentDetailsPage({
    super.key,
    required this.deployment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(deployment.scheduleName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Header (Non-interactive)
            _buildMapHeader(),
            
            // Deployment Info
            _buildDeploymentInfo(),
            
            // Timeline
            _buildTimeline(),
            
            // Trash Collection Details
            if (deployment.trashCollection != null)
              _buildTrashCollectionCard(),
            
            // Water Quality Details
            if (deployment.waterQuality != null)
              _buildWaterQualityCard(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMapHeader() {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(deployment.operationLat, deployment.operationLng),
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, // Make map non-interactive
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.agos_app',
              ),
              // Operation area circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(deployment.operationLat, deployment.operationLng),
                    radius: deployment.operationRadius,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withOpacity(0.2),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  // Operation center marker
                  Marker(
                    point: LatLng(deployment.operationLat, deployment.operationLng),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Map legend overlay
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(Icons.my_location, 'Operation Area', AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeploymentInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  deployment.scheduleName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(deployment.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(deployment.status).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  deployment.status.toUpperCase(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _getStatusColor(deployment.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(color: AppColors.border),
          const SizedBox(height: 16),
          
          // Bot and River info
          _buildInfoRow(Icons.directions_boat, 'Bot', deployment.botName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.water, 'River', deployment.riverName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.place, 'Location', deployment.operationLocation ?? 'Not specified'),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.radio_button_checked,
            'Coverage Radius',
            '${deployment.operationRadius.toStringAsFixed(0)}m',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Timeline items
          _buildTimelineItem(
            'Created',
            deployment.createdAt,
            Icons.add_circle,
            Colors.blue,
            isFirst: true,
          ),
          
          if (deployment.scheduledStartTime != null)
            _buildTimelineItem(
              'Scheduled Start',
              deployment.scheduledStartTime!,
              Icons.schedule,
              Colors.purple,
            ),
          
          if (deployment.actualStartTime != null)
            _buildTimelineItem(
              'Deployment Started',
              deployment.actualStartTime!,
              Icons.play_circle,
              Colors.green,
            ),
          
          if (deployment.actualEndTime != null)
            _buildTimelineItem(
              'Deployment Completed',
              deployment.actualEndTime!,
              Icons.check_circle,
              Colors.green.shade700,
            ),
          
          if (deployment.status == 'cancelled')
            _buildTimelineItem(
              'Cancelled',
              deployment.updatedAt,
              Icons.cancel,
              Colors.red,
              isLast: true,
            ),
          
          if (deployment.status == 'completed' && deployment.actualEndTime != null)
            _buildTimelineItem(
              'Status: Completed',
              deployment.actualEndTime!,
              Icons.done_all,
              AppColors.success,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    DateTime time,
    IconData icon,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          Column(
            children: [
              // Top line
              if (!isFirst)
                Container(
                  width: 2,
                  height: 12,
                  color: AppColors.border,
                ),
              
              // Dot
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              
              // Bottom line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy · h:mm a').format(time),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCollectionCard() {
    final trash = deployment.trashCollection!;
    final totalItems = trash.totalItems == 0
        ? trash.trashByType.values.fold<int>(0, (sum, v) => sum + v)
        : trash.totalItems;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.green, size: 24),
              const SizedBox(width: 10),
              Text(
                'Trash Collection',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Summary
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Weight',
                  '${trash.totalWeight.toStringAsFixed(2)} kg',
                  Icons.scale,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Total Items',
                  '${trash.totalItems}',
                  Icons.inventory_2,
                  Colors.blue,
                ),
              ),
            ],
          ),
          
          // Trash by type
          if (trash.trashByType.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Breakdown by Type',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trash.trashByType.entries.map((entry) {
                return _buildTrashTypeChip(entry.key, entry.value);
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Trash Analytics',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: trash.trashByType.entries.map((entry) {
                final type = entry.key;
                final count = entry.value;
                final double percent =
                    totalItems > 0 ? (count / totalItems) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            type.capitalize(),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$count items · ${(percent * 100).toStringAsFixed(1)}%',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent.clamp(0.0, 1.0),
                          backgroundColor:
                              AppColors.border.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getTrashTypeColor(type),
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrashTypeChip(String type, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getTrashTypeColor(type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getTrashTypeColor(type).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getTrashTypeIcon(type),
            size: 16,
            color: _getTrashTypeColor(type),
          ),
          const SizedBox(width: 6),
          Text(
            '${type.capitalize()}: $count',
            style: AppTextStyles.bodySmall.copyWith(
              color: _getTrashTypeColor(type),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterQualityCard() {
    final wq = deployment.waterQuality!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: Colors.blue, size: 24),
              const SizedBox(width: 10),
              Text(
                'Water Quality',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Water quality metrics in 2 columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildMetricCard(
                      'pH Level',
                      wq.avgPhLevel.toStringAsFixed(1),
                      Icons.science,
                      Colors.purple,
                    ),
                    const SizedBox(height: 8),
                    _buildMetricCard(
                      'Temperature',
                      '${wq.avgTemperature.toStringAsFixed(1)}°C',
                      Icons.thermostat,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _buildMetricCard(
                      'Turbidity',
                      '${wq.avgTurbidity.toStringAsFixed(1)} NTU',
                      Icons.opacity,
                      Colors.brown,
                    ),
                    const SizedBox(height: 8),
                    _buildMetricCard(
                      'Dissolved O₂',
                      '${wq.avgDissolvedOxygen.toStringAsFixed(1)} mg/L',
                      Icons.air,
                      Colors.cyan,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            '${wq.sampleCount} samples collected',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
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
      case 'completed':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getTrashTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'plastic':
        return Colors.blue;
      case 'metal':
        return Colors.grey.shade700;
      case 'paper':
        return Colors.brown;
      case 'glass':
        return Colors.cyan;
      case 'organic':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getTrashTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'plastic':
        return Icons.recycling;
      case 'metal':
        return Icons.build;
      case 'paper':
        return Icons.description;
      case 'glass':
        return Icons.wine_bar;
      case 'organic':
        return Icons.eco;
      default:
        return Icons.delete;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

