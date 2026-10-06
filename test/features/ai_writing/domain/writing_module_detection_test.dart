import 'package:career_buddy_lms/features/ai_writing/domain/services/writing_module_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isWritingModuleActivity', () {
    test('matches when the title contains both "writing" and "professional", any case', () {
      expect(isWritingModuleActivity('Professional Passage Writing'), isTrue);
      expect(isWritingModuleActivity('PROFESSIONAL PASSAGE WRITING'), isTrue);
      expect(isWritingModuleActivity('writing for professional growth'), isTrue);
    });

    test('does not match when only one keyword is present', () {
      expect(isWritingModuleActivity('Professional Speaking'), isFalse);
      expect(isWritingModuleActivity('Creative Writing Basics'), isFalse);
    });

    test('does not match an unrelated activity title', () {
      expect(isWritingModuleActivity('Business Vocabulary'), isFalse);
    });

    test('does not match an empty title', () {
      expect(isWritingModuleActivity(''), isFalse);
    });

    test('does not collide with the Speaking module\'s title', () {
      expect(isWritingModuleActivity('Professional Speaking'), isFalse);
    });
  });
}
