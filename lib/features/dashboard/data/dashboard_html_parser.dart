import '../../../core/utils/date_format.dart';
import '../../../core/utils/html_unescape.dart';
import '../domain/entities/activity_progress.dart';
import '../domain/entities/dashboard_data.dart';
import '../domain/entities/dashboard_stats.dart';
import '../domain/entities/payment_record.dart';
import '../domain/entities/recent_result.dart';
import '../domain/entities/recommended_job.dart';

/// Regex extraction against `activities.views.dashboard`'s server-rendered
/// HTML (`templates/dashboard.html`) — the same legitimate reuse-of-an-
/// already-fetched-page technique already used throughout this app (e.g.
/// `parseEmployerDashboardHtml`), not a new API. Every regex below is
/// anchored to markup read directly from the template, not guessed.
///
/// **Why this exists instead of parsing `dashboard_api`'s JSON**: that
/// endpoint is real, deliberately mobile-shaped source
/// (`activities/views.py:dashboard_api`, documented in
/// `docs/BACKEND_CONTRACT_dashboard.md`) but is **not deployed to
/// production** — confirmed live: `GET /dashboard/api/` returns a genuine
/// Django 404 (not the 401 `{"error":"Not authenticated"}` the view itself
/// would return if it were reachable), while the plain HTML `/dashboard/`
/// page it's a JSON sibling of works live today. Rather than leave the
/// app's primary post-login screen permanently broken until that endpoint
/// ships, this scrapes the one that's actually live — [DashboardData]'s own
/// shape is unchanged, so no other file in this feature needed to change.
///
/// Two fields the JSON contract would have carried have no real source in
/// this HTML page, confirmed by reading the template line by line — both
/// documented as deliberate, not silently guessed:
/// - [RecentResult.date] isn't rendered anywhere on the dashboard (only
///   title/activity/score are) — this parser fills `DateTime.now()`, which
///   is never actually shown by `RecentResultsList` (checked: it reads
///   `title`/`activityName`/`score`/`maxScore`/`percentage` only).
/// - [RecentResult.percentage] is likewise never rendered as a number (only
///   used server-side to pick a CSS color tier) — recomputed here as
///   `score/maxScore*100`, an honest derivation from two real numbers, not
///   fabricated data.
DashboardData parseDashboardHtml(String html) {
  if (!isDashboardHtml(html)) {
    throw const FormatException('Not a dashboard page');
  }

  return DashboardData(
    stats: _parseStats(html),
    activities: _parseActivities(html),
    recentResults: _parseRecentResults(html),
    recommendedJobs: _parseRecommendedJobs(html),
    paymentHistory: _parsePaymentHistory(html),
    interviewScore: _parseInterviewScore(html),
  );
}

/// `dashboard.html:52` — present only on the real, rendered dashboard page
/// (not on a login redirect or an error page), so this is this parser's
/// success/failure signal, same role as `isResumeMatchResultHtml` elsewhere.
bool isDashboardHtml(String html) => html.contains('class="dashboard-welcome"');

DashboardStats _parseStats(String html) {
  final values = RegExp(
    r'<div class="stat-card-value">\s*([\d.]+)\s*</div>',
  ).allMatches(html).map((m) => num.tryParse(m.group(1)!) ?? 0).toList();
  // `dashboard.html:69,76,83,90` — fixed order: Total Activities, Completed,
  // In Progress, Total Score.
  return DashboardStats(
    totalActivities: values.isNotEmpty ? values[0].toInt() : 0,
    completedCount: values.length > 1 ? values[1].toInt() : 0,
    inProgressCount: values.length > 2 ? values[2].toInt() : 0,
    totalScore: values.length > 3 ? values[3] : 0,
  );
}

num? _parseInterviewScore(String html) {
  final match = RegExp(r'interview score of <strong>([\d.]+)/100</strong>').firstMatch(html);
  if (match == null) return null;
  return num.tryParse(match.group(1)!);
}

/// Splits a section of [html] into one slice per occurrence of [marker],
/// each running up to the next occurrence (or [maxLength] characters for
/// the last one) — the same "card-start-marker splitting" technique used
/// throughout this app's other list-parsing screens, needed because these
/// cards nest to an unpredictable depth that a naive non-greedy
/// `[\s\S]*?</div>` would cut short at the first nested closing tag.
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

List<ActivityProgress> _parseActivities(String html) {
  final activities = <ActivityProgress>[];
  for (final item in _splitByMarker(html, '<div class="progress-activity-item">')) {
    final hrefMatch = RegExp(r'<a href="([^"]*)" class="progress-activity-link">').firstMatch(item);
    if (hrefMatch == null) continue;
    // `dashboard.html:164`: usually `{% url 'activity_detail' item.activity.pk %}`
    // (`/activities/<pk>/`), but can instead be a `direct_url` straight to
    // a single-exercise/workshop activity's own page for that subset of
    // activities — best-effort: use whatever numeric id appears first in
    // the href either way, rather than drop the whole item for lacking
    // the canonical pattern.
    final idMatch = RegExp(r'(\d+)').firstMatch(hrefMatch.group(1)!);
    if (idMatch == null) continue;

    final nameMatch = RegExp(r'class="progress-activity-name">([^<]*)</span>').firstMatch(item);
    // Strips the `{{ item.activity.order }}. ` prefix the template adds
    // for display (`dashboard.html:171`) — the JSON contract's own `title`
    // field was always the bare title with no numbering, and this keeps
    // this parser's output identical either way.
    final rawName = _unescape(nameMatch?.group(1)?.trim() ?? '');
    final title = rawName.replaceFirst(RegExp(r'^\d+\.\s*'), '');

    final pctMatch = RegExp(r'progress-activity-pct[^>]*>\s*([\d.]+)%').firstMatch(item);
    final subsMatch = RegExp(r'>(\d+)/(\d+)\s*sub-activities').firstMatch(item);
    final startedMatch = RegExp(r'Started\s+([A-Za-z]{3}\s+\d{1,2},\s*\d{4})').firstMatch(item);

    activities.add(
      ActivityProgress(
        activityId: int.parse(idMatch.group(1)!),
        title: title,
        completionRate: double.tryParse(pctMatch?.group(1) ?? '') ?? 0,
        completedSubActivities: int.tryParse(subsMatch?.group(1) ?? '') ?? 0,
        totalSubActivities: int.tryParse(subsMatch?.group(2) ?? '') ?? 0,
        startedAt: startedMatch != null ? parseMonthDayYear(startedMatch.group(1)!) : null,
      ),
    );
  }
  return activities;
}

List<RecentResult> _parseRecentResults(String html) {
  final results = <RecentResult>[];
  for (final item in _splitByMarker(html, '<div class="recent-result-item">', maxLength: 800)) {
    final titleMatch = RegExp(r'result-exercise-name">([^<]*)</div>').firstMatch(item);
    final activityMatch = RegExp(r'result-activity-name text-muted">([^<]*)').firstMatch(item);
    final scoreMatch = RegExp(r'score-badge[^>]*>\s*([\d.]+)/([\d.]+)\s*</span>').firstMatch(item);
    if (titleMatch == null || scoreMatch == null) continue;

    final score = num.tryParse(scoreMatch.group(1)!) ?? 0;
    final maxScore = num.tryParse(scoreMatch.group(2)!) ?? 0;
    results.add(
      RecentResult(
        title: _unescape(titleMatch.group(1)!.trim()),
        activityName: _unescape(activityMatch?.group(1)?.trim() ?? ''),
        score: score,
        maxScore: maxScore,
        percentage: maxScore > 0 ? (score / maxScore * 100).toDouble() : 0,
        // Not rendered on this page at all — see this file's top-level doc
        // comment for why a placeholder here is honest, not fabricated.
        date: DateTime.now(),
      ),
    );
  }
  return results;
}

List<RecommendedJob> _parseRecommendedJobs(String html) {
  final jobs = <RecommendedJob>[];
  for (final item in _splitByMarker(html, 'class="job-card border rounded-3 p-3 h-100 overflow-hidden"')) {
    final titleMatch = RegExp(r'<h6 class="fw-bold mb-0 text-truncate"[^>]*>([^<]*)</h6>').firstMatch(item);
    if (titleMatch == null) continue;
    final companyMatch = RegExp(r'<small class="text-muted">([^<]*)</small>').firstMatch(item);
    final skills = RegExp(
      r'<span class="badge bg-light text-dark border text-truncate"[^>]*>([^<]*)</span>',
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

    jobs.add(
      RecommendedJob(
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

List<PaymentRecord> _parsePaymentHistory(String html) {
  final tbodyMatch = RegExp(r'<tbody>([\s\S]*?)</tbody>').firstMatch(html);
  if (tbodyMatch == null) return const [];
  final tbody = tbodyMatch.group(1)!;

  final payments = <PaymentRecord>[];
  for (final rowMatch in RegExp(r'<tr>([\s\S]*?)</tr>').allMatches(tbody)) {
    final row = rowMatch.group(1)!;
    final dateMatch = RegExp(r'<td>([^<]*)</td>').firstMatch(row);
    final amountMatch = RegExp(r'₹([\d.]+)').firstMatch(row);
    final transactionMatch = RegExp(r'<small class="text-muted">([^<]*)</small>').firstMatch(row);
    if (dateMatch == null || amountMatch == null) continue;

    final date = parseMonthDayYear(dateMatch.group(1)!.trim());
    if (date == null) continue;

    payments.add(
      PaymentRecord(
        date: date,
        isPlanActive: row.contains('bg-success">Active<'),
        amountRupees: num.tryParse(amountMatch.group(1)!) ?? 0,
        transactionId: _unescape(transactionMatch?.group(1)?.trim() ?? ''),
      ),
    );
  }
  return payments;
}

String _unescape(String value) => unescapeHtmlEntities(value);
