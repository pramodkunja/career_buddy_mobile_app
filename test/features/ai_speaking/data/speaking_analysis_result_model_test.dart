import 'package:career_buddy_lms/features/ai_speaking/data/models/speaking_analysis_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validJson({bool withTranscript = true}) => {
  if (withTranscript) 'transcript': 'This is my transcript.' else 'text': 'Fallback text.',
  'issues': [
    {'phrase': 'a apple', 'type': 'Grammar', 'message': 'Article mismatch.', 'suggestion': 'an apple'},
  ],
  'improved_passage': 'This is my improved passage.',
  'feedback': 'Solid attempt overall.',
  'scores': {'fluency': 80, 'pronunciation': 75.5, 'relevance': 90},
  'score_25': 20,
  'duration_seconds': 42,
  'pause_count': 2,
};

void main() {
  group('SpeakingAnalysisResultParsing.fromJson', () {
    test('parses every field from a full valid response', () {
      final result = SpeakingAnalysisResultParsing.fromJson(_validJson());

      expect(result.transcript, 'This is my transcript.');
      expect(result.issues, hasLength(1));
      expect(result.issues.single.phrase, 'a apple');
      expect(result.issues.single.type, 'Grammar');
      expect(result.issues.single.message, 'Article mismatch.');
      expect(result.issues.single.suggestion, 'an apple');
      expect(result.improvedPassage, 'This is my improved passage.');
      expect(result.feedback, 'Solid attempt overall.');
      expect(result.scores, {'fluency': 80, 'pronunciation': 75.5, 'relevance': 90});
      expect(result.score25, 20);
      expect(result.durationSeconds, 42.0);
      expect(result.pauseCount, 2);
    });

    test('falls back to "text" when "transcript" is absent, mirroring the view setting transcript = text', () {
      final result = SpeakingAnalysisResultParsing.fromJson(_validJson(withTranscript: false));
      expect(result.transcript, 'Fallback text.');
    });

    test('a null/non-string "feedback" is treated as absent, not a parse error', () {
      final json = _validJson()..['feedback'] = null;
      final result = SpeakingAnalysisResultParsing.fromJson(json);
      expect(result.feedback, isNull);
    });

    test('an empty issues list parses to an empty list, not an error', () {
      final json = _validJson()..['issues'] = <dynamic>[];
      final result = SpeakingAnalysisResultParsing.fromJson(json);
      expect(result.issues, isEmpty);
    });

    test('a non-numeric entry inside "scores" is silently dropped, not a parse error', () {
      final json = _validJson()..['scores'] = {'fluency': 80, 'note': 'ignored, not a number'};
      final result = SpeakingAnalysisResultParsing.fromJson(json);
      expect(result.scores, {'fluency': 80});
    });

    test('throws a FormatException when a required field is missing', () {
      final json = _validJson()..remove('score_25');
      expect(() => SpeakingAnalysisResultParsing.fromJson(json), throwsFormatException);
    });

    test('throws a FormatException when a required field has the wrong type', () {
      final json = _validJson()..['issues'] = 'not a list';
      expect(() => SpeakingAnalysisResultParsing.fromJson(json), throwsFormatException);
    });

    test('throws a FormatException when an issue entry is missing a required field', () {
      final json = _validJson()
        ..['issues'] = [
          {'phrase': 'a', 'type': 'Grammar', 'message': 'msg'},
        ];
      expect(() => SpeakingAnalysisResultParsing.fromJson(json), throwsFormatException);
    });
  });
}
