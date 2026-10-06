import '../../activities/domain/entities/exercise_attempt.dart';

/// Passed via `context.push`'s `extra` to [TimerExerciseScreen]'s route —
/// same reasoning as `GenericWritingRouteArgs`/`MatchingRouteArgs`:
/// [title]/[order] travel here because there is no JSON API response to
/// read them back from, and the caller (`SubActivityDetailScreen`) already
/// has them on the `ExerciseSummary` it built this tile from.
class TimerExerciseRouteArgs {
  const TimerExerciseRouteArgs({
    required this.title,
    required this.order,
    required this.activityId,
    required this.subActivityId,
    this.previousAttempt,
  });

  final String title;
  final int order;

  /// See `MatchingRouteArgs.activityId`'s doc comment.
  final int activityId;
  final int subActivityId;
  final ExerciseAttempt? previousAttempt;
}
