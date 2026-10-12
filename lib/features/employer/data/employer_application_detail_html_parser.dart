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
  final status = _parseSelectedStatus(html);
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
    status: status,
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
// `{{ form.status }}` (`application_detail.html:210`) renders Django's
// default `Select` widget: `<select name="status" ...>` wrapping one
// `<option>` per `STATUS_CHOICES`. Scoped to this specific `<select>` first
// (not `.firstMatch` against the whole page) so an unrelated `selected`
// option elsewhere could never be mistaken for the real status.
final _statusSelectPattern = RegExp(r'<select[^>]*\bname="status"[^>]*>([\s\S]*?)</select>');
// Django's `Select` widget marks only the current value's `<option>` with a
// bare `selected` attribute (no `="selected"`); every other option has none.
// `[^>]*\bselected\b` tolerates either attribute order or an explicit
// `selected=""`, rather than assuming one exact Django rendering.
final _selectedOptionValuePattern = RegExp(r'<option\s+value="([^"]*)"[^>]*\bselected\b');

/// Returns `null` — never a guessed value — whenever the real, currently
/// selected status can't be established with confidence: the `<select
/// name="status">` block itself wasn't found, it had no `selected` option,
/// or the value it did select isn't one of `kApplicationStatusOptions`'
/// known 6 (a markup change could otherwise select some unrelated, now
/// wrongly-"current" value). See `EmployerApplicationDetail.status`'s doc
/// comment for why a fabricated fallback here is unsafe.
String? _parseSelectedStatus(String html) {
  final statusBlock = _statusSelectPattern.firstMatch(html)?.group(1);
  if (statusBlock == null) return null;
  final rawValue = _selectedOptionValuePattern.firstMatch(statusBlock)?.group(1);
  if (rawValue == null) return null;
  final isKnownValue = kApplicationStatusOptions.any((option) => option.value == rawValue);
  return isKnownValue ? rawValue : null;
}
final _employerNotesPattern = RegExp(r'name="employer_notes"[^>]*>([\s\S]*?)</textarea>');
final _appliedAtPattern = RegExp(r'Applied on\s+([^<]*)</small>');
