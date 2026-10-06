/// One Timer exercise task/prompt — the spoken-answer equivalent of
/// Generic Writing's `WritingPrompt`. [position] is the task's 1-based
/// index within the exercise's question order — matches the web's own
/// `answers[idx+1] = text` submission key
/// (`static/js/exercises.js:1408-1409`), not a database `Question.id`.
///
/// [guide] mirrors `{% if question.explanation %}` shown under the task
/// heading (`templates/activities/exercise.html:352-354`) — plain
/// supporting text, not scanned for a word-count range like Generic
/// Writing's own `guide` (Timer has no word-count *requirement*, only the
/// 60-second `DURATION` — `static/js/exercises.js:1114`).
class TimerTask {
  const TimerTask({required this.position, required this.questionText, this.guide});

  final int position;
  final String questionText;
  final String? guide;
}
