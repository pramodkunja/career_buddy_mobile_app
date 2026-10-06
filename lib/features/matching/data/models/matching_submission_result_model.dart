import '../../domain/entities/matching_submission_result.dart';

/// Parses `POST /activities/exercise/<id>/submit/`'s response —
/// `{"status": "ok", "score", "max_score", "percentage", "attempt",
/// "customSummaryHtml"}` (`activities/views.py:1519-1526`), the same
/// generic, non-enveloped endpoint W007/W009 would also use. `attempt` is
/// the only field with no client-side fallback (see
/// `MatchingSubmissionResult`'s doc comment) — a missing/wrong-type value
/// there is treated as a malformed response, not silently defaulted.
extension MatchingSubmissionResultParsing on MatchingSubmissionResult {
  static MatchingSubmissionResult fromJson(
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

    return MatchingSubmissionResult(
      exerciseId: exerciseId,
      score: score,
      maxScore: maxScore,
      percentage: percentage,
      attemptNumber: attempt,
    );
  }
}
