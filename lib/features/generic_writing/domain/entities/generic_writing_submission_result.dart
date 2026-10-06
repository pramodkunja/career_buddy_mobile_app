import 'writing_task_feedback.dart';

/// The outcome of a Generic Writing submission.
///
/// Unlike Matching/Bingo/Fill in the Blank (fully client-authoritative),
/// this exercise type's score can be **server-overridden**:
/// `submit_exercise`'s `if exercise.exercise_type in ('writing', 'timer')
/// and settings.SARVAM_API_KEY:` branch (`activities/views.py:1422-1495`)
/// discards the client-computed [score] entirely and recomputes it via
/// Sarvam AI whenever that key is configured — falling back to the
/// client's own score only per-prompt, if a single AI call throws. When
/// the key is unset, the server trusts the client score verbatim, same as
/// every other exercise type. [taskFeedback] is empty in that fallback
/// case (`custom_summary_html` stays `""`,
/// `activities/views.py:1420`).
class GenericWritingSubmissionResult {
  const GenericWritingSubmissionResult({
    required this.exerciseId,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.attemptNumber,
    this.taskFeedback = const [],
  });

  final int exerciseId;
  final int score;
  final int maxScore;

  /// Percentage, 0-100.
  final int percentage;
  final int attemptNumber;

  /// Parsed from `customSummaryHtml` (see [WritingTaskFeedback] /
  /// `parseWritingSummaryHtml`) — one entry per prompt the AI branch
  /// actually produced feedback for.
  final List<WritingTaskFeedback> taskFeedback;
}
