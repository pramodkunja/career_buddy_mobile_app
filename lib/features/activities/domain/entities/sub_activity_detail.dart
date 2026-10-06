import 'exercise_summary.dart';
import 'sub_activity_status.dart';

class SubActivityDetail {
  const SubActivityDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.order,
    required this.activityId,
    required this.activityTitle,
    required this.status,
    required this.allExercisesDone,
    required this.exercises,
    this.startedAt,
    this.completedAt,
  });

  final int id;
  final String title;
  final String description;
  final String instructions;
  final int order;
  final int activityId;
  final String activityTitle;
  final SubActivityStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool allExercisesDone;
  final List<ExerciseSummary> exercises;
}
