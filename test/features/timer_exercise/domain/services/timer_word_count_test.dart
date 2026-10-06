import 'package:career_buddy_lms/features/timer_exercise/domain/services/timer_word_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countTimerWords', () {
    test('an empty string counts as 0', () {
      expect(countTimerWords(''), 0);
    });

    test('a whitespace-only string counts as 0', () {
      expect(countTimerWords('   \n\t  '), 0);
    });

    test('counts words separated by any run of whitespace', () {
      expect(countTimerWords('one two   three\nfour'), 4);
    });

    test('punctuation is never stripped', () {
      expect(countTimerWords('well-known, hello!'), 2);
    });

    test('leading/trailing whitespace does not add phantom words', () {
      expect(countTimerWords('  one two  '), 2);
    });
  });
}
