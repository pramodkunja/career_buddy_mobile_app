import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../activities/domain/entities/exercise_attempt.dart';
import '../../domain/entities/matching_pair.dart';
import '../controllers/matching_exercise_controller.dart';
import 'matching_colors.dart';
import 'matching_item_tile.dart';

/// The tap-to-match interaction, matching `initMatching()`
/// (`static/js/exercises.js:267-448`): select a left term, select a right
/// definition, they pair; tap either half of an existing pair to unpair it
/// (mobile adaptation of the web's double-click — see
/// `MatchingExerciseController.tapLeft`'s doc comment).
///
/// Layout mirrors `.matching-grid`'s own responsive rule
/// (`static/css/exercises.css:140-143,569-570`): a single stacked column
/// below 640px (the web's own `@media (max-width: 640px)` breakpoint —
/// re-verified directly, not assumed), two side-by-side columns at/above
/// it. The web's `#matching-svg` connector column is dead markup (never
/// populated by any JS — confirmed by grep) and is not reproduced.
class MatchingInProgressBody extends StatelessWidget {
  const MatchingInProgressBody({required this.state, required this.controller, this.previousAttempt, super.key});

  final MatchingExerciseInProgress state;
  final MatchingExerciseController controller;

  /// Mirrors the web's "Previous Score" sidebar (`all_attempts.0`,
  /// `templates/activities/exercise.html:427-436`) — passed in by the
  /// caller from `ExerciseSummary.lastAttempt` (see `MatchingRouteArgs`),
  /// same reasoning as `AiSpeakingScreen.previousAttempt`.
  final ExerciseAttempt? previousAttempt;

  @override
  Widget build(BuildContext context) {
    final total = state.exercise.pairs.length;
    final matchedCount = state.matches.length;
    final pairsByPosition = {for (final pair in state.exercise.pairs) pair.position: pair};

    return Column(
      children: [
        if (previousAttempt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: _PreviousScoreCard(attempt: previousAttempt!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('$matchedCount of $total matched', style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : matchedCount / total,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  // `.progress-bar-fill{background:#2563eb}`
                  // (`static/css/exercises.css:26`) — same literal as MCQ's.
                  color: MatchingColors.blue,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final leftColumn = _ItemColumn(
                  header: 'Terms',
                  positions: [for (final pair in state.exercise.pairs) pair.position],
                  pairsByPosition: pairsByPosition,
                  isLeftColumn: true,
                  state: state,
                  controller: controller,
                );
                final rightColumn = _ItemColumn(
                  header: 'Definitions',
                  positions: state.rightOrder,
                  pairsByPosition: pairsByPosition,
                  isLeftColumn: false,
                  state: state,
                  controller: controller,
                );

                if (constraints.maxWidth < 640) {
                  return Column(
                    children: [
                      leftColumn,
                      const SizedBox(height: AppSpacing.lg),
                      rightColumn,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftColumn),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: rightColumn),
                  ],
                );
              },
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
                Expanded(
                  child: AppButton(
                    label: 'Reset',
                    // `<i class="fas fa-redo me-1"></i>Reset`
                    // (`templates/activities/exercise.html:241`).
                    icon: Icons.refresh,
                    variant: AppButtonVariant.outlined,
                    onPressed: state.isSubmitting || state.matches.isEmpty ? null : controller.reset,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Check Matches',
                    // `<i class="fas fa-check me-2"></i>Check Matches`
                    // (`templates/activities/exercise.html:244`).
                    icon: Icons.check,
                    isLoading: state.isSubmitting,
                    onPressed: state.allMatched ? controller.submit : null,
                    // `#submit-matching` is `.btn-success` on the web
                    // (`templates/activities/exercise.html:243`), same as
                    // MCQ's submit button.
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
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

class _ItemColumn extends StatelessWidget {
  const _ItemColumn({
    required this.header,
    required this.positions,
    required this.pairsByPosition,
    required this.isLeftColumn,
    required this.state,
    required this.controller,
  });

  final String header;
  final List<int> positions;
  final Map<int, MatchingPair> pairsByPosition;
  final bool isLeftColumn;
  final MatchingExerciseInProgress state;
  final MatchingExerciseController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final position in positions) ...[
          MatchingItemTile(
            text: isLeftColumn ? pairsByPosition[position]!.leftText : pairsByPosition[position]!.rightText,
            state: _visualStateFor(position),
            onTap: () => isLeftColumn ? controller.tapLeft(position) : controller.tapRight(position),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  MatchItemVisualState _visualStateFor(int position) {
    final isMatched = isLeftColumn ? state.matches.containsKey(position) : state.matches.containsValue(position);
    if (isMatched) return MatchItemVisualState.matched;
    final isSelected = isLeftColumn ? state.selectedLeft == position : state.selectedRight == position;
    return isSelected ? MatchItemVisualState.selected : MatchItemVisualState.normal;
  }
}

/// `templates/activities/exercise.html:420-436`'s "Previous Score" sidebar
/// card, for the generic (non-module) exercise flow — shows only the most
/// recent attempt's raw score, no percentage, matching the web exactly
/// (`{{ attempt.score }}/{{ attempt.max_score }}`, not `/25` like the
/// AI-module screens' own previous-score card).
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
