import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/color_palette.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/snackbar_util.dart';
import '../../providers/bot_registration_provider.dart';
import '../../../../core/services/bot_service.dart';
import '../../../../core/providers/bot_provider.dart';
import 'qr_scan_page.dart';
import 'bot_details_page.dart';

class MethodSelectionPage extends ConsumerStatefulWidget {
  const MethodSelectionPage({super.key});

  @override
  ConsumerState<MethodSelectionPage> createState() => _MethodSelectionPageState();
}

class _MethodSelectionPageState extends ConsumerState<MethodSelectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _botIdController = TextEditingController();
  bool _showManualEntry = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _botIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Register Bot',
        showDrawer: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_boat,
                    size: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register New Bot',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your preferred registration method',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Registration Options
            Row(
              children: [
                // QR Code Scan Option
                Expanded(
                  child: _buildRegistrationOption(
                    context,
                    icon: Icons.qr_code_scanner,
                    title: 'QR Scan',
                    description: 'Scan bot QR code for quick setup',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRScanPage(),
                        ),
                      );
                    },
                    isSelected: !_showManualEntry,
                  ),
                ),
                const SizedBox(width: 16),
                // Manual Entry Option
                Expanded(
                  child: _buildRegistrationOption(
                    context,
                    icon: Icons.edit,
                    title: 'Manual',
                    description: 'Validate bot ID from registry',
                    onTap: () {
                      setState(() {
                        _showManualEntry = true;
                      });
                    },
                    isOutlined: true,
                    isSelected: _showManualEntry,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Manual Entry Form (conditionally shown)
            if (_showManualEntry) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bot ID Validation',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showManualEntry = false;
                                _botIdController.clear();
                              });
                            },
                            icon: const Icon(Icons.close, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _botIdController,
                        label: 'Bot ID',
                        hint: 'Enter the bot ID from registry',
                        prefixIcon: Icons.directions_boat,
                        validator: (value) => Validators.validateRequired(value, 'Bot ID'),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Validate Bot',
                        onPressed: _isLoading ? null : _validateBot,
                        isLoading: _isLoading,
                        icon: Icons.verified,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Add some bottom spacing to ensure content is visible above keyboard
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isOutlined = false,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withValues(alpha: 0.2)
              : isOutlined 
                  ? Colors.transparent 
                  : AppColors.primary.withValues(alpha: 0.1),
          border: Border.all(
            color: isSelected 
                ? AppColors.primary
                : isOutlined 
                    ? AppColors.border 
                    : AppColors.primary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected 
                  ? AppColors.primary
                  : isOutlined 
                      ? AppColors.textSecondary 
                      : AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected 
                    ? AppColors.primary
                    : isOutlined 
                        ? AppColors.textPrimary 
                        : AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validateBot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final botRegistryService = ref.read(botRegistryServiceProvider);
      final botId = _botIdController.text.trim();
      
      // Check if bot exists in registry
      final botExists = await botRegistryService.botIdExists(botId);
      
      if (!botExists) {
        // Bot doesn't exist in registry
        if (mounted) {
          SnackbarUtil.showError(
            context,
            'Bot ID "$botId" not found in the registry. Please check the ID and try again.',
          );
        }
        return;
      }
      
      // Check if bot is already registered
      final isAlreadyRegistered = await botRegistryService.isBotRegistered(botId);
      
      if (isAlreadyRegistered) {
        if (mounted) {
          SnackbarUtil.showError(
            context,
            'Bot "$botId" is already registered. Cannot proceed with registration.',
          );
        }
        return;
      }
      
      // Bot exists and is not registered, proceed to bot details
      if (mounted) {
        SnackbarUtil.showSuccess(
          context,
          'Bot ID validated successfully!',
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BotDetailsPage(scannedBotId: botId),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(
          context,
          'Failed to validate bot ID. Please try again.',
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
