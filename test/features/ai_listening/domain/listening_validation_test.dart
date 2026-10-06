import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasMeaningfulText', () {
    test('false for empty text', () {
      expect(hasMeaningfulText(''), isFalse);
    });

    test('false when fewer than 4 words', () {
      expect(hasMeaningfulText('one two three'), isFalse);
    });

    test('false when 4+ words but under 12 total letters', () {
      expect(hasMeaningfulText('a a a a'), isFalse);
    });

    test('true when both the word-count and letter-count minimums are met', () {
      expect(hasMeaningfulText('Riya woke up late'), isTrue);
    });

    test('custom thresholds are honored', () {
      expect(hasMeaningfulText('one two', minWords: 2, minLetters: 4), isTrue);
    });
  });
}
