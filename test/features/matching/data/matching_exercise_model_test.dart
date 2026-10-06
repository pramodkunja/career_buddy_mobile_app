import 'package:career_buddy_lms/features/matching/data/models/matching_exercise_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractEmbeddedJsonList', () {
    test('extracts and decodes a JSON array from the questions-data script tag', () {
      const html = '''
<html><body>
<script type="application/json" id="questions-data">[{"id": 1, "left": "ASAP"}]</script>
</body></html>
''';
      final result = extractEmbeddedJsonList(html, 'questions-data');
      expect(result, isNotNull);
      expect(result, hasLength(1));
    });

    test('returns null when the tag is absent (e.g. a locked-activity redirect page)', () {
      final result = extractEmbeddedJsonList('<html><body>Activities</body></html>', 'questions-data');
      expect(result, isNull);
    });

    test('returns null when the tag content is not valid JSON', () {
      const html = '<script type="application/json" id="questions-data">not json</script>';
      expect(extractEmbeddedJsonList(html, 'questions-data'), isNull);
    });

    test('returns null when the decoded JSON is an object, not an array', () {
      const html = '<script type="application/json" id="questions-data">{"a": 1}</script>';
      expect(extractEmbeddedJsonList(html, 'questions-data'), isNull);
    });
  });

  group('MatchingExerciseParsing.fromQuestionsJson', () {
    test('assigns position by array index (1-based), not by the embedded database id', () {
      final exercise = MatchingExerciseParsing.fromQuestionsJson(
        exerciseId: 42,
        title: 'Abbreviations',
        order: 1,
        questionsJson: [
          {'id': 999, 'text': 'q1', 'left': 'ASAP', 'right': 'As soon as possible', 'correct': ''},
          {'id': 5, 'text': 'q2', 'left': 'FYI', 'right': 'For your information', 'correct': ''},
        ],
      );

      expect(exercise.id, 42);
      expect(exercise.title, 'Abbreviations');
      expect(exercise.pairs, hasLength(2));
      expect(exercise.pairs[0].position, 1);
      expect(exercise.pairs[0].leftText, 'ASAP');
      expect(exercise.pairs[0].rightText, 'As soon as possible');
      expect(exercise.pairs[1].position, 2);
      expect(exercise.pairs[1].leftText, 'FYI');
    });

    test('left falls back to text, and right falls back to correct, when blank — mirroring the Django template', () {
      final exercise = MatchingExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: [
          {'id': 1, 'text': 'What does ASAP mean?', 'left': '', 'right': '', 'correct': 'As soon as possible'},
        ],
      );

      expect(exercise.pairs.single.leftText, 'What does ASAP mean?');
      expect(exercise.pairs.single.rightText, 'As soon as possible');
    });

    test('skips non-map entries defensively rather than throwing', () {
      final exercise = MatchingExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: ['not a map', {'id': 1, 'left': 'A', 'right': 'B'}],
      );

      expect(exercise.pairs, hasLength(1));
      expect(exercise.pairs.single.position, 2);
    });

    test('an empty questions list produces an exercise with no pairs', () {
      final exercise = MatchingExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: const [],
      );
      expect(exercise.pairs, isEmpty);
    });
  });
}
