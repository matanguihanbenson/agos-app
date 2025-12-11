import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'snackbar_util.dart';
import '../services/logging_service.dart';

class ErrorHandler {
  static final LoggingService _loggingService = LoggingService();

  static String getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  static String getFirestoreErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action.';
      case 'unavailable':
        return 'Service is currently unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please check your connection.';
      case 'not-found':
        return 'Requested data not found.';
      case 'already-exists':
        return 'The document already exists.';
      case 'resource-exhausted':
        return 'Resource limit exceeded. Please try again later.';
      case 'failed-precondition':
        return 'Operation failed due to a precondition.';
      case 'aborted':
        return 'Operation was aborted. Please try again.';
      case 'out-of-range':
        return 'Value is out of range.';
      case 'unimplemented':
        return 'This operation is not implemented.';
      case 'internal':
        return 'Internal server error. Please try again later.';
      case 'data-loss':
        return 'Data loss occurred. Please contact support.';
      default:
        return e.message ?? 'A database error occurred.';
    }
  }

  static void handleError({
    required BuildContext context,
    required dynamic error,
    required String errorContext,
    String? userId,
    bool showSnackbar = true,
  }) {
    String message = 'An unexpected error occurred.';
    
    if (error is FirebaseAuthException) {
      message = getFirebaseAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      message = getFirestoreErrorMessage(error);
    } else if (error is SocketException) {
      message = 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      message = 'Request timed out. Please try again.';
    } else {
      message = error.toString();
    }

    // Log the error
    _loggingService.logError(
      error: error.toString(),
      context: errorContext,
      userId: userId,
      stackTrace: StackTrace.current,
    );

    // Show user feedback
    if (showSnackbar) {
      SnackbarUtil.showError(context, message);
    }
  }

  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return getFirebaseAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      return getFirestoreErrorMessage(error);
    } else if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else {
      return error.toString();
    }
  }
}
