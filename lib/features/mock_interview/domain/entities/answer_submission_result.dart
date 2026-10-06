/// `resume_submit_answer`'s response (`career_app/views.py:1313-1369`):
/// `{"score": <0-5 int>, "feedback": "<str>", "timed_out": <bool>}` — score
/// is server-graded via `evaluate_answer`, capped to 0-5 (each question is
/// worth 5 marks), `feedback` is the AI evaluator's own text, and
/// `timed_out` is true when the answer arrived after the 30s
/// `ANSWER_TIME_LIMIT_SECONDS` window (still scored/saved either way — a
/// late answer is zeroed only past the extra `ANSWER_TIME_GRACE_SECONDS`
/// grace window, at which point `answer_text` itself is discarded
/// server-side before scoring).
class AnswerSubmissionResult {
  const AnswerSubmissionResult({required this.score, required this.feedback, required this.timedOut});

  final int score;
  final String feedback;
  final bool timedOut;
}
