/// The outcome of a Fill in the Blank submission.
///
/// Score is **client**-computed, same as Matching/Bingo — `submit_exercise`
/// (`activities/views.py`) trusts the `score`/`max_score` this app sends
/// verbatim for the `fill_blank` exercise type (the server-side AI
/// re-grading branch only applies to `writing`/`timer`). [attemptNumber]
/// is the one genuinely server-authoritative field.
class FillBlankSubmissionResult {
  const FillBlankSubmissionResult({
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
