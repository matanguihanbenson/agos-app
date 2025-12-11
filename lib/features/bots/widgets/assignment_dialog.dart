import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/bot_provider.dart';

class AssignmentDialog extends ConsumerStatefulWidget {
  final BotModel bot;
  final VoidCallback? onAssigned;

  const AssignmentDialog({
    super.key,
    required this.bot,
    this.onAssigned,
  });

  @override
  ConsumerState<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends ConsumerState<AssignmentDialog> {
  UserModel? _selectedUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load users when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadUsers();
    });
  }

  Future<void> _assignBot() async {
    if (_selectedUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(botProvider.notifier).assignBotToUser(
        widget.bot.id,
        _selectedUser!.id,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAssigned?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign bot: $e'),
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
    final userState = ref.watch(userProvider);

    return AlertDialog(
      title: Text(
        'Assign Bot',
        style: AppTextStyles.titleLarge,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bot: ${widget.bot.name}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a user to assign this bot to:',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (userState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (userState.users.isEmpty)
            Text(
              'No users available',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: userState.users.length,
                itemBuilder: (context, index) {
                  final user = userState.users[index];
                  final isSelected = _selectedUser?.id == user.id;

                  return ListTile(
                    title: Text(user.fullName),
                    subtitle: Text(user.email),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedUser = user;
                      });
                    },
                  );
                },
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
          text: 'Assign',
          onPressed: _selectedUser != null && !_isLoading ? _assignBot : null,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
