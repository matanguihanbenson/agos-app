import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/models/bot_model.dart';

class EditBotPage extends ConsumerStatefulWidget {
  final BotModel bot;

  const EditBotPage({
    super.key,
    required this.bot,
  });

  @override
  ConsumerState<EditBotPage> createState() => _EditBotPageState();
}

class _EditBotPageState extends ConsumerState<EditBotPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedOrganizationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill data
    _nameController.text = widget.bot.name;
    _selectedOrganizationId = widget.bot.organizationId;

    // Load organizations created by current admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser != null) {
        ref.read(organizationProvider.notifier).loadOrganizationsByCreator(currentUser.id);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateBot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final botService = ref.read(botServiceProvider);
      
      // Create updated bot model
      final updatedBot = widget.bot.copyWith(
        name: _nameController.text.trim(),
        organizationId: _selectedOrganizationId,
        updatedAt: DateTime.now(),
      );

      // Update bot in Firestore
      await botService.update(widget.bot.id, updatedBot.toMap());

      // Refresh the bot list
      ref.read(botProvider.notifier).loadBots();

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'Bot updated successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to update bot: ${e.toString()}');
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
    final organizationState = ref.watch(organizationProvider);

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Edit Bot',
        showDrawer: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              
              // Bot ID Field (Read-only)
              CustomTextField(
                controller: TextEditingController(text: widget.bot.id),
                label: 'Bot ID',
                hint: 'Bot identifier',
                prefixIcon: Icons.tag,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              
              // Bot Name Field
              CustomTextField(
                controller: _nameController,
                label: 'Bot Name *',
                hint: 'Enter bot name',
                prefixIcon: Icons.directions_boat,
                validator: (value) => Validators.validateRequired(value, 'Bot name'),
              ),
              const SizedBox(height: 12),
              
              // Organization Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization (Optional)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedOrganizationId,
                        hint: Text(
                          'Select organization (optional)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...organizationState.organizations.map((org) {
                            return DropdownMenuItem<String>(
                              value: org.id,
                              child: Text(org.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedOrganizationId = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Update Button
              CustomButton(
                text: 'Update Bot',
                onPressed: _isLoading ? null : _updateBot,
                isLoading: _isLoading,
                icon: Icons.save,
              ),
              const SizedBox(height: 12),
              
              // Cancel Button
              CustomButton(
                text: 'Cancel',
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                isOutlined: true,
                icon: Icons.cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
