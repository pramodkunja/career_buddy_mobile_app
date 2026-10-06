import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/mock_test_question.dart';
import '../../domain/entities/mock_test_question_result.dart';
import '../../domain/entities/mock_test_submission_result.dart';
import 'mock_exam_colors.dart';
import 'mock_test_option_tile.dart';

/// Mirrors `showResults(data)` (`005 oop-mastery.html:2749-2769`) — score,
/// the same 4-tier qualitative message (own tiers, distinct from MCQ's own
/// 6-tier system), and a full per-question review honoring the
/// attempted-only reveal rule. Every value shown comes from [result]
/// (server-authoritative); nothing here is computed client-side.
///
/// Deliberately does not reproduce the web's 30-second auto-redirect back
/// to the assessment guide page — there is no equivalent "guide page" to
/// return to in this app, and an unrequested auto-navigation away from a
/// result screen is poor mobile UX; "Close" instead returns to the intro
/// screen under the user's own control.
class MockTestResultView extends StatelessWidget {
  const MockTestResultView({
    required this.title,
    required this.questions,
    required this.answers,
    required this.result,
    required this.onRetake,
    required this.onClose,
    super.key,
  });

  /// The bare quiz name — composed the same way the web's result header
  /// does: `"Result — $title Mock Test"` (`005 oop-mastery.html:2764`,
  /// byte-identical across every subject page verified for W021).
  final String title;
  final List<MockTestQuestion> questions;
  final Map<int, int> answers;
  final MockTestSubmissionResult result;
  final VoidCallback onRetake;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = result.total == 0 ? 0 : (result.score / result.total * 100).round();
    final message = _messageFor(percent);
    final color = percent >= 85
        ? AppColors.success
        : percent >= 50
        ? AppColors.warning
        : AppColors.danger;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Result — $title Mock Test', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              Text(
                '${result.score} / ${result.total}',
                style: theme.textTheme.headlineMedium?.copyWith(color: MockExamColors.navy, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$percent% correct — $message',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(label: 'Take another test', icon: Icons.refresh, onPressed: onRetake),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Close', variant: AppButtonVariant.outlined, onPressed: onClose),
        const SizedBox(height: AppSpacing.lg),
        Text('Review', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < questions.length; i++) ...[
          _QuestionReviewCard(index: i, question: questions[i], yourAnswer: answers[questions[i].id], outcome: result.results[questions[i].id]),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  /// Exact wording from `showResults(data)`
  /// (`005 oop-mastery.html:2757-2760`) — this is OOP Mastery's own 4-tier
  /// system, not to be conflated with MCQ's separate 6-tier one.
  String _messageFor(int percent) {
    if (percent >= 85) return 'Outstanding — strong command of OOP, basics to edge cases.';
    if (percent >= 65) return 'Solid pass. A little more practice on the tricky ones and you are set.';
    if (percent >= 50) return 'Borderline — revisit the topics you missed and retake.';
    return 'Keep practicing — review the explanations below and try again.';
  }
}

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({required this.index, required this.question, required this.yourAnswer, required this.outcome});

  final int index;
  final MockTestQuestion question;
  final int? yourAnswer;
  final MockTestQuestionResult? outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attempted = outcome?.wasAttempted ?? false;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q${index + 1}. ${question.questionText}', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (!attempted)
            Text(
              'Your answer: Not answered',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: AppColors.textMuted),
            )
          else ...[
            for (var i = 0; i < question.options.length; i++) ...[
              MockTestOptionTile(
                index: i,
                text: question.options[i],
                selected: yourAnswer == i,
                onTap: null,
                isCorrect: outcome?.correctAnswerIndex == i,
                isWrongSelection: yourAnswer == i && outcome?.isCorrect == false,
              ),
              if (i != question.options.length - 1) const SizedBox(height: AppSpacing.xs),
            ],
            if ((outcome?.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                outcome!.explanation!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
