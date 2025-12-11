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

class AssignBotPage extends ConsumerStatefulWidget {
  final BotModel? preSelectedBot;
  
  const AssignBotPage({super.key, this.preSelectedBot});

  @override
  ConsumerState<AssignBotPage> createState() => _AssignBotPageState();
}

class _AssignBotPageState extends ConsumerState<AssignBotPage> {
  BotModel? _selectedBot;
  UserModel? _selectedFieldOperator;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set pre-selected bot if provided
    _selectedBot = widget.preSelectedBot;
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

    // Filter bots owned by current admin and not assigned
    final availableBots = botState.bots
        .where((bot) => 
            bot.ownerAdminId == currentUserId && 
            bot.assignedTo == null)
        .toList();

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Assign Bot',
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
                        Icons.assignment,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Assign Bot to Field Operator',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a bot and field operator to create an assignment',
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
              'Select Bot',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            if (botState.isLoading)
              const LoadingIndicator(message: 'Loading bots...')
            else if (availableBots.isEmpty)
              const EmptyState(
                icon: Icons.directions_boat,
                title: 'No Available Bots',
                message: 'All your bots are already assigned or you have no bots.',
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: availableBots.length,
                  itemBuilder: (context, index) {
                    final bot = availableBots[index];
                    final isSelected = _selectedBot?.id == bot.id;
                    
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
                      subtitle: Text('ID: ${bot.id}'),
                      trailing: isSelected 
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedBot = bot;
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Field Operator Selection
            Text(
              'Select Field Operator',
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
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.primary : AppColors.background,
                          child: Text(
                            operator.initials,
                            style: TextStyle(
                              color: isSelected ? AppColors.surface : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          operator.fullName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(operator.email),
                        trailing: isSelected 
                            ? Icon(Icons.check_circle, color: AppColors.primary)
                            : null,
                        onTap: () {
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
                    text: 'Assign Bot',
                    onPressed: _selectedBot != null && _selectedFieldOperator != null
                        ? _assignBot
                        : null,
                    isLoading: _isLoading,
                    icon: Icons.assignment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignBot() async {
    if (_selectedBot == null || _selectedFieldOperator == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update bot with assignment
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
          'Bot ${_selectedBot!.name} assigned to ${_selectedFieldOperator!.fullName}',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(
          context,
          'Failed to assign bot. Please try again.',
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
