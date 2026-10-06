import '../domain/entities/employer_dashboard_summary.dart';

/// Regex extraction against `jobs_app.views.employer_dashboard`'s
/// server-rendered HTML (`templates/employer/dashboard.html`) — the same
/// legitimate-reuse-of-an-already-fetched-page technique already used
/// elsewhere in this app (e.g. `extractExerciseHeroMeta`), not a new API.
/// Every regex below is anchored to markup read directly from the
/// template, not guessed.
EmployerDashboardSummary parseEmployerDashboardHtml(String html) {
  final greetingMatch = RegExp(r'Welcome back,\s*([^!<]+)!').firstMatch(html);
  final greetingName = _unescape(greetingMatch?.group(1)?.trim() ?? '');

  final statMatches = RegExp(
    r'<div class="emp-stat-number"[^>]*>\s*(\d+)\s*</div>',
  ).allMatches(html).toList();
  final totalJobsCount = statMatches.isNotEmpty ? int.parse(statMatches[0].group(1)!) : 0;
  final activeJobs = statMatches.length > 1 ? int.parse(statMatches[1].group(1)!) : 0;
  final totalApps = statMatches.length > 2 ? int.parse(statMatches[2].group(1)!) : 0;

  final tbodyMatch = RegExp(r'<tbody>([\s\S]*?)</tbody>').firstMatch(html);
  final tbody = tbodyMatch?.group(1) ?? '';
  final jobs = <EmployerJobListItem>[];
  for (final rowMatch in RegExp(r'<tr>([\s\S]*?)</tr>').allMatches(tbody)) {
    final row = rowMatch.group(1)!;
    final titleMatch = RegExp(r'class="ps-4 fw-bold text-slate-900">([^<]*)</td>').firstMatch(row);
    if (titleMatch == null) continue; // The `{% empty %}` row has no title cell.

    final typeMatch = RegExp(r'background: #eff6ff;[^"]*">\s*([^<]+?)\s*</span>').firstMatch(row);
    final statusMatch = RegExp(r'>(Active|Closed|Draft)</span>').firstMatch(row);
    final appsMatch = RegExp(r'fa-users me-1 text-primary"></i>\s*(\d+)').firstMatch(row);
    final dateMatch = RegExp(r'class="text-slate-500 small">([^<]*)</td>').firstMatch(row);
    final jobIdMatch = RegExp(r'/jobs/(\d+)/edit/').firstMatch(row);
    if (jobIdMatch == null) continue; // No stable id to act on — skip rather than guess.

    jobs.add(
      EmployerJobListItem(
        jobId: int.parse(jobIdMatch.group(1)!),
        title: _unescape(titleMatch.group(1)!.trim()),
        jobType: _unescape(typeMatch?.group(1)?.trim() ?? ''),
        status: (statusMatch?.group(1) ?? 'draft').toLowerCase(),
        applicationsCount: int.tryParse(appsMatch?.group(1) ?? '') ?? 0,
        postedDate: _unescape(dateMatch?.group(1)?.trim() ?? ''),
      ),
    );
  }

  return EmployerDashboardSummary(
    greetingName: greetingName,
    totalJobsCount: totalJobsCount,
    activeJobs: activeJobs,
    totalApps: totalApps,
    jobs: jobs,
  );
}

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');
