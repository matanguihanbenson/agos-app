import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/deployment_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';

class DeploymentGroup {
  final String botId;
  final String botName;
  final String riverId;
  final String riverName;
  final DateTime day;
  final List<DeploymentModel> deployments;
  final double totalWeight;

  DeploymentGroup({
    required this.botId,
    required this.botName,
    required this.riverId,
    required this.riverName,
    required this.day,
    required this.deployments,
    required this.totalWeight,
  });
}

class GroupedDeploymentDetailsPage extends StatefulWidget {
  final DeploymentGroup group;

  const GroupedDeploymentDetailsPage({
    super.key,
    required this.group,
  });

  @override
  State<GroupedDeploymentDetailsPage> createState() =>
      _GroupedDeploymentDetailsPageState();
}

class _GroupedDeploymentDetailsPageState
    extends State<GroupedDeploymentDetailsPage> {
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    final deployments = [...widget.group.deployments]
      ..sort((a, b) => _ascending
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.group.botName} · ${widget.group.riverName}'),
        actions: [
          IconButton(
            tooltip: _ascending ? 'Sort newest first' : 'Sort oldest first',
            icon: Icon(
              _ascending ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () {
              setState(() {
                _ascending = !_ascending;
              });
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderSummary(deployments),
          const SizedBox(height: 16),
          _buildTimeline(deployments),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary(List<DeploymentModel> deployments) {
    final totalWeight = deployments.fold<double>(
      0.0,
      (sum, d) => sum + (d.trashCollection?.totalWeight ?? 0.0),
    );
    final totalItems = deployments.fold<int>(
      0,
      (sum, d) => sum + (d.trashCollection?.totalItems ?? 0),
    );
    
    // Calculate average water quality
    final deploymentsWithWQ = deployments.where((d) => d.waterQuality != null).toList();
    final avgPh = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgPhLevel) / deploymentsWithWQ.length;
    final avgTemp = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgTemperature) / deploymentsWithWQ.length;
    final avgTurbidity = deploymentsWithWQ.isEmpty ? 0.0 : deploymentsWithWQ.fold<double>(0.0, (sum, d) => sum + d.waterQuality!.avgTurbidity) / deploymentsWithWQ.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      child: Card(
        elevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timeline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Combined Deployments',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${deployments.length} deployments on ${DateFormat('MMM d, yyyy').format(widget.group.day)}',
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
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              
              // Trash Collection Summary
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      'Total Trash',
                      '${totalWeight.toStringAsFixed(1)} kg',
                      Icons.delete_sweep,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetric(
                      'Total Items',
                      '$totalItems',
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetric(
                      'Avg/Deploy',
                      deployments.isEmpty ? '0.0 kg' : '${(totalWeight / deployments.length).toStringAsFixed(1)} kg',
                      Icons.analytics,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              
              if (deploymentsWithWQ.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryMetric(
                        'Avg pH',
                        avgPh.toStringAsFixed(1),
                        Icons.science,
                        Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Avg Temp',
                        '${avgTemp.toStringAsFixed(1)}°C',
                        Icons.thermostat,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Avg Turbidity',
                        '${avgTurbidity.toStringAsFixed(0)} NTU',
                        Icons.opacity,
                        Colors.brown,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSummaryMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(List<DeploymentModel> deployments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Deployment Timeline',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...deployments.asMap().entries.map((entry) {
          final index = entry.key;
          final deployment = entry.value;
          final isFirst = index == 0;
          final isLast = index == deployments.length - 1;
          return _buildTimelineItem(deployment, isFirst, isLast);
        }).toList(),
      ],
    );
  }

  Widget _buildTimelineItem(
      DeploymentModel deployment, bool isFirst, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 12,
                  color: AppColors.border,
                ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getStatusColor(deployment.status),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(deployment.status).withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  _getStatusIcon(deployment.status),
                  size: 12,
                  color: Colors.white,
                ),
              ),
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
          // Deployment card content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('h:mm a').format(deployment.createdAt),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(deployment.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              deployment.status.toUpperCase(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (deployment.operationLocation != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.place, size: 11, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                deployment.operationLocation!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (deployment.trashCollection != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Trash: ${deployment.trashCollection!.totalWeight.toStringAsFixed(1)} kg · ${deployment.trashCollection!.totalItems} items',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (deployment.waterQuality != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'pH ${deployment.waterQuality!.avgPhLevel.toStringAsFixed(1)} · ${deployment.waterQuality!.avgTemperature.toStringAsFixed(1)}°C',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Turb: ${deployment.waterQuality!.avgTurbidity.toStringAsFixed(0)} NTU · DO: ${deployment.waterQuality!.avgDissolvedOxygen.toStringAsFixed(1)} mg/L',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check;
      case 'scheduled':
        return Icons.schedule;
      case 'cancelled':
        return Icons.close;
      default:
        return Icons.circle;
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