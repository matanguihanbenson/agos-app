import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/activity_log_model.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/date_formatter.dart';

class ActivityLogDetailsPage extends StatelessWidget {
  final ActivityLogModel log;

  const ActivityLogDetailsPage({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'Log Details',
        showDrawer: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Icon with background
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _getSeverityColor(log.severity).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      _getTypeIcon(log.type),
                      color: _getSeverityColor(log.severity),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    log.title,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    log.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Severity Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(log.severity).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getSeverityColor(log.severity).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      log.severity.name.toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _getSeverityColor(log.severity),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details Section
            _buildSection(
              context,
              'General Information',
              [
                _buildDetailRow('Category', _formatCategory(log.category)),
                _buildDetailRow('Type', _formatType(log.type)),
                _buildDetailRow('Timestamp', DateFormatter.formatDateTime(log.timestamp)),
                _buildDetailRow('Platform', log.platform.toUpperCase()),
                if (log.ipAddress != null)
                  _buildDetailRow('IP Address', log.ipAddress!),
                if (log.deviceInfo != null)
                  _buildDetailRow('Device', log.deviceInfo!),
              ],
            ),

            // User Information
            if (log.userId != null || log.userName != null || 
                log.targetUserId != null || log.targetUserName != null)
              _buildSection(
                context,
                'User Information',
                [
                  if (log.userName != null)
                    _buildDetailRow('Performed By', log.userName!),
                  if (log.userId != null)
                    _buildDetailRow('User ID', log.userId!, monospace: true),
                  if (log.targetUserName != null)
                    _buildDetailRow('Target User', log.targetUserName!),
                  if (log.targetUserId != null)
                    _buildDetailRow('Target User ID', log.targetUserId!, monospace: true),
                ],
              ),

            // Bot Information
            if (log.botId != null || log.botName != null)
              _buildSection(
                context,
                'Bot Information',
                [
                  if (log.botName != null)
                    _buildDetailRow('Bot Name', log.botName!),
                  if (log.botId != null)
                    _buildDetailRow('Bot ID', log.botId!, monospace: true),
                ],
              ),

            // Organization Information
            if (log.organizationId != null || log.organizationName != null)
              _buildSection(
                context,
                'Organization Information',
                [
                  if (log.organizationName != null)
                    _buildDetailRow('Organization', log.organizationName!),
                  if (log.organizationId != null)
                    _buildDetailRow('Organization ID', log.organizationId!, monospace: true),
                ],
              ),

            // Metadata
            if (log.metadata.isNotEmpty)
              _buildSection(
                context,
                'Additional Metadata',
                log.metadata.entries.map((entry) {
                  return _buildDetailRow(
                    _formatMetadataKey(entry.key),
                    entry.value.toString(),
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
              },
              child: Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontFamily: monospace ? 'monospace' : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCategory(ActivityLogCategory category) {
    switch (category) {
      case ActivityLogCategory.system:
        return 'System';
      case ActivityLogCategory.auth:
        return 'Authentication';
      case ActivityLogCategory.user:
        return 'User Management';
      case ActivityLogCategory.bot:
        return 'Bot Operations';
    }
  }

  String _formatType(ActivityLogType type) {
    return type.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatMetadataKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  IconData _getTypeIcon(ActivityLogType type) {
    switch (type) {
      case ActivityLogType.login:
        return Icons.login_rounded;
      case ActivityLogType.logout:
        return Icons.logout_rounded;
      case ActivityLogType.loginFailed:
        return Icons.error_outline_rounded;
      case ActivityLogType.passwordChanged:
      case ActivityLogType.passwordResetRequested:
      case ActivityLogType.passwordResetCompleted:
        return Icons.lock_reset_rounded;
      case ActivityLogType.userCreated:
        return Icons.person_add_rounded;
      case ActivityLogType.userUpdated:
      case ActivityLogType.profileUpdated:
        return Icons.edit_rounded;
      case ActivityLogType.userDeleted:
        return Icons.person_remove_rounded;
      case ActivityLogType.userAssignedToOrg:
        return Icons.business_rounded;
      case ActivityLogType.userBotAssigned:
      case ActivityLogType.botAssigned:
        return Icons.assignment_ind_rounded;
      case ActivityLogType.botRegistered:
        return Icons.add_circle_outline_rounded;
      case ActivityLogType.botUnregistered:
        return Icons.remove_circle_outline_rounded;
      case ActivityLogType.botReassigned:
        return Icons.swap_horiz_rounded;
      case ActivityLogType.botUnassigned:
        return Icons.link_off_rounded;
      case ActivityLogType.scheduleCreated:
        return Icons.event_available_rounded;
      case ActivityLogType.scheduleCanceled:
        return Icons.event_busy_rounded;
      case ActivityLogType.deploymentStarted:
        return Icons.rocket_launch_rounded;
      case ActivityLogType.deploymentCompleted:
        return Icons.check_circle_outline_rounded;
      case ActivityLogType.deploymentFailed:
        return Icons.error_rounded;
      case ActivityLogType.systemError:
        return Icons.bug_report_rounded;
      case ActivityLogType.systemWarning:
        return Icons.warning_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getSeverityColor(ActivityLogSeverity severity) {
    switch (severity) {
      case ActivityLogSeverity.success:
        return AppColors.success;
      case ActivityLogSeverity.info:
        return AppColors.info;
      case ActivityLogSeverity.warning:
        return AppColors.warning;
      case ActivityLogSeverity.error:
      case ActivityLogSeverity.critical:
        return AppColors.error;
    }
  }
}
