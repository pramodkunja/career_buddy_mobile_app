import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/generic_writing_exercise.dart';
import '../../domain/entities/generic_writing_submission_result.dart';
import '../../domain/entities/writing_task_feedback.dart';

/// The same shared score-tier result pattern already established by
/// `McqResultView`/`MatchingResultView`/`BingoResultView`/
/// `FillBlankResultView` — not a new result design. The only genuinely new
/// section is the per-task AI feedback list, present only when the server
/// actually produced `customSummaryHtml` (`SARVAM_API_KEY` configured and
/// at least one prompt long enough to evaluate — see
/// [GenericWritingSubmissionResult]'s doc comment); when it's empty
/// (unconfigured/fallback), this screen shows only the score, exactly like
/// the web's own empty `#result-details` in that case.
class GenericWritingResultView extends StatelessWidget {
  const GenericWritingResultView({
    required this.exercise,
    required this.result,
    required this.onTryAgain,
    required this.onBackToSubActivity,
    super.key,
  });

  final GenericWritingExercise exercise;
  final GenericWritingSubmissionResult result;
  final VoidCallback onTryAgain;
  final VoidCallback onBackToSubActivity;

  static const _excellentGradient = [Color(0xFF10B981), Color(0xFF059669)];
  static const _goodGradient = [Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const _averageGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const _lowGradient = [Color(0xFFEF4444), Color(0xFFDC2626)];

  (List<Color>, String, String) _tierFor(int percentage) {
    if (percentage == 100) return (_excellentGradient, '🏆', 'Perfect Score!');
    if (percentage >= 90) return (_excellentGradient, '🌟', 'Excellent!');
    if (percentage >= 80) return (_excellentGradient, '✨', 'Very Good!');
    if (percentage >= 60) return (_goodGradient, '👍', 'Good Job!');
    if (percentage >= 40) return (_averageGradient, '💪', 'Average');
    return (_lowGradient, '📚', 'Keep Practising');
  }

  @override
  Widget build(BuildContext context) {
    final (gradient, emoji, message) = _tierFor(result.percentage);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(message, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text('${result.score} / ${result.maxScore}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('${result.percentage}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: gradient.first)),
              const SizedBox(height: AppSpacing.xs),
              Text('Attempt ${result.attemptNumber}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (result.taskFeedback.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('AI Feedback', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final task in result.taskFeedback) ...[
            _TaskFeedbackCard(task: task),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(label: 'Try Again', variant: AppButtonVariant.outlined, onPressed: onTryAgain),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(label: 'Back to Sub-Activity', onPressed: onBackToSubActivity),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskFeedbackCard extends StatelessWidget {
  const _TaskFeedbackCard({required this.task});

  final WritingTaskFeedback task;

  static const _danger = Color(0xFFDC3545);
  static const _success = Color(0xFF198754);
  static const _improvedBg = Color(0xFFF8F9FA);
  static const _improvedBorder = Color(0xFFDEE2E6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Task ${task.taskNumber}', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          if (task.tooShortToEvaluate)
            Text('Answer too short to evaluate.', style: theme.textTheme.bodySmall?.copyWith(color: _danger))
          else if (task.issues.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: _success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('No major issues found.', style: theme.textTheme.bodySmall?.copyWith(color: _success)),
                ),
              ],
            )
          else
            for (final issue in task.issues) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                    children: [
                      TextSpan(text: issue.phrase, style: const TextStyle(color: _danger, fontWeight: FontWeight.w700)),
                      TextSpan(text: ': ${issue.message}\n'),
                      TextSpan(text: 'Suggestion: ${issue.suggestion}', style: const TextStyle(color: _success)),
                    ],
                  ),
                ),
              ),
            ],
          if (task.improvedPassage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: _improvedBg, border: Border.all(color: _improvedBorder), borderRadius: BorderRadius.circular(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Improved Version:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(task.improvedPassage!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
