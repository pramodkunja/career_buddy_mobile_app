import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('speaking topic pool', () {
    test('has exactly 20 entries, verbatim from speaking.js', () {
      expect(kSpeakingTopics, hasLength(20));
    });

    test('has no duplicate entries', () {
      expect(kSpeakingTopics.toSet(), hasLength(kSpeakingTopics.length));
    });

    test('the hardcoded initial topic is not a member of the cycling pool', () {
      expect(kSpeakingTopics.contains(kSpeakingInitialTopic), isFalse);
    });
  });
}
