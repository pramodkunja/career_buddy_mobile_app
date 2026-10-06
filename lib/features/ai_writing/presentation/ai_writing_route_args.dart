import '../../activities/domain/entities/exercise_attempt.dart';

/// Passed via `context.push`'s `extra` to [AiWritingScreen]'s route — see
/// `RoutePaths.aiWritingPattern`'s doc comment for why this travels as
/// `extra` rather than being re-fetched or URL-encoded.
class AiWritingRouteArgs {
  const AiWritingRouteArgs({
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
