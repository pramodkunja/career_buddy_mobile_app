import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../controllers/mark_sub_complete_controller.dart';

/// Mirrors `templates/activities/sub_activity.html:157-185` exactly:
/// - Not completed: a card explaining the gating rule (all exercises must
///   be done first — a client-side-only rule on the web too, see
///   `MarkSubCompleteController`'s doc comment) with a disabled/enabled
///   "Mark Complete" button.
/// - Completed: a banner with the completion date, and the card is gone
///   entirely (the web has no "unmark" action).
class MarkCompleteSection extends StatelessWidget {
  const MarkCompleteSection({
    required this.allExercisesDone,
    required this.completedAt,
    required this.state,
    required this.onSubmit,
    super.key,
  });

  final bool allExercisesDone;
  final DateTime? completedAt;
  final MarkCompleteState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final completedAt = this.completedAt;
    if (completedAt != null) {
      // `.completed-banner` (`style.css:1894-1901`) — a solid green
      // gradient with white text, not a pale success-tinted card.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.success, Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Sub-activity completed on ${formatFullMonthDayYear(completedAt)}!',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final isSubmitting = state is MarkCompleteSubmitting;

    // `.mark-complete-card` (`style.css:1886-1892`) — a light-green tinted
    // card, not the generic white `AppCard`.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.checklist_outlined, color: AppColors.success, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Finished this sub-activity?', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  allExercisesDone
                      ? 'Mark it complete to track your overall progress.'
                      : 'Please complete all interactive exercises first.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: allExercisesDone ? null : AppColors.danger,
                  ),
                ),
                if (state is MarkCompleteFailed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    (state as MarkCompleteFailed).failure.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Mark Complete',
                  icon: Icons.check,
                  isLoading: isSubmitting,
                  fullWidth: false,
                  onPressed: (allExercisesDone && !isSubmitting) ? onSubmit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
