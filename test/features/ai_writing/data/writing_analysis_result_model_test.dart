import 'package:career_buddy_lms/features/ai_writing/data/models/writing_analysis_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validBody({bool includeScore25 = true}) => {
  'success': true,
  'data': {
    'text': 'This is my essay.',
    'issues': [
      {'phrase': 'a apple', 'type': 'Grammar', 'message': 'Article mismatch.', 'suggestion': 'an apple'},
    ],
    'improved_passage': 'This is my improved essay.',
    'feedback': 'Solid attempt overall.',
    'scores': {'grammar': 80, 'vocabulary': 75.5, 'overall': 78},
  },
  'error': null,
  if (includeScore25) 'score_25': 20,
};

void main() {
  group('WritingAnalysisResultParsing.fromJson', () {
    test('parses every field from a full valid response body, score_25 from the TOP level', () {
      final body = _validBody();
      (body['data'] as Map<String, dynamic>)['quick_tip'] = 'Read your draft once more.';
      final result = WritingAnalysisResultParsing.fromJson(body);

      expect(result.text, 'This is my essay.');
      expect(result.issues, hasLength(1));
      expect(result.issues.single.phrase, 'a apple');
      expect(result.issues.single.suggestion, 'an apple');
      expect(result.improvedPassage, 'This is my improved essay.');
      expect(result.feedback, 'Solid attempt overall.');
      expect(result.quickTip, 'Read your draft once more.');
      expect(result.scores, {'grammar': 80, 'vocabulary': 75.5, 'overall': 78});
      expect(result.score25, 20);
    });

    test('throws a FormatException when the top-level "score_25" is missing — it is never inside "data"', () {
      final body = _validBody(includeScore25: false);
      (body['data'] as Map<String, dynamic>)['quick_tip'] = 'tip';
      expect(() => WritingAnalysisResultParsing.fromJson(body), throwsFormatException);
    });

    test('throws a FormatException if "score_25" is only (incorrectly) placed inside "data"', () {
      final body = _validBody(includeScore25: false);
      (body['data'] as Map<String, dynamic>)
        ..['quick_tip'] = 'tip'
        ..['score_25'] = 20;
      expect(() => WritingAnalysisResultParsing.fromJson(body), throwsFormatException);
    });

    test('an empty issues list parses to an empty list, not an error', () {
      final body = _validBody();
      (body['data'] as Map<String, dynamic>)
        ..['issues'] = <dynamic>[]
        ..['quick_tip'] = 'tip';
      final result = WritingAnalysisResultParsing.fromJson(body);
      expect(result.issues, isEmpty);
    });

    test('a non-numeric entry inside "scores" is silently dropped, not a parse error', () {
      final body = _validBody();
      (body['data'] as Map<String, dynamic>)
        ..['scores'] = {'grammar': 80, 'note': 'ignored, not a number'}
        ..['quick_tip'] = 'tip';
      final result = WritingAnalysisResultParsing.fromJson(body);
      expect(result.scores, {'grammar': 80});
    });

    test('throws a FormatException when "feedback" is missing (unlike Speaking, it is required here)', () {
      final body = _validBody();
      (body['data'] as Map<String, dynamic>)
        ..remove('feedback')
        ..['quick_tip'] = 'tip';
      expect(() => WritingAnalysisResultParsing.fromJson(body), throwsFormatException);
    });

    test('throws a FormatException when "quick_tip" is missing', () {
      final body = _validBody();
      expect(() => WritingAnalysisResultParsing.fromJson(body), throwsFormatException);
    });

    test('throws a FormatException when an issue entry is missing a required field', () {
      final body = _validBody();
      (body['data'] as Map<String, dynamic>)
        ..['issues'] = [
          {'phrase': 'a', 'type': 'Grammar', 'message': 'msg'},
        ]
        ..['quick_tip'] = 'tip';
      expect(() => WritingAnalysisResultParsing.fromJson(body), throwsFormatException);
    });
  });
}
