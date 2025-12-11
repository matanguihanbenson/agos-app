import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_bar.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/providers/auth_provider.dart';
import 'bottom_navigation.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onIndexChanged;

  const MainNavigation({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  String _getPageTitle(int index) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.userProfile?.isAdmin ?? false;
    
    if (isAdmin) {
      switch (index) {
        case 0: return 'Map';
        case 1: return 'Bots';
        case 2: return 'Dashboard';
        case 3: return 'Management';
        case 4: return 'Monitoring';
        default: return 'AGOS';
      }
    } else {
      switch (index) {
        case 0: return 'Map';
        case 1: return 'Control';
        case 2: return 'Dashboard';
        case 3: return 'Schedule';
        case 4: return 'Monitoring';
        default: return 'AGOS';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(title: _getPageTitle(widget.currentIndex)),
      body: widget.child,
      drawer: const AppSidebar(),
      bottomNavigationBar: RoleBasedBottomNavigation(
        currentIndex: widget.currentIndex,
        onTap: widget.onIndexChanged,
      ),
    );
  }
}
