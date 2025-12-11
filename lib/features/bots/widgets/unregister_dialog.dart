import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/providers/schedule_provider.dart';

class UnregisterDialog extends ConsumerStatefulWidget {
  final BotModel bot;
  final VoidCallback? onUnregistered;

  const UnregisterDialog({
    super.key,
    required this.bot,
    this.onUnregistered,
  });

  @override
  ConsumerState<UnregisterDialog> createState() => _UnregisterDialogState();
}

class _UnregisterDialogState extends ConsumerState<UnregisterDialog> {
  bool _isLoading = false;

  Future<void> _unregisterBot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if bot has active or scheduled deployment
      final deploymentService = ref.read(deploymentServiceProvider);
      final hasActiveDeployment = await deploymentService.hasBotActiveOrScheduledDeployment(widget.bot.id);
      
      if (hasActiveDeployment) {
        throw Exception('Cannot unregister bot. This bot is currently scheduled or actively deployed. Please cancel or complete the deployment first.');
      }

      await ref.read(botProvider.notifier).deleteBot(widget.bot.id);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUnregistered?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unregister bot: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Unregister Bot',
        style: AppTextStyles.titleLarge,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to unregister this bot?',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bot Details:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Name: ${widget.bot.name}',
                  style: AppTextStyles.bodyMedium,
                ),
                Text(
                  'ID: ${widget.bot.id}',
                  style: AppTextStyles.bodyMedium,
                ),
                Text(
                  'Status: ${widget.bot.status}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This action cannot be undone. All bot data will be permanently deleted.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CustomButton(
          text: 'Unregister',
          onPressed: _isLoading ? null : _unregisterBot,
          isLoading: _isLoading,
          backgroundColor: AppColors.error,
        ),
      ],
    );
  }
}
