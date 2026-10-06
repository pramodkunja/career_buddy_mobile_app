import 'package:career_buddy_lms/features/ai_writing/domain/services/writing_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countNonSpaceChars', () {
    test('counts characters excluding whitespace runs of any length', () {
      expect(countNonSpaceChars('abc'), 3);
      expect(countNonSpaceChars('a b c'), 3);
      expect(countNonSpaceChars('a   b\n\tc'), 3);
      expect(countNonSpaceChars(''), 0);
      expect(countNonSpaceChars('   '), 0);
    });
  });

  group('isWritingLengthValid', () {
    test('is false below the 500-character minimum', () {
      expect(isWritingLengthValid('a' * 499), isFalse);
    });

    test('is true at exactly the 500-character minimum', () {
      expect(isWritingLengthValid('a' * 500), isTrue);
    });

    test('is true at exactly the 900-character maximum', () {
      expect(isWritingLengthValid('a' * 900), isTrue);
    });

    test('is false above the 900-character maximum', () {
      expect(isWritingLengthValid('a' * 901), isFalse);
    });

    test('is false for empty text', () {
      expect(isWritingLengthValid(''), isFalse);
    });

    test('whitespace does not count toward the minimum', () {
      expect(isWritingLengthValid('${'a' * 400} ${' ' * 200}'), isFalse);
    });
  });
}
