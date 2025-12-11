import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';

class ScheduleCard extends StatelessWidget {
  final ScheduleModel schedule;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onRecall;
  final VoidCallback? onViewActions;

  const ScheduleCard({
    super.key,
    required this.schedule,
    this.onTap,
    this.onEdit,
    this.onCancel,
    this.onDelete,
    this.onRecall,
    this.onViewActions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Bot info and Status
              Row(
                children: [
                  // Bot Icon and Name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_boat,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          schedule.botName ?? schedule.botId,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Status Chip (on the right)
                  _buildStatusChip(),
                ],
              ),
              const SizedBox(height: 10),

              // Date and Time
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM d, y').format(schedule.scheduledDate),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('h:mm a').format(schedule.scheduledDate),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Location
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      schedule.operationArea.locationName ?? 'Coverage Area',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Action Buttons based on status
              const SizedBox(height: 10),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (schedule.status) {
      case 'scheduled':
        statusColor = AppColors.primary;
        statusIcon = Icons.schedule;
        statusText = 'Scheduled';
        break;
      case 'active':
        statusColor = AppColors.success;
        statusIcon = Icons.play_circle;
        statusText = 'Running';
        break;
      case 'completed':
        statusColor = const Color(0xFF757575);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: AppTextStyles.bodySmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Scheduled: Edit, Cancel, Delete
    if (schedule.isScheduled) {
      return Row(
        children: [
          if (onEdit != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit,
                label: 'Edit',
                onPressed: onEdit!,
              ),
            ),
          if (onEdit != null && onCancel != null) const SizedBox(width: 6),
          if (onCancel != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.cancel_outlined,
                label: 'Cancel',
                onPressed: onCancel!,
                color: AppColors.warning,
              ),
            ),
          if (onCancel != null && onDelete != null) const SizedBox(width: 6),
          if (onDelete != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed: onDelete!,
                color: AppColors.error,
              ),
            ),
        ],
      );
    }

    // Active: Recall only (pause removed)
    if (schedule.isActive) {
      return Row(
        children: [
          if (onRecall != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.replay,
                label: 'Recall Bot',
                onPressed: onRecall!,
                color: AppColors.info,
              ),
            ),
        ],
      );
    }

    // Completed: View Actions
    if (schedule.isCompleted) {
      return Row(
        children: [
          if (onViewActions != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.visibility_outlined,
                label: 'View Actions',
                onPressed: onViewActions!,
              ),
            ),
        ],
      );
    }

    // Default: Just View button
    return Row(
      children: [
        if (onTap != null)
          Expanded(
            child: _buildActionButton(
              icon: Icons.visibility_outlined,
              label: 'View Details',
              onPressed: onTap!,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primary;
    
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        side: BorderSide(color: buttonColor.withValues(alpha: 0.5), width: 1),
        foregroundColor: buttonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
