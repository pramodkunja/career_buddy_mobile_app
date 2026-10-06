import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';

/// `templates/registration/password_reset_complete.html`.
class PasswordResetCompleteScreen extends StatelessWidget {
  const PasswordResetCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 30),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Password reset successful',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Your password has been updated. You can now log in with your new password.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Go to login',
                        icon: Icons.login,
                        onPressed: () => context.go(RoutePaths.login),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
