/// A faithful Dart port of `career_app/resume_document.py`'s validation
/// rules (`normalize_state`'s companion `validate_state()` and every helper
/// it calls), verified line-by-line against that source. This is
/// **client-side only** — it never claims to replace or match the server's
/// own `validate_state()` byte-for-byte (see this file's own limitations
/// noted per-function below); the real server call remains authoritative
/// once a later, separately-approved phase adds it. `field` strings here
/// intentionally match the Python side's own dotted field names exactly
/// (snake_case, e.g. `'personal.name'`, `'employment.0.bullets'`) rather
/// than this codebase's camelCase model field names, so a future
/// server-response integration can match errors from either source by the
/// same key.
library;

import '../entities/manual_resume_draft.dart';
import '../entities/resume_role.dart';

const int kMaxText = 300;
const int kMaxLongText = 2000;
const int kMaxItems = 15;
const int kMaxBullets = 15;
const int kMaxSkills = 40;
const int kSkillMin = 2;
const int kSkillMax = 50;
const int kPhoneMinDigits = 10;
const int kPhoneMaxDigits = 15;
const int kEmailMax = 254;

final RegExp _placeholderRe = RegExp(r'\[[^\[\]\n]{1,80}\]');
final RegExp _phoneDigitsRe = RegExp(r'\d');
final RegExp _phoneAllowedRe = RegExp(r'^\+?[0-9\s\-()]+$');
final RegExp _emailRe = RegExp(r'^[^@\s]+@([a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$', caseSensitive: false);
// Python's `[^\W\d_]` is "a word character that is neither a digit nor an
// underscore" — effectively any Unicode letter under `re.UNICODE` (Python
// 3's default). `\p{L}` is the closest Dart equivalent; see `isValidName`'s
// own doc comment for the practical limitation this approximation carries.
final RegExp _nameRe = RegExp(r"^[\p{L}]+(?:[ .'\-]+[\p{L}]+)*\.?$", unicode: true);
final RegExp _linkRe = RegExp(
  r'^(https?://)?([a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}(:\d{1,5})?([/?#][^\s<>"' r"'" r'`]*)?$',
  caseSensitive: false,
);
final RegExp _monthRe = RegExp(r'^(\d{4})-(\d{2})$');
final RegExp _passportRe = RegExp(r'^[A-Z0-9]{6,12}$');

/// Per-field (min length if entered, max length, label) — matching
/// `resume_document.py`'s `PERSONAL_RULES`. Required-ness is checked
/// separately; an empty optional field is never a length error.
class LengthRule {
  const LengthRule(this.min, this.max, this.label);
  final int min;
  final int max;
  final String label;
}

const Map<String, LengthRule> kPersonalRules = {
  'name': LengthRule(2, 80, 'Full name'),
  'location': LengthRule(2, 100, 'Location'),
};

const Map<String, LengthRule> kTopRules = {
  'target_title': LengthRule(2, 100, 'Target job title'),
  'domain': LengthRule(2, 100, 'Industry / domain'),
  'summary': LengthRule(50, 1200, 'Professional summary'),
  'achievements': LengthRule(20, 800, 'Achievements'),
  'languages': LengthRule(2, 200, 'Languages'),
  'additional': LengthRule(2, 800, 'Additional information'),
  'place': LengthRule(2, 60, 'Place'),
};

const Map<String, Map<String, LengthRule>> kEntryRules = {
  'employment': {
    'title': LengthRule(2, 100, 'Job title'),
    'company': LengthRule(2, 120, 'Company'),
    'location': LengthRule(2, 100, 'Location'),
    'bullets': LengthRule(20, 1500, 'Responsibilities'),
  },
  'internships': {
    'title': LengthRule(2, 100, 'Role / position'),
    'company': LengthRule(2, 150, 'Organisation'),
    'location': LengthRule(2, 100, 'Location'),
    'bullets': LengthRule(20, 1500, 'Responsibilities'),
  },
  'projects': {
    'name': LengthRule(2, 120, 'Project name'),
    'context': LengthRule(2, 150, 'Type / context'),
    'tools': LengthRule(2, 500, 'Tools / technologies'),
    'bullets': LengthRule(30, 1200, 'Project description'),
  },
  'education': {
    'degree': LengthRule(2, 100, 'Degree / qualification'),
    'institution': LengthRule(2, 150, 'Institution'),
    'location': LengthRule(2, 100, 'Location'),
    'year': LengthRule(2, 30, 'Year / duration'),
    'score': LengthRule(1, 50, 'Grade / CGPA'),
  },
  'certifications': {
    'name': LengthRule(2, 150, 'Certification'),
    'issuer': LengthRule(2, 150, 'Issued by'),
    'year': LengthRule(4, 20, 'Year'),
  },
  'training': {
    'name': LengthRule(2, 150, 'Training / course'),
    'provider': LengthRule(2, 150, 'Provider'),
    'year': LengthRule(4, 20, 'Year'),
  },
};

/// Step numbers match the builder's step indicator (`STEP_PERSONAL`..
/// `STEP_SUMMARY`, `resume_document.py:60`), so an error can take the
/// candidate straight to the right panel.
const int kStepPersonal = 1;
const int kStepSkills = 2;
const int kStepExperience = 3;
const int kStepEducation = 4;
const int kStepSummary = 5;

class ManualResumeValidationError {
  const ManualResumeValidationError({required this.field, required this.step, required this.message});
  final String field;
  final int step;
  final String message;
}

int _textLen(String value) {
  final lines = value.split('\n').where((l) => l.trim().isNotEmpty);
  return lines.join('\n').length;
}

/// '' when [value] is empty or within [rule]'s bounds; the user-facing
/// message otherwise. Matches `length_error()` exactly.
String lengthError(String value, LengthRule rule) {
  if (value.isEmpty) return '';
  final n = _textLen(value);
  if (n < rule.min) return '${rule.label}: please enter at least ${rule.min} characters.';
  if (n > rule.max) return '${rule.label} can be at most ${rule.max} characters (currently $n).';
  return '';
}

/// Proper format only (no spaces, a real domain, max 254 chars) — never
/// treated as "verified". Does not reproduce Django's `validate_email`'s
/// extra checks (per-label length, domain-literal/punycode handling) —
/// the regex alone is the practical approximation used here; see this
/// library's own top-level doc comment.
bool isValidEmail(String value) {
  if (value.length > kEmailMax) return false;
  return _emailRe.hasMatch(value);
}

/// 10–15 digits; only digits, a leading `+`, spaces, hyphens and
/// parentheses.
bool isValidPhone(String value) {
  final digits = _phoneDigitsRe.allMatches(value).length;
  return value.isNotEmpty && _phoneAllowedRe.hasMatch(value) && digits >= kPhoneMinDigits && digits <= kPhoneMaxDigits;
}

/// See [_nameRe]'s own doc comment for the Unicode-letter approximation
/// this relies on instead of Python's exact `[^\W\d_]` semantics.
bool isValidName(String value) {
  final rule = kPersonalRules['name']!;
  return value.length >= rule.min && value.length <= rule.max && _nameRe.hasMatch(value);
}

bool isValidLink(String value) => _linkRe.hasMatch(value);

bool hasPlaceholder(String text) => _placeholderRe.hasMatch(text);

/// (year, month) for a `'YYYY-MM'` string with a real month 1–12, else
/// `null`. Matches `_month_key()`.
(int, int)? monthKey(String value) {
  final m = _monthRe.firstMatch(value);
  if (m == null) return null;
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return (year, month);
}

bool _jobTouched(ManualResumeJobEntry e) =>
    e.title.isNotEmpty ||
    e.company.isNotEmpty ||
    e.location.isNotEmpty ||
    e.start.isNotEmpty ||
    e.end.isNotEmpty ||
    e.bullets.isNotEmpty;

bool _jobFilled(ManualResumeJobEntry e) => e.title.isNotEmpty && e.company.isNotEmpty;

bool _projectTouched(ManualResumeProjectEntry e) =>
    e.name.isNotEmpty || e.context.isNotEmpty || e.tools.isNotEmpty || e.start.isNotEmpty || e.end.isNotEmpty || e.bullets.isNotEmpty;

bool _educationTouched(ManualResumeEducationEntry e) =>
    e.degree.isNotEmpty || e.institution.isNotEmpty || e.location.isNotEmpty || e.year.isNotEmpty || e.score.isNotEmpty;

bool _certTouched(ManualResumeCertificationEntry e) => e.name.isNotEmpty || e.issuer.isNotEmpty || e.year.isNotEmpty;

bool _trainingTouched(ManualResumeTrainingEntry e) => e.name.isNotEmpty || e.provider.isNotEmpty || e.year.isNotEmpty;

List<ManualResumeJobEntry> validJobs(List<ManualResumeJobEntry> entries) => entries.where(_jobFilled).toList();

List<ManualResumeProjectEntry> validProjects(List<ManualResumeProjectEntry> entries) =>
    entries.where((e) => e.name.isNotEmpty).toList();

List<ManualResumeEducationEntry> validEducation(List<ManualResumeEducationEntry> entries) =>
    entries.where((e) => e.degree.isNotEmpty).toList();

List<ManualResumeCertificationEntry> validCertifications(List<ManualResumeCertificationEntry> entries) =>
    entries.where((e) => e.name.isNotEmpty).toList();

List<ManualResumeTrainingEntry> validTraining(List<ManualResumeTrainingEntry> entries) =>
    entries.where((e) => e.name.isNotEmpty).toList();

/// `[(label, items)]` for the role's own skill-group fields, in the role's
/// order, plus any group the role no longer defines (e.g. renamed) still
/// counted under a generic "Skills" label. Matches `role_skill_groups()`.
List<MapEntry<String, List<String>>> roleSkillGroups(ManualResumeDraft draft, ResumeRole? role) {
  final groups = draft.skills.groups;
  final out = <MapEntry<String, List<String>>>[];
  final used = <String>{};
  for (final field in role?.fields ?? const <ResumeRoleSkillField>[]) {
    final items = groups[field.key] ?? const <String>[];
    if (items.isNotEmpty) out.add(MapEntry(field.label, items));
    used.add(field.key);
  }
  groups.forEach((key, items) {
    if (!used.contains(key) && items.isNotEmpty) out.add(MapEntry('Skills', items));
  });
  return out;
}

int relevantSkillCount(ManualResumeDraft draft, ResumeRole? role) {
  final seen = <String>{};
  for (final entry in roleSkillGroups(draft, role)) {
    seen.addAll(entry.value.map((i) => i.toLowerCase()));
  }
  seen.addAll(draft.skills.suggested.map((i) => i.toLowerCase()));
  seen.addAll(draft.skills.other.map((i) => i.toLowerCase()));
  return seen.length;
}

/// Mandatory-field rules, ported from `validate_state()`. Returns an empty
/// list when the draft is ready. Employment history and certifications are
/// never mandatory on their own: freshers may use projects, internships or
/// training, and experienced candidates may use projects.
List<ManualResumeValidationError> validateManualResumeDraft(ManualResumeDraft draft, ResumeRole? role) {
  final errors = <ManualResumeValidationError>[];
  ManualResumeValidationError err(String field, int step, String message) =>
      ManualResumeValidationError(field: field, step: step, message: message);

  final p = draft.personal;
  if (p.name.isEmpty) {
    errors.add(err('personal.name', kStepPersonal, 'Please enter your full name.'));
  } else {
    final nameLenErr = lengthError(p.name, kPersonalRules['name']!);
    if (nameLenErr.isNotEmpty) {
      errors.add(err('personal.name', kStepPersonal, nameLenErr));
    } else if (!_nameRe.hasMatch(p.name)) {
      errors.add(
        err('personal.name', kStepPersonal, 'Full name can contain only letters, spaces, hyphens and apostrophes.'),
      );
    }
  }
  if (!isValidEmail(p.email)) {
    errors.add(err('personal.email', kStepPersonal, 'Please enter a valid email address.'));
  }
  if (!isValidPhone(p.phone)) {
    errors.add(err('personal.phone', kStepPersonal, 'Enter a valid phone number with at least 10 digits.'));
  }
  final locationLenErr = lengthError(p.location, kPersonalRules['location']!);
  if (locationLenErr.isNotEmpty) {
    errors.add(err('personal.location', kStepPersonal, locationLenErr));
  }
  if (p.linkedin.isNotEmpty && !isValidLink(p.linkedin)) {
    errors.add(
      err(
        'personal.linkedin',
        kStepPersonal,
        'Please enter a valid LinkedIn link (e.g. https://example.com/your-name).',
      ),
    );
  }
  if (p.website.isNotEmpty && !isValidLink(p.website)) {
    errors.add(
      err(
        'personal.website',
        kStepPersonal,
        'Please enter a valid Portfolio / website link (e.g. https://example.com/your-name).',
      ),
    );
  }
  if (p.passport.isNotEmpty && !_passportRe.hasMatch(p.passport)) {
    errors.add(
      err('personal.passport', kStepPersonal, 'Please enter a valid passport number (6–12 letters or digits).'),
    );
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(p.dob)) {
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (p.dob.compareTo(todayIso) >= 0) {
      errors.add(err('personal.dob', kStepPersonal, 'Date of birth must be in the past.'));
    }
  }

  if (role == null) {
    errors.add(err('role', kStepSkills, 'Please select a job role.'));
  }
  if (draft.level.isEmpty) {
    errors.add(err('level', kStepSkills, 'Please select your experience level.'));
  }
  if (draft.years.isNotEmpty && !RegExp(r'^\d{1,2}(\.\d)?$').hasMatch(draft.years)) {
    errors.add(err('years', kStepSkills, 'Please enter your years of experience as a number.'));
  }
  if (role != null && relevantSkillCount(draft, role) == 0) {
    errors.add(err('skills', kStepSkills, 'Please select relevant skills for your chosen role.'));
  }

  // Partially filled entries would print half a line, so they must be
  // completed or removed.
  for (final (i, e) in draft.employment.indexed) {
    if (_jobTouched(e) && !_jobFilled(e)) {
      final field = e.title.isEmpty ? 'title' : 'company';
      errors.add(
        err(
          'employment.$i.$field',
          kStepExperience,
          'Please complete the role title and organisation for employment ${i + 1}, or remove it.',
        ),
      );
    }
  }
  for (final (i, e) in draft.internships.indexed) {
    if (_jobTouched(e) && !_jobFilled(e)) {
      final field = e.title.isEmpty ? 'title' : 'company';
      errors.add(
        err(
          'internships.$i.$field',
          kStepExperience,
          'Please complete the role title and organisation for internship ${i + 1}, or remove it.',
        ),
      );
    }
  }
  for (final (i, e) in draft.projects.indexed) {
    if (_projectTouched(e) && e.name.isEmpty) {
      errors.add(err('projects.$i.name', kStepExperience, 'Please add a name for project ${i + 1}, or remove it.'));
    }
  }
  void checkDateRange(String listKey, int i, String start, String end, bool current) {
    final startKey = monthKey(start);
    final endKey = monthKey(end);
    if (startKey != null && endKey != null && !current && _compareMonth(endKey, startKey) < 0) {
      errors.add(err('$listKey.$i.end', kStepExperience, 'End date cannot be before the start date.'));
    }
    if (startKey != null && _compareMonth(startKey, _nowMonth()) > 0) {
      errors.add(err('$listKey.$i.start', kStepExperience, 'Start date cannot be in the future.'));
    }
  }

  for (final (i, e) in draft.employment.indexed) {
    checkDateRange('employment', i, e.start, e.end, e.current);
  }
  for (final (i, e) in draft.internships.indexed) {
    checkDateRange('internships', i, e.start, e.end, e.current);
  }
  for (final (i, e) in draft.projects.indexed) {
    checkDateRange('projects', i, e.start, e.end, false);
  }

  final jobs = validJobs(draft.employment);
  final projects = validProjects(draft.projects);
  final bool hasExperience;
  if (draft.level == 'fresher') {
    hasExperience =
        jobs.isNotEmpty ||
        projects.isNotEmpty ||
        validJobs(draft.internships).isNotEmpty ||
        validTraining(draft.training).isNotEmpty;
  } else {
    hasExperience = jobs.isNotEmpty || projects.isNotEmpty;
  }
  if (!hasExperience) {
    errors.add(err('employment', kStepExperience, 'Please provide your employment details or relevant projects.'));
  }

  for (final (i, e) in draft.education.indexed) {
    if (_educationTouched(e) && e.degree.isEmpty) {
      errors.add(
        err(
          'education.$i.degree',
          kStepEducation,
          'Please enter the degree or qualification for education entry ${i + 1}, or remove it.',
        ),
      );
    }
  }
  if (validEducation(draft.education).isEmpty) {
    errors.add(err('education', kStepEducation, 'Please add your education details.'));
  }
  for (final (i, e) in draft.certifications.indexed) {
    if (_certTouched(e) && e.name.isEmpty) {
      errors.add(
        err(
          'certifications.$i.name',
          kStepEducation,
          'Please add the certification name for entry ${i + 1}, or remove it.',
        ),
      );
    }
  }
  for (final (i, e) in draft.training.indexed) {
    if (_trainingTouched(e) && e.name.isEmpty) {
      errors.add(
        err('training.$i.name', kStepEducation, 'Please add the training name for entry ${i + 1}, or remove it.'),
      );
    }
  }

  // Field-specific lengths for everything entered (empty optional fields
  // are skipped).
  final topValues = {
    'target_title': draft.targetTitle,
    'domain': draft.domain,
    'summary': draft.summary,
    'achievements': draft.achievements,
    'languages': draft.languages,
    'additional': draft.additional,
    'place': draft.place,
  };
  kTopRules.forEach((key, rule) {
    final message = lengthError(topValues[key]!, rule);
    if (message.isNotEmpty) {
      final step = (key == 'target_title' || key == 'domain') ? kStepSkills : kStepSummary;
      errors.add(err(key, step, message));
    }
  });

  void checkEntryLengths<T>(String listKey, List<T> entries, Map<String, LengthRule> rules, int step,
      String Function(T, String) fieldValue) {
    for (final (i, e) in entries.indexed) {
      rules.forEach((field, rule) {
        final message = lengthError(fieldValue(e, field), rule);
        if (message.isNotEmpty) errors.add(err('$listKey.$i.$field', step, message));
      });
      final bulletsField = rules.containsKey('bullets') ? fieldValue(e, 'bullets') : null;
      if (bulletsField != null && _lines(bulletsField, 1000).length > kMaxBullets) {
        errors.add(err('$listKey.$i.bullets', step, 'Please keep to $kMaxBullets points or fewer.'));
      }
    }
  }

  checkEntryLengths(
    'employment',
    draft.employment,
    kEntryRules['employment']!,
    kStepExperience,
    (e, f) => switch (f) { 'title' => e.title, 'company' => e.company, 'location' => e.location, 'bullets' => e.bullets, _ => '' },
  );
  checkEntryLengths(
    'internships',
    draft.internships,
    kEntryRules['internships']!,
    kStepExperience,
    (e, f) => switch (f) { 'title' => e.title, 'company' => e.company, 'location' => e.location, 'bullets' => e.bullets, _ => '' },
  );
  checkEntryLengths(
    'projects',
    draft.projects,
    kEntryRules['projects']!,
    kStepExperience,
    (e, f) => switch (f) { 'name' => e.name, 'context' => e.context, 'tools' => e.tools, 'bullets' => e.bullets, _ => '' },
  );
  checkEntryLengths(
    'education',
    draft.education,
    kEntryRules['education']!,
    kStepEducation,
    (e, f) => switch (f) {
      'degree' => e.degree,
      'institution' => e.institution,
      'location' => e.location,
      'year' => e.year,
      'score' => e.score,
      _ => '',
    },
  );
  checkEntryLengths(
    'certifications',
    draft.certifications,
    kEntryRules['certifications']!,
    kStepEducation,
    (e, f) => switch (f) { 'name' => e.name, 'issuer' => e.issuer, 'year' => e.year, _ => '' },
  );
  checkEntryLengths(
    'training',
    draft.training,
    kEntryRules['training']!,
    kStepEducation,
    (e, f) => switch (f) { 'name' => e.name, 'provider' => e.provider, 'year' => e.year, _ => '' },
  );

  final allSkills = [for (final group in draft.skills.groups.values) ...group, ...draft.skills.other];
  final badSkill = allSkills.cast<String?>().firstWhere(
        (s) => s != null && (s.length < kSkillMin || s.length > kSkillMax),
        orElse: () => null,
      );
  if (badSkill != null) {
    errors.add(
      err('skills', kStepSkills, 'Each skill must be $kSkillMin–$kSkillMax characters — fix “$badSkill”.'),
    );
  }

  // Template text must be replaced with the candidate's own facts before
  // it is printed.
  if (hasPlaceholder(draft.summary)) {
    errors.add(
      err(
        'summary',
        kStepSummary,
        'Please replace the [placeholder] text in your professional summary with your own details.',
      ),
    );
  }
  if (hasPlaceholder(draft.achievements)) {
    errors.add(
      err(
        'achievements',
        kStepSummary,
        'Please replace the [placeholder] text in your achievements with your own details.',
      ),
    );
  }
  for (final (i, e) in draft.employment.indexed) {
    if (hasPlaceholder(e.bullets)) {
      errors.add(
        err(
          'employment.$i.bullets',
          kStepExperience,
          'Please replace the [placeholder] text in your responsibilities with your own details.',
        ),
      );
    }
  }
  for (final (i, e) in draft.internships.indexed) {
    if (hasPlaceholder(e.bullets)) {
      errors.add(
        err(
          'internships.$i.bullets',
          kStepExperience,
          'Please replace the [placeholder] text in your responsibilities with your own details.',
        ),
      );
    }
  }
  for (final (i, e) in draft.projects.indexed) {
    if (hasPlaceholder(e.bullets)) {
      errors.add(
        err(
          'projects.$i.bullets',
          kStepExperience,
          'Please replace the [placeholder] text in your responsibilities with your own details.',
        ),
      );
    }
  }

  return errors;
}

/// Text area → list of non-empty lines, bullet markers stripped,
/// de-duplicated (case-insensitively). Matches `_lines()`.
List<String> _lines(String value, int limit) {
  final raw = value.split('\n');
  final out = <String>[];
  final seen = <String>{};
  final bulletRe = RegExp(r'^\s*(?:[-*•·▪◦‣]|\d+[.)])\s+');
  for (var line in raw) {
    line = line.trim();
    line = line.replaceFirst(bulletRe, '').trim();
    final key = line.toLowerCase();
    if (line.isNotEmpty && !seen.contains(key)) {
      seen.add(key);
      out.add(line);
    }
    if (out.length >= limit) break;
  }
  return out;
}

int _compareMonth((int, int) a, (int, int) b) {
  if (a.$1 != b.$1) return a.$1 - b.$1;
  return a.$2 - b.$2;
}

(int, int) _nowMonth() {
  final now = DateTime.now();
  return (now.year, now.month);
}
