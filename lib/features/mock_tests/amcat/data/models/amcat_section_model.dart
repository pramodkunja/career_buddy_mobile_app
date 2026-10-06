import '../../../../../core/utils/json_parsing.dart';
import '../../domain/entities/amcat_question.dart';
import '../../domain/entities/amcat_section.dart';

/// Parses `amcat_questions`'s `"sections"` array
/// (`activities/views.py:2291-2303`): each entry is
/// `{"key", "name", "timeSec", "type", "questions": [{"id", "q", "options"}]}`.
/// `type` is parsed nowhere — see `AmcatSection`'s doc comment for why.
extension AmcatSectionParsing on AmcatSection {
  static AmcatSection fromJson(Map<String, dynamic> json) {
    return AmcatSection(
      key: requireString(json, 'key'),
      name: requireString(json, 'name'),
      timeSeconds: requireInt(json, 'timeSec'),
      questions: requireList(json, 'questions').map((e) => _questionFromJson(asMap(e, 'questions[]'))).toList(),
    );
  }

  static AmcatQuestion _questionFromJson(Map<String, dynamic> json) {
    return AmcatQuestion(
      id: requireInt(json, 'id'),
      questionText: requireString(json, 'q'),
      options: requireList(json, 'options').map((e) => e.toString()).toList(),
    );
  }
}
