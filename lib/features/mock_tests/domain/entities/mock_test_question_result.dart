/// One question's grading outcome, from `oop_quiz_submit`/`quiz_submit`'s
/// response (`activities/views.py`). `correctAnswerIndex`/`explanation` are
/// only ever present when the question was actually attempted — the server
/// deliberately withholds them for a question left unanswered ("Only reveal
/// the correct answer/explanation for questions the user actually
/// attempted... stops blank-submit harvesting", `activities/views.py:2178-2180`),
/// so this entity mirrors that by leaving them `null` rather than guessing.
class MockTestQuestionResult {
  const MockTestQuestionResult({required this.isCorrect, this.correctAnswerIndex, this.explanation});

  final bool isCorrect;
  final int? correctAnswerIndex;
  final String? explanation;

  bool get wasAttempted => correctAnswerIndex != null;
}
