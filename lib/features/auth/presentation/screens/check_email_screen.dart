import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';

/// `templates/registration/password_reset_done.html`. The web flow's next
/// step (opening the emailed link) happens in the user's mail client; since
/// this app has no universal-link/app-link verification configured against
/// the production host, "I have my reset link" hands off to
/// [RoutePaths.resetPasswordConfirm], which asks the user to paste the
/// link's URL rather than requiring the email to deep-link straight into
/// the app — an explicit, documented mobile adaptation, not a missing
/// feature.
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check Your Email')),
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
                        child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF16A34A), size: 30),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Check your email',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "If an account exists for that email, we've sent a password reset "
                        'link. Please check your inbox (and spam folder). The link is '
                        'valid for a limited time.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'I have my reset link',
                        icon: Icons.link,
                        onPressed: () => context.push(RoutePaths.resetPasswordConfirm),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => context.go(RoutePaths.login),
                        child: const Text('Back to login'),
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
