import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/widgets/auth_wrapper.dart';
import 'features/bots/pages/bots_page.dart';
import 'features/map/pages/map_page.dart';
import 'features/control/pages/control_page.dart';
import 'features/management/pages/management_page.dart';
import 'features/monitoring/pages/monitoring_page.dart';
import 'features/schedule/pages/schedule_page.dart';
import 'features/dashboard/pages/dashboard_page.dart' as dashboard;
import 'shared/navigation/main_navigation.dart';
import 'core/providers/auth_provider.dart';

class AgosApp extends ConsumerWidget {
  const AgosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return MaterialApp(
      title: 'AGOS',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      onGenerateRoute: AppRoutes.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}


class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  int _currentIndex = 2; // Start at dashboard (index 2)

  // Lazy cache for pages after first visit to keep them mounted (for realtime streams)
  List<Widget?> _cachedPages = [];
  String? _roleKey; // 'admin' or 'fo'

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.userProfile?.isAdmin ?? false;
    final roleKey = isAdmin ? 'admin' : 'fo';

    // Define page builders for current role (closures avoid building until needed)
    final List<Widget Function()> builders = isAdmin
        ? [
            () => const MapPage(),
            () => const BotsPage(),
            () => const dashboard.DashboardPage(),
            () => const ManagementPage(),
            () => const MonitoringPage(),
          ]
        : [
            () => const MapPage(),
            () => const ControlPage(),
            () => const dashboard.DashboardPage(),
            () => const SchedulePage(),
            () => const MonitoringPage(),
          ];

    // Reset cache if role changes or size mismatch
    if (_roleKey != roleKey || _cachedPages.length != builders.length) {
      _roleKey = roleKey;
      _cachedPages = List<Widget?>.filled(builders.length, null, growable: false);
      // Keep current index within bounds
      if (_currentIndex >= builders.length) {
        _currentIndex = 0;
      }
    }

    final safeIndex = _currentIndex >= builders.length ? 0 : _currentIndex;

    // Ensure current page is instantiated and cached
    _cachedPages[safeIndex] ??= builders[safeIndex]();

    // Build children for IndexedStack lazily: previously visited pages stay mounted; others are placeholders
    final children = List<Widget>.generate(
      builders.length,
      (i) => _cachedPages[i] ?? const SizedBox.shrink(),
      growable: false,
    );

    return MainNavigation(
      currentIndex: safeIndex,
      onIndexChanged: (index) {
        setState(() {
          _currentIndex = index;
          // Instantiate on first visit so it stays mounted for realtime updates
          _cachedPages[index] ??= builders[index]();
        });
      },
      child: IndexedStack(
        index: safeIndex,
        children: children,
      ),
    );
  }
}

