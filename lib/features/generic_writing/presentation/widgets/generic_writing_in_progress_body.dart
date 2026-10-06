import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../controllers/generic_writing_controller.dart';
import 'generic_writing_prompt_card.dart';

/// All prompts displayed simultaneously — mirrors the web's `writing`
/// branch exactly (`templates/activities/exercise.html:295-320`): a single
/// Submit button at the bottom, gated on every prompt's live word count
/// (`initWriting()`, `static/js/exercises.js:759-802`) — no per-prompt
/// Check button, no navigation between prompts, no progress bar, no timer.
class GenericWritingInProgressBody extends StatelessWidget {
  const GenericWritingInProgressBody({required this.state, required this.controller, this.previousAttempt, super.key});

  final GenericWritingInProgress state;
  final GenericWritingController controller;

  /// Mirrors the web's "Previous Score" sidebar (`all_attempts.0`,
  /// `templates/activities/exercise.html:427-436`) — same reasoning as
  /// `FillBlankInProgressBody`'s own previous-score card.
  final ExerciseAttempt? previousAttempt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (previousAttempt != null) ...[
                _PreviousScoreCard(attempt: previousAttempt!),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final prompt in state.exercise.prompts) ...[
                GenericWritingPromptCard(
                  prompt: prompt,
                  draft: state.draftFor(prompt.position),
                  limits: state.limitsFor(prompt),
                  onChanged: (text) => controller.updateDraft(prompt.position, text),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        if (state.submitError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Text(
              state.submitError!.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Submit Writing',
              isLoading: state.isSubmitting,
              onPressed: state.allValid ? controller.submit : null,
              // `#submit-writing` is `.btn-success` on the web
              // (`templates/activities/exercise.html:316`), same as
              // MCQ/Matching/Bingo/Fill in the Blank's submit buttons.
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviousScoreCard extends StatelessWidget {
  const _PreviousScoreCard({required this.attempt});

  final ExerciseAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text('Previous score: ', style: theme.textTheme.bodySmall),
          Text('${attempt.score}/${attempt.maxScore}', style: theme.textTheme.titleSmall),
          const Spacer(),
          Text(formatMonthDayYear(attempt.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
