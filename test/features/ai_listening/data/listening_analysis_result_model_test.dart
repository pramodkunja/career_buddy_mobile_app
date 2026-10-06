import 'package:career_buddy_lms/features/ai_listening/data/models/listening_analysis_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validData({bool includeScore25 = true, bool includeMatch = true}) => {
  'text': 'My summary of the story.',
  'issues': [
    {'phrase': 'a apple', 'type': 'Grammar', 'message': 'Article mismatch.', 'suggestion': 'an apple'},
  ],
  'improved_passage': 'My improved summary.',
  'feedback': 'Your response has been reviewed for meaning and language quality.',
  'quick_tip': 'Keep practicing for better results.',
  'scores': {'fluency': 80, 'accuracy': 70},
  if (includeScore25) 'score_25': 18,
  if (includeMatch) 'content_match_percent': 72,
};

void main() {
  group('ListeningAnalysisResultParsing.fromJson', () {
    test('parses every field from a full valid "data" object', () {
      final result = ListeningAnalysisResultParsing.fromJson(_validData());

      expect(result.text, 'My summary of the story.');
      expect(result.issues, hasLength(1));
      expect(result.issues.single.suggestion, 'an apple');
      expect(result.improvedPassage, 'My improved summary.');
      expect(result.feedback, 'Your response has been reviewed for meaning and language quality.');
      expect(result.scores, {'fluency': 80, 'accuracy': 70});
      expect(result.score25, 18);
      expect(result.contentMatchPercent, 72);
    });

    test('throws a FormatException when "score_25" is missing from "data"', () {
      final data = _validData(includeScore25: false);
      expect(() => ListeningAnalysisResultParsing.fromJson(data), throwsFormatException);
    });

    test('throws a FormatException when "content_match_percent" is missing from "data"', () {
      final data = _validData(includeMatch: false);
      expect(() => ListeningAnalysisResultParsing.fromJson(data), throwsFormatException);
    });

    test('an empty issues list parses to an empty list, not an error', () {
      final data = _validData()..['issues'] = <dynamic>[];
      final result = ListeningAnalysisResultParsing.fromJson(data);
      expect(result.issues, isEmpty);
    });

    test('a non-numeric entry inside "scores" is silently dropped, not a parse error', () {
      final data = _validData()..['scores'] = {'fluency': 80, 'note': 'ignored'};
      final result = ListeningAnalysisResultParsing.fromJson(data);
      expect(result.scores, {'fluency': 80});
    });

    test('throws a FormatException when "feedback" is missing', () {
      final data = _validData()..remove('feedback');
      expect(() => ListeningAnalysisResultParsing.fromJson(data), throwsFormatException);
    });

    test('throws a FormatException when an issue entry is missing a required field', () {
      final data = _validData()
        ..['issues'] = [
          {'phrase': 'a', 'type': 'Grammar', 'message': 'msg'},
        ];
      expect(() => ListeningAnalysisResultParsing.fromJson(data), throwsFormatException);
    });
  });
}
