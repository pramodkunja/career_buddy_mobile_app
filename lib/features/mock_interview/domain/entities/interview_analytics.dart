/// One row of `resume_analytics`'s embedded `analytics-data` JSON blob
/// (`career_app/views.py:1529-1555`, `json.dumps(results)` — see
/// `templates/resume_analytics.html:524`): `topic`, `difficulty`, `question`
/// (the question text), `answer` (empty string if never answered),
/// `score` (0-5, 0 if unanswered), `feedback` (`"No answer provided."` if
/// unanswered).
class InterviewQuestionResult {
  const InterviewQuestionResult({
    required this.topic,
    required this.difficulty,
    required this.question,
    required this.answer,
    required this.score,
    required this.feedback,
  });

  final String topic;
  final String difficulty;
  final String question;
  final String answer;
  final int score;
  final String feedback;
}

/// `resume_analytics`'s summary numbers (`career_app/views.py:1505-1601`) —
/// `total_integer_score` (0-100, ceil-scaled from the raw 5-marks-per-
/// question total), `is_passed` (`total_integer_score >= 70`), `avg_score`
/// (raw 0-5 average, unscaled), `answered_count`/`total_questions`,
/// `years_exp` (from the résumé, unrelated to the interview itself but
/// rendered on the same page). `suitable_jobs` (job recommendations shown
/// only when passed) is deliberately not modeled here — see
/// `mock_interview_html_parser.dart`'s doc comment for why.
class InterviewAnalyticsResult {
  const InterviewAnalyticsResult({
    required this.totalScore,
    required this.isPassed,
    required this.avgScore,
    required this.answeredCount,
    required this.totalQuestions,
    required this.yearsExperience,
    required this.questionResults,
  });

  final int totalScore;
  final bool isPassed;
  final double avgScore;
  final int answeredCount;
  final int totalQuestions;
  final double yearsExperience;
  final List<InterviewQuestionResult> questionResults;
}
