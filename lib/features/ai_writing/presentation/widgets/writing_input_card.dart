import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/module_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/services/writing_validation.dart';

/// Mirrors the writing panel (`writing.html:152-170`): the always-visible,
/// always-editable textarea, its character counter/progress bar, a
/// validation alert, and "Submit for Analysis" — enabled only within
/// [kWritingMinChars]-[kWritingMaxChars] non-whitespace characters, exactly
/// like `updateWordGuard()`. Unlike AI Speaking's recorder card, this is
/// never replaced by the result — the web keeps the textarea visible and
/// resubmittable even after a successful analysis.
class WritingInputCard extends StatelessWidget {
  const WritingInputCard({
    required this.controller,
    required this.nonSpaceChars,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final int nonSpaceChars;
  final bool isSubmitting;
  final VoidCallback onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = nonSpaceChars > 0;
    final isWithinRange = nonSpaceChars >= kWritingMinChars && nonSpaceChars <= kWritingMaxChars;
    final progress = (nonSpaceChars / kWritingMaxChars).clamp(0.0, 1.0);
    // `.char-bar` (`writing.html:252`): too-short `#f59e0b` (matches
    // `AppColors.warning`), too-long `#dc2626` (distinct from the generic
    // `AppColors.danger`/`#EF4444`), good `#16a34a` — the module's own
    // green, not the generic `AppColors.success`/`#10B981`.
    final barColor = nonSpaceChars < kWritingMinChars
        ? AppColors.warning
        : nonSpaceChars > kWritingMaxChars
        ? const Color(0xFFDC2626)
        : ModuleColors.writing;

    String? alertMessage;
    if (hasText && nonSpaceChars < kWritingMinChars) {
      alertMessage = 'Please write at least $kWritingMinChars characters.';
    } else if (nonSpaceChars > kWritingMaxChars) {
      alertMessage = 'Please keep your answer within $kWritingMaxChars characters.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard, size: 18, color: ModuleColors.writing),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('Your Answer', style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$nonSpaceChars / $kWritingMinChars–$kWritingMaxChars chars',
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            maxLines: 8,
            minLines: 6,
            enabled: !isSubmitting,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: 'Write your response here (minimum 500 characters, maximum 900 characters)...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.background, color: barColor),
          ),
          if (alertMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(alertMessage, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning)),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: isSubmitting ? 'Analyzing…' : 'Submit for Analysis',
            icon: Icons.psychology_outlined,
            isLoading: isSubmitting,
            onPressed: (!isWithinRange || isSubmitting) ? null : onSubmit,
            backgroundColor: ModuleColors.writing,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}
