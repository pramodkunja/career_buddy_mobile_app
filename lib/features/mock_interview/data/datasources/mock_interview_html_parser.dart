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
import '../../../dashboard/domain/entities/recommended_job.dart';
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
/// `suitable_jobs` (job recommendations, only rendered when `is_passed and
/// suitable_jobs` — `resume_analytics.html:350`) is parsed by
/// [_parseSuitableJobs] below, reusing the dashboard's own [RecommendedJob]
/// entity: `career_app/views.py`'s `_get_matched_jobs` is the exact same
/// `JobPosting` query `activities/views.py`'s dashboard recommendations use,
/// and the per-job id comes from the same stable
/// `{% url 'employer_portal:job_detail' job.pk %}` link
/// `RoutePaths.publicJobDetail`/`PublicJobDetailScreen` already serve (wired
/// in Phase 4 — see `recommended_jobs_section.dart`'s `_JobCard`).
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
    suitableJobs: _parseSuitableJobs(html),
  );
}

/// Splits a section of [html] into one slice per occurrence of [marker] —
/// same "card-start-marker splitting" technique as
/// `dashboard_html_parser.dart`'s `_splitByMarker`, duplicated locally
/// rather than shared across features (this codebase's established
/// per-feature convention; see e.g. the GD/JAM language-picker widgets).
List<String> _splitByMarker(String html, String marker, {int maxLength = 3000}) {
  final starts = <int>[];
  var searchFrom = 0;
  while (true) {
    final index = html.indexOf(marker, searchFrom);
    if (index == -1) break;
    starts.add(index);
    searchFrom = index + marker.length;
  }
  return [
    for (var i = 0; i < starts.length; i++)
      html.substring(starts[i], i + 1 < starts.length ? starts[i + 1] : (starts[i] + maxLength).clamp(0, html.length)),
  ];
}

/// `resume_analytics.html:356-408`'s job cards — near-identical markup to
/// `dashboard.html`'s own recommended-job cards (same `_get_matched_jobs`
/// source), with two confirmed differences this parser must account for
/// rather than reuse `dashboard_html_parser.dart`'s regexes verbatim: the
/// outer card div omits `overflow-hidden`, and the skill badge omits
/// `text-truncate`.
List<RecommendedJob> _parseSuitableJobs(String html) {
  final jobs = <RecommendedJob>[];
  for (final item in _splitByMarker(html, 'class="job-card border rounded-3 p-3 h-100"')) {
    final titleMatch = RegExp(r'<h6 class="fw-bold mb-0 text-truncate"[^>]*>([^<]*)</h6>').firstMatch(item);
    if (titleMatch == null) continue;
    final companyMatch = RegExp(r'<small class="text-muted">([^<]*)</small>').firstMatch(item);
    final skills = RegExp(
      r'<span class="badge bg-light text-dark border">([^<]*)</span>',
    ).allMatches(item).map((m) => _unescape(m.group(1)!.trim())).toList();
    final locationMatch = RegExp(
      r'<span class="text-muted"><i class="fas fa-map-marker-alt me-1"></i>([^<]*)</span>',
    ).firstMatch(item);
    final jobTypeMatch = RegExp(r'<span class="badge bg-primary bg-opacity-10 text-primary">([^<]*)</span>').firstMatch(item);
    final experienceMatch = RegExp(
      r'<span class="text-muted"><i class="fas fa-briefcase me-1"></i>([^<]*)</span>',
    ).firstMatch(item);
    final salaryMatch = RegExp(
      r'<small class="fw-bold text-success"><i class="fas fa-rupee-sign me-1"></i>([^<]*)</small>',
    ).firstMatch(item);
    // `resume_analytics.html:406`: `<a href="{% url 'employer_portal:job_detail'
    // job.pk %}" class="btn btn-primary btn-sm w-100 rounded-3 fw-bold"
    // target="_blank">` — byte-for-byte the same link markup
    // `dashboard_html_parser.dart`'s `_parseRecommendedJobs` already extracts
    // `job.pk` from; same technique reused here, not assumed.
    final jobHrefMatch = RegExp(
      r'<a href="([^"]*)"\s*class="btn btn-primary btn-sm w-100 rounded-3 fw-bold"',
    ).firstMatch(item);
    final jobId = jobHrefMatch == null
        ? null
        : int.tryParse(RegExp(r'(\d+)').firstMatch(jobHrefMatch.group(1)!)?.group(1) ?? '');

    jobs.add(
      RecommendedJob(
        id: jobId,
        title: _unescape(titleMatch.group(1)!.trim()),
        companyName: _unescape(companyMatch?.group(1)?.trim() ?? ''),
        skills: skills,
        location: _unescape(locationMatch?.group(1)?.trim() ?? ''),
        jobType: _unescape(jobTypeMatch?.group(1)?.trim() ?? ''),
        experienceLevel: _unescape(experienceMatch?.group(1)?.trim() ?? ''),
        salaryDisplay: _unescape(salaryMatch?.group(1)?.trim() ?? ''),
      ),
    );
  }
  return jobs;
}

String _unescape(String value) => unescapeHtmlEntities(value);
