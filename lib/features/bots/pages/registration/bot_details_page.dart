import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/color_palette.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/snackbar_util.dart';
import '../../../../core/providers/organization_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../providers/bot_registration_provider.dart';

class BotDetailsPage extends ConsumerStatefulWidget {
  final String? scannedBotId;
  final Map<String, String>? preFilledData;

  const BotDetailsPage({
    super.key,
    this.scannedBotId,
    this.preFilledData,
  });

  @override
  ConsumerState<BotDetailsPage> createState() => _BotDetailsPageState();
}

class _BotDetailsPageState extends ConsumerState<BotDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _botIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedOrganizationId;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill data if provided
    if (widget.scannedBotId != null) {
      _botIdController.text = widget.scannedBotId!;
    }
    
    if (widget.preFilledData != null) {
      _nameController.text = widget.preFilledData!['name'] ?? '';
      _descriptionController.text = widget.preFilledData!['description'] ?? '';
      _locationController.text = widget.preFilledData!['location'] ?? '';
    }

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
    _botIdController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _registerBot() async {
    if (!_formKey.currentState!.validate()) return;

    final registrationNotifier = ref.read(botRegistrationProvider.notifier);
    final success = await registrationNotifier.registerBot(
      botId: _botIdController.text.trim(),
      name: _nameController.text.trim(),
      organizationId: _selectedOrganizationId,
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
    );

    if (success && mounted) {
      SnackbarUtil.showSuccess(context, 'Bot registered successfully!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      final registrationState = ref.read(botRegistrationProvider);
      if (registrationState.error != null) {
        SnackbarUtil.showError(context, registrationState.error!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationState = ref.watch(organizationProvider);
    final registrationState = ref.watch(botRegistrationProvider);

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Bot Details',
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
              // Bot ID Field
              CustomTextField(
                controller: _botIdController,
                label: 'Bot ID *',
                hint: 'Enter unique bot identifier',
                prefixIcon: Icons.tag,
                validator: Validators.validateBotId,
                readOnly: widget.scannedBotId != null,
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
                        items: organizationState.organizations.map((org) {
                          return DropdownMenuItem<String>(
                            value: org.id,
                            child: Text(org.name),
                          );
                        }).toList(),
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
              const SizedBox(height: 12),
              // Description Field
              CustomTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hint: 'Enter bot description',
                prefixIcon: Icons.description,
                maxLines: 2,
                validator: Validators.validateDescription,
              ),
              const SizedBox(height: 24),
              // Register Button
              CustomButton(
                text: 'Register Bot',
                onPressed: registrationState.isLoading ? null : _registerBot,
                isLoading: registrationState.isLoading,
                icon: Icons.add,
              ),
              const SizedBox(height: 12),
              // Back Button
              CustomButton(
                text: 'Back',
                onPressed: registrationState.isLoading ? null : () => Navigator.pop(context),
                isOutlined: true,
                icon: Icons.arrow_back,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
