import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../../domain/entities/bingo_exercise.dart';
import '../controllers/bingo_exercise_controller.dart';
import 'bingo_board.dart';
import 'bingo_header.dart';
import 'bingo_legend.dart';

/// Loaded, not yet started — "Press Start to begin"
/// (`templates/activities/exercise.html:256`). The board is visible but
/// inert (no `onCellTap`) — tapping a cell before Start is a no-op on the
/// web too (`if (!gameActive ...) return;`).
class BingoReadyBody extends StatelessWidget {
  const BingoReadyBody({required this.exercise, required this.startLabel, required this.onStart, this.previousAttempt, super.key});

  final BingoExercise exercise;
  final String startLabel;
  final VoidCallback onStart;
  final ExerciseAttempt? previousAttempt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (previousAttempt != null) ...[
          _PreviousScoreCard(attempt: previousAttempt!),
          const SizedBox(height: AppSpacing.md),
        ],
        BingoHeader(
          currentWordText: 'Press Start to begin',
          roundText: '',
          startLabel: startLabel,
          onStart: onStart,
          onNext: null,
        ),
        const SizedBox(height: AppSpacing.md),
        BingoBoard(cards: exercise.board, cellStateFor: (_) => BingoCellState.neutral, onCellTap: null),
        const SizedBox(height: AppSpacing.md),
        const BingoLegend(),
      ],
    );
  }
}

/// The user is playing: one definition shown at a time.
class BingoPlayingBody extends StatelessWidget {
  const BingoPlayingBody({required this.state, required this.startLabel, required this.onStart, required this.onNext, required this.onCellTap, super.key});

  final BingoExercisePlaying state;
  final String startLabel;
  final VoidCallback onStart;
  final VoidCallback? onNext;
  final void Function(String word) onCellTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        BingoHeader(
          currentWordText: state.currentCard.definition,
          roundText: 'Word ${state.roundIndex + 1} of ${state.sequence.length}',
          startLabel: startLabel,
          onStart: onStart,
          onNext: onNext,
        ),
        const SizedBox(height: AppSpacing.md),
        BingoBoard(
          cards: state.exercise.board,
          cellStateFor: (word) => state.markedWord == word ? BingoCellState.marked : BingoCellState.neutral,
          onCellTap: onCellTap,
        ),
        const SizedBox(height: AppSpacing.md),
        const BingoLegend(),
      ],
    );
  }
}

/// `templates/activities/exercise.html:420-436`'s "Previous Score" sidebar
/// card, for the generic (non-module) exercise flow — same widget shape
/// as Matching's own `_PreviousScoreCard`.
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
