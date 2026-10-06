import '../../domain/entities/generic_writing_submission_result.dart';
import '../../domain/services/writing_summary_parser.dart';

/// Parses `POST /activities/exercise/<id>/submit/`'s response —
/// `{"status": "ok", "score", "max_score", "percentage", "attempt",
/// "customSummaryHtml"}` (`activities/views.py:1519-1526`), the exact same
/// generic, non-enveloped endpoint Matching/Bingo/Fill in the Blank use.
/// `attempt` is the only field with no client-side fallback; a
/// missing/wrong-type value there is treated as a malformed response, not
/// silently defaulted. `customSummaryHtml` is parsed via
/// [parseWritingSummaryHtml] rather than kept as a raw string — see that
/// function's doc comment.
extension GenericWritingSubmissionResultParsing on GenericWritingSubmissionResult {
  static GenericWritingSubmissionResult fromJson(
    Map<String, dynamic> json, {
    required int exerciseId,
    required int fallbackScore,
    required int fallbackMaxScore,
  }) {
    final attempt = json['attempt'];
    if (attempt is! int) {
      throw const FormatException('Expected "attempt" to be an int');
    }
    final score = json['score'] is int ? json['score'] as int : fallbackScore;
    final maxScore = json['max_score'] is int ? json['max_score'] as int : fallbackMaxScore;
    final percentage = json['percentage'] is int
        ? json['percentage'] as int
        : (maxScore == 0 ? 0 : ((score / maxScore) * 100).round());
    final customSummaryHtml = json['customSummaryHtml'];

    return GenericWritingSubmissionResult(
      exerciseId: exerciseId,
      score: score,
      maxScore: maxScore,
      percentage: percentage,
      attemptNumber: attempt,
      taskFeedback: customSummaryHtml is String && customSummaryHtml.isNotEmpty
          ? parseWritingSummaryHtml(customSummaryHtml)
          : const [],
    );
  }
}
