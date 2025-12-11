import 'package:flutter/material.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/constants/app_constants.dart';

class BotStatusIndicator extends StatelessWidget {
  final String status;
  final bool showLabel;

  const BotStatusIndicator({
    super.key,
    required this.status,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusConfig['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusConfig['color'].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusConfig['color'],
              shape: BoxShape.circle,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              statusConfig['label'],
              style: AppTextStyles.labelSmall.copyWith(
                color: statusConfig['color'],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case AppConstants.botStatusActive:
        return {
          'color': AppColors.botActive,
          'label': 'Active',
        };
      case AppConstants.botStatusInactive:
        return {
          'color': AppColors.botInactive,
          'label': 'Inactive',
        };
      case AppConstants.botStatusMaintenance:
        return {
          'color': AppColors.botMaintenance,
          'label': 'Maintenance',
        };
      case AppConstants.botStatusOffline:
        return {
          'color': AppColors.botOffline,
          'label': 'Offline',
        };
      default:
        return {
          'color': AppColors.textMuted,
          'label': 'Unknown',
        };
    }
  }
}
