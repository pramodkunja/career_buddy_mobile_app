import '../../../dashboard/domain/entities/recommended_job.dart';

/// One row of `resume_analytics`'s embedded `analytics-data` JSON blob
/// (`career_app/views.py:1841`, `json.dumps(results)` — see
/// `templates/resume_analytics.html:529`): `topic`, `difficulty`, `question`
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

/// `resume_analytics`'s summary numbers (`career_app/views.py:1775-1875`) —
/// `total_integer_score` (0-100, ceil-scaled from the raw 5-marks-per-
/// question total), `is_passed` (`total_integer_score >= PASSING_SCORE`,
/// verified = 90 in the updated backend — this was accurately 70 against
/// the original backend; Flutter itself never hardcodes this number either
/// way, instead scraping the literal substring `"Qualified Candidate
/// (Score"` — see `mock_interview_html_parser.dart`), `avg_score`
/// (raw 0-5 average, unscaled), `answered_count`/`total_questions`,
/// `years_exp` (from the résumé, unrelated to the interview itself but
/// rendered on the same page). `suitable_jobs` (`career_app/views.py`'s
/// `_get_matched_jobs`, only populated when `is_passed`) reuses the
/// dashboard's own [RecommendedJob] entity rather than a duplicate model —
/// confirmed the same `JobPosting` query and the same per-job template
/// fields back both `resume_analytics.html:350-409` and
/// `dashboard.html:96-151`.
class InterviewAnalyticsResult {
  const InterviewAnalyticsResult({
    required this.totalScore,
    required this.isPassed,
    required this.avgScore,
    required this.answeredCount,
    required this.totalQuestions,
    required this.yearsExperience,
    required this.questionResults,
    this.suitableJobs = const [],
  });

  final int totalScore;
  final bool isPassed;
  final double avgScore;
  final int answeredCount;
  final int totalQuestions;
  final double yearsExperience;
  final List<InterviewQuestionResult> questionResults;

  /// Only ever non-empty when [isPassed] — mirrors the web's own
  /// `{% if is_passed and suitable_jobs %}` gate exactly (see
  /// `mock_interview_html_parser.dart`'s parser doc comment).
  final List<RecommendedJob> suitableJobs;
}
