import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/utils/snackbar_util.dart';

class UnregisterBotPage extends ConsumerStatefulWidget {
  const UnregisterBotPage({super.key});

  @override
  ConsumerState<UnregisterBotPage> createState() => _UnregisterBotPageState();
}

class _UnregisterBotPageState extends ConsumerState<UnregisterBotPage> {
  final Set<String> _selectedBotIds = <String>{};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(botProvider.notifier).loadBots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final botState = ref.watch(botProvider);
    final currentUserId = authState.userProfile?.id;

    // Filter bots owned by current admin
    final ownedBots = botState.bots
        .where((bot) => bot.ownerAdminId == currentUserId)
        .toList();

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Unregister Bots',
        showDrawer: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Unregister Bots',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select bots to unregister. This action cannot be undone and will remove the bots from your system permanently.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selection Info
            if (_selectedBotIds.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_selectedBotIds.length} bot${_selectedBotIds.length == 1 ? '' : 's'} selected for unregistration',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bot List
            Text(
              'Your Bots',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            if (botState.isLoading)
              const Expanded(
                child: LoadingIndicator(message: 'Loading bots...'),
              )
            else if (ownedBots.isEmpty)
              const Expanded(
                child: EmptyState(
                  icon: Icons.directions_boat,
                  title: 'No Bots Found',
                  message: 'You don\'t have any bots to unregister.',
                ),
              )
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: ownedBots.length,
                    itemBuilder: (context, index) {
                      final bot = ownedBots[index];
                      final isSelected = _selectedBotIds.contains(bot.id);
                      
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedBotIds.add(bot.id);
                            } else {
                              _selectedBotIds.remove(bot.id);
                            }
                          });
                        },
                        secondary: Icon(
                          Icons.directions_boat,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        title: Text(
                          bot.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${bot.id}'),
                            if (bot.assignedTo != null)
                              Text(
                                'Assigned to field operator',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        activeColor: AppColors.primary,
                        checkColor: AppColors.surface,
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Unregister Selected',
                    onPressed: _selectedBotIds.isNotEmpty ? _showConfirmationDialog : null,
                    isLoading: _isLoading,
                    icon: Icons.remove_circle,
                    backgroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.error),
            const SizedBox(width: 12),
            const Text('Confirm Unregistration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to unregister ${_selectedBotIds.length} bot${_selectedBotIds.length == 1 ? '' : 's'}?',
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will:',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Permanently remove the bots from your system\n'
                    '• Unassign them from any field operators\n'
                    '• Delete all associated data\n'
                    '• Cannot be undone',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unregisterBots();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Unregister'),
          ),
        ],
      ),
    );
  }

  Future<void> _unregisterBots() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final botNotifier = ref.read(botProvider.notifier);
      
      for (final botId in _selectedBotIds) {
        await botNotifier.deleteBot(botId);
      }

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          '${_selectedBotIds.length} bot${_selectedBotIds.length == 1 ? '' : 's'} unregistered successfully',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(
          context,
          'Failed to unregister bots. Please try again.',
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
}
