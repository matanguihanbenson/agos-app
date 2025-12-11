import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'logging_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggingService _loggingService = LoggingService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Get user profile to get the name
        final userProfile = await getUserProfile(credential.user!.uid);
        final userName = userProfile != null 
            ? '${userProfile.firstName} ${userProfile.lastName}'
            : email;

        await _loggingService.logLogin(
          userId: credential.user!.uid,
          userName: userName,
          email: email,
        );
      }

      return credential;
    } catch (e) {
      // Log failed login attempt
      await _loggingService.logLoginFailed(
        email: email,
        reason: e.toString(),
      );
      await _loggingService.logError(
        error: e.toString(),
        context: 'sign_in',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loggingService.logAuthEvent(
          userId: credential.user!.uid,
          event: 'sign_up',
          metadata: {'email': email},
        );
      }

      return credential;
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'sign_up',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Sign up with email and create user profile
  Future<UserCredential> signUpWithEmailAndProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user profile in Firestore
        final userProfile = UserModel(
          id: credential.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          role: 'admin', // Self-registered users are admins
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        debugPrint('DEBUG: Creating user profile with role: ${userProfile.role}');
        debugPrint('DEBUG: User profile data: ${userProfile.toMap()}');
        
        await createUserProfile(userProfile);
        
        debugPrint('DEBUG: User profile created successfully');

        await _loggingService.logAuthEvent(
          userId: credential.user!.uid,
          event: 'sign_up_with_profile',
          metadata: {'email': email, 'role': 'admin'},
        );
      }

      return credential;
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'sign_up_with_profile',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final userId = currentUser?.uid;
      String? userName;
      
      if (userId != null) {
        // Get user profile to get the name before signing out
        final userProfile = await getUserProfile(userId);
        userName = userProfile != null 
            ? '${userProfile.firstName} ${userProfile.lastName}'
            : null;
      }
      
      await _auth.signOut();
      
      if (userId != null && userName != null) {
        await _loggingService.logLogout(
          userId: userId,
          userName: userName,
        );
      }
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'sign_out',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      await _loggingService.logPasswordResetRequested(
        email: email,
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'password_reset',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        await _loggingService.logAuthEvent(
          userId: user.uid,
          event: 'password_updated',
        );
      }
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'update_password',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Reauthenticate with current password and then update to a new password
  Future<void> reauthenticateAndUpdatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-logged-in',
          message: 'No authenticated user.',
        );
      }
      final email = user.email;
      if (email == null) {
        throw FirebaseAuthException(
          code: 'no-email',
          message: 'Your account does not have an email address.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      // Get user profile for logging
      final userProfile = await getUserProfile(user.uid);
      final userName = userProfile != null 
          ? '${userProfile.firstName} ${userProfile.lastName}'
          : email;

      await _loggingService.logPasswordChanged(
        userId: user.uid,
        userName: userName,
      );
    } on FirebaseAuthException catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'reauth_update_password',
        userId: currentUser?.uid,
      );
      rethrow;
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'reauth_update_password',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }

  // Get user profile from Firestore
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'get_user_profile',
        userId: userId,
      );
      return null;
    }
  }

  // Create user profile in Firestore
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toMap());
      await _loggingService.logEvent(
        event: 'user_profile_created',
        parameters: {'user_id': user.id},
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'create_user_profile',
        userId: user.id,
      );
      rethrow;
    }
  }

  // Update user profile in Firestore
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _loggingService.logEvent(
        event: 'user_profile_updated',
        parameters: {'user_id': userId},
      );
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'update_user_profile',
        userId: userId,
      );
      rethrow;
    }
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        // Delete user profile from Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        
        // Delete Firebase Auth user
        await user.delete();
        
        await _loggingService.logAuthEvent(
          userId: user.uid,
          event: 'account_deleted',
        );
      }
    } catch (e) {
      await _loggingService.logError(
        error: e.toString(),
        context: 'delete_user_account',
        userId: currentUser?.uid,
      );
      rethrow;
    }
  }
}
