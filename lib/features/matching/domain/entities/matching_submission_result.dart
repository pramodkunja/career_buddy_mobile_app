/// The outcome of a Matching submission.
///
/// Unlike MCQ (`McqSubmissionResult`), the score here is **client**-
/// computed — `submit_exercise` (`activities/views.py`) trusts the
/// `score`/`max_score` this app sends verbatim for the `matching` exercise
/// type (confirmed by reading the view: the server-side AI re-grading
/// branch only applies to `writing`/`timer`). [attemptNumber] is the one
/// genuinely server-authoritative field — `submit_exercise` computes it
/// from `UserExerciseResult.objects.filter(...).count() + 1` itself, never
/// trusting a client-sent value. `score`/`maxScore`/`percentage` are read
/// from the server's response when present, falling back to what this app
/// sent — mirroring `submitScore()`'s own preference in
/// `static/js/exercises.js:66-67` (`data.score !== undefined ? data.score
/// : score`), not inventing new fallback behavior.
class MatchingSubmissionResult {
  const MatchingSubmissionResult({
    required this.exerciseId,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.attemptNumber,
  });

  final int exerciseId;
  final int score;
  final int maxScore;

  /// Percentage, 0-100.
  final int percentage;
  final int attemptNumber;
}
