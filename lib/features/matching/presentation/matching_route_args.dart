import '../../activities/domain/entities/exercise_attempt.dart';

/// Passed via `context.push`'s `extra` to [MatchingExerciseScreen]'s route
/// — same reasoning as `AiSpeakingRouteArgs`. [title]/[order] travel here
/// too (not just `subActivityId`/`previousAttempt`) because, unlike MCQ,
/// there is no JSON API response to read them back from — the caller
/// (`SubActivityDetailScreen`) already has them on the `ExerciseSummary` it
/// built this tile from.
class MatchingRouteArgs {
  const MatchingRouteArgs({
    required this.title,
    required this.order,
    required this.activityId,
    required this.subActivityId,
    this.previousAttempt,
  });

  final String title;
  final int order;

  /// The parent activity's id — needed only to invalidate the right
  /// `subActivityDetailControllerProvider` family instance when returning
  /// to it (that provider's key now mirrors the real web's composite
  /// `/activities/<activity_pk>/sub/<sub_pk>/` URL — see
  /// `RoutePaths.subActivityDetail`'s doc comment), not for this screen's
  /// own route.
  final int activityId;
  final int subActivityId;
  final ExerciseAttempt? previousAttempt;
}
