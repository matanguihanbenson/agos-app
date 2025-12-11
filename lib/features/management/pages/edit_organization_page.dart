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

class EditOrganizationPage extends ConsumerStatefulWidget {
  final OrganizationModel organization;
  
  const EditOrganizationPage({
    super.key,
    required this.organization,
  });

  @override
  ConsumerState<EditOrganizationPage> createState() => _EditOrganizationPageState();
}

class _EditOrganizationPageState extends ConsumerState<EditOrganizationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactPhoneController;
  late String _status;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.organization.name);
    _descriptionController = TextEditingController(text: widget.organization.description);
    _locationController = TextEditingController(text: widget.organization.address ?? '');
    _contactEmailController = TextEditingController(text: widget.organization.contactEmail ?? '');
    _contactPhoneController = TextEditingController(text: widget.organization.contactPhone ?? '');
    _status = widget.organization.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _updateOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent duplicate submission
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final organizationService = ref.read(organizationServiceProvider);
      
      // Update organization data
      await organizationService.update(widget.organization.id, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'address': _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        'contact_email': _contactEmailController.text.trim().isEmpty 
            ? null 
            : _contactEmailController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim().isEmpty 
            ? null 
            : _contactPhoneController.text.trim(),
        'status': _status,
        'updated_at': DateTime.now(),
      });

      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser != null && mounted) {
        ref.read(organizationProvider.notifier).loadOrganizationsByCreator(currentUser.id);
        SnackbarUtil.showSuccess(context, 'Organization updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to update organization: ${e.toString()}');
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
        title: 'Edit Organization',
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
                  
                  const SizedBox(height: 16),
                  
                  // Status Section
                  _buildSectionHeader('Status'),
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.toggle_on, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Organization Status',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _status,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _status = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
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
                          text: 'Update Organization',
                          onPressed: _isLoading ? null : _updateOrganization,
                          isLoading: _isLoading,
                          icon: Icons.save,
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
