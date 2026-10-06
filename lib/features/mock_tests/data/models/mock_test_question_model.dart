import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/mock_test_question.dart';

/// Parses one item of `oop_quiz_questions`/`quiz_questions`'s `"questions"`
/// array (`activities/views.py:2150-2154,2223-2227`):
/// `{"id", "q", "options", "difficulty", "topic"}`. Deliberately has no
/// `answer`/`explanation` field to parse — the server never sends them here.
extension MockTestQuestionParsing on MockTestQuestion {
  static MockTestQuestion fromJson(Map<String, dynamic> json) {
    return MockTestQuestion(
      id: requireInt(json, 'id'),
      questionText: requireString(json, 'q'),
      options: requireList(json, 'options').map((e) => e.toString()).toList(),
      // Always present in practice (verified in `activities/data/oop_questions.json`
      // and by the generic `quiz_questions` view's own `.get(key, "")`
      // construction), but treated as optional here to stay safe against a
      // stray null and to keep this parser reusable for other subject
      // banks later without a stricter guarantee.
      difficulty: json['difficulty'] is String ? json['difficulty'] as String : '',
      topic: json['topic'] is String ? json['topic'] as String : '',
    );
  }
}
