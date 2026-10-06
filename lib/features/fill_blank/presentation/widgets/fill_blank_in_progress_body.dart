import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../controllers/fill_blank_exercise_controller.dart';
import 'fill_blank_question_card.dart';

/// All questions displayed simultaneously, each independently checkable —
/// mirrors the web's `fill_blank` branch exactly
/// (`templates/activities/exercise.html:183-212`): no Start button, no
/// question-by-question navigation, no progress bar, no question counter,
/// no timer — none of those elements exist in the real page for this
/// exercise type, so none are invented here either.
class FillBlankInProgressBody extends StatelessWidget {
  const FillBlankInProgressBody({required this.state, required this.controller, this.previousAttempt, super.key});

  final FillBlankExerciseInProgress state;
  final FillBlankExerciseController controller;

  /// Mirrors the web's "Previous Score" sidebar (`all_attempts.0`,
  /// `templates/activities/exercise.html:427-436`) — same reasoning as
  /// `MatchingInProgressBody`/`BingoReadyBody`'s own previous-score card.
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
              for (final question in state.exercise.questions) ...[
                FillBlankQuestionCard(
                  question: question,
                  checkedResult: state.checkedResults[question.position],
                  showEmptyError: state.emptyErrorPositions.contains(question.position),
                  onCheck: (given) => controller.checkAnswer(question.position, given),
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
              label: 'Submit All Answers',
              isLoading: state.isSubmitting,
              onPressed: state.allChecked ? controller.submit : null,
              // `#submit-fill` is `.btn-success` on the web
              // (`templates/activities/exercise.html:208`), same as
              // MCQ/Matching/Bingo's submit buttons.
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
