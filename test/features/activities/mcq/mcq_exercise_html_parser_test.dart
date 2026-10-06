import 'package:career_buddy_lms/features/activities/data/models/mcq_exercise_html_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractMcqQuestionsJson', () {
    test('extracts and decodes a JSON array from the questions-data script tag', () {
      const html = '''
<html><body>
<script type="application/json" id="questions-data">[{"id": 1, "correct": "a"}]</script>
</body></html>
''';
      final result = extractMcqQuestionsJson(html);
      expect(result, isNotNull);
      expect(result, hasLength(1));
    });

    test('returns null when the tag is absent (e.g. a locked-activity redirect page)', () {
      expect(extractMcqQuestionsJson('<html><body>Activities</body></html>'), isNull);
    });
  });

  group('McqExerciseParsing.fromQuestionsJson', () {
    test('parses options/correctAnswer/explanation, keyed by the real database question id', () {
      final exercise = McqExerciseParsing.fromQuestionsJson(
        exerciseId: 56,
        title: 'Vocabulary Quiz',
        questionsJson: [
          {
            'id': 123,
            'text': "What is the synonym of 'concise'?",
            'options': {'a': 'Brief', 'b': 'Long', 'c': 'Vague', 'd': 'Complex'},
            'correct': 'a',
            'explanation': "'Brief' means concise.",
          },
        ],
      );

      expect(exercise.id, 56);
      expect(exercise.title, 'Vocabulary Quiz');
      final question = exercise.questions.single;
      expect(question.id, 123);
      expect(question.questionText, "What is the synonym of 'concise'?");
      expect(question.options, {'a': 'Brief', 'b': 'Long', 'c': 'Vague', 'd': 'Complex'});
      expect(question.correctAnswer, 'a');
      expect(question.explanation, "'Brief' means concise.");
    });

    test('drops option letters the backend left blank, rather than showing an empty tappable option', () {
      final exercise = McqExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        questionsJson: [
          {
            'id': 1,
            'text': 'q',
            'options': {'a': 'Yes', 'b': '', 'c': 'No', 'd': ''},
            'correct': 'a',
          },
        ],
      );

      expect(exercise.questions.single.options, {'a': 'Yes', 'c': 'No'});
    });

    test('a blank/absent explanation parses as null, not an empty string', () {
      final exercise = McqExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        questionsJson: [
          {
            'id': 1,
            'text': 'q',
            'options': {'a': 'Yes'},
            'correct': 'a',
            'explanation': '',
          },
        ],
      );

      expect(exercise.questions.single.explanation, isNull);
    });

    test('skips a question missing a correct answer, options, or a parseable id', () {
      final exercise = McqExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        questionsJson: [
          {'id': 1, 'text': 'no correct', 'options': {'a': 'Yes'}, 'correct': ''},
          {'id': 2, 'text': 'no options', 'options': <String, dynamic>{}, 'correct': 'a'},
          {'text': 'no id', 'options': {'a': 'Yes'}, 'correct': 'a'},
          'not a map',
        ],
      );

      expect(exercise.questions, isEmpty);
    });

    test('an empty questions list produces an exercise with no questions', () {
      final exercise = McqExerciseParsing.fromQuestionsJson(exerciseId: 1, title: 'T', questionsJson: const []);
      expect(exercise.questions, isEmpty);
    });
  });
}
