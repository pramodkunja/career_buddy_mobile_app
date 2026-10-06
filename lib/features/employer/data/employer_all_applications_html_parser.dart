import '../domain/entities/employer_all_applications.dart';

/// Parses `templates/employer/all_applications.html` (`jobs_app.views.
/// all_applications`). Same card-start-marker splitting technique as
/// `parseEmployerJobApplicationsHtml` — cards nest to an unpredictable
/// depth, so there's no fixed closing-tag count to rely on.
EmployerAllApplicationsPage parseEmployerAllApplicationsHtml(String html) {
  final starts = [for (final m in RegExp(r'application-card p-4[^"]*">').allMatches(html)) m.end];
  final applications = <EmployerAllApplicationListItem>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : html.length;
    final card = html.substring(starts[i], end);

    final pkMatch = RegExp(r'/employer/employer/applications/(\d+)/').firstMatch(card);
    final nameMatch = RegExp(r'fw-bold fs-5 text-slate-900">([^<]*)</div>').firstMatch(card);
    if (pkMatch == null || nameMatch == null) continue;

    final emailMatch = RegExp(r'text-slate-400"></i>([^<]*)</div>').firstMatch(card);
    final jobTitleMatch = RegExp(r'job-tag">[\s\S]*?</i>\s*([^<]*?)\s*</span>').firstMatch(card);
    final sourceMatch = RegExp(r'source-badge-(parsed|direct)"').firstMatch(card);
    final appliedAtMatch = RegExp(r'<strong>Applied:</strong>\s*([^<]*?)\s*</div>').firstMatch(card);
    final statusMatch = RegExp(r'app-status-badge status-[\w-]+">\s*([^<]+?)\s*</span>').firstMatch(card);

    applications.add(
      EmployerAllApplicationListItem(
        applicationId: int.parse(pkMatch.group(1)!),
        applicantName: _unescape(nameMatch.group(1)!.trim()),
        applicantEmail: _unescape(emailMatch?.group(1)?.trim() ?? ''),
        jobTitle: _unescape(jobTitleMatch?.group(1)?.trim() ?? ''),
        source: sourceMatch?.group(1) == 'parsed' ? 'resume_parsed' : 'direct',
        appliedAt: _unescape(appliedAtMatch?.group(1)?.trim() ?? ''),
        status: _statusValueForLabel(_unescape(statusMatch?.group(1)?.trim() ?? '')),
      ),
    );
  }

  return EmployerAllApplicationsPage(applications: applications);
}

/// Same `get_status_display` → raw-value mapping as
/// `parseEmployerJobApplicationsHtml`.
String _statusValueForLabel(String label) {
  const pairs = [
    ('applied', 'Applied'),
    ('reviewing', 'Under Review'),
    ('shortlisted', 'Shortlisted'),
    ('interview', 'Interview Scheduled'),
    ('offered', 'Offer Extended'),
    ('rejected', 'Rejected'),
  ];
  for (final (value, text) in pairs) {
    if (text == label) return value;
  }
  return label;
}

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');
