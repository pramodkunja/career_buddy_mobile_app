import 'package:career_buddy_lms/features/generic_writing/domain/services/writing_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getWritingLimits', () {
    test('defaults to a 50-word minimum with no maximum when nothing else matches', () {
      final limits = getWritingLimits(exerciseTitle: 'Some Exercise', questionText: 'Write about your day.');
      expect(limits.min, 50);
      expect(limits.max, isNull);
    });

    test('an explicit "X-Y words" range in the guide text is used', () {
      final limits = getWritingLimits(
        exerciseTitle: 'Negotiation Outcome Reflection',
        questionText: 'Describe the outcome.',
        guide: 'Aim for 80-120 words. Use past tense.',
      );
      expect(limits.min, 80);
      expect(limits.max, 120);
    });

    test('an en-dash range ("80–120 words") is recognized the same as a hyphen', () {
      final limits = getWritingLimits(exerciseTitle: 'X', questionText: 'Q', guide: 'Aim for 80–120 words.');
      expect(limits.min, 80);
      expect(limits.max, 120);
    });

    test('a "to" range ("80 to 120 words") is recognized', () {
      final limits = getWritingLimits(exerciseTitle: 'X', questionText: 'Q', guide: 'Write 80 to 120 words.');
      expect(limits.min, 80);
      expect(limits.max, 120);
    });

    test('a single count ("150 words") sets the minimum with no maximum', () {
      final limits = getWritingLimits(exerciseTitle: 'X', questionText: 'Q', guide: 'Write at least 150 words.');
      expect(limits.min, 150);
      expect(limits.max, isNull);
    });

    test('the exercise title "Proposal Section Writing" forces 150-200 regardless of guide text', () {
      final limits = getWritingLimits(
        exerciseTitle: 'Proposal Section Writing',
        questionText: 'Q',
        guide: 'Write 500 words.',
      );
      expect(limits.min, 150);
      expect(limits.max, 200);
    });

    test('the exercise title check is case-insensitive', () {
      final limits = getWritingLimits(exerciseTitle: 'PROPOSAL SECTION WRITING', questionText: 'Q');
      expect(limits.min, 150);
      expect(limits.max, 200);
    });

    test('question text containing "proposal section" forces 150-200 even under a different exercise title', () {
      final limits = getWritingLimits(exerciseTitle: 'Some Other Exercise', questionText: 'Write the Proposal Section for the client.');
      expect(limits.min, 150);
      expect(limits.max, 200);
    });

    test('no guide text at all falls through to the default', () {
      final limits = getWritingLimits(exerciseTitle: 'X', questionText: 'Q');
      expect(limits.min, 50);
      expect(limits.max, isNull);
    });
  });
}
