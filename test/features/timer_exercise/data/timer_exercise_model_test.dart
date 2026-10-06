import 'package:career_buddy_lms/features/timer_exercise/data/models/timer_exercise_model.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

// A realistic fixture matching the real template's `timer` branch
// structure (`templates/activities/exercise.html:322-383`): the tasks come
// from the same `#questions-data` embedded JSON script tag every other
// HTML-extraction exercise type reads (`questions_json`,
// `activities/views.py:1389-1403`).
const _pageHtml = '''
<html><body>
<div class="exercise-hero bg-purple">
<ol class="breadcrumb">
<li class="breadcrumb-item"><a href="#">Business Negotiation Simulation</a></li>
<li class="breadcrumb-item"><a href="#">Live Negotiation and Debrief</a></li>
</ol>
</div>
<div id="timer-exercise" class="exercise-container text-center">
<script type="application/json" id="questions-data">[
  {"id": 1, "text": "Describe your morning routine in detail.", "type": "timer", "options": {"a": "", "b": "", "c": "", "d": ""}, "correct": "", "explanation": "Speak clearly and try to fill the full 60 seconds.", "left": "", "right": ""},
  {"id": 2, "text": "What are the benefits of remote work?", "type": "timer", "options": {"a": "", "b": "", "c": "", "d": ""}, "correct": "", "explanation": "", "left": "", "right": ""}
]</script>
</div>
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

  group('TimerExerciseParsing.fromQuestionsJson', () {
    test('parses tasks in order, with 1-based position and guide from explanation', () {
      final questionsJson = extractEmbeddedJsonList(_pageHtml, 'questions-data')!;
      final exercise = TimerExerciseParsing.fromQuestionsJson(
        exerciseId: 42,
        title: 'Elevator Pitch Practice',
        order: 3,
        questionsJson: questionsJson,
      );

      expect(exercise.id, 42);
      expect(exercise.title, 'Elevator Pitch Practice');
      expect(exercise.order, 3);
      expect(exercise.tasks, hasLength(2));
      expect(exercise.tasks[0].position, 1);
      expect(exercise.tasks[0].questionText, 'Describe your morning routine in detail.');
      expect(exercise.tasks[0].guide, 'Speak clearly and try to fill the full 60 seconds.');
      expect(exercise.tasks[1].position, 2);
      expect(exercise.tasks[1].guide, isNull); // empty explanation -> null, not ""
    });

    test('a task with missing/empty text is skipped', () {
      final exercise = TimerExerciseParsing.fromQuestionsJson(
        exerciseId: 1,
        title: 'T',
        order: 1,
        questionsJson: [
          {'text': '', 'explanation': 'x'},
          {'text': 'Real task.', 'explanation': null},
        ],
      );

      expect(exercise.tasks, hasLength(1));
      expect(exercise.tasks.single.questionText, 'Real task.');
      expect(exercise.tasks.single.position, 2); // position is the original index + 1, not re-numbered
    });

    test('a malformed (non-map) entry is skipped rather than throwing', () {
      final exercise = TimerExerciseParsing.fromQuestionsJson(exerciseId: 1, title: 'T', order: 1, questionsJson: ['not a map', 42, null]);
      expect(exercise.tasks, isEmpty);
    });
  });

  group('TimerExercise (constructed directly)', () {
    test('carries heroMeta through unchanged', () {
      const exercise = TimerExercise(id: 1, title: 'T', order: 1, tasks: []);
      expect(exercise.heroMeta, isNull);
    });
  });
}
