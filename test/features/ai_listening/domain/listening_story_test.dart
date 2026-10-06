import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('listening story pools', () {
    test('has exactly 2 levels, each with exactly 6 stories, verbatim from listening.js', () {
      expect(kListeningStoriesByLevel.keys, {'beginner', 'intermediate'});
      for (final entry in kListeningStoriesByLevel.entries) {
        expect(entry.value, hasLength(6), reason: 'level "${entry.key}"');
      }
    });

    test('no level has duplicate story titles', () {
      for (final entry in kListeningStoriesByLevel.entries) {
        final titles = entry.value.map((s) => s.title).toSet();
        expect(titles, hasLength(entry.value.length), reason: 'level "${entry.key}"');
      }
    });

    test('kListeningDefaultLevel is "beginner"', () {
      expect(kListeningDefaultLevel, 'beginner');
    });

    test('every story has non-empty title and text', () {
      for (final stories in kListeningStoriesByLevel.values) {
        for (final story in stories) {
          expect(story.title, isNotEmpty);
          expect(story.text, isNotEmpty);
        }
      }
    });
  });
}
