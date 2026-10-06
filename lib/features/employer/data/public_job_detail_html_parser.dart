import '../domain/entities/public_job_detail.dart';

/// Parses `templates/jobs/job_detail.html` (`jobs_app.views.job_detail`).
PublicJobDetail parsePublicJobDetailHtml(String html) {
  final titleMatch = RegExp(r'<h3 class="fw-bold mb-0">([^<]*)</h3>').firstMatch(html);
  final companyMatch = RegExp(r'<span class="text-muted">([^<]*)</span>').firstMatch(html);
  final jobTypeMatch = RegExp(r'badge bg-primary">([^<]*)</span>').firstMatch(html);
  final experienceMatch = RegExp(r'badge bg-secondary">([^<]*)</span>').firstMatch(html);
  final locationMatch = RegExp(r'fa-map-marker-alt me-1"></i>([^<]*)</span>').firstMatch(html);
  final salaryMatch = RegExp(r'fa-money-bill-wave me-1"></i>([^<]*)</span>').firstMatch(html);
  final openingsMatch = RegExp(r'badge bg-warning text-dark">([^<]*)</span>').firstMatch(html);
  // `{{ job.description|linebreaks }}` wraps EACH paragraph in its own
  // <p>, so this captures everything up to the next <h5> (not just the
  // first </p>) to avoid truncating a multi-paragraph description.
  final descriptionMatch = RegExp(r'Job Description</h5>\s*([\s\S]*?)\s*<h5').firstMatch(html);
  final requirementsMatch = RegExp(r'Requirements</h5>\s*([\s\S]*?)\s*<h5').firstMatch(html);
  final deadlineMatch = RegExp(r'Application Deadline:\s*<strong>([^<]*)</strong>').firstMatch(html);

  final skills = [
    for (final m in RegExp(r'badge-skill[^"]*">([^<]*)</span>').allMatches(html)) _unescape(m.group(1)!.trim()),
  ];

  return PublicJobDetail(
    title: _unescape(titleMatch?.group(1)?.trim() ?? ''),
    companyName: _unescape(companyMatch?.group(1)?.trim() ?? ''),
    jobType: _unescape(jobTypeMatch?.group(1)?.trim() ?? ''),
    experience: _unescape(experienceMatch?.group(1)?.trim() ?? ''),
    location: _unescape(locationMatch?.group(1)?.trim() ?? ''),
    salaryDisplay: _unescape(salaryMatch?.group(1)?.trim() ?? ''),
    openings: _unescape(openingsMatch?.group(1)?.trim() ?? ''),
    description: _stripHtml(descriptionMatch?.group(1) ?? ''),
    requirements: _stripHtml(requirementsMatch?.group(1) ?? ''),
    skills: skills,
    deadline: _unescape(deadlineMatch?.group(1)?.trim() ?? ''),
  );
}

final _htmlTagPattern = RegExp(r'<[^>]*>');

String _stripHtml(String value) => _unescape(value.replaceAll(_htmlTagPattern, '\n').trim());

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"');
