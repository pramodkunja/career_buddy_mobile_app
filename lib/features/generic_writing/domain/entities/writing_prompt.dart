/// One Generic Writing prompt.
///
/// [position] is the prompt's 1-based index within the exercise's question
/// order — matches the web's own `data-q="{{ forloop.counter }}"` /
/// submission key (`answers['1']`, `answers['2']`, ...), not a database
/// `Question.id` (`templates/activities/exercise.html:307`,
/// `static/js/exercises.js:846`).
///
/// [guide] mirrors `{% if question.explanation %}` — shown as the "Guide"
/// box (`templates/activities/exercise.html:301-306`) — and is also the
/// text `getWritingLimits()` scans for an explicit word-count range
/// (`static/js/exercises.js:694-728`), so it is kept as one field rather
/// than split into "guide text" vs. "limit hint source".
class WritingPrompt {
  const WritingPrompt({required this.position, required this.questionText, this.guide});

  final int position;
  final String questionText;
  final String? guide;
}
