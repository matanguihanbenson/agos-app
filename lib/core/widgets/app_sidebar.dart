import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/text_styles.dart';
import '../theme/color_palette.dart';
import '../providers/auth_provider.dart';
import '../constants/app_constants.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.userProfile;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header with app branding only
            _buildHeader(context, user),
            
            // Navigation links
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 12),
                  
                  // User Profile Section
                  _buildUserProfileSection(user),
                  
                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    height: 1,
                    color: AppColors.border,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _buildNavItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'View Profile',
                    onTap: () => _navigateToProfile(context),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () => _navigateToChangePassword(context),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.history,
                    title: 'Activity Logs',
                    onTap: () => _navigateToActivityLogs(context),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.route,
                    title: 'Deployment History',
                    onTap: () => _navigateToDeploymentHistory(context),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.water,
                    title: 'Rivers Management',
                    onTap: () => _navigateToRivers(context),
                  ),
                  // Show schedule link for admin users only
                  if (user?.role == AppConstants.adminRole)
                    _buildNavItem(
                      context,
                      icon: Icons.calendar_month,
                      title: 'All Schedules',
                      onTap: () => _navigateToSchedules(context),
                    ),
                ],
              ),
            ),
            
            // Footer links
            _buildFooter(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/backgrounds/sidebar-min.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App Logo and Name Section - Centered
          Column(
            children: [
              // App Logo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/logos/logo-white.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              
              // App Name and Subtitle
              Column(
                children: [
                  Text(
                    'AGOS',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Autonomous Garbage-cleaning Operation System',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileSection(dynamic user) {
    final initials = user?.initials ?? 'U';
    final fullName = user?.fullName ?? 'User';
    final role = user?.role ?? 'Unknown';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Profile avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRole(role),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.textSecondary,
        size: 20,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavItem(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => _navigateToSettings(context),
          ),
          _buildNavItem(
            context,
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case AppConstants.adminRole:
        return 'Administrator';
      case AppConstants.fieldOperatorRole:
        return 'Field Operator';
      default:
        return role.replaceAll('_', ' ').split(' ')
            .map((word) => word.isNotEmpty 
                ? word[0].toUpperCase() + word.substring(1).toLowerCase() 
                : '')
            .join(' ');
    }
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  void _navigateToChangePassword(BuildContext context) {
    Navigator.pushNamed(context, '/change-password');
  }

  void _navigateToActivityLogs(BuildContext context) {
    Navigator.pushNamed(context, '/activity-logs');
  }

  void _navigateToDeploymentHistory(BuildContext context) {
    Navigator.pushNamed(context, '/deployment-history');
  }

  void _navigateToRivers(BuildContext context) {
    Navigator.pushNamed(context, '/rivers');
  }

  void _navigateToSchedules(BuildContext context) {
    Navigator.pushNamed(context, '/schedules-admin');
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.pushNamed(context, '/settings');
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authProvider.notifier); // cache before dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out',
          style: AppTextStyles.titleLarge,
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await authNotifier.signOut();
                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // Show error message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Sign Out',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
