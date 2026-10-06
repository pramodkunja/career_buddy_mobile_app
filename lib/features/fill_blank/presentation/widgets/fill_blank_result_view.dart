import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/fill_blank_exercise.dart';
import '../../domain/entities/fill_blank_submission_result.dart';
import '../controllers/fill_blank_exercise_controller.dart';

/// The same shared score-tier result pattern already established by
/// `McqResultView`/`MatchingResultView`/`BingoResultView` — not a new
/// result design.
class FillBlankResultView extends StatelessWidget {
  const FillBlankResultView({
    required this.exercise,
    required this.checkedResults,
    required this.result,
    required this.onTryAgain,
    required this.onBackToSubActivity,
    super.key,
  });

  final FillBlankExercise exercise;
  final Map<int, FillBlankCheckedResult> checkedResults;
  final FillBlankSubmissionResult result;
  final VoidCallback onTryAgain;
  final VoidCallback onBackToSubActivity;

  static const _excellentGradient = [Color(0xFF10B981), Color(0xFF059669)];
  static const _goodGradient = [Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const _averageGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const _lowGradient = [Color(0xFFEF4444), Color(0xFFDC2626)];

  static const _correctText = Color(0xFF065F46);
  static const _wrongText = Color(0xFF991B1B);
  static const _correctBg = Color(0xFFECFDF5);
  static const _wrongBg = Color(0xFFFEF2F2);

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
              Text(
                '${result.percentage}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: gradient.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Attempt ${result.attemptNumber}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Review', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final question in exercise.questions) ...[
          if (checkedResults[question.position] case final checked?)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              // `.fill-feedback.correct-fb`/`.wrong-fb`
              // (`static/css/exercises.css:135-136`) — both carry a
              // matching-tint border, not just a fill color.
              decoration: BoxDecoration(
                color: checked.isCorrect ? _correctBg : _wrongBg,
                border: Border.all(color: checked.isCorrect ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question ${question.position}', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(question.questionText, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Your answer: ${checked.given}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: checked.isCorrect ? _correctText : _wrongText),
                  ),
                  if (!checked.isCorrect)
                    Text(
                      'Correct answer: ${question.correctAnswer}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _wrongText, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
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
