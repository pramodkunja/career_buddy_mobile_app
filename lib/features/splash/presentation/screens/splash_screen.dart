import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Shown only while [AuthController] resolves the cached session
/// (`AuthUnknown`); the router redirects away as soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.textOnDark),
      ),
    );
  }
}
