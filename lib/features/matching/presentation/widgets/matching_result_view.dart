import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/matching_exercise.dart';
import '../../domain/entities/matching_pair.dart';
import '../../domain/entities/matching_submission_result.dart';
import 'matching_colors.dart';
import 'matching_item_tile.dart';

/// Combines the web's two post-submit displays into one screen: the
/// matching grid recolored in place to correct/wrong-match
/// (`.correct`/`.wrong-match`, `static/js/exercises.js:391-407`) plus the
/// shared `showResultPanel()` score/tier summary
/// (`static/js/exercises.js:81-120`) every exercise type uses — the same
/// combining `McqResultView` already does for MCQ (a full result screen,
/// not an in-place recolor-then-reveal-a-panel-below sequence).
class MatchingResultView extends StatelessWidget {
  const MatchingResultView({
    required this.exercise,
    required this.matches,
    required this.result,
    required this.onTryAgain,
    required this.onBackToSubActivity,
    super.key,
  });

  final MatchingExercise exercise;
  final Map<int, int> matches;
  final MatchingSubmissionResult result;
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
        Text('Correct Pairings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final pair in exercise.pairs) ...[
          _PairReviewCard(pair: pair, isCorrect: matches[pair.position] == pair.position),
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

class _PairReviewCard extends StatelessWidget {
  const _PairReviewCard({required this.pair, required this.isCorrect});

  final MatchingPair pair;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final state = isCorrect ? MatchItemVisualState.correct : MatchItemVisualState.wrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MatchingItemTile(text: pair.leftText, state: state, onTap: null),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Icon(Icons.arrow_downward, size: 16, color: isCorrect ? MatchingColors.correctBorder : MatchingColors.wrongBorder),
        ),
        const SizedBox(height: 4),
        MatchingItemTile(text: pair.rightText, state: state, onTap: null),
      ],
    );
  }
}
