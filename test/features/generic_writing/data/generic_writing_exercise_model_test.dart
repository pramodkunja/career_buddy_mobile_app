import 'package:career_buddy_lms/features/generic_writing/data/models/generic_writing_exercise_model.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_exercise.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/writing_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageHtml = '''
<html><body>
<script type="application/json" id="questions-data">[
  {"id": 1, "text": "Describe the outcome.", "type": "writing", "options": {"a": "", "b": "", "c": "", "d": ""}, "correct": "", "explanation": "Aim for 80-120 words.", "left": "", "right": ""},
  {"id": 2, "text": "What phrases did you use?", "type": "writing", "options": {"a": "", "b": "", "c": "", "d": ""}, "correct": "", "explanation": "", "left": "", "right": ""}
]</script>
<script type="application/json" id="bingo-data">[]</script>
</body></html>
''';

void main() {
  group('extractEmbeddedJsonList', () {
    test('extracts and decodes the questions-data script tag', () {
      final decoded = extractEmbeddedJsonList(_pageHtml, 'questions-data');
      expect(decoded, hasLength(2));
    });

    test('returns null when the element id is not present (e.g. a locked-redirect page)', () {
      expect(extractEmbeddedJsonList('<html><body>Locked</body></html>', 'questions-data'), isNull);
    });
  });

  group('GenericWritingExerciseParsing.fromQuestionsJson', () {
    test('parses prompts in order, with 1-based position and guide from explanation', () {
      final questionsJson = extractEmbeddedJsonList(_pageHtml, 'questions-data')!;
      final exercise = GenericWritingExerciseParsing.fromQuestionsJson(
        exerciseId: 42,
        title: 'Negotiation Outcome Reflection',
        order: 3,
        questionsJson: questionsJson,
      );

      expect(exercise.id, 42);
      expect(exercise.title, 'Negotiation Outcome Reflection');
      expect(exercise.order, 3);
      expect(exercise.prompts, hasLength(2));
      expect(exercise.prompts[0].position, 1);
      expect(exercise.prompts[0].questionText, 'Describe the outcome.');
      expect(exercise.prompts[0].guide, 'Aim for 80-120 words.');
      expect(exercise.prompts[1].position, 2);
      expect(exercise.prompts[1].guide, isNull); // empty explanation -> null, not ""
    });

    test('a question with missing/empty text is skipped', () {
      final exercise = GenericWritingExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: [
          {'text': '', 'explanation': 'x'},
          {'text': 'Real prompt.', 'explanation': null},
        ],
      );

      expect(exercise.prompts, hasLength(1));
      expect(exercise.prompts.single.questionText, 'Real prompt.');
      expect(exercise.prompts.single.position, 2); // position is the original index + 1, not re-numbered
    });

    test('a malformed (non-map) entry is skipped rather than throwing', () {
      final exercise = GenericWritingExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: ['not a map', 42, null],
      );
      expect(exercise.prompts, isEmpty);
    });
  });

  group('GenericWritingExercise.limitsFor', () {
    test('derives limits from this exercise\'s own title and the prompt\'s guide text', () {
      const exercise = GenericWritingExercise(id: 1, title: 'Proposal Section Writing', order: 1, prompts: []);
      const prompt = WritingPrompt(position: 1, questionText: 'Write the section.');

      final limits = exercise.limitsFor(prompt);

      expect(limits.min, 150);
      expect(limits.max, 200);
    });
  });
}
