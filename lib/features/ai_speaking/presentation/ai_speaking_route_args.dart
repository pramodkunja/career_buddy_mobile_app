import '../../activities/domain/entities/exercise_attempt.dart';

/// Passed via `context.push`'s `extra` to [AiSpeakingScreen]'s route — see
/// `RoutePaths.aiSpeakingPattern`'s doc comment for why this travels as
/// `extra` rather than being re-fetched or URL-encoded.
class AiSpeakingRouteArgs {
  const AiSpeakingRouteArgs({
    required this.activityId,
    required this.subActivityId,
    required this.activityTitle,
    this.previousAttempt,
  });

  /// See `MatchingRouteArgs.activityId`'s doc comment — needed here to key
  /// `markSubCompleteControllerProvider`/`subActivityDetailControllerProvider`,
  /// not for this screen's own route.
  final int activityId;
  final int subActivityId;

  /// For [ModuleHero]'s title/breadcrumb — the caller
  /// (`SubActivityDetailScreen`) already has this on the
  /// `SubActivityDetail` it built this route from.
  final String activityTitle;
  final ExerciseAttempt? previousAttempt;
}
