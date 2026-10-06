import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/timer_exercise.dart';
import '../../domain/entities/timer_submission_result.dart';

/// The same shared score-tier result pattern already established by
/// `McqResultView`/`MatchingResultView`/`GenericWritingResultView` — not a
/// new result design. Unlike Generic Writing, there is deliberately no
/// per-task AI feedback section here — `customSummaryHtml` is always empty
/// for `exercise_type == 'timer'` (see `TimerSubmissionResult`'s doc
/// comment), so only the score is shown, exactly like the web's own empty
/// `#result-details` in that case.
class TimerExerciseResultView extends StatelessWidget {
  const TimerExerciseResultView({
    required this.exercise,
    required this.result,
    required this.onTryAgain,
    required this.onBackToSubActivity,
    super.key,
  });

  final TimerExercise exercise;
  final TimerSubmissionResult result;
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
