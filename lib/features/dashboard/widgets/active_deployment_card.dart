import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/active_deployment_info.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';

class ActiveDeploymentCard extends StatelessWidget {
  final ActiveDeploymentInfo deployment;
  final VoidCallback? onTap;

  const ActiveDeploymentCard({
    super.key,
    required this.deployment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Schedule name and status
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deployment.scheduleName,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      deployment.statusDisplay,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bot and River info
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      icon: Icons.directions_boat,
                      label: deployment.botName,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      icon: Icons.water,
                      label: deployment.riverName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location and Battery
              Row(
                children: [
                  if (deployment.hasLocation)
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.location_on,
                        label: '${deployment.currentLat!.toStringAsFixed(4)}, ${deployment.currentLng!.toStringAsFixed(4)}',
                      ),
                    )
                  else
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.location_off,
                        label: 'No location',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (deployment.battery != null)
                    Expanded(
                      child: _buildInfoRow(
                        icon: _getBatteryIcon(deployment.battery!),
                        label: '${deployment.battery}%',
                        color: _getBatteryColor(deployment.battery!),
                      ),
                    ),
                ],
              ),

              // Trash collected (if available)
              if (deployment.trashCollected != null && deployment.trashCollected! > 0) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.delete_outline,
                  label: '${deployment.trashCollected!.toStringAsFixed(2)} kg collected',
                  color: AppColors.success,
                ),
              ],

              // Started time
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Started: ${_formatTime(deployment.scheduledStartTime)}',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color ?? AppColors.textPrimary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (deployment.status?.toLowerCase()) {
      case 'active':
      case 'deployed':
        return AppColors.success;
      case 'scheduled':
        return AppColors.info;
      case 'recalling':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getBatteryIcon(int battery) {
    if (battery > 80) return Icons.battery_full;
    if (battery > 50) return Icons.battery_5_bar;
    if (battery > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  Color _getBatteryColor(int battery) {
    if (battery > 20) return AppColors.success;
    return AppColors.error;
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }
}
