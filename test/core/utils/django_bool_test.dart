import 'package:career_buddy_lms/core/utils/django_bool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('djangoBool', () {
    test('true maps to the capitalized "True" (Python\'s str(bool) convention)', () {
      expect(djangoBool(true), 'True');
    });

    test('false maps to the capitalized "False"', () {
      expect(djangoBool(false), 'False');
    });
  });
}
