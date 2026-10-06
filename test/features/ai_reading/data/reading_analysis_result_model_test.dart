import 'package:career_buddy_lms/features/ai_reading/data/models/reading_analysis_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validData({bool includeScore25 = true}) => {
  'text': 'The reference passage with mistakes highlighted.',
  'issues': [
    {'phrase': 'a apple', 'type': 'Pronunciation', 'message': 'Mispronounced.', 'suggestion': 'an apple'},
  ],
  'improved_passage': 'An improved reading.',
  'feedback': 'Great reading. You are improving with good pace and clarity.',
  'quick_tip': 'Track each word carefully and try to match the passage exactly as written.',
  'scores': {'accuracy': 80, 'pronunciation': 75},
  'user_transcript': 'the user actually said this, never displayed',
  if (includeScore25) 'score_25': 20,
};

void main() {
  group('ReadingAnalysisResultParsing.fromJson', () {
    test('parses every field from a full valid "data" object', () {
      final result = ReadingAnalysisResultParsing.fromJson(_validData());

      expect(result.text, 'The reference passage with mistakes highlighted.');
      expect(result.issues, hasLength(1));
      expect(result.issues.single.suggestion, 'an apple');
      expect(result.improvedPassage, 'An improved reading.');
      expect(result.feedback, 'Great reading. You are improving with good pace and clarity.');
      expect(result.quickTip, 'Track each word carefully and try to match the passage exactly as written.');
      expect(result.scores, {'accuracy': 80, 'pronunciation': 75});
      expect(result.score25, 20);
    });

    test('throws a FormatException when "score_25" is missing from "data"', () {
      final data = _validData(includeScore25: false);
      expect(() => ReadingAnalysisResultParsing.fromJson(data), throwsFormatException);
    });

    test('an empty issues list parses to an empty list, not an error', () {
      final data = _validData()..['issues'] = <dynamic>[];
      final result = ReadingAnalysisResultParsing.fromJson(data);
      expect(result.issues, isEmpty);
    });

    test('a non-numeric entry inside "scores" is silently dropped, not a parse error', () {
      final data = _validData()..['scores'] = {'accuracy': 80, 'note': 'ignored'};
      final result = ReadingAnalysisResultParsing.fromJson(data);
      expect(result.scores, {'accuracy': 80});
    });

    test('throws a FormatException when "feedback" is missing', () {
      final data = _validData()..remove('feedback');
      expect(() => ReadingAnalysisResultParsing.fromJson(data), throwsFormatException);
    });

    test('throws a FormatException when "quick_tip" is missing', () {
      final data = _validData()..remove('quick_tip');
      expect(() => ReadingAnalysisResultParsing.fromJson(data), throwsFormatException);
    });

    test('throws a FormatException when an issue entry is missing a required field', () {
      final data = _validData()
        ..['issues'] = [
          {'phrase': 'a', 'type': 'Grammar', 'message': 'msg'},
        ];
      expect(() => ReadingAnalysisResultParsing.fromJson(data), throwsFormatException);
    });
  });
}
