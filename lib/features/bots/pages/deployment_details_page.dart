import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/models/deployment_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';

class DeploymentDetailsPage extends ConsumerStatefulWidget {
  final DeploymentModel deployment;

  const DeploymentDetailsPage({
    super.key,
    required this.deployment,
  });

  @override
  ConsumerState<DeploymentDetailsPage> createState() => _DeploymentDetailsPageState();
}

class _DeploymentDetailsPageState extends ConsumerState<DeploymentDetailsPage> {
  Map<String, dynamic>? _botRealtimeData;
  bool _isLoadingRealtimeData = false;
  StreamSubscription<DatabaseEvent>? _rtdbSub;

  @override
  void initState() {
    super.initState();
    if (widget.deployment.isActive) {
      _subscribeBotRealtime();
    }
  }

  void _subscribeBotRealtime() {
    setState(() {
      _isLoadingRealtimeData = true;
    });

    _rtdbSub?.cancel();
    _rtdbSub = FirebaseDatabase.instance
        .ref('bots/${widget.deployment.botId}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value is Map) {
        setState(() {
          _botRealtimeData = Map<String, dynamic>.from(event.snapshot.value as Map);
          _isLoadingRealtimeData = false;
        });
      } else {
        setState(() {
          _botRealtimeData = null;
          _isLoadingRealtimeData = false;
        });
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRealtimeData = false;
      });
    });
  }

  Future<void> _loadBotRealtimeData() async {
    // Manual refresh triggers a one-shot read; stream remains active
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('bots/${widget.deployment.botId}')
          .get();
      if (!mounted) return;
      if (snapshot.exists && snapshot.value is Map) {
        setState(() {
          _botRealtimeData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Deployment Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _buildStatusCard(),
            const SizedBox(height: 16),
            
            // Schedule information
            _buildScheduleInfo(),
            const SizedBox(height: 16),
            
            // Real-time bot data (if active)
            if (widget.deployment.isActive) ...[
              _buildRealtimeBotData(),
              const SizedBox(height: 16),
            ],
            
            // Summary cards (if completed)
            if (widget.deployment.isCompleted) ...[
              _buildSummaryCards(),
              const SizedBox(height: 16),
              
              // Water quality data
              if (widget.deployment.waterQuality != null) ...[
                _buildWaterQualityCard(),
                const SizedBox(height: 16),
              ],
              
              // Trash analytics
              if (widget.deployment.trashCollection != null) ...[
                _buildTrashAnalyticsCard(),
                const SizedBox(height: 16),
              ],
            ],
            
            // Notes
            if (widget.deployment.notes != null && widget.deployment.notes!.isNotEmpty) ...[
              _buildNotesCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (widget.deployment.status) {
      case 'scheduled':
        statusColor = AppColors.primary;
        statusIcon = Icons.schedule;
        statusText = 'Scheduled';
        break;
      case 'active':
        statusColor = AppColors.success;
        statusIcon = Icons.play_circle;
        statusText = 'Active';
        break;
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.help;
        statusText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.deployment.scheduleName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Information',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.directions_boat, 'Bot', widget.deployment.botName),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.water, 'River', widget.deployment.riverName),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.calendar_today, 
            'Scheduled Start', 
            DateFormat('MMM d, y • h:mm a').format(widget.deployment.scheduledStartTime),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.access_time_filled, 
            'Scheduled End', 
            DateFormat('MMM d, y • h:mm a').format(widget.deployment.scheduledEndTime),
          ),
          if (widget.deployment.actualStartTime != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.play_arrow, 
              'Actual Start', 
              DateFormat('MMM d, y • h:mm a').format(widget.deployment.actualStartTime!),
            ),
          ],
          if (widget.deployment.actualEndTime != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.check, 
              'Actual End', 
              DateFormat('MMM d, y • h:mm a').format(widget.deployment.actualEndTime!),
            ),
          ],
          if (widget.deployment.durationMinutes != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.timer, 
              'Duration', 
              '${widget.deployment.durationMinutes} minutes',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (widget.deployment.trashCollection != null)
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.delete_sweep,
                  color: AppColors.success,
                  label: 'Trash Collected',
                  value: '${widget.deployment.trashCollection!.totalWeight.toStringAsFixed(1)} kg',
                  subtitle: '${widget.deployment.trashCollection!.totalItems} items',
                ),
              ),
            if (widget.deployment.trashCollection != null && widget.deployment.distanceTraveled != null)
              const SizedBox(width: 12),
            if (widget.deployment.distanceTraveled != null)
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.straighten,
                  color: AppColors.info,
                  label: 'Distance',
                  value: '${(widget.deployment.distanceTraveled! / 1000).toStringAsFixed(2)} km',
                  subtitle: '${widget.deployment.distanceTraveled!.toStringAsFixed(0)} m',
                ),
              ),
          ],
        ),
        if (widget.deployment.areaCoveredPercentage != null) ...[
          const SizedBox(height: 12),
          _buildSummaryCard(
            icon: Icons.map,
            color: AppColors.primary,
            label: 'Area Covered',
            value: '${widget.deployment.areaCoveredPercentage!.toStringAsFixed(1)}%',
            subtitle: 'of operation area',
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaterQualityCard() {
    final wq = widget.deployment.waterQuality!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'Water Quality Data',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildWQMetric('pH Level', wq.avgPhLevel.toStringAsFixed(2), AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _buildWQMetric('Turbidity', '${wq.avgTurbidity.toStringAsFixed(1)} NTU', AppColors.warning)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildWQMetric('Temperature', '${wq.avgTemperature.toStringAsFixed(1)}°C', AppColors.error)),
              const SizedBox(width: 12),
              Expanded(child: _buildWQMetric('DO', '${wq.avgDissolvedOxygen.toStringAsFixed(1)} mg/L', AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Based on ${wq.sampleCount} samples',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWQMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashAnalyticsCard() {
    final trash = widget.deployment.trashCollection!;
    final totalCount = trash.trashByType.values.fold<int>(0, (sum, count) => sum + count);
    
    // Sort by count descending
    final sortedTypes = trash.trashByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'Trash Analytics',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pie chart
          if (sortedTypes.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: sortedTypes.take(5).map((entry) {
                        final percentage = (entry.value / totalCount) * 100;
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title: '${percentage.toStringAsFixed(0)}%',
                          color: _getTrashTypeColor(entry.key),
                          radius: 36,
                          titleStyle: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedTypes.take(5).map((entry) {
                      final percentage = (entry.value / totalCount) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getTrashTypeColor(entry.key),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${entry.value} (${percentage.toStringAsFixed(0)}%)',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRealtimeBotData() {
    if (_isLoadingRealtimeData) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_botRealtimeData == null) {
      return const SizedBox.shrink();
    }

    final status = _botRealtimeData!['status'] ?? 'unknown';
    final batteryLevel = _botRealtimeData!['battery_level']?.toDouble() ?? 0.0;
    final phLevel = _botRealtimeData!['ph_level']?.toDouble();
    final temperature = _botRealtimeData!['temp']?.toDouble();
    final turbidity = _botRealtimeData!['turbidity']?.toDouble();
    final trashCollected = _botRealtimeData!['trash_collected']?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                'Real-Time Bot Data',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadBotRealtimeData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Bot Status and Battery
          Row(
            children: [
              Expanded(
                child: _buildRealtimeMetricCard(
                  'Bot Status',
                  status.toUpperCase(),
                  Icons.info_outline,
                  _getStatusColor(status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRealtimeMetricCard(
                  'Battery',
                  '${batteryLevel.toStringAsFixed(0)}%',
                  Icons.battery_charging_full,
                  batteryLevel > 20 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Water Quality Metrics
          Row(
            children: [
              Expanded(
                child: _buildRealtimeMetricCard(
                  'pH Level',
                  phLevel != null ? phLevel.toStringAsFixed(2) : 'N/A',
                  Icons.water_drop,
                  AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRealtimeMetricCard(
                  'Temperature',
                  temperature != null ? '${temperature.toStringAsFixed(1)}°C' : 'N/A',
                  Icons.thermostat,
                  AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Turbidity and Trash
          Row(
            children: [
              Expanded(
                child: _buildRealtimeMetricCard(
                  'Turbidity',
                  turbidity != null ? turbidity.toStringAsFixed(1) : 'N/A',
                  Icons.blur_on,
                  AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRealtimeMetricCard(
                  'Trash Collected',
                  '${trashCollected.toStringAsFixed(2)} kg',
                  Icons.delete,
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
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
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.deployment.notes!,
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTrashTypeColor(String type) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF3F51B5),
      const Color(0xFF00BCD4),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
      const Color(0xFFFFC107),
      const Color(0xFF795548),
    ];
    return colors[type.hashCode % colors.length];
  }
}

