import 'package:career_buddy_lms/features/fill_blank/data/models/fill_blank_submission_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FillBlankSubmissionResultParsing.fromJson', () {
    test('parses every field from a full response', () {
      final result = FillBlankSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 3, 'max_score': 4, 'percentage': 75, 'attempt': 2, 'customSummaryHtml': ''},
        exerciseId: 42,
        fallbackScore: 0,
        fallbackMaxScore: 0,
      );

      expect(result.exerciseId, 42);
      expect(result.score, 3);
      expect(result.maxScore, 4);
      expect(result.percentage, 75);
      expect(result.attemptNumber, 2);
    });

    test('falls back to the client-sent score/max_score/percentage when the server omits them', () {
      final result = FillBlankSubmissionResultParsing.fromJson(
        {'status': 'ok', 'attempt': 1},
        exerciseId: 1,
        fallbackScore: 2,
        fallbackMaxScore: 4,
      );

      expect(result.score, 2);
      expect(result.maxScore, 4);
      expect(result.percentage, 50);
    });

    test('throws FormatException when "attempt" is missing — the one field with no honest fallback', () {
      expect(
        () => FillBlankSubmissionResultParsing.fromJson(
          {'status': 'ok', 'score': 1, 'max_score': 1},
          exerciseId: 1,
          fallbackScore: 1,
          fallbackMaxScore: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a zero max_score does not divide by zero when deriving percentage', () {
      final result = FillBlankSubmissionResultParsing.fromJson(
        {'attempt': 1},
        exerciseId: 1,
        fallbackScore: 0,
        fallbackMaxScore: 0,
      );
      expect(result.percentage, 0);
    });
  });
}
