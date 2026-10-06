import '../domain/entities/employer_application_detail.dart';

/// `templates/employer/application_detail.html` — no JSON API, plain
/// server-rendered HTML. Reuses the same `info-label`/`info-value`
/// regex-pair scraping technique already proven against Profile's
/// identically-shaped markup (`ProfileRemoteDataSource`), plus a few
/// page-specific patterns for the header, status `<select>`, and the
/// conditional interview/cover-letter sections.
EmployerApplicationDetail parseEmployerApplicationDetailHtml(String html) {
  final infoPairs = <String, String>{};
  for (final m in _infoPairPattern.allMatches(html)) {
    infoPairs.putIfAbsent(m.group(1)!.trim(), () => _stripHtml(m.group(2)!));
  }

  final resumeMatch = _resumeLinkPattern.firstMatch(html);
  final interviewScoreMatch = _interviewScorePattern.firstMatch(html);
  final interviewVideoMatch = _interviewVideoPattern.firstMatch(html);
  final interviewDateMatch = _interviewDatePattern.firstMatch(html);
  final coverLetterMatch = _coverLetterPattern.firstMatch(html);
  final statusMatch = _selectedStatusPattern.firstMatch(html);
  final notesMatch = _employerNotesPattern.firstMatch(html);
  final appliedAtMatch = _appliedAtPattern.firstMatch(html);
  final nameMatch = _applicantNamePattern.firstMatch(html);
  final jobTitleMatch = _jobTitlePattern.firstMatch(html);
  final emailMatch = _emailPattern.firstMatch(html);
  final phoneMatch = _phonePattern.firstMatch(html);

  return EmployerApplicationDetail(
    applicantName: nameMatch == null ? '' : _stripHtml(nameMatch.group(1)!),
    jobTitle: jobTitleMatch == null ? '' : _stripHtml(jobTitleMatch.group(1)!),
    applicantEmail: emailMatch?.group(1)?.trim() ?? '',
    applicantPhone: phoneMatch?.group(1)?.trim() ?? '',
    yearsExperience: int.tryParse((infoPairs['Experience'] ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0,
    currentCompany: infoPairs['Current Company'] ?? 'N/A',
    currentSalary: infoPairs['Current Salary'] ?? 'N/A',
    expectedSalary: infoPairs['Expected Salary'] ?? 'N/A',
    resumeUrl: resumeMatch?.group(1),
    coverLetter: coverLetterMatch == null ? null : _stripHtml(coverLetterMatch.group(1)!).trim(),
    interviewScore: interviewScoreMatch == null ? null : int.tryParse(interviewScoreMatch.group(1)!),
    interviewVideoUrl: interviewVideoMatch?.group(1),
    interviewRecordedAt: interviewDateMatch?.group(1)?.trim(),
    status: statusMatch?.group(1) ?? 'applied',
    employerNotes: notesMatch == null ? '' : _stripHtml(notesMatch.group(1)!).trim(),
    appliedAt: appliedAtMatch?.group(1)?.trim() ?? '',
  );
}

final _htmlTagPattern = RegExp(r'<[^>]*>');
String _stripHtml(String value) => value.replaceAll(_htmlTagPattern, '').trim();

final _infoPairPattern = RegExp(
  r'info-label">([^<]*)</div>\s*<div class="info-value">\s*([\s\S]*?)\s*</div>',
);
final _applicantNamePattern = RegExp(
  r'text-slate-900 mb-1" style="font-size: 2rem;">\s*([\s\S]*?)\s*</h2>',
);
final _jobTitlePattern = RegExp(r'Applicant for\s+([\s\S]*?)\s*</span>');
final _emailPattern = RegExp(r'fa-envelope me-1\.5 text-slate-400"></i>\s*([^<]*)</span>');
final _phonePattern = RegExp(r'fa-phone me-1\.5 text-slate-400"></i>\s*([^<]*)</span>');
final _resumeLinkPattern = RegExp(r'<a href="([^"]*)" target="_blank"[^>]*>\s*<i class="fas fa-file-pdf');
final _interviewScorePattern = RegExp(r'Score (\d+)/100');
final _interviewVideoPattern = RegExp(r'<source src="([^"]*)">');
final _interviewDatePattern = RegExp(r'Recorded\s+([^<]*)</div>');
final _coverLetterPattern = RegExp(
  r'text-slate-700 small" style="line-height: 1\.7;">\s*([\s\S]*?)\s*</div>',
);
// Django's `Select` widget marks only the current value's `<option>` with a
// bare `selected` attribute (no `="selected"`); every other option has none.
// `[^>]*\bselected\b` tolerates either attribute order or an explicit
// `selected=""`, rather than assuming one exact Django rendering.
final _selectedStatusPattern = RegExp(r'<option value="([a-z_]+)"[^>]*\bselected\b');
final _employerNotesPattern = RegExp(r'name="employer_notes"[^>]*>([\s\S]*?)</textarea>');
final _appliedAtPattern = RegExp(r'Applied on\s+([^<]*)</small>');
