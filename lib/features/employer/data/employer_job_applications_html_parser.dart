import '../../../core/utils/html_unescape.dart';
import '../domain/entities/employer_job_applications.dart';

/// Parses `templates/employer/applications.html` (`jobs_app.views.
/// job_applications`) — live-verified against a real job with 4
/// applications.
EmployerJobApplicationsPage parseEmployerJobApplicationsHtml(String html) {
  final titleMatch = RegExp(r'<h1[^>]*>\s*([\s\S]*?)\s*</h1>').firstMatch(html);
  final jobTitle = _unescape(titleMatch?.group(1)?.trim() ?? '');

  // Cards nest to an unpredictable depth (avatar/name/email block, then 3
  // more sibling columns), so there's no fixed "</div>" count that reliably
  // closes one — splitting on each card's own start marker and taking
  // everything up to the next one (or end of this section) is simpler and
  // doesn't depend on counting nested tags.
  final starts = [for (final m in RegExp(r'candidate-card p-4">').allMatches(html)) m.end];
  final applications = <EmployerJobApplicationListItem>[];
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1] : html.length;
    final card = html.substring(starts[i], end);

    final pkMatch = RegExp(r'/employer/employer/applications/(\d+)/').firstMatch(card);
    final nameMatch = RegExp(r'fw-bold text-slate-900 mb-0">([^<]*)</h5>').firstMatch(card);
    if (pkMatch == null || nameMatch == null) continue;

    final emailMatch = RegExp(r'text-slate-400"></i>([^<]*)</div>').firstMatch(card);
    final expMatch = RegExp(r'fw-bold text-slate-800">\s*(\d+)\s*yr\(s\)').firstMatch(card);
    final statusMatch = RegExp(r'app-status-badge status-[\w-]+">\s*([^<]+?)\s*</span>').firstMatch(card);

    applications.add(
      EmployerJobApplicationListItem(
        applicationId: int.parse(pkMatch.group(1)!),
        applicantName: _unescape(nameMatch.group(1)!.trim()),
        applicantEmail: _unescape(emailMatch?.group(1)?.trim() ?? ''),
        yearsExperience: int.tryParse(expMatch?.group(1) ?? '') ?? 0,
        status: _statusValueForLabel(_unescape(statusMatch?.group(1)?.trim() ?? '')),
      ),
    );
  }

  return EmployerJobApplicationsPage(jobTitle: jobTitle, applications: applications);
}

/// The template prints `app.get_status_display` (a human label, e.g.
/// "Under Review"), not the raw stored value — mapped back via the same
/// `JobApplication.STATUS_CHOICES` pairs `kApplicationStatusOptions`
/// already carries, so this list's status matches
/// `EmployerApplicationDetail.status`'s convention (raw value, not label).
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

String _unescape(String value) => unescapeHtmlEntities(value);
