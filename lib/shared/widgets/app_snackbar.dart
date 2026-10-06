import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Standard snackbar feedback, so success/error styling stays consistent
/// instead of every screen building its own [SnackBar].
abstract final class AppSnackbar {
  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.danger);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.success);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
