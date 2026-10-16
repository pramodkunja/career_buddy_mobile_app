/// The Manual Resume Builder's form state — verified field-for-field against
/// `career_app/resume_document.py`'s `normalize_state()` (Phase 24 audit),
/// never invented. Every field defaults to the same concrete, non-null
/// value the Python side always produces (empty string/list/false — never
/// an absent key), so `fromJson`/`toJson` never need to special-case a
/// missing field as distinct from an empty one, matching the server's own
/// normalization philosophy exactly.
///
/// This is a **local, client-only** model — Phase 24 confirmed the real
/// `manual_resume_*` endpoints never persist anything server-side, so
/// there is no server "draft" shape this mirrors beyond the one-shot
/// request body `preview_api`/`pdf_download`/`preview_pages_api` expect.
/// [currentStep] is the one field with no server equivalent at all — it
/// exists purely so a restored draft can reopen on the step the candidate
/// was last editing (`STEP_PERSONAL`..`STEP_SUMMARY`, 1-5, same numbering
/// `career_app/resume_document.py:60` uses).
library;

const int kManualResumeDraftSchemaVersion = 1;
const int kManualResumeFirstStep = 1;
const int kManualResumeLastStep = 5;

int _asInt(Object? value, int fallback) => value is int ? value : (value is num ? value.toInt() : fallback);
String _asString(Object? value) => value is String ? value : '';
bool _asBool(Object? value) => value is bool && value;
List<String> _asStringList(Object? value) => value is List ? value.whereType<String>().toList() : const [];
Map<String, dynamic> _asMap(Object? value) => value is Map<String, dynamic> ? value : const {};

int _clampStep(int step) => step.clamp(kManualResumeFirstStep, kManualResumeLastStep);

/// `personal.*` (`resume_document.py:149-158`).
class ManualResumePersonalInfo {
  const ManualResumePersonalInfo({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.linkedin = '',
    this.website = '',
    this.dob = '',
    this.passport = '',
  });

  final String name;
  final String email;
  final String phone;
  final String location;
  final String linkedin;
  final String website;
  final String dob;
  final String passport;

  factory ManualResumePersonalInfo.fromJson(Map<String, dynamic> json) => ManualResumePersonalInfo(
    name: _asString(json['name']),
    email: _asString(json['email']),
    phone: _asString(json['phone']),
    location: _asString(json['location']),
    linkedin: _asString(json['linkedin']),
    website: _asString(json['website']),
    dob: _asString(json['dob']),
    passport: _asString(json['passport']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'location': location,
    'linkedin': linkedin,
    'website': website,
    'dob': dob,
    'passport': passport,
  };

  ManualResumePersonalInfo copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    String? linkedin,
    String? website,
    String? dob,
    String? passport,
  }) => ManualResumePersonalInfo(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    location: location ?? this.location,
    linkedin: linkedin ?? this.linkedin,
    website: website ?? this.website,
    dob: dob ?? this.dob,
    passport: passport ?? this.passport,
  );
}

/// `skills.*` (`resume_document.py:162-167`).
class ManualResumeSkills {
  const ManualResumeSkills({
    this.groups = const {},
    this.suggested = const [],
    this.soft = const [],
    this.other = const [],
  });

  /// Role-specific skill categories, keyed by the role's own field key
  /// (`role.fields[].key`) — never invented category names.
  final Map<String, List<String>> groups;
  final List<String> suggested;
  final List<String> soft;
  final List<String> other;

  factory ManualResumeSkills.fromJson(Map<String, dynamic> json) {
    final rawGroups = _asMap(json['groups']);
    return ManualResumeSkills(
      groups: {for (final entry in rawGroups.entries) entry.key: _asStringList(entry.value)},
      suggested: _asStringList(json['suggested']),
      soft: _asStringList(json['soft']),
      other: _asStringList(json['other']),
    );
  }

  Map<String, dynamic> toJson() => {
    'groups': groups,
    'suggested': suggested,
    'soft': soft,
    'other': other,
  };

  ManualResumeSkills copyWith({
    Map<String, List<String>>? groups,
    List<String>? suggested,
    List<String>? soft,
    List<String>? other,
  }) => ManualResumeSkills(
    groups: groups ?? this.groups,
    suggested: suggested ?? this.suggested,
    soft: soft ?? this.soft,
    other: other ?? this.other,
  );
}

/// One `employment[]`/`internships[]` entry — both lists share this exact
/// shape server-side (`JOB_FIELDS`, `resume_document.py:130`, plus the
/// `bullets`/`current` fields `_entries()` adds identically to both).
class ManualResumeJobEntry {
  const ManualResumeJobEntry({
    this.title = '',
    this.company = '',
    this.location = '',
    this.start = '',
    this.end = '',
    this.current = false,
    this.bullets = '',
  });

  final String title;
  final String company;
  final String location;
  final String start;
  final String end;
  final bool current;

  /// Raw multi-line text as typed — the server's own `_lines()` splits
  /// this into bullet points; stored here verbatim, not pre-split, since
  /// splitting is a display/assembly concern, not part of the form state.
  final String bullets;

  factory ManualResumeJobEntry.fromJson(Map<String, dynamic> json) => ManualResumeJobEntry(
    title: _asString(json['title']),
    company: _asString(json['company']),
    location: _asString(json['location']),
    start: _asString(json['start']),
    end: _asString(json['end']),
    current: _asBool(json['current']),
    bullets: _asString(json['bullets']),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'company': company,
    'location': location,
    'start': start,
    'end': end,
    'current': current,
    'bullets': bullets,
  };

  ManualResumeJobEntry copyWith({
    String? title,
    String? company,
    String? location,
    String? start,
    String? end,
    bool? current,
    String? bullets,
  }) => ManualResumeJobEntry(
    title: title ?? this.title,
    company: company ?? this.company,
    location: location ?? this.location,
    start: start ?? this.start,
    end: end ?? this.end,
    current: current ?? this.current,
    bullets: bullets ?? this.bullets,
  );
}

/// One `projects[]` entry (`PROJECT_FIELDS`, `resume_document.py:131`).
class ManualResumeProjectEntry {
  const ManualResumeProjectEntry({
    this.name = '',
    this.context = '',
    this.tools = '',
    this.start = '',
    this.end = '',
    this.bullets = '',
  });

  final String name;
  final String context;
  final String tools;
  final String start;
  final String end;
  final String bullets;

  factory ManualResumeProjectEntry.fromJson(Map<String, dynamic> json) => ManualResumeProjectEntry(
    name: _asString(json['name']),
    context: _asString(json['context']),
    tools: _asString(json['tools']),
    start: _asString(json['start']),
    end: _asString(json['end']),
    bullets: _asString(json['bullets']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'context': context,
    'tools': tools,
    'start': start,
    'end': end,
    'bullets': bullets,
  };

  ManualResumeProjectEntry copyWith({
    String? name,
    String? context,
    String? tools,
    String? start,
    String? end,
    String? bullets,
  }) => ManualResumeProjectEntry(
    name: name ?? this.name,
    context: context ?? this.context,
    tools: tools ?? this.tools,
    start: start ?? this.start,
    end: end ?? this.end,
    bullets: bullets ?? this.bullets,
  );
}

/// One `education[]` entry (`EDU_FIELDS`, `resume_document.py:132`).
class ManualResumeEducationEntry {
  const ManualResumeEducationEntry({
    this.degree = '',
    this.institution = '',
    this.location = '',
    this.year = '',
    this.score = '',
  });

  final String degree;
  final String institution;
  final String location;
  final String year;
  final String score;

  factory ManualResumeEducationEntry.fromJson(Map<String, dynamic> json) => ManualResumeEducationEntry(
    degree: _asString(json['degree']),
    institution: _asString(json['institution']),
    location: _asString(json['location']),
    year: _asString(json['year']),
    score: _asString(json['score']),
  );

  Map<String, dynamic> toJson() => {
    'degree': degree,
    'institution': institution,
    'location': location,
    'year': year,
    'score': score,
  };

  ManualResumeEducationEntry copyWith({
    String? degree,
    String? institution,
    String? location,
    String? year,
    String? score,
  }) => ManualResumeEducationEntry(
    degree: degree ?? this.degree,
    institution: institution ?? this.institution,
    location: location ?? this.location,
    year: year ?? this.year,
    score: score ?? this.score,
  );
}

/// One `certifications[]` entry (`CERT_FIELDS`, `resume_document.py:133`)
/// — `issuer`, not `provider` (see [ManualResumeTrainingEntry] for the
/// distinct field name `training[]` actually uses).
class ManualResumeCertificationEntry {
  const ManualResumeCertificationEntry({this.name = '', this.issuer = '', this.year = ''});

  final String name;
  final String issuer;
  final String year;

  factory ManualResumeCertificationEntry.fromJson(Map<String, dynamic> json) => ManualResumeCertificationEntry(
    name: _asString(json['name']),
    issuer: _asString(json['issuer']),
    year: _asString(json['year']),
  );

  Map<String, dynamic> toJson() => {'name': name, 'issuer': issuer, 'year': year};

  ManualResumeCertificationEntry copyWith({String? name, String? issuer, String? year}) =>
      ManualResumeCertificationEntry(name: name ?? this.name, issuer: issuer ?? this.issuer, year: year ?? this.year);
}

/// One `training[]` entry (`TRAINING_FIELDS`, `resume_document.py:134`) —
/// `provider`, not `issuer`.
class ManualResumeTrainingEntry {
  const ManualResumeTrainingEntry({this.name = '', this.provider = '', this.year = ''});

  final String name;
  final String provider;
  final String year;

  factory ManualResumeTrainingEntry.fromJson(Map<String, dynamic> json) => ManualResumeTrainingEntry(
    name: _asString(json['name']),
    provider: _asString(json['provider']),
    year: _asString(json['year']),
  );

  Map<String, dynamic> toJson() => {'name': name, 'provider': provider, 'year': year};

  ManualResumeTrainingEntry copyWith({String? name, String? provider, String? year}) =>
      ManualResumeTrainingEntry(name: name ?? this.name, provider: provider ?? this.provider, year: year ?? this.year);
}

/// The full Manual Resume Builder draft — one per authenticated account,
/// matching `normalize_state()`'s top-level shape
/// (`resume_document.py:137-181`) field-for-field, plus [currentStep]
/// (local-only, see this file's own top-level doc comment).
class ManualResumeDraft {
  const ManualResumeDraft({
    this.role = '',
    this.roleDef = const {},
    this.level = '',
    this.personal = const ManualResumePersonalInfo(),
    this.targetTitle = '',
    this.domain = '',
    this.years = '',
    this.skills = const ManualResumeSkills(),
    this.employment = const [],
    this.internships = const [],
    this.projects = const [],
    this.education = const [],
    this.certifications = const [],
    this.training = const [],
    this.achievements = '',
    this.languages = '',
    this.additional = '',
    this.summary = '',
    this.declaration = false,
    this.place = '',
    this.declDate = '',
    this.currentStep = kManualResumeFirstStep,
  });

  /// A brand-new, empty draft — the starting point both for a fresh
  /// "Build Resume" and for `fromJson`'s safe fallback.
  factory ManualResumeDraft.blank() => const ManualResumeDraft();

  final String role;

  /// Only populated for a role with no predefined template (`custom_role`,
  /// `career_app/resume_roles.py`) — always empty for every role Phase 23's
  /// catalog currently returns, kept here so the field is never silently
  /// discarded once a future phase needs it.
  final Map<String, dynamic> roleDef;

  final String level;
  final ManualResumePersonalInfo personal;
  final String targetTitle;
  final String domain;
  final String years;
  final ManualResumeSkills skills;
  final List<ManualResumeJobEntry> employment;
  final List<ManualResumeJobEntry> internships;
  final List<ManualResumeProjectEntry> projects;
  final List<ManualResumeEducationEntry> education;
  final List<ManualResumeCertificationEntry> certifications;
  final List<ManualResumeTrainingEntry> training;
  final String achievements;
  final String languages;
  final String additional;
  final String summary;
  final bool declaration;
  final String place;
  final String declDate;

  /// 1-5, matching `STEP_PERSONAL`..`STEP_SUMMARY`
  /// (`resume_document.py:60`). Always clamped into range — never stored
  /// or read out-of-bounds.
  final int currentStep;

  factory ManualResumeDraft.fromJson(Map<String, dynamic> json) {
    List<T> entries<T>(Object? value, T Function(Map<String, dynamic>) each) {
      if (value is! List) return const [];
      return value.whereType<Map<String, dynamic>>().map(each).toList();
    }

    return ManualResumeDraft(
      role: _asString(json['role']),
      roleDef: _asMap(json['roleDef']),
      level: _asString(json['level']),
      personal: ManualResumePersonalInfo.fromJson(_asMap(json['personal'])),
      targetTitle: _asString(json['targetTitle']),
      domain: _asString(json['domain']),
      years: _asString(json['years']),
      skills: ManualResumeSkills.fromJson(_asMap(json['skills'])),
      employment: entries(json['employment'], ManualResumeJobEntry.fromJson),
      internships: entries(json['internships'], ManualResumeJobEntry.fromJson),
      projects: entries(json['projects'], ManualResumeProjectEntry.fromJson),
      education: entries(json['education'], ManualResumeEducationEntry.fromJson),
      certifications: entries(json['certifications'], ManualResumeCertificationEntry.fromJson),
      training: entries(json['training'], ManualResumeTrainingEntry.fromJson),
      achievements: _asString(json['achievements']),
      languages: _asString(json['languages']),
      additional: _asString(json['additional']),
      summary: _asString(json['summary']),
      declaration: _asBool(json['declaration']),
      place: _asString(json['place']),
      declDate: _asString(json['declDate']),
      currentStep: _clampStep(_asInt(json['currentStep'], kManualResumeFirstStep)),
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'roleDef': roleDef,
    'level': level,
    'personal': personal.toJson(),
    'targetTitle': targetTitle,
    'domain': domain,
    'years': years,
    'skills': skills.toJson(),
    'employment': employment.map((e) => e.toJson()).toList(),
    'internships': internships.map((e) => e.toJson()).toList(),
    'projects': projects.map((e) => e.toJson()).toList(),
    'education': education.map((e) => e.toJson()).toList(),
    'certifications': certifications.map((e) => e.toJson()).toList(),
    'training': training.map((e) => e.toJson()).toList(),
    'achievements': achievements,
    'languages': languages,
    'additional': additional,
    'summary': summary,
    'declaration': declaration,
    'place': place,
    'declDate': declDate,
    'currentStep': currentStep,
  };

  ManualResumeDraft copyWith({
    String? role,
    Map<String, dynamic>? roleDef,
    String? level,
    ManualResumePersonalInfo? personal,
    String? targetTitle,
    String? domain,
    String? years,
    ManualResumeSkills? skills,
    List<ManualResumeJobEntry>? employment,
    List<ManualResumeJobEntry>? internships,
    List<ManualResumeProjectEntry>? projects,
    List<ManualResumeEducationEntry>? education,
    List<ManualResumeCertificationEntry>? certifications,
    List<ManualResumeTrainingEntry>? training,
    String? achievements,
    String? languages,
    String? additional,
    String? summary,
    bool? declaration,
    String? place,
    String? declDate,
    int? currentStep,
  }) => ManualResumeDraft(
    role: role ?? this.role,
    roleDef: roleDef ?? this.roleDef,
    level: level ?? this.level,
    personal: personal ?? this.personal,
    targetTitle: targetTitle ?? this.targetTitle,
    domain: domain ?? this.domain,
    years: years ?? this.years,
    skills: skills ?? this.skills,
    employment: employment ?? this.employment,
    internships: internships ?? this.internships,
    projects: projects ?? this.projects,
    education: education ?? this.education,
    certifications: certifications ?? this.certifications,
    training: training ?? this.training,
    achievements: achievements ?? this.achievements,
    languages: languages ?? this.languages,
    additional: additional ?? this.additional,
    summary: summary ?? this.summary,
    declaration: declaration ?? this.declaration,
    place: place ?? this.place,
    declDate: declDate ?? this.declDate,
    currentStep: currentStep == null ? this.currentStep : _clampStep(currentStep),
  );
}
