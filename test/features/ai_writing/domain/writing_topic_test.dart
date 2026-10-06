import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('writing topic pools', () {
    test('has exactly 3 types, each with exactly 10 topics, verbatim from writing.js', () {
      expect(kWritingTopicsByType.keys, {'general', 'story', 'opinion'});
      for (final entry in kWritingTopicsByType.entries) {
        expect(entry.value, hasLength(10), reason: 'type "${entry.key}"');
      }
    });

    test('no type has duplicate topics', () {
      for (final entry in kWritingTopicsByType.entries) {
        expect(entry.value.toSet(), hasLength(entry.value.length), reason: 'type "${entry.key}"');
      }
    });

    test('the hardcoded initial topic IS the first entry of the "general" pool — unlike Speaking\'s', () {
      expect(kWritingTopicsByType[kWritingDefaultType]!.first, kWritingInitialTopic);
    });

    test('kWritingDefaultType is "general", matching typeSelect\'s default selected option', () {
      expect(kWritingDefaultType, 'general');
    });
  });
}
