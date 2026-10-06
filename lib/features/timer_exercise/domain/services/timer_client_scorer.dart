import 'timer_word_count.dart';

/// One task's captured answer, as needed by [computeTimerClientScore].
class TimerTaskAnswer {
  const TimerTaskAnswer({required this.position, required this.transcript, required this.questionText});

  /// 1-based, matching [TimerTask.position].
  final int position;

  /// The captured transcript for this task — may be empty if the task was
  /// never attempted.
  final String transcript;
  final String questionText;
}

class TimerClientScore {
  const TimerClientScore({required this.score, required this.maxScore});
  final int score;
  final int maxScore;
}

final _keywordPattern = RegExp(r'\b\w{4,}\b');

/// Ports `submit-timer`'s click handler scoring heuristic verbatim
/// (`static/js/exercises.js:1401-1434`) — the score/max_score this app must
/// submit as `{score, max_score}` so the backend behaves identically to the
/// web's own submission: when `SARVAM_API_KEY` is unset, `submit_exercise`
/// trusts this score outright (the AI `"speaking"`-mode branch at
/// `activities/views.py:1422` never runs); when it *is* set, the server
/// discards this score entirely and recomputes it via Sarvam AI instead —
/// see [TimerSubmissionResult]'s doc comment. This is not a new scoring
/// algorithm — it is a direct port of the deterministic heuristic that
/// already ships on the web, per the task's own instruction not to invent
/// one.
///
/// For each task with a **non-empty** transcript (a task never started
/// contributes nothing, exactly like the web's `Object.keys(taskTranscripts
/// ).forEach` only iterating tasks that were actually recorded):
/// - `wordScore = min(1, words / 70)` — the web's `words / (DURATION/60 *
///   70)` with `DURATION` always 60 here, i.e. a 70-words-per-60-seconds
///   target rate.
/// - `keywords` = every 4+ letter/digit word in `"task {position}:
///   {questionText}"` lowercased (matching the web's own
///   `promptEl.querySelector('h5')?.textContent?.toLowerCase()`, where that
///   `<h5>` literally renders `"Task {{ forloop.counter }}:
///   {{ question.question_text }}"` — the leading "Task N:" prefix is
///   included in the real keyword set too, not stripped out).
/// - `relScore = keywords.isEmpty ? 1 : (keywords found in the transcript,
///   duplicates counted) / keywords.length`.
/// - the task's contribution is `wordScore * 0.5 + relScore * 0.5`.
///
/// `score` is the rounded sum of every evaluated task's contribution
/// (`Math.round((totalScore / totalTasks) * totalTasks)`, which is
/// algebraically just `Math.round(totalScore)` — confirmed by reading the
/// web's own source rather than assumed); `max_score` is always the total
/// number of tasks, **not** 100 (unlike Generic Writing) — confirmed the
/// same way (`submitScore(finalScore, totalTasks, ...)`,
/// `static/js/exercises.js:1440`).
TimerClientScore computeTimerClientScore({required int totalTasks, required List<TimerTaskAnswer> answers}) {
  var totalScore = 0.0;
  for (final answer in answers) {
    final text = answer.transcript.trim();
    if (text.isEmpty) continue;

    final words = countTimerWords(text);
    final wordScore = (words / 70).clamp(0, 1);

    final promptText = 'task ${answer.position}: ${answer.questionText}'.toLowerCase();
    final keywords = _keywordPattern.allMatches(promptText).map((m) => m.group(0)!).toList();
    final textLower = text.toLowerCase();
    final matches = keywords.where(textLower.contains).length;
    final relScore = keywords.isEmpty ? 1.0 : matches / keywords.length;

    totalScore += wordScore * 0.5 + relScore * 0.5;
  }

  return TimerClientScore(score: totalScore.round(), maxScore: totalTasks);
}
