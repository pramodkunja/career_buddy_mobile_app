import 'package:career_buddy_lms/features/generic_writing/data/models/generic_writing_submission_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenericWritingSubmissionResultParsing.fromJson', () {
    test('parses score/max_score/percentage/attempt when all present', () {
      final result = GenericWritingSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 78, 'max_score': 100, 'percentage': 78, 'attempt': 2},
        exerciseId: 5,
        fallbackScore: -1,
        fallbackMaxScore: -1,
      );

      expect(result.exerciseId, 5);
      expect(result.score, 78);
      expect(result.maxScore, 100);
      expect(result.percentage, 78);
      expect(result.attemptNumber, 2);
      expect(result.taskFeedback, isEmpty);
    });

    test('missing "attempt" is treated as a malformed response, not silently defaulted', () {
      expect(
        () => GenericWritingSubmissionResultParsing.fromJson(
          {'status': 'ok', 'score': 1, 'max_score': 100},
          exerciseId: 5,
          fallbackScore: 0,
          fallbackMaxScore: 100,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a missing score/max_score falls back to the caller-supplied client values', () {
      final result = GenericWritingSubmissionResultParsing.fromJson(
        {'status': 'ok', 'attempt': 1},
        exerciseId: 5,
        fallbackScore: 42,
        fallbackMaxScore: 100,
      );
      expect(result.score, 42);
      expect(result.maxScore, 100);
      expect(result.percentage, 42);
    });

    test('an empty customSummaryHtml (SARVAM_API_KEY unset, the server fallback path) parses to no task feedback', () {
      final result = GenericWritingSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 80, 'max_score': 100, 'percentage': 80, 'attempt': 1, 'customSummaryHtml': ''},
        exerciseId: 5,
        fallbackScore: 80,
        fallbackMaxScore: 100,
      );
      expect(result.taskFeedback, isEmpty);
    });

    test('a non-empty customSummaryHtml is parsed into structured task feedback', () {
      const html =
          "<div class='mt-3 mb-2 text-start'><strong>Task 1:</strong></div>"
          "<div class='text-success text-start mb-2 ps-2'><i class='fas fa-check-circle me-1'></i>No major issues found.</div>";
      final result = GenericWritingSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 90, 'max_score': 100, 'percentage': 90, 'attempt': 1, 'customSummaryHtml': html},
        exerciseId: 5,
        fallbackScore: 90,
        fallbackMaxScore: 100,
      );
      expect(result.taskFeedback, hasLength(1));
      expect(result.taskFeedback.single.taskNumber, 1);
    });
  });
}
