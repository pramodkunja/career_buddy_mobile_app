import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_module_detection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isListeningModuleActivity', () {
    test('matches when the title contains "listen", any case — no "professional" keyword required', () {
      expect(isListeningModuleActivity('Listen & Write'), isTrue);
      expect(isListeningModuleActivity('LISTEN & LEARN'), isTrue);
      expect(isListeningModuleActivity('Professional Listening'), isTrue);
    });

    test('does not require "professional", unlike Speaking/Writing', () {
      // The real seed title is 'Listen & Write' — no "professional" at all.
      expect(isListeningModuleActivity('Listen & Write'), isTrue);
    });

    test('does not match an unrelated activity title', () {
      expect(isListeningModuleActivity('Business Vocabulary'), isFalse);
    });

    test('does not match an empty title', () {
      expect(isListeningModuleActivity(''), isFalse);
    });

    test('does not collide with Speaking/Writing titles', () {
      expect(isListeningModuleActivity('Professional Speaking'), isFalse);
      expect(isListeningModuleActivity('Professional Passage Writing'), isFalse);
    });
  });
}
