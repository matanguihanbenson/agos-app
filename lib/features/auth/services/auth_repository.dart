import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _authService.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    await _authService.updatePassword(newPassword);
  }

  // Get current user
  User? get currentUser => _authService.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Get user profile
  Future<UserModel?> getUserProfile(String userId) async {
    return await _authService.getUserProfile(userId);
  }

  // Create user profile
  Future<void> createUserProfile(UserModel user) async {
    await _authService.createUserProfile(user);
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await _authService.updateUserProfile(userId, data);
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    await _authService.deleteUserAccount();
  }
}
