import 'package:career_buddy_lms/features/fill_blank/data/models/fill_blank_exercise_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractEmbeddedJsonList', () {
    test('extracts and decodes a JSON array from the questions-data script tag', () {
      const html = '''
<html><body>
<script type="application/json" id="questions-data">[{"id": 1, "text": "q", "correct": "a"}]</script>
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
  });

  group('FillBlankExerciseParsing.fromQuestionsJson', () {
    test('assigns position by array index (1-based), preserving stored order, unsliced', () {
      final exercise = FillBlankExerciseParsing.fromQuestionsJson(
        exerciseId: 42,
        title: 'Vocabulary Fill in the Blank',
        order: 1,
        questionsJson: [
          {'id': 5, 'text': 'Please find the report ___ to this email.', 'correct': 'attached', 'explanation': 'exp1'},
          {'id': 2, 'text': 'Could you please touch ___?', 'correct': 'base', 'explanation': ''},
        ],
      );

      expect(exercise.id, 42);
      expect(exercise.title, 'Vocabulary Fill in the Blank');
      expect(exercise.questions, hasLength(2));
      expect(exercise.questions[0].position, 1);
      expect(exercise.questions[0].questionText, 'Please find the report ___ to this email.');
      expect(exercise.questions[0].correctAnswer, 'attached');
      expect(exercise.questions[0].explanation, 'exp1');
      expect(exercise.questions[1].position, 2);
      expect(exercise.questions[1].correctAnswer, 'base');
    });

    test('an empty-string explanation is treated as absent (null), not an empty hint', () {
      final exercise = FillBlankExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: [
          {'id': 1, 'text': 'q', 'correct': 'a', 'explanation': ''},
        ],
      );
      expect(exercise.questions.single.explanation, isNull);
    });

    test('a missing explanation field defaults to null', () {
      final exercise = FillBlankExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: [
          {'id': 1, 'text': 'q', 'correct': 'a'},
        ],
      );
      expect(exercise.questions.single.explanation, isNull);
    });

    test('skips entries with a missing/blank question text or correct answer', () {
      final exercise = FillBlankExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: [
          {'id': 1, 'text': '', 'correct': 'a'}, // blank text
          {'id': 2, 'correct': 'a'}, // missing text
          {'id': 3, 'text': 'q', 'correct': ''}, // blank correct
          {'id': 4, 'text': 'q'}, // missing correct
          {'id': 5, 'text': 'q', 'correct': 'a'}, // valid
        ],
      );

      expect(exercise.questions, hasLength(1));
      expect(exercise.questions.single.questionText, 'q');
    });

    test('skips non-map entries defensively rather than throwing', () {
      final exercise = FillBlankExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: ['not a map', {'id': 1, 'text': 'q', 'correct': 'a'}],
      );

      expect(exercise.questions, hasLength(1));
      expect(exercise.questions.single.position, 2);
    });

    test('an empty questions list produces an exercise with no questions', () {
      final exercise = FillBlankExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: const [],
      );
      expect(exercise.questions, isEmpty);
    });
  });
}
