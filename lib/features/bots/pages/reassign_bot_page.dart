import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/utils/snackbar_util.dart';

class ReassignBotPage extends ConsumerStatefulWidget {
  const ReassignBotPage({super.key});

  @override
  ConsumerState<ReassignBotPage> createState() => _ReassignBotPageState();
}

class _ReassignBotPageState extends ConsumerState<ReassignBotPage> {
  BotModel? _selectedBot;
  UserModel? _selectedFieldOperator;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    ref.read(userProvider.notifier).loadUsers();
    ref.read(botProvider.notifier).loadBots();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userState = ref.watch(userProvider);
    final botState = ref.watch(botProvider);
    final currentUserId = authState.userProfile?.id;

    // Filter field operators created by current admin
    final fieldOperators = userState.users
        .where((user) => 
            user.role == 'field_operator' && 
            user.createdBy == currentUserId)
        .toList();

    // Filter bots owned by current admin and already assigned
    final assignedBots = botState.bots
        .where((bot) => 
            bot.ownerAdminId == currentUserId && 
            bot.assignedTo != null)
        .toList();

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Reassign Bot',
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Reassign Bot to Different Operator',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select an assigned bot and reassign it to a different field operator',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bot Selection
            Text(
              'Select Assigned Bot',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            if (botState.isLoading)
              const LoadingIndicator(message: 'Loading bots...')
            else if (assignedBots.isEmpty)
              const EmptyState(
                icon: Icons.directions_boat,
                title: 'No Assigned Bots',
                message: 'You have no bots that are currently assigned.',
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: assignedBots.length,
                  itemBuilder: (context, index) {
                    final bot = assignedBots[index];
                    final isSelected = _selectedBot?.id == bot.id;
                    
                    // Find current assigned operator
                    final currentOperator = fieldOperators
                        .where((op) => op.id == bot.assignedTo)
                        .firstOrNull;
                    
                    return ListTile(
                      leading: Icon(
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
                      subtitle: Text(
                        'ID: ${bot.id}\nCurrently assigned to: ${currentOperator?.fullName ?? 'Unknown'}',
                      ),
                      trailing: isSelected 
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedBot = bot;
                          // Reset field operator selection when bot changes
                          _selectedFieldOperator = null;
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Field Operator Selection
            Text(
              'Reassign to Field Operator',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            if (userState.isLoading)
              const LoadingIndicator(message: 'Loading field operators...')
            else if (fieldOperators.isEmpty)
              const EmptyState(
                icon: Icons.person,
                title: 'No Field Operators',
                message: 'You haven\'t created any field operators yet.',
              )
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: fieldOperators.length,
                    itemBuilder: (context, index) {
                      final operator = fieldOperators[index];
                      final isSelected = _selectedFieldOperator?.id == operator.id;
                      final isCurrentlyAssigned = _selectedBot?.assignedTo == operator.id;
                      
                      return ListTile(
                        enabled: !isCurrentlyAssigned,
                        leading: CircleAvatar(
                          backgroundColor: isCurrentlyAssigned 
                              ? AppColors.textMuted
                              : isSelected 
                                  ? AppColors.primary 
                                  : AppColors.background,
                          child: Text(
                            operator.initials,
                            style: TextStyle(
                              color: isCurrentlyAssigned
                                  ? AppColors.surface
                                  : isSelected 
                                      ? AppColors.surface 
                                      : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          operator.fullName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isCurrentlyAssigned
                                ? AppColors.textMuted
                                : isSelected 
                                    ? AppColors.primary 
                                    : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          isCurrentlyAssigned 
                              ? '${operator.email} (Currently assigned)'
                              : operator.email,
                          style: TextStyle(
                            color: isCurrentlyAssigned 
                                ? AppColors.textMuted 
                                : AppColors.textSecondary,
                          ),
                        ),
                        trailing: isSelected 
                            ? Icon(Icons.check_circle, color: AppColors.primary)
                            : isCurrentlyAssigned
                                ? Icon(Icons.person, color: AppColors.textMuted)
                                : null,
                        onTap: isCurrentlyAssigned ? null : () {
                          setState(() {
                            _selectedFieldOperator = operator;
                          });
                        },
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
                    text: 'Reassign Bot',
                    onPressed: _selectedBot != null && _selectedFieldOperator != null
                        ? _reassignBot
                        : null,
                    isLoading: _isLoading,
                    icon: Icons.swap_horiz,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reassignBot() async {
    if (_selectedBot == null || _selectedFieldOperator == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update bot with new assignment
      await ref.read(botProvider.notifier).updateBot(
        _selectedBot!.id,
        {
          'assigned_to': _selectedFieldOperator!.id,
          'assigned_at': DateTime.now(),
          'updated_at': DateTime.now(),
        },
      );

      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'Bot ${_selectedBot!.name} reassigned to ${_selectedFieldOperator!.fullName}',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(
          context,
          'Failed to reassign bot. Please try again.',
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
