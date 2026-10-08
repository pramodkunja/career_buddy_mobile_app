// `career_app.views` renders three kinds of non-JSON responses this feature
// has to read directly: `resume_start_interview`'s redirect chain (lands on
// either `resume_interview.html` on success, or a flashed-message page on
// failure — see `ApiEndpoints.resumeStartInterview`'s doc comment) and
// `resume_analytics.html` (summary numbers in plain markup, the per-question
// breakdown as embedded JSON). Same legitimate reuse-of-an-already-fetched-
// page technique already established by `resume_html_parser.dart` — every
// regex below is anchored to markup read directly from the templates, not
// guessed.

import 'dart:convert';

import '../../../../core/utils/html_unescape.dart';
import '../../domain/entities/interview_analytics.dart';

/// True when a GET to `resume_start_interview` (default `followRedirects:
/// true`) actually landed on `resume_interview.html` — that page's own
/// mandatory camera-gate screen (`templates/resume_interview.html:415`) is
/// unique to it (`pro_page`/`resume_builder`/`resume_job_match`, the
/// redirect targets on every failure branch, never render this id).
bool isMockInterviewSessionHtml(String html) => html.contains('id="camera-gate-screen"');

/// A blocked `resume_start_interview` attempt (no Premium plan, or no parsed
/// resume) sets a Django flash message (`messages.info(...)`) before
/// redirecting — rendered by `base.html`'s shared `.messages-container`
/// (`<div class="alert alert-{{ message.tags }}" ... role="alert">`, see
/// `templates/base.html:224-233`). Unlike `resume_html_parser.dart`'s
/// `parseFlashedErrorMessage` (which only ever needs to match `error`/
/// `danger` tags), `resume_start_interview`'s own blocking messages are
/// `messages.info(...)` (tag `info`) — so this matches any tag.
String? parseMockInterviewFlashedMessage(String html) {
  final match = RegExp(
    r'class="alert alert-[a-z]+[^"]*"[^>]*role="alert">\s*(?:<i[^>]*></i>\s*)?([^<]*)',
  ).firstMatch(html);
  return match == null ? null : _unescape(match.group(1)!.trim());
}

/// True when a GET to `resume_analytics` actually rendered a completed
/// session's results (`templates/resume_analytics.html:524`'s
/// `analytics-data` script tag only ever renders on the `{% if not error %}`
/// branch — the `{% if error %}` branch, reached when there's no session
/// at all, never emits it).
bool isInterviewAnalyticsHtml(String html) => html.contains('id="analytics-data"');

/// Parses a `resume_analytics.html` response. Callers must check
/// [isInterviewAnalyticsHtml] first — this does not itself validate the
/// error branch.
///
/// `suitable_jobs` (job recommendations, only rendered when passed) is
/// deliberately not parsed here: unlike every other field on this page, its
/// markup carries no stable per-job id to act on (`{% url
/// 'employer_portal:job_detail' job.pk %}` is the only identifier, and this
/// app has no Job Detail screen to route it to yet — see
/// `RoutePaths.jobDetail`'s own doc comment), so there'd be nothing a mobile
/// results screen could actually do with a parsed job beyond re-displaying
/// text already summarized by [InterviewAnalyticsResult.isPassed].
InterviewAnalyticsResult parseInterviewAnalyticsHtml(String html) {
  final totalScoreMatch = RegExp(
    r'<div class="stat-value"[^>]*>\s*(\d+)\s*</div>\s*<div class="stat-label">Total Score / 100</div>',
  ).firstMatch(html);
  final totalScore = int.tryParse(totalScoreMatch?.group(1) ?? '') ?? 0;

  // `resume_analytics.html:207-208` — only rendered on the `{% if is_passed
  // %}` branch.
  final isPassed = html.contains('Qualified Candidate (Score');

  final avgMatch = RegExp(r'Overall Score</span>\s*<span[^>]*>([\d.]+)/5</span>').firstMatch(html);
  final avgScore = double.tryParse(avgMatch?.group(1) ?? '') ?? 0.0;

  final answeredMatch = RegExp(
    r'<div class="stat-value text-success">(\d+)</div>\s*<div class="stat-label">Answered</div>',
  ).firstMatch(html);
  final answeredCount = int.tryParse(answeredMatch?.group(1) ?? '') ?? 0;

  final totalQuestionsMatch = RegExp(
    r'<div class="stat-value">\s*(\d+)\s*</div>\s*<div class="stat-label">Total Questions</div>',
  ).firstMatch(html);
  final totalQuestions = int.tryParse(totalQuestionsMatch?.group(1) ?? '') ?? 0;

  final yearsMatch = RegExp(
    r'<div class="stat-value"[^>]*>\s*([\d.]+) yrs\s*</div>\s*<div class="stat-label">Experience Level</div>',
  ).firstMatch(html);
  final yearsExperience = double.tryParse(yearsMatch?.group(1) ?? '') ?? 0.0;

  final jsonMatch = RegExp(
    r'<script id="analytics-data" type="application/json">([\s\S]*?)</script>',
  ).firstMatch(html);
  final rawJson = jsonMatch?.group(1)?.trim() ?? '[]';
  final decoded = rawJson.isEmpty ? <dynamic>[] : jsonDecode(rawJson) as List<dynamic>;
  final questionResults = [
    for (final entry in decoded)
      InterviewQuestionResult(
        topic: (entry['topic'] as String?) ?? 'General',
        difficulty: (entry['difficulty'] as String?) ?? 'Easy',
        question: (entry['question'] as String?) ?? '',
        answer: (entry['answer'] as String?) ?? '',
        score: (entry['score'] as num?)?.toInt() ?? 0,
        feedback: (entry['feedback'] as String?) ?? '',
      ),
  ];

  return InterviewAnalyticsResult(
    totalScore: totalScore,
    isPassed: isPassed,
    avgScore: avgScore,
    answeredCount: answeredCount,
    totalQuestions: totalQuestions,
    yearsExperience: yearsExperience,
    questionResults: questionResults,
  );
}

String _unescape(String value) => unescapeHtmlEntities(value);
