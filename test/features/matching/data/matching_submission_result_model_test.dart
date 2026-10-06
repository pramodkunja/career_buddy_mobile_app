import 'package:career_buddy_lms/features/matching/data/models/matching_submission_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchingSubmissionResultParsing.fromJson', () {
    test('parses every field from a full response', () {
      final result = MatchingSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 4, 'max_score': 5, 'percentage': 80, 'attempt': 2, 'customSummaryHtml': ''},
        exerciseId: 42,
        fallbackScore: 0,
        fallbackMaxScore: 0,
      );

      expect(result.exerciseId, 42);
      expect(result.score, 4);
      expect(result.maxScore, 5);
      expect(result.percentage, 80);
      expect(result.attemptNumber, 2);
    });

    test('falls back to the client-sent score/max_score/percentage when the server omits them — '
        'mirrors submitScore()\'s own preference', () {
      final result = MatchingSubmissionResultParsing.fromJson(
        {'status': 'ok', 'attempt': 1},
        exerciseId: 1,
        fallbackScore: 3,
        fallbackMaxScore: 5,
      );

      expect(result.score, 3);
      expect(result.maxScore, 5);
      expect(result.percentage, 60);
    });

    test('throws FormatException when "attempt" is missing — the one field with no honest fallback', () {
      expect(
        () => MatchingSubmissionResultParsing.fromJson(
          {'status': 'ok', 'score': 1, 'max_score': 1},
          exerciseId: 1,
          fallbackScore: 1,
          fallbackMaxScore: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a zero max_score does not divide by zero when deriving percentage', () {
      final result = MatchingSubmissionResultParsing.fromJson(
        {'attempt': 1},
        exerciseId: 1,
        fallbackScore: 0,
        fallbackMaxScore: 0,
      );
      expect(result.percentage, 0);
    });
  });
}
