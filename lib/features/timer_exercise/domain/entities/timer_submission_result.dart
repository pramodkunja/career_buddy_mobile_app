/// The outcome of a Timer submission.
///
/// Like Generic Writing, this exercise type's score can be
/// **server-overridden**: `submit_exercise`'s `if exercise.exercise_type in
/// ('writing', 'timer') and settings.SARVAM_API_KEY:` branch
/// (`activities/views.py:1422` onward) discards the client-computed score
/// entirely and recomputes it via a Sarvam AI call in `"speaking"` mode
/// (`ai_mode = "speaking" if exercise.exercise_type == "timer" else
/// "writing"`) whenever that key is configured, falling back to the
/// client's own per-task share (`score / len(questions)`) only if a single
/// AI call throws. When the key is unset, the server trusts the client
/// score verbatim, same as every other exercise type.
///
/// Unlike Generic Writing, **no per-task AI feedback is ever produced for
/// `timer`** — confirmed directly in `submit_exercise`: every
/// `ai_feedbacks.append(...)` call (the HTML this app would otherwise parse
/// as `customSummaryHtml`) is guarded by `if exercise.exercise_type !=
/// "timer":`, so `custom_summary_html` is always `""` for this exercise
/// type. There is deliberately no `taskFeedback`-style field here — only
/// the score.
class TimerSubmissionResult {
  const TimerSubmissionResult({
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
