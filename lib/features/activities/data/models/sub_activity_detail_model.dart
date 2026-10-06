import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/exercise_attempt.dart';
import '../../domain/entities/exercise_summary.dart';
import '../../domain/entities/sub_activity_detail.dart';
import '../../domain/entities/sub_activity_status.dart';

/// Parses `GET /activities/api/sub/<id>/`'s `data` object (see
/// `docs/BACKEND_CONTRACT_activities.md`) into [SubActivityDetail].
extension SubActivityDetailParsing on SubActivityDetail {
  static SubActivityDetail fromJson(Map<String, dynamic> json) {
    final activity = requireMap(json, 'activity');
    return SubActivityDetail(
      id: requireInt(json, 'id'),
      title: requireString(json, 'title'),
      description: requireString(json, 'description'),
      instructions: requireString(json, 'instructions'),
      order: requireInt(json, 'order'),
      activityId: requireInt(activity, 'id'),
      activityTitle: requireString(activity, 'title'),
      status: SubActivityStatus.fromWire(requireString(json, 'status')),
      startedAt: optionalDateTime(json, 'started_at'),
      completedAt: optionalDateTime(json, 'completed_at'),
      allExercisesDone: requireBool(json, 'all_exercises_done'),
      exercises: requireList(json, 'exercises').map((e) => _exerciseFromJson(asMap(e, 'exercises[]'))).toList(),
    );
  }

  static ExerciseSummary _exerciseFromJson(Map<String, dynamic> json) {
    final lastAttemptJson = json['last_attempt'];
    return ExerciseSummary(
      id: requireInt(json, 'id'),
      title: requireString(json, 'title'),
      exerciseType: requireString(json, 'exercise_type'),
      exerciseTypeDisplay: requireString(json, 'exercise_type_display'),
      order: requireInt(json, 'order'),
      lastAttempt: lastAttemptJson == null ? null : _attemptFromJson(asMap(lastAttemptJson, 'last_attempt')),
    );
  }

  static ExerciseAttempt _attemptFromJson(Map<String, dynamic> json) {
    return ExerciseAttempt(
      score: requireInt(json, 'score'),
      maxScore: requireInt(json, 'max_score'),
      percentage: requireInt(json, 'percentage'),
      attemptNumber: requireInt(json, 'attempt_number'),
      completedAt: requireDateTime(json, 'completed_at'),
    );
  }
}
