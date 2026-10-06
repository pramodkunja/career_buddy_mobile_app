import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeJamAssessmentEligibility', () {
    test('all 3 difficulties completed → eligible, no missing labels', () {
      final eligibility = computeJamAssessmentEligibility(const [
        JamPracticeSessionSummary(difficulty: 'easy'),
        JamPracticeSessionSummary(difficulty: 'medium'),
        JamPracticeSessionSummary(difficulty: 'hard'),
      ]);

      expect(eligibility.easyDone, isTrue);
      expect(eligibility.mediumDone, isTrue);
      expect(eligibility.hardDone, isTrue);
      expect(eligibility.isEligible, isTrue);
      expect(eligibility.missingLevelLabels, isEmpty);
      expect(eligibility.ineligibleReason, isEmpty);
    });

    test('duplicate sessions at the same difficulty still count as done once', () {
      final eligibility = computeJamAssessmentEligibility(const [
        JamPracticeSessionSummary(difficulty: 'easy'),
        JamPracticeSessionSummary(difficulty: 'easy'),
        JamPracticeSessionSummary(difficulty: 'medium'),
        JamPracticeSessionSummary(difficulty: 'hard'),
      ]);

      expect(eligibility.isEligible, isTrue);
    });

    test('missing the hard difficulty → not eligible, reports only Hard as missing', () {
      final eligibility = computeJamAssessmentEligibility(const [
        JamPracticeSessionSummary(difficulty: 'easy'),
        JamPracticeSessionSummary(difficulty: 'medium'),
      ]);

      expect(eligibility.hardDone, isFalse);
      expect(eligibility.isEligible, isFalse);
      expect(eligibility.missingLevelLabels, ['Hard']);
      expect(eligibility.ineligibleReason, contains('Still pending: Hard.'));
    });

    test('missing medium and hard → reports both, in easy-medium-hard order', () {
      final eligibility = computeJamAssessmentEligibility(const [JamPracticeSessionSummary(difficulty: 'easy')]);

      expect(eligibility.missingLevelLabels, ['Intermediate', 'Hard']);
      expect(eligibility.ineligibleReason, contains('Still pending: Intermediate, Hard.'));
      expect(
        eligibility.ineligibleReason,
        contains('Complete one topic from each of the three levels (Simple, Intermediate, Hard)'),
      );
    });

    test('no completed sessions at all → nothing done, every level missing', () {
      final eligibility = computeJamAssessmentEligibility(const []);

      expect(eligibility.easyDone, isFalse);
      expect(eligibility.mediumDone, isFalse);
      expect(eligibility.hardDone, isFalse);
      expect(eligibility.isEligible, isFalse);
      expect(eligibility.missingLevelLabels, ['Simple', 'Intermediate', 'Hard']);
    });
  });
}
