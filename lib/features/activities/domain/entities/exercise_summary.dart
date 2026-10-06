import 'exercise_attempt.dart';

class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.title,
    required this.exerciseType,
    required this.exerciseTypeDisplay,
    required this.order,
    this.lastAttempt,
  });

  final int id;
  final String title;
  final String exerciseType;
  final String exerciseTypeDisplay;
  final int order;
  final ExerciseAttempt? lastAttempt;
}
