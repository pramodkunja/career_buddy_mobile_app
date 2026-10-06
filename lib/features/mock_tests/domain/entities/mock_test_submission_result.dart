import 'mock_test_question_result.dart';

/// The server's response to `oop_quiz_submit`/`quiz_submit`
/// (`activities/views.py`) — fully server-authoritative: `score` is
/// computed by comparing each submitted answer against the question bank
/// server-side, never trusted from the client.
class MockTestSubmissionResult {
  const MockTestSubmissionResult({required this.score, required this.total, required this.results});

  final int score;
  final int total;

  /// Question id -> its grading outcome. Keyed by id (not position), same
  /// as the wire response.
  final Map<int, MockTestQuestionResult> results;

  double get percentage => total == 0 ? 0 : (score / total) * 100;
}
