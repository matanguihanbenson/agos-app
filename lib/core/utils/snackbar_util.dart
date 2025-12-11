import 'package:flutter/material.dart';
import '../theme/color_palette.dart';

class SnackbarUtil {
  static ScaffoldMessengerState? _currentMessenger;

  static void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _hideCurrent();
    _currentMessenger = ScaffoldMessenger.of(context);

    _currentMessenger!.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _getSnackbarColor(type),
        duration: duration,
        behavior: SnackBarBehavior.fixed, // Stick to bottom, full width
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.error);
  }

  static void showInfo(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.info);
  }

  static void showWarning(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.warning);
  }

  static void _hideCurrent() {
    if (_currentMessenger != null) {
      _currentMessenger!.hideCurrentSnackBar();
      _currentMessenger = null;
    }
  }

  static Color _getSnackbarColor(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return AppColors.success;
      case SnackbarType.error:
        return AppColors.error;
      case SnackbarType.warning:
        return AppColors.warning;
      case SnackbarType.info:
        return AppColors.info;
    }
  }
}

enum SnackbarType { success, error, warning, info }
