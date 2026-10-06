import '../domain/entities/my_application_detail.dart';

/// Parses `templates/jobs/my_application.html` (`jobs_app.views.
/// my_application_detail`).
MyApplicationDetail parseMyApplicationDetailHtml(String html) {
  final pkMatch = RegExp(r'Application #(\d+)').firstMatch(html);
  final titleMatch = RegExp(r'<h1[^>]*>([^<]*)</h1>').firstMatch(html);
  final companyLineMatch = RegExp(r'</h1>\s*<p[^>]*>([\s\S]*?)</p>').firstMatch(html);
  final statusMatch = RegExp(r'rounded-pill[\s\S]*?>\s*([^<]+?)\s*</span>').firstMatch(html);
  final appliedAtMatch = RegExp(r'Applied on</div>\s*<div[^>]*>([^<]*)</div>').firstMatch(html);
  final updatedAtMatch = RegExp(r'Last updated</div>\s*<div[^>]*>([^<]*)</div>').firstMatch(html);
  final appliedAsMatch = RegExp(r'Applied as</div>\s*<div[^>]*>([^<]*?)\s*&middot;\s*([^<]*)</div>').firstMatch(html);
  final jobTypeMatch = RegExp(r'Job type</div>\s*<div[^>]*>([^<]*?)\s*&middot;\s*([^<]*)</div>').firstMatch(html);
  final coverLetterMatch = RegExp(r'Your cover letter</div>\s*<p[^>]*>([\s\S]*?)</p>').firstMatch(html);
  final jobLinkMatch = RegExp(r"employer/jobs/(\d+)/").firstMatch(html);

  final companyLine = (companyLineMatch?.group(1) ?? '').replaceAll(_htmlTagPattern, '').trim();
  final companyParts = companyLine.split('&middot;').map((s) => _unescape(s.trim())).where((s) => s.isNotEmpty).toList();

  return MyApplicationDetail(
    applicationId: int.tryParse(pkMatch?.group(1) ?? '') ?? 0,
    jobId: jobLinkMatch == null ? null : int.tryParse(jobLinkMatch.group(1)!),
    jobTitle: _unescape(titleMatch?.group(1)?.trim() ?? ''),
    companyName: companyParts.isNotEmpty ? companyParts[0] : '',
    jobLocation: companyParts.length > 1 ? companyParts[1] : '',
    status: _statusValueForLabel(_unescape(statusMatch?.group(1)?.trim() ?? '')),
    appliedAt: _unescape(appliedAtMatch?.group(1)?.trim() ?? ''),
    updatedAt: _unescape(updatedAtMatch?.group(1)?.trim() ?? ''),
    applicantName: _unescape(appliedAsMatch?.group(1)?.trim() ?? ''),
    applicantEmail: _unescape(appliedAsMatch?.group(2)?.trim() ?? ''),
    jobType: _unescape(jobTypeMatch?.group(1)?.trim() ?? ''),
    jobExperience: _unescape(jobTypeMatch?.group(2)?.trim() ?? ''),
    coverLetter: coverLetterMatch == null ? null : _unescape(coverLetterMatch.group(1)!.trim()),
    jobIsActive: html.contains('View job posting'),
  );
}

/// Same `get_status_display` → raw-value mapping already used by the
/// other application-list parsers.
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

final _htmlTagPattern = RegExp(r'<[^>]*>');

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');
