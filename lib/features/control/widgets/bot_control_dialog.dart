import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/bot_service.dart';

class BotControlDialog extends ConsumerStatefulWidget {
  final String action;
  final BotModel? bot;
  final List<BotModel> bots;
  final VoidCallback onComplete;

  const BotControlDialog({
    super.key,
    required this.action,
    this.bot,
    required this.bots,
    required this.onComplete,
  });

  @override
  ConsumerState<BotControlDialog> createState() => _BotControlDialogState();
}

class _BotControlDialogState extends ConsumerState<BotControlDialog> {
  final BotService _botService = BotService();
  BotModel? _selectedBot;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedBot = widget.bot;
  }

  String get _actionTitle {
    switch (widget.action) {
      case 'recall':
        return 'Recall Bot';
      case 'deploy':
        return 'Deploy Bot';
      case 'pause':
        return 'Pause Bot';
      case 'stop':
        return 'Stop Bot';
      default:
        return 'Control Bot';
    }
  }

  String get _actionDescription {
    switch (widget.action) {
      case 'recall':
        return 'This will command the bot to return to its starting point.';
      case 'deploy':
        return 'This will deploy the bot to start its operation.';
      case 'pause':
        return 'This will temporarily pause the bot\'s operation.';
      case 'stop':
        return 'This will stop the bot\'s current operation.';
      default:
        return 'Perform control action on selected bot.';
    }
  }

  Color get _actionColor {
    switch (widget.action) {
      case 'recall':
        return AppColors.warning;
      case 'deploy':
        return AppColors.success;
      case 'stop':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData get _actionIcon {
    switch (widget.action) {
      case 'recall':
        return Icons.replay;
      case 'deploy':
        return Icons.play_arrow;
      case 'pause':
        return Icons.pause;
      case 'stop':
        return Icons.stop;
      default:
        return Icons.control_camera;
    }
  }

  Future<void> _executeAction() async {
    if (_selectedBot == null) {
      _showSnackBar('Please select a bot', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      String newStatus;
      switch (widget.action) {
        case 'recall':
          newStatus = 'idle'; // Recalled bots become idle
          break;
        case 'deploy':
          newStatus = 'deployed';
          break;
        case 'pause':
        case 'stop':
          newStatus = 'idle';
          break;
        default:
          newStatus = 'idle';
      }

      // Update bot status in Firestore
      await _botService.updateBotStatus(_selectedBot!.id, newStatus);

      _showSnackBar('$_actionTitle executed successfully', isError: false);
      widget.onComplete();
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to execute ${_actionTitle.toLowerCase()}: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_actionIcon, color: _actionColor),
          const SizedBox(width: 12),
          Text(
            _actionTitle,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _actionDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Bot',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.bot != null)
              // If bot is pre-selected, show it as fixed
              _buildBotSelectionTile(widget.bot!, enabled: false)
            else
              // Otherwise show dropdown for bot selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BotModel>(
                    value: _selectedBot,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    hint: Text(
                      'Choose a bot...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    items: widget.bots.map((bot) {
                      return DropdownMenuItem<BotModel>(
                        value: bot,
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_boat,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    bot.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Status: ${bot.displayStatus}',
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
                    }).toList(),
                    onChanged: _isProcessing
                        ? null
                        : (BotModel? value) {
                            setState(() {
                              _selectedBot = value;
                            });
                          },
                  ),
                ),
              ),
            if (_selectedBot != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: _actionColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Status: ${_selectedBot!.displayStatus}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing || _selectedBot == null ? null : _executeAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: _actionColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
          ),
          child: _isProcessing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_actionTitle),
        ),
      ],
    );
  }

  Widget _buildBotSelectionTile(BotModel bot, {required bool enabled}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled ? AppColors.primary : AppColors.border.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_boat,
            size: 24,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bot.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Status: ${bot.displayStatus}',
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
}
