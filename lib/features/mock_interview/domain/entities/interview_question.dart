/// One question served by `resume_get_next_question`
/// (`career_app/views.py:1180-1311`) — fields match that endpoint's JSON
/// response verbatim (`id`, `text`, `topic`, `difficulty`, `is_coding`,
/// `question_type`, `progress` — an `"N/20"` string, not split server-side —
/// `time_limit`, `time_remaining`).
class InterviewQuestion {
  const InterviewQuestion({
    required this.id,
    required this.text,
    required this.topic,
    required this.difficulty,
    required this.isCoding,
    required this.questionType,
    required this.progress,
    required this.timeLimitSeconds,
    required this.timeRemainingSeconds,
  });

  final int id;
  final String text;
  final String topic;
  final String difficulty;

  /// `question_type == 'coding'` — the server's own `is_coding` boolean
  /// (`career_app/views.py:1307`), not re-derived from [questionType] here.
  final bool isCoding;

  /// `'theory'` or `'coding'` (`ResumeQuestion.QUESTION_TYPES`).
  final String questionType;

  /// The server's own `"N/20"` string (`career_app/views.py:1298-1305` —
  /// `total_questions` is deliberately hard-floored at 20 there even while
  /// domain questions 11-20 are still being generated lazily, so this is
  /// never re-derived from a locally-tracked question count).
  final String progress;
  final int timeLimitSeconds;
  final int timeRemainingSeconds;

  int get currentNumber => int.tryParse(progress.split('/').first) ?? 1;
  int get totalCount => int.tryParse(progress.split('/').last) ?? 20;
}
