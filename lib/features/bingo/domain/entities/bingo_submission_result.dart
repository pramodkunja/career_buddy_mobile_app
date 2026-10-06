/// The outcome of a Bingo submission.
///
/// Score is **client**-computed, same as Matching — `submit_exercise`
/// (`activities/views.py`) trusts the `score`/`max_score` this app sends
/// verbatim for the `bingo` exercise type (the server-side AI re-grading
/// branch only applies to `writing`/`timer`). [attemptNumber] is the one
/// genuinely server-authoritative field. Unlike Matching, the real web
/// page never surfaces a "Claim Score" action to the user at all — the
/// `#submit-bingo` button exists in the DOM but is permanently
/// `display:none` and never wired to a click handler
/// (`static/js/exercises.js`, confirmed by grep for `submit-bingo`) —
/// grading and submission both fire automatically the instant the last
/// round is answered (`evaluate()` calls `submitScore()` directly). This
/// app reproduces that: submission is automatic, not a separate user
/// action.
class BingoSubmissionResult {
  const BingoSubmissionResult({
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
