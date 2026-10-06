import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/mock_test_question_result.dart';
import '../../domain/entities/mock_test_submission_result.dart';

/// Parses `oop_quiz_submit`/`quiz_submit`'s response
/// (`activities/views.py:2185-2193,2256-2264`): `score` (int), `total`
/// (int), and `results` — a map of stringified question id to
/// `{"correct": bool, ["answer": int, "explanation": str] if attempted}`.
/// `results` keys are stringified question ids (standard JSON object-key
/// behavior), parsed back to `int` here.
extension MockTestSubmissionResultParsing on MockTestSubmissionResult {
  static MockTestSubmissionResult fromJson(Map<String, dynamic> json) {
    final resultsJson = requireMap(json, 'results');
    return MockTestSubmissionResult(
      score: requireInt(json, 'score'),
      total: requireInt(json, 'total'),
      results: resultsJson.map((key, value) {
        final id = int.tryParse(key);
        if (id == null) throw FormatException('Expected a numeric question id key, got: $key');
        return MapEntry(id, _resultFromJson(asMap(value, 'results["$key"]')));
      }),
    );
  }

  static MockTestQuestionResult _resultFromJson(Map<String, dynamic> json) {
    return MockTestQuestionResult(
      isCorrect: requireBool(json, 'correct'),
      // `answer`/`explanation` are only present when the question was
      // attempted (`activities/views.py:2186-2188`) — absent, not null, so
      // a plain map lookup (not `requireInt`/`requireString`) is correct
      // here.
      correctAnswerIndex: json['answer'] is int ? json['answer'] as int : null,
      explanation: json['explanation'] is String ? json['explanation'] as String : null,
    );
  }
}
