import '../../../../../core/utils/json_parsing.dart';
import '../../domain/entities/amcat_submission_result.dart';

/// Parses `amcat_submit`'s response (`activities/views.py:2308-2343`):
/// `{"score", "total", "sections": {key: {"name","correct","total"}},
/// "results": {id: {"correct", "section", ["answer"], ["explanation"]}}}`.
/// `results` and `sections` keys are both stringified in JSON (section by
/// key, question by id) — parsed back here.
extension AmcatSubmissionResultParsing on AmcatSubmissionResult {
  static AmcatSubmissionResult fromJson(Map<String, dynamic> json) {
    final sectionsJson = requireMap(json, 'sections');
    final resultsJson = requireMap(json, 'results');
    return AmcatSubmissionResult(
      score: requireInt(json, 'score'),
      total: requireInt(json, 'total'),
      sectionScores: sectionsJson.map(
        (key, value) => MapEntry(key, _sectionScoreFromJson(asMap(value, 'sections["$key"]'))),
      ),
      questionResults: resultsJson.map((key, value) {
        final id = int.tryParse(key);
        if (id == null) throw FormatException('Expected a numeric question id key, got: $key');
        return MapEntry(id, _questionResultFromJson(asMap(value, 'results["$key"]')));
      }),
    );
  }

  static AmcatSectionScore _sectionScoreFromJson(Map<String, dynamic> json) {
    return AmcatSectionScore(name: requireString(json, 'name'), correct: requireInt(json, 'correct'), total: requireInt(json, 'total'));
  }

  static AmcatQuestionResult _questionResultFromJson(Map<String, dynamic> json) {
    return AmcatQuestionResult(
      isCorrect: requireBool(json, 'correct'),
      // Only present when attempted — see `AmcatQuestionResult`'s doc.
      correctAnswerIndex: json['answer'] is int ? json['answer'] as int : null,
    );
  }
}
