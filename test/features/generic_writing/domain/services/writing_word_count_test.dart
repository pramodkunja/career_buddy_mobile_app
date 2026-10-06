import 'package:career_buddy_lms/features/generic_writing/domain/services/writing_word_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countWritingWords', () {
    test('empty string is 0', () => expect(countWritingWords(''), 0));
    test('whitespace-only string is 0', () => expect(countWritingWords('   \n\t  '), 0));
    test('one word', () => expect(countWritingWords('hello'), 1));
    test('multiple spaces between words collapse to one boundary', () => expect(countWritingWords('hello   world'), 2));
    test('newlines separate words', () => expect(countWritingWords('hello\nworld\n\nagain'), 3));
    test('punctuation does not affect the count', () => expect(countWritingWords('hello, world! how are you?'), 5));
    test('leading/trailing whitespace is trimmed before counting', () => expect(countWritingWords('  hello world  '), 2));
    test('a hyphenated word counts as one word', () => expect(countWritingWords('well-known fact'), 2));
  });
}
