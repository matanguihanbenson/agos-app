import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/text_styles.dart';
import '../../core/providers/auth_provider.dart';

class BottomNavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const BottomNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

class RoleBasedBottomNavigation extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const RoleBasedBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.userProfile?.isAdmin ?? false;
    
    final items = isAdmin ? _getAdminNavItems() : _getFieldOperatorNavItems();
    
    return BottomNavigationBar(
      currentIndex: currentIndex >= items.length ? 0 : currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
      unselectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
        fontSize: 11,
      ),
      elevation: 0,
      selectedIconTheme: const IconThemeData(size: 22),
      unselectedIconTheme: const IconThemeData(size: 20),
      items: items.map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        activeIcon: Icon(item.activeIcon),
        label: item.label,
      )).toList(),
    );
  }

  List<BottomNavigationItem> _getAdminNavItems() {
    return const [
      BottomNavigationItem(
        label: 'Map',
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
        route: '/map',
      ),
      BottomNavigationItem(
        label: 'Bots',
        icon: Icons.directions_boat_outlined,
        activeIcon: Icons.directions_boat,
        route: '/bots',
      ),
      BottomNavigationItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        route: '/dashboard',
      ),
      BottomNavigationItem(
        label: 'Management',
        icon: Icons.manage_accounts_outlined,
        activeIcon: Icons.manage_accounts,
        route: '/management',
      ),
      BottomNavigationItem(
        label: 'Monitoring',
        icon: Icons.monitor_outlined,
        activeIcon: Icons.monitor,
        route: '/monitoring',
      ),
    ];
  }

  List<BottomNavigationItem> _getFieldOperatorNavItems() {
    return const [
      BottomNavigationItem(
        label: 'Map',
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
        route: '/map',
      ),
      BottomNavigationItem(
        label: 'Control',
        icon: Icons.control_camera_outlined,
        activeIcon: Icons.control_camera,
        route: '/control',
      ),
      BottomNavigationItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        route: '/dashboard',
      ),
      BottomNavigationItem(
        label: 'Schedule',
        icon: Icons.schedule_outlined,
        activeIcon: Icons.schedule,
        route: '/schedule',
      ),
      BottomNavigationItem(
        label: 'Monitoring',
        icon: Icons.monitor_outlined,
        activeIcon: Icons.monitor,
        route: '/monitoring',
      ),
    ];
  }
}

// Legacy AppBottomNavigation for backward compatibility
class AppBottomNavigation extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationItem> items;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      selectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
      ),
      items: items.map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        activeIcon: Icon(item.activeIcon),
        label: item.label,
      )).toList(),
    );
  }
}
