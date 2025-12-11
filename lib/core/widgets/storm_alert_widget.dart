import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../theme/color_palette.dart';
import '../theme/text_styles.dart';

class StormAlertWidget extends ConsumerStatefulWidget {
  const StormAlertWidget({super.key});

  @override
  ConsumerState<StormAlertWidget> createState() => _StormAlertWidgetState();
}

class _StormAlertWidgetState extends ConsumerState<StormAlertWidget> {
  StreamSubscription<DatabaseEvent>? _alertSubscription;
  StormAlertData? _currentAlert;

  @override
  void initState() {
    super.initState();
    _listenToStormAlerts();
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  void _listenToStormAlerts() {
    final db = FirebaseDatabase.instance.ref();
    
    // Listen to weather_alerts node in RTDB
    _alertSubscription = db.child('weather_alerts/current').onValue.listen((event) {
      if (!mounted) return;
      
      try {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final rawValue = event.snapshot.value;
          
          if (rawValue is Map) {
            final data = Map<String, dynamic>.from(rawValue as Map);
            
            // Check if alert is active
            final isActive = data['active'] == true;
            
            print('Storm Alert Data: $data'); // Debug log
            print('Alert Active: $isActive'); // Debug log
            
            if (isActive) {
              setState(() {
                _currentAlert = StormAlertData.fromMap(data);
              });
            } else {
              setState(() {
                _currentAlert = null;
              });
            }
          } else {
            print('Storm Alert: Invalid data type: ${rawValue.runtimeType}'); // Debug log
            setState(() {
              _currentAlert = null;
            });
          }
        } else {
          print('Storm Alert: No data exists'); // Debug log
          setState(() {
            _currentAlert = null;
          });
        }
      } catch (e) {
        print('Storm Alert Error: $e'); // Debug log
        setState(() {
          _currentAlert = null;
        });
      }
    }, onError: (error) {
      print('Storm Alert Stream Error: $error'); // Debug log
      if (mounted) {
        setState(() {
          _currentAlert = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If no alert or alert level is 'none', show minimal green "All Clear" widget
    if (_currentAlert == null || _currentAlert!.level == StormAlertLevel.none) {
      return _buildAllClearWidget();
    }

    // Show active alert
    return _buildAlertWidget(_currentAlert!);
  }

  Widget _buildAllClearWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Clear',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'No storm alerts at this time',
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

  Widget _buildAlertWidget(StormAlertData alert) {
    final Color alertColor = _getAlertColor(alert);
    final IconData alertIcon = _getAlertIcon(alert);
    final String alertText = _getAlertText(alert);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  alertIcon,
                  color: alertColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storm Alert',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      alertText,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: alertColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (alert.autoRecallEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.autorenew, size: 14, color: AppColors.info),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-Recall',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (alert.message != null && alert.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: alertColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.message!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.thermostat,
                'Wind',
                alert.windSpeed != null ? '${alert.windSpeed!.toStringAsFixed(0)} km/h' : 'N/A',
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.water_drop,
                'Pressure',
                alert.pressure != null ? '${alert.pressure!.toStringAsFixed(0)} hPa' : 'N/A',
              ),
            ],
          ),
          if (alert.autoRecallTriggered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency recall has been triggered for all active bots',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (alert.lastUpdated != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Last updated: ${_formatTimestamp(alert.lastUpdated!)}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAlertColor(StormAlertData alert) {
    // Check for rain type first
    if (alert.type == 'rain') {
      return Colors.blue.shade700;
    }
    
    // Otherwise use level-based colors
    switch (alert.level) {
      case StormAlertLevel.none:
        return AppColors.success;
      case StormAlertLevel.low:
        return Colors.lightBlue;
      case StormAlertLevel.medium:
      case StormAlertLevel.warning:
        return AppColors.warning;
      case StormAlertLevel.high:
        return Colors.orange;
      case StormAlertLevel.critical:
        return AppColors.error;
    }
  }

  IconData _getAlertIcon(StormAlertData alert) {
    // Check for rain type first
    if (alert.type == 'rain') {
      return Icons.water_drop_rounded;
    }
    
    // Otherwise use level-based icons
    switch (alert.level) {
      case StormAlertLevel.none:
        return Icons.check_circle;
      case StormAlertLevel.low:
        return Icons.cloud_outlined;
      case StormAlertLevel.medium:
      case StormAlertLevel.warning:
        return Icons.cloud_queue;
      case StormAlertLevel.high:
        return Icons.thunderstorm;
      case StormAlertLevel.critical:
        return Icons.warning_amber_rounded;
    }
  }

  String _getAlertText(StormAlertData alert) {
    // Check for rain type first
    if (alert.type == 'rain') {
      return 'Rain Detected';
    }
    
    // Otherwise use level-based text
    switch (alert.level) {
      case StormAlertLevel.none:
        return 'All Clear';
      case StormAlertLevel.low:
        return 'Low Risk';
      case StormAlertLevel.medium:
        return 'Medium Risk';
      case StormAlertLevel.warning:
        return 'Weather Warning';
      case StormAlertLevel.high:
        return 'High Risk';
      case StormAlertLevel.critical:
        return 'CRITICAL';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

enum StormAlertLevel {
  none,
  low,
  medium,
  warning,
  high,
  critical,
}

class StormAlertData {
  final String? type; // 'rain', 'storm', 'typhoon', etc.
  final StormAlertLevel level;
  final String? message;
  final bool autoRecallEnabled;
  final bool autoRecallTriggered;
  final double? windSpeed; // km/h
  final double? pressure; // hPa
  final DateTime? lastUpdated;

  StormAlertData({
    this.type,
    required this.level,
    this.message,
    required this.autoRecallEnabled,
    required this.autoRecallTriggered,
    this.windSpeed,
    this.pressure,
    this.lastUpdated,
  });

  factory StormAlertData.fromMap(Map<String, dynamic> map) {
    final levelStr = (map['level'] as String?)?.toLowerCase() ?? 'none';
    StormAlertLevel level;
    
    switch (levelStr) {
      case 'low':
        level = StormAlertLevel.low;
        break;
      case 'medium':
        level = StormAlertLevel.medium;
        break;
      case 'warning':
        level = StormAlertLevel.warning;
        break;
      case 'high':
        level = StormAlertLevel.high;
        break;
      case 'critical':
        level = StormAlertLevel.critical;
        break;
      default:
        level = StormAlertLevel.none;
    }

    final updatedAtMs = map['updated_at'] as int?;

    return StormAlertData(
      type: map['type'] as String?,
      level: level,
      message: map['message'] as String?,
      autoRecallEnabled: map['auto_recall_enabled'] == true,
      autoRecallTriggered: map['auto_recall_triggered'] == true,
      windSpeed: (map['wind_speed'] as num?)?.toDouble(),
      pressure: (map['pressure'] as num?)?.toDouble(),
      lastUpdated: updatedAtMs != null 
          ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
          : null,
    );
  }
}

