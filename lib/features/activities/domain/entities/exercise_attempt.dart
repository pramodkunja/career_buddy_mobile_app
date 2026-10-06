class ExerciseAttempt {
  const ExerciseAttempt({
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.attemptNumber,
    required this.completedAt,
  });

  final int score;
  final int maxScore;

  /// Percentage, 0-100.
  final int percentage;
  final int attemptNumber;
  final DateTime completedAt;
}
