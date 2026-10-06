import 'interview_question.dart';

/// `resume_get_next_question`'s two possible shapes: a fresh [InterviewQuestion]
/// (`{"status": "active", ...}`) or `{"status": "completed"}` once
/// `curr_idx >= len(questions)` (`career_app/views.py:1250-1257`) — the
/// server has already scored and finalized the session by the time it
/// returns the latter, so nothing further needs to be sent before fetching
/// `resume_analytics`.
sealed class NextQuestionOutcome {
  const NextQuestionOutcome();
}

final class NextQuestionReady extends NextQuestionOutcome {
  const NextQuestionReady(this.question);
  final InterviewQuestion question;
}

final class InterviewCompleted extends NextQuestionOutcome {
  const InterviewCompleted();
}
