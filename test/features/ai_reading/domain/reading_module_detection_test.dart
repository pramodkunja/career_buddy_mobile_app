import 'package:career_buddy_lms/features/ai_reading/domain/services/reading_module_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isReadingModuleActivity', () {
    test('matches when the title contains both "reading" and "professional", any case', () {
      expect(isReadingModuleActivity('Professional Reading'), isTrue);
      expect(isReadingModuleActivity('PROFESSIONAL READING'), isTrue);
      expect(isReadingModuleActivity('reading for professional growth'), isTrue);
    });

    test('does not match when only one keyword is present', () {
      expect(isReadingModuleActivity('Professional Speaking'), isFalse);
      expect(isReadingModuleActivity('Casual Reading Club'), isFalse);
    });

    test('does not match an unrelated activity title', () {
      expect(isReadingModuleActivity('Business Vocabulary'), isFalse);
    });

    test('does not match an empty title', () {
      expect(isReadingModuleActivity(''), isFalse);
    });

    test('does not collide with the other three module titles', () {
      expect(isReadingModuleActivity('Professional Speaking'), isFalse);
      expect(isReadingModuleActivity('Professional Passage Writing'), isFalse);
      expect(isReadingModuleActivity('Listen & Write'), isFalse);
    });
  });
}
