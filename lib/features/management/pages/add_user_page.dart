import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

class AddUserPage extends ConsumerStatefulWidget {
  const AddUserPage({super.key});

  @override
  ConsumerState<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends ConsumerState<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = ref.read(authProvider).userProfile;
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      final userService = ref.read(userServiceProvider);
      final authService = AuthService();

      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      // 1) Create Firebase Auth user for this field operator
      final credential = await authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('Failed to create authentication account for user');
      }

      // 2) Create Firestore user profile linked to that Auth UID
      final newUser = UserModel(
        id: uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        role: 'field_operator',
        status: 'active',
        createdBy: currentUser.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // IMPORTANT: Use AuthService to ensure the Firestore doc ID matches the Auth UID
      await authService.createUserProfile(newUser);

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'User created successfully!');
        ref.read(userProvider.notifier).loadUsersByCreator(currentUser.id);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String message;
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              message = 'The email address is already in use. Please use a different email.';
              break;
            case 'invalid-email':
              message = 'The email address is invalid. Please check and try again.';
              break;
            case 'weak-password':
              message = 'The password is too weak. Please choose a stronger password.';
              break;
            default:
              message = e.message ?? 'An authentication error occurred. Please try again.';
          }
        } else {
          message = e.toString().replaceFirst('Exception: ', '');
        }
        SnackbarUtil.showError(context, 'Failed to create user: $message');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Add User',
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
                  
                  // Personal Information Section
                  _buildSectionHeader('User Information'),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _firstNameController,
                          label: 'First Name *',
                          hint: 'Enter first name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) => Validators.validateRequired(value, 'First name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          controller: _lastNameController,
                          label: 'Last Name *',
                          hint: 'Enter last name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) => Validators.validateRequired(value, 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email *',
                    hint: 'Enter email address',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Role Information (Read-only)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Role: Field Operator',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Security Section
                  _buildSectionHeader('Security'),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password *',
                    hint: 'Enter password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 12),
                  
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password *',
                    hint: 'Confirm password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    validator: _validateConfirmPassword,
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
                          text: 'Create User',
                          onPressed: _isLoading ? null : _createUser,
                          isLoading: _isLoading,
                          icon: Icons.person_add,
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
