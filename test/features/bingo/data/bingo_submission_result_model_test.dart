import 'package:career_buddy_lms/features/bingo/data/models/bingo_submission_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BingoSubmissionResultParsing.fromJson', () {
    test('parses every field from a full response', () {
      final result = BingoSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 10, 'max_score': 16, 'percentage': 63, 'attempt': 2, 'customSummaryHtml': ''},
        exerciseId: 7,
        fallbackScore: 0,
        fallbackMaxScore: 0,
      );

      expect(result.exerciseId, 7);
      expect(result.score, 10);
      expect(result.maxScore, 16);
      expect(result.percentage, 63);
      expect(result.attemptNumber, 2);
    });

    test('falls back to the client-sent score/max_score/percentage when the server omits them', () {
      final result = BingoSubmissionResultParsing.fromJson(
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
        () => BingoSubmissionResultParsing.fromJson(
          {'status': 'ok', 'score': 1, 'max_score': 1},
          exerciseId: 1,
          fallbackScore: 1,
          fallbackMaxScore: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a zero max_score does not divide by zero when deriving percentage', () {
      final result = BingoSubmissionResultParsing.fromJson(
        {'attempt': 1},
        exerciseId: 1,
        fallbackScore: 0,
        fallbackMaxScore: 0,
      );
      expect(result.percentage, 0);
    });
  });
}
