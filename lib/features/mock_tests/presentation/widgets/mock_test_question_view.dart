import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../controllers/mock_test_controller.dart';
import 'mock_exam_colors.dart';
import 'mock_test_option_tile.dart';

/// The live exam question pane — mirrors `renderQ()`
/// (`005 oop-mastery.html:2770-2790`): question number/text/difficulty,
/// four options, and a Previous / Mark for review / Next action row.
class MockTestQuestionView extends StatelessWidget {
  const MockTestQuestionView({required this.state, required this.controller, super.key});

  final MockTestInProgress state;
  final MockTestController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = state.currentQuestion;
    final selected = state.answers[question.id];
    final isMarked = state.marked.contains(question.id);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Question ${state.currentIndex + 1} of ${state.questions.length}', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(question.questionText, style: theme.textTheme.titleMedium)),
            if (question.difficulty.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Chip(
                label: Text(question.difficulty),
                visualDensity: VisualDensity.compact,
                labelStyle: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < question.options.length; i++) ...[
          MockTestOptionTile(
            index: i,
            text: question.options[i],
            selected: selected == i,
            onTap: () => controller.selectAnswer(question.id, i),
          ),
          if (i != question.options.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Previous',
                icon: Icons.arrow_back,
                variant: AppButtonVariant.outlined,
                onPressed: state.isFirstQuestion ? null : controller.previousQuestion,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Next',
                icon: Icons.arrow_forward,
                variant: AppButtonVariant.outlined,
                onPressed: state.isLastQuestion ? null : controller.nextQuestion,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // `.exam-btn.mark{border:1px solid #FCA311;color:#b9720a}` /
        // `.exam-btn.mark.on{background:#FCA311;color:#14213D}`
        // (`005 oop-mastery.html:2439-2440`) — gold-themed, not the app's
        // generic text-button blue.
        SizedBox(
          width: double.infinity,
          height: 48,
          child: isMarked
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MockExamColors.gold,
                    foregroundColor: MockExamColors.navy,
                  ),
                  onPressed: () => controller.toggleMarkedForReview(question.id),
                  child: const Text('★ Marked'),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MockExamColors.eyebrow,
                    side: const BorderSide(color: MockExamColors.gold),
                  ),
                  onPressed: () => controller.toggleMarkedForReview(question.id),
                  child: const Text('☆ Mark for review'),
                ),
        ),
        if (state.submitError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.submitError!.message,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
