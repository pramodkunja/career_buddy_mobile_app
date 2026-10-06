import '../domain/entities/job_openings.dart';

/// Parses `templates/employer/job_openings.html` (`jobs_app.views.
/// job_openings`). Same card-start-marker splitting technique as the
/// other list parsers.
JobOpeningsPage parseJobOpeningsHtml(String html) {
  final starts = [for (final m in RegExp(r'job-card-col"[^>]*>').allMatches(html)) m.end];
  final jobs = <JobOpeningListItem>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : html.length;
    final card = html.substring(starts[i], end);

    final idMatch = RegExp(r'/employer/jobs/(\d+)/"').firstMatch(card);
    final titleMatch = RegExp(r'text-truncate text-slate-900"[^>]*title="([^"]*)"').firstMatch(card);
    if (idMatch == null || titleMatch == null) continue;

    final companyMatch = RegExp(r'text-slate-500 small mb-0 text-truncate">([^<]*)</p>').firstMatch(card);
    final jobTypeMatch = RegExp(r'job-badge badge-[\w-]+">\s*([^<]+?)\s*</span>').firstMatch(card);
    final isSeeded = RegExp(r'>CB</span>').hasMatch(card);
    final locationMatch = RegExp(r'fa-map-marker-alt me-1 text-slate-400"></i>\s*([^<]*?)\s*</div>').firstMatch(card);
    final experienceMatch = RegExp(r'fa-briefcase me-1 text-slate-400"></i>\s*([^<]*?)\s*</div>').firstMatch(card);
    final salaryMatch = RegExp(r'fw-bold small text-primary">\s*([^<]*?)\s*</div>').firstMatch(card);

    final skills = [
      for (final m in RegExp(r'skill-tag">([^<]*)</span>').allMatches(card)) _unescape(m.group(1)!.trim()),
    ];

    jobs.add(
      JobOpeningListItem(
        jobId: int.parse(idMatch.group(1)!),
        title: _unescape(titleMatch.group(1)!.trim()),
        companyName: _unescape(companyMatch?.group(1)?.trim() ?? ''),
        jobType: _unescape(jobTypeMatch?.group(1)?.trim() ?? ''),
        isSeeded: isSeeded,
        location: _unescape(locationMatch?.group(1)?.trim() ?? ''),
        experience: _unescape(experienceMatch?.group(1)?.trim() ?? ''),
        skills: skills,
        salaryDisplay: _unescape(salaryMatch?.group(1)?.trim() ?? ''),
      ),
    );
  }
  return JobOpeningsPage(jobs: jobs);
}

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');
