import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/pages/login_page.dart';
import '../../app.dart';
import 'splash_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _showSplash = true;

  void _hideSplash() {
    if (_showSplash && mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen during animation
    if (_showSplash) {
      return SplashScreen(onComplete: _hideSplash);
    }

    // After splash, watch auth state
    final authState = ref.watch(authProvider);

    // Show loading only if auth is still initializing
    if (authState.isLoading) {
      // Use a transparent scaffold to avoid flash
      return const Scaffold(
        backgroundColor: Color(0xFF0066CC),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    // Show login page if not authenticated
    if (authState.userProfile == null) {
      return const LoginPage();
    }

    // Show main app if authenticated
    return const MainApp();
  }
}
