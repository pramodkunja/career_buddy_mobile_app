import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../controllers/mcq_exercise_controller.dart';
import 'mcq_question_card.dart';

/// One question at a time, mirroring the web's single-visible-question
/// flow (`templates/activities/exercise.html`): Next is disabled until the
/// current question is answered, and Submit (replacing Next on the last
/// question) is disabled until every question has an answer.
class McqInProgressBody extends StatelessWidget {
  const McqInProgressBody({
    required this.state,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.controller,
    super.key,
  });

  final McqExerciseInProgress state;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final McqExerciseController controller;

  @override
  Widget build(BuildContext context) {
    final questions = state.exercise.questions;
    final question = questions[currentIndex];
    final isLast = currentIndex == questions.length - 1;
    final selected = state.selectedAnswers[question.id];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Question ${currentIndex + 1} of ${questions.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${state.selectedAnswers.length}/${questions.length} answered',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / questions.length,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  // `.progress-bar-fill{background:#2563eb}`
                  // (`static/css/exercises.css:27`) — the web's literal
                  // hex, not `AppColors.action` (#185ADB), which is a
                  // similar but not identical blue.
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: McqQuestionCard(
              question: question,
              questionNumber: currentIndex + 1,
              selectedLetter: selected,
              onSelect: (letter) => controller.selectAnswer(question.id, letter),
            ),
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
            child: Row(
              children: [
                if (currentIndex > 0) ...[
                  Expanded(
                    child: AppButton(
                      label: 'Previous',
                      variant: AppButtonVariant.outlined,
                      onPressed: state.isSubmitting ? null : () => onIndexChanged(currentIndex - 1),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: isLast
                      ? AppButton(
                          label: 'Submit',
                          isLoading: state.isSubmitting,
                          onPressed: state.allQuestionsAnswered ? controller.submit : null,
                          // `#submit-mcq` is `.btn-success` on the web
                          // (`templates/activities/exercise.html:172`),
                          // distinct from `.btn-primary`'s gold Next
                          // button — confirmed not overridden by the
                          // site's gold/navy rebrand.
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        )
                      : AppButton(
                          label: 'Next',
                          onPressed: selected == null ? null : () => onIndexChanged(currentIndex + 1),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
