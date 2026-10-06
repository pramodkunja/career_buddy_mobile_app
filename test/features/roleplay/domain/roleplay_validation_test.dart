import 'package:career_buddy_lms/features/roleplay/domain/services/roleplay_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roleplayPromptMissingSecondCharacter', () {
    test('empty prompt is never missing a second character (falls back server-side)', () {
      expect(roleplayPromptMissingSecondCharacter(''), isFalse);
      expect(roleplayPromptMissingSecondCharacter('   '), isFalse);
    });

    test('a short single-subject prompt is missing a second character', () {
      expect(roleplayPromptMissingSecondCharacter('Manager'), isTrue);
      expect(roleplayPromptMissingSecondCharacter('Environment'), isTrue);
    });

    test('a short prompt with a connector word names a second character', () {
      expect(roleplayPromptMissingSecondCharacter('Student and Teacher'), isFalse);
      expect(roleplayPromptMissingSecondCharacter('Customer vs Shopkeeper'), isFalse);
      expect(roleplayPromptMissingSecondCharacter('Teammate with Manager'), isFalse);
      expect(roleplayPromptMissingSecondCharacter('Boss & Employee'), isFalse);
      expect(roleplayPromptMissingSecondCharacter('Doctor, Patient'), isFalse);
    });

    test('a longer prompt is assumed to already describe an interaction', () {
      expect(roleplayPromptMissingSecondCharacter('Customer asking for a refund'), isFalse);
    });

    test('a 3-word prompt with no connector is still missing a second character', () {
      expect(roleplayPromptMissingSecondCharacter('Angry customer complaint'), isTrue);
    });

    test('a prompt over 3 words with no connector is assumed to already describe an interaction', () {
      expect(roleplayPromptMissingSecondCharacter('A very angry customer complaint'), isFalse);
    });
  });
}
