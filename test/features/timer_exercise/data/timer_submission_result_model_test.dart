import 'package:career_buddy_lms/features/timer_exercise/data/models/timer_submission_result_model.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimerSubmissionResultParsing.fromJson', () {
    test('uses the server score/max_score/percentage when present', () {
      final result = TimerSubmissionResultParsing.fromJson(
        {'status': 'ok', 'score': 2, 'max_score': 3, 'percentage': 67, 'attempt': 2, 'customSummaryHtml': ''},
        exerciseId: 7,
        fallbackScore: 1,
        fallbackMaxScore: 3,
      );

      expect(result.score, 2);
      expect(result.maxScore, 3);
      expect(result.percentage, 67);
      expect(result.attemptNumber, 2);
    });

    test('falls back to the client-sent score/max_score when the server omits them', () {
      final result = TimerSubmissionResultParsing.fromJson({'status': 'ok', 'attempt': 1}, exerciseId: 7, fallbackScore: 2, fallbackMaxScore: 3);

      expect(result.score, 2);
      expect(result.maxScore, 3);
      expect(result.percentage, 67); // computed: round(2/3*100)
    });

    test('throws FormatException when "attempt" is missing or the wrong type', () {
      expect(
        () => TimerSubmissionResultParsing.fromJson({'status': 'ok'}, exerciseId: 7, fallbackScore: 0, fallbackMaxScore: 3),
        throwsFormatException,
      );
    });

    test('never reads customSummaryHtml into any feedback field (there is none on TimerSubmissionResult)', () {
      final result = TimerSubmissionResultParsing.fromJson(
        {'score': 1, 'max_score': 3, 'percentage': 33, 'attempt': 1, 'customSummaryHtml': '<div>ignored</div>'},
        exerciseId: 7,
        fallbackScore: 0,
        fallbackMaxScore: 3,
      );
      expect(result, isA<TimerSubmissionResult>());
      // No taskFeedback-style field exists on TimerSubmissionResult at all —
      // this test simply documents that customSummaryHtml is never
      // consulted for `timer` (see the entity's own doc comment).
    });
  });
}
