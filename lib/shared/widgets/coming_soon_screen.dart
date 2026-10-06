import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Generic placeholder for a destination the web app has — and that a real
/// screen (e.g. the login screen's Forgot Password / Create Account /
/// Employer Portal links) points to — but that hasn't been built in Flutter
/// yet. Navigating here is real, working navigation; it deliberately does
/// NOT reproduce the destination's actual web functionality, which would
/// mean inventing behavior (a registration form, a password-reset flow,
/// an employer login form) beyond what's in scope for the screen that
/// links to it.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 40, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
