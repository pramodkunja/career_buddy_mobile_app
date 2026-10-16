import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';

/// The native equivalent of `core/skillup_access.py`'s own `LOCKED_PAGE`
/// HTML (`SkillUpAccessMiddleware`'s 403 response body) — same copy, reused
/// verbatim rather than invented, but as a real Flutter view whose action
/// reaches this app's own verified Pro/Subscription route instead of the
/// live website's `/pro/` page a WebView's own rendering of that HTML would
/// otherwise have navigated to. See [SkillUpLessonScreen]'s own doc comment
/// for the full evidence behind when this is shown.
class SkillUpLockedView extends StatelessWidget {
  const SkillUpLockedView({required this.onViewPlans, super.key});

  final VoidCallback onViewPlans;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'This Skill Up content is locked',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Your Free plan includes English & Vocabulary, Grammar and one activity. Upgrade to unlock '
              'Aptitude, the Tech Center, the Non-IT Center and certifications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'View Plans',
              onPressed: onViewPlans,
              fullWidth: false,
              width: 180,
            ),
          ],
        ),
      ),
    );
  }
}
