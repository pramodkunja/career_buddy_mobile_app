/// A single mock-test question, as returned by any of the "mock quiz"
/// family of endpoints (`/activities/oop-quiz/questions/`,
/// `/activities/quiz/<subject>/questions/`) — verified against
/// `activities/views.py:oop_quiz_questions`/`quiz_questions`: the correct
/// answer/explanation are deliberately withheld until after submission, so
/// this entity has no such field at all (not merely nulled out).
class MockTestQuestion {
  const MockTestQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.difficulty,
    required this.topic,
  });

  final int id;
  final String questionText;

  /// Always 4 options, positionally indexed 0-3 (`activities/data/oop_questions.json`).
  final List<String> options;
  final String difficulty;
  final String topic;
}
