import '../../activities/domain/entities/exercise_attempt.dart';

/// Passed via `context.push`'s `extra` to [AiReadingScreen]'s route — see
/// `RoutePaths.aiReadingPattern`'s doc comment.
class AiReadingRouteArgs {
  const AiReadingRouteArgs({
    required this.activityId,
    required this.subActivityId,
    required this.activityTitle,
    this.previousAttempt,
  });

  /// See `MatchingRouteArgs.activityId`'s doc comment.
  final int activityId;
  final int subActivityId;

  /// For [ModuleHero]'s title/breadcrumb — the caller
  /// (`SubActivityDetailScreen`) already has this on the
  /// `SubActivityDetail` it built this route from.
  final String activityTitle;
  final ExerciseAttempt? previousAttempt;
}
