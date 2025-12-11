import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/models/deployment_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import 'edit_schedule_page.dart';

class ScheduleDetailPage extends StatefulWidget {
  final ScheduleModel schedule;

  const ScheduleDetailPage({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  DeploymentModel? _deployment;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _deploymentSub;

  @override
  void initState() {
    super.initState();
    _subscribeDeployment();
  }

  void _subscribeDeployment() {
    setState(() => _isLoading = true);
    _deploymentSub?.cancel();
    _deploymentSub = FirebaseFirestore.instance
        .collection('deployments')
        .where('schedule_id', isEqualTo: widget.schedule.id)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          _deployment = DeploymentModel.fromMap(doc.data(), doc.id);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Details'),
        actions: [
          if (widget.schedule.isScheduled)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditSchedulePage(schedule: widget.schedule),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
              tooltip: 'Edit Schedule',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _subscribeDeployment,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildStatusCard(),
                  const SizedBox(height: 12),

                  // Basic Info Card
                  _buildInfoCard(),
                  const SizedBox(height: 12),

                  // Schedule Time Card
                  _buildTimeCard(),
                  const SizedBox(height: 12),

                  // Operation Area Map
                  _buildMapCard(),
                  const SizedBox(height: 12),

                  // Comprehensive Results (if deployment exists)
                  if (_deployment != null && _deployment!.isCompleted) ...[
                    _buildComprehensiveResults(),
                    const SizedBox(height: 12),
                  ],

                  // Notes (if any)
                  if (_deployment?.notes != null && _deployment!.notes!.isNotEmpty) ...[
                    _buildNotesCard(),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _deploymentSub?.cancel();
    super.dispose();
  }

  Widget _buildStatusCard() {
    final status = _deployment?.status ?? widget.schedule.status;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'scheduled':
        statusColor = AppColors.primary;
        statusIcon = Icons.schedule;
        break;
      case 'active':
        statusColor = AppColors.success;
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = const Color(0xFF757575);
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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
                  (_deployment?.status ?? widget.schedule.status).toUpperCase(),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusDescription(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cleanup Information',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.label, 'Name', _deployment?.scheduleName ?? widget.schedule.name),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.directions_boat, 'Bot', _deployment?.botName ?? widget.schedule.botName ?? widget.schedule.botId),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.water, 'River', _deployment?.riverName ?? widget.schedule.riverName ?? widget.schedule.riverId),
          if (widget.schedule.assignedOperatorName != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, 'Operator', widget.schedule.assignedOperatorName!),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Times',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.calendar_today,
            'Scheduled Date',
            DateFormat('MMM d, y').format(_deployment?.scheduledStartTime ?? widget.schedule.scheduledDate),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.access_time,
            'Start Time',
            DateFormat('h:mm a').format(_deployment?.scheduledStartTime ?? widget.schedule.scheduledDate),
          ),
          if (_deployment?.scheduledEndTime != null || widget.schedule.scheduledEndDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time_filled,
              'End Time',
              DateFormat('h:mm a').format(_deployment?.scheduledEndTime ?? widget.schedule.scheduledEndDate!),
            ),
          ],
          if (_deployment?.actualStartTime != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.play_arrow,
              'Actually Started',
              DateFormat('MMM d, y • h:mm a').format(_deployment!.actualStartTime!),
            ),
          ],
          if (_deployment?.actualEndTime != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.check,
              'Completed',
              DateFormat('MMM d, y • h:mm a').format(_deployment!.actualEndTime!),
            ),
          ],
          if (_deployment?.durationMinutes != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.timer,
              'Duration',
              '${_deployment!.durationMinutes!} minutes',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  _deployment?.operationLat ?? widget.schedule.operationArea.center.latitude,
                  _deployment?.operationLng ?? widget.schedule.operationArea.center.longitude,
                ),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agos.app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(
                        _deployment?.operationLat ?? widget.schedule.operationArea.center.latitude,
                        _deployment?.operationLng ?? widget.schedule.operationArea.center.longitude,
                      ),
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2,
                      radius: _deployment?.operationRadius?.toDouble() ?? widget.schedule.operationArea.radiusInMeters,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Operation center
                    Marker(
                      point: LatLng(
                        _deployment?.operationLat ?? widget.schedule.operationArea.center.latitude,
                        _deployment?.operationLng ?? widget.schedule.operationArea.center.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                    // Docking point
                    Marker(
                      point: LatLng(
                        widget.schedule.dockingPoint.latitude,
                        widget.schedule.dockingPoint.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.anchor,
                        color: AppColors.success,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.primary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Operation Area',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.anchor, color: AppColors.success, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Docking Point',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComprehensiveResults() {
    if (_deployment == null) return const SizedBox();

    return Column(
      children: [
        // Performance Summary
        _buildPerformanceSummary(),
        const SizedBox(height: 12),

        // Water Quality Data
        if (_deployment!.waterQuality != null) ...[
          _buildWaterQualityCard(),
          const SizedBox(height: 12),
        ],

        // Trash Collection Details
        if (_deployment!.trashCollection != null) ...[
          _buildTrashCollectionCard(),
        ],
      ],
    );
  }

  Widget _buildPerformanceSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'Deployment Summary',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  Icons.delete_sweep,
                  'Trash Collected',
                  '${_deployment!.trashCollection?.totalWeight.toStringAsFixed(1) ?? '0'} kg',
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricBox(
                  Icons.category,
                  'Items Collected',
                  '${_deployment!.trashCollection?.totalItems ?? 0}',
                  AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_deployment!.areaCoveredPercentage != null)
                Expanded(
                  child: _buildMetricBox(
                    Icons.map,
                    'Area Covered',
                    '${_deployment!.areaCoveredPercentage!.toStringAsFixed(0)}%',
                    AppColors.primary,
                  ),
                ),
              if (_deployment!.distanceTraveled != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricBox(
                    Icons.straighten,
                    'Distance',
                    '${(_deployment!.distanceTraveled! / 1000).toStringAsFixed(2)} km',
                    AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterQualityCard() {
    final wq = _deployment!.waterQuality!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'Water Quality Metrics',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildWaterQualityItem(
                  'pH Level',
                  wq.avgPhLevel.toStringAsFixed(2),
                  _getPhQuality(wq.avgPhLevel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWaterQualityItem(
                  'Turbidity',
                  '${wq.avgTurbidity.toStringAsFixed(1)} NTU',
                  _getTurbidityQuality(wq.avgTurbidity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildWaterQualityItem(
                  'Temperature',
                  '${wq.avgTemperature.toStringAsFixed(1)}°C',
                  'Normal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWaterQualityItem(
                  'Dissolved O₂',
                  '${wq.avgDissolvedOxygen.toStringAsFixed(1)} mg/L',
                  _getDOQuality(wq.avgDissolvedOxygen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ${wq.sampleCount} samples',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCollectionCard() {
    final trash = _deployment!.trashCollection!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.recycling, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                'Trash Collection Breakdown',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (trash.trashByType.isNotEmpty) ...[
            ...trash.trashByType.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value} items',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${trash.totalWeight.toStringAsFixed(1)} kg',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildMetricBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterQualityItem(String label, String value, String quality) {
    Color qualityColor;
    switch (quality.toLowerCase()) {
      case 'good':
        qualityColor = AppColors.success;
        break;
      case 'moderate':
        qualityColor = AppColors.warning;
        break;
      case 'poor':
        qualityColor = AppColors.error;
        break;
      default:
        qualityColor = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: qualityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              quality,
              style: AppTextStyles.bodySmall.copyWith(
                color: qualityColor,
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }



  String _getPhQuality(double ph) {
    if (ph >= 6.5 && ph <= 8.5) return 'Good';
    if (ph >= 6.0 && ph <= 9.0) return 'Moderate';
    return 'Poor';
  }

  String _getTurbidityQuality(double turbidity) {
    if (turbidity < 5) return 'Good';
    if (turbidity < 25) return 'Moderate';
    return 'Poor';
  }

  String _getDOQuality(double dissolvedOxygen) {
    if (dissolvedOxygen >= 6) return 'Good';
    if (dissolvedOxygen >= 4) return 'Moderate';
    return 'Poor';
  }

  Widget _buildNotesCard() {
    final notes = _deployment?.notes ?? widget.schedule.notes;
    if (notes == null || notes.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13,
            ),
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

  String _getStatusDescription() {
    final status = _deployment?.status ?? widget.schedule.status;
    switch (status) {
      case 'scheduled':
        return 'Waiting for scheduled time';
      case 'active':
        return 'Cleanup operation in progress';
      case 'completed':
        return 'Cleanup successfully completed';
      case 'cancelled':
        return 'Schedule was cancelled';
      default:
        return '';
    }
  }
}
