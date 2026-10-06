import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../controllers/bingo_exercise_controller.dart';
import 'bingo_board.dart';
import 'bingo_header.dart';
import 'bingo_legend.dart';
import 'bingo_status_bar.dart';

/// Every round answered — grading is already final and displayed the
/// instant this state is entered ([BingoExerciseResult.cardStates]/
/// [BingoExerciseResult.bingoLines]/[BingoExerciseResult.correctCount]
/// never change); only [BingoExerciseResult.isSubmitting]/[submitError]/
/// [submissionResult] update afterward as the POST resolves — see
/// `BingoExerciseResult`'s doc comment for why that split matches the
/// web's own `evaluate()` exactly.
class BingoResultView extends StatelessWidget {
  const BingoResultView({required this.state, required this.onTryAgain, required this.onRetrySubmit, required this.onBackToSubActivity, super.key});

  final BingoExerciseResult state;
  final VoidCallback onTryAgain;
  final VoidCallback onRetrySubmit;
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
    final max = state.maxCount;
    final percentage = max == 0 ? 0 : ((state.correctCount / max) * 100).round();
    final (gradient, emoji, message) = _tierFor(percentage);

    // Mirrors `evaluate()`'s own two possible status messages exactly
    // (`static/js/exercises.js:637-643`).
    final statusText = state.bingoLines > 0
        ? '🎉 BINGO! ${state.bingoLines} ${state.bingoLines > 1 ? 'lines' : 'line'} — '
              'you matched ${state.correctCount} of $max.'
        : 'You matched ${state.correctCount} of $max correctly — no 5-in-a-row this time.';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        BingoHeader(
          currentWordText: 'All done — see your score below.',
          roundText: '',
          startLabel: 'Restart',
          onStart: onTryAgain,
          onNext: null,
        ),
        const SizedBox(height: AppSpacing.md),
        BingoBoard(
          cards: state.exercise.board,
          cellStateFor: (word) => state.cardStates[word] ?? BingoCellState.neutral,
          bingoLineWords: state.bingoLineWords,
          onCellTap: null,
        ),
        const SizedBox(height: AppSpacing.md),
        const BingoLegend(),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: BingoStatusBar(
            text: statusText,
            tone: state.bingoLines > 0 ? BingoStatusTone.bingo : BingoStatusTone.playing,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
              Text('${state.correctCount} / $max', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('$percentage%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: gradient.first)),
              const SizedBox(height: AppSpacing.xs),
              if (state.isSubmitting)
                Text('Submitting…', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted))
              else if (state.submissionResult != null)
                Text('Attempt ${state.submissionResult!.attemptNumber}', style: Theme.of(context).textTheme.bodySmall)
              else if (state.submitError != null) ...[
                Text(
                  state.submitError!.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'Retry Submit', variant: AppButtonVariant.outlined, fullWidth: false, onPressed: onRetrySubmit),
              ],
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
