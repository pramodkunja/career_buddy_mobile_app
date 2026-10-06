import 'package:career_buddy_lms/features/ai_speaking/domain/services/speaking_module_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSpeakingModuleActivity', () {
    test('matches when the title contains both "speaking" and "professional", any case', () {
      expect(isSpeakingModuleActivity('Professional Speaking Skills'), isTrue);
      expect(isSpeakingModuleActivity('PROFESSIONAL SPEAKING SKILLS'), isTrue);
      expect(isSpeakingModuleActivity('speaking for professional growth'), isTrue);
    });

    test('does not match when only one keyword is present', () {
      expect(isSpeakingModuleActivity('Professional Writing Skills'), isFalse);
      expect(isSpeakingModuleActivity('Public Speaking Basics'), isFalse);
    });

    test('does not match an unrelated activity title', () {
      expect(isSpeakingModuleActivity('Business Vocabulary'), isFalse);
    });

    test('does not match an empty title', () {
      expect(isSpeakingModuleActivity(''), isFalse);
    });
  });
}
