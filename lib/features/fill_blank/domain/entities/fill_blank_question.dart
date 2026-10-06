/// One Fill in the Blank question.
///
/// [position] is the question's 1-based index within the exercise's
/// question order — matches the web's own `data-q="{{ forloop.counter }}"`
/// / submission key (`answers['1']`, `answers['2']`, ...), not a database
/// `Question.id`. Only the fields the real web branch actually uses are
/// present: `option_a`-`option_d`/`left_item`/`right_item` are irrelevant
/// to this exercise type and are not modeled here.
class FillBlankQuestion {
  const FillBlankQuestion({
    required this.position,
    required this.questionText,
    required this.correctAnswer,
    this.explanation,
  });

  final int position;
  final String questionText;
  final String correctAnswer;

  /// Shown as a hint once the question is checked (correct or wrong),
  /// only if non-empty — mirrors `{% if question.explanation %}`
  /// (`templates/activities/exercise.html:199`).
  final String? explanation;
}
