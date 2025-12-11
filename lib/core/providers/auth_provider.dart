import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';

class AuthState {
  final User? currentUser;
  final UserModel? userProfile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.currentUser,
    this.userProfile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? currentUser,
    UserModel? userProfile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => currentUser != null;
  bool get hasProfile => userProfile != null;
  bool get isAdmin => userProfile?.isAdmin ?? false;
  bool get isFieldOperator => userProfile?.isFieldOperator ?? false;
}


class AuthNotifier extends Notifier<AuthState> {
  PresenceSessionHandle? _presenceHandle;
  String? _sessionId;

  @override
  AuthState build() {
    final authService = ref.read(authServiceProvider);
    
    // Listen to auth state changes
    authService.authStateChanges.listen((user) async {
      if (user != null) {
        await _loadUserProfile(user.uid, authService);
        // After profile loaded, enforce single-session
        await _ensureSingleSession(user.uid);
      } else {
        // Release any presence handle
        await _releasePresence();
        // User signed out - clear all state
        state = const AuthState();
      }
    });
    
    // Set initial state based on current user
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      // Schedule loading for after build completes
      Future.microtask(() async {
        await _loadUserProfile(currentUser.uid, authService);
        await _ensureSingleSession(currentUser.uid);
      });
      // Return loading state initially
      return const AuthState(isLoading: true);
    } else {
      // No current user - return empty state
      return const AuthState();
    }
  }

  Future<void> _loadUserProfile(String userId, AuthService authService) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final userProfile = await authService.getUserProfile(userId);
      state = state.copyWith(
        currentUser: authService.currentUser,
        userProfile: userProfile,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmailAndProfile(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      final authService = ref.read(authServiceProvider);
      await _releasePresence();
      await authService.signOut();
      // Listener will update state
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updatePasswordWithCurrent(String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.reauthenticateAndUpdatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'The current password you entered is incorrect.';
          break;
        case 'weak-password':
          message = 'The new password is too weak. Please choose a stronger password.';
          break;
        case 'requires-recent-login':
          message = 'For security reasons, please sign in again and retry changing your password.';
          break;
        default:
          message = e.message ?? 'Failed to change password.';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> refreshUserProfile() async {
    if (state.currentUser != null) {
      final authService = ref.read(authServiceProvider);
      await _loadUserProfile(state.currentUser!.uid, authService);
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> _ensureSingleSession(String uid) async {
    try {
      // Avoid duplicate claims
      if (_presenceHandle != null) return;
      _sessionId ??= uid + '-' + DateTime.now().millisecondsSinceEpoch.toString();
      final presenceService = PresenceService();
      final isAdmin = state.userProfile?.isAdmin ?? false;
      final handle = await presenceService.claimUserSession(uid: uid, sessionId: _sessionId!, isAdmin: isAdmin);
      if (handle == null) {
        // Someone else is logged in; sign out immediately and show error
        state = state.copyWith(
          isLoading: false,
          error: 'Account is logged in on another device.',
        );
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        return;
      }
      _presenceHandle = handle;
    } catch (e) {
      // If presence claim fails, allow login but warn
      state = state.copyWith(error: 'Warning: Could not verify single-session: $e');
    }
  }

  Future<void> _releasePresence() async {
    try {
      await _presenceHandle?.release();
      _presenceHandle = null;
    } catch (_) {}
  }
} 

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
