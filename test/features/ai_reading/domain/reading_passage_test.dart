import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_passage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading passage pools', () {
    test('has exactly 3 levels, each with exactly 5 passages, verbatim from reading.js', () {
      expect(kReadingPassagesByLevel.keys, {1, 2, 3});
      for (final entry in kReadingPassagesByLevel.entries) {
        expect(entry.value, hasLength(5), reason: 'level ${entry.key}');
      }
    });

    test('no level has duplicate passage titles', () {
      for (final entry in kReadingPassagesByLevel.entries) {
        final titles = entry.value.map((p) => p.title).toSet();
        expect(titles, hasLength(entry.value.length), reason: 'level ${entry.key}');
      }
    });

    test('kReadingDefaultLevel is 1', () {
      expect(kReadingDefaultLevel, 1);
    });

    test('every passage has non-empty title and text', () {
      for (final passages in kReadingPassagesByLevel.values) {
        for (final passage in passages) {
          expect(passage.title, isNotEmpty);
          expect(passage.text, isNotEmpty);
        }
      }
    });
  });
}
