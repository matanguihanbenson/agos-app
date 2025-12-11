import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/models/organization_model.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/providers/auth_provider.dart';

class AddOrganizationPage extends ConsumerStatefulWidget {
  const AddOrganizationPage({super.key});

  @override
  ConsumerState<AddOrganizationPage> createState() => _AddOrganizationPageState();
}

class _AddOrganizationPageState extends ConsumerState<AddOrganizationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      final organizationService = ref.read(organizationServiceProvider);
      
      // Create new organization
      final newOrganization = OrganizationModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? '' 
            : _descriptionController.text.trim(),
        address: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty 
            ? null 
            : _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty 
            ? null 
            : _contactPhoneController.text.trim(),
        status: 'active',
        createdBy: currentUser.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await organizationService.create(newOrganization);

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'Organization created successfully!');
        ref.read(organizationProvider.notifier).loadOrganizationsByCreator(currentUser.id);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to create organization: ${e.toString()}');
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
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Add Organization',
        showDrawer: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  
                  // Organization Information Section
                  _buildSectionHeader('Organization Information'),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _nameController,
                    label: 'Organization Name *',
                    hint: 'Enter organization name',
                    prefixIcon: Icons.business,
                    validator: (value) => Validators.validateRequired(value, 'Organization name'),
                  ),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Enter organization description',
                    prefixIcon: Icons.description,
                    maxLines: 3,
                    validator: null,
                  ),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _locationController,
                    label: 'Address',
                    hint: 'Enter organization address',
                    prefixIcon: Icons.location_on,
                    validator: null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Contact Information Section
                  _buildSectionHeader('Contact Information'),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _contactEmailController,
                    label: 'Contact Email',
                    hint: 'Enter contact email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        return Validators.validateEmail(value);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _contactPhoneController,
                    label: 'Contact Phone',
                    hint: 'Enter contact phone number',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: null,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons - Row layout
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Cancel',
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          isOutlined: true,
                          icon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'Create Organization',
                          onPressed: _isLoading ? null : _createOrganization,
                          isLoading: _isLoading,
                          icon: Icons.business,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: LoadingIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.titleSmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
