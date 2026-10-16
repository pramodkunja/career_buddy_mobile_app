/// The Create Resume builder's own form state — a faithful model of
/// `career_app.create_resume.normalize()`'s return shape (verified directly
/// against the source). Phase 39 implements a coherent subset of the real
/// web's 10 content sections: personal details, summary, skills, experience
/// and education. The remaining sections the real backend also accepts —
/// projects, certifications, achievements, internships/volunteering,
/// languages, additional information — are not yet editable here; omitting
/// them from a submitted payload is not an error (the server's own
/// `build_document()` simply omits any section with no entries), so a
/// resume built with only these fields is already a valid, correctly
/// rendering, honestly partial document, not a broken one. See
/// `docs/PHASE_39_CREATE_RESUME_WORKFLOW_REPORT.md` for the full scope
/// decision.
library;

const List<String> kCreateResumeTemplates = ['classic', 'modern', 'minimal'];

class CreateResumePersonalInfo {
  const CreateResumePersonalInfo({
    this.name = '',
    this.title = '',
    this.email = '',
    this.phone = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.linkedin = '',
    this.github = '',
    this.portfolio = '',
    this.website = '',
    this.address = '',
  });

  final String name;
  final String title;
  final String email;
  final String phone;
  final String city;
  final String state;
  final String country;
  final String linkedin;
  final String github;
  final String portfolio;
  final String website;
  final String address;

  CreateResumePersonalInfo copyWith({
    String? name,
    String? title,
    String? email,
    String? phone,
    String? city,
    String? state,
    String? country,
    String? linkedin,
    String? github,
    String? portfolio,
    String? website,
    String? address,
  }) => CreateResumePersonalInfo(
    name: name ?? this.name,
    title: title ?? this.title,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    linkedin: linkedin ?? this.linkedin,
    github: github ?? this.github,
    portfolio: portfolio ?? this.portfolio,
    website: website ?? this.website,
    address: address ?? this.address,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': title,
    'email': email,
    'phone': phone,
    'city': city,
    'state': state,
    'country': country,
    'linkedin': linkedin,
    'github': github,
    'portfolio': portfolio,
    'website': website,
    // 'profile_url' is a field the server accepts but the real web's own
    // builder never populates (no corresponding form input found) — left
    // unset here too, never fabricated.
    'address': address,
  };

  factory CreateResumePersonalInfo.fromJson(Map<String, dynamic> json) =>
      CreateResumePersonalInfo(
        name: json['name'] as String? ?? '',
        title: json['title'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        country: json['country'] as String? ?? '',
        linkedin: json['linkedin'] as String? ?? '',
        github: json['github'] as String? ?? '',
        portfolio: json['portfolio'] as String? ?? '',
        website: json['website'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );
}

/// One `experience[]` entry (`ENTRY_FIELDS['experience']`, confirmed
/// directly). Dates are kept as separate month/year strings (`'1'`..`'12'`,
/// `'YYYY'`) exactly as the server's own `_entry()` normalizes them, rather
/// than a combined value, so no reshaping is needed at the request boundary.
class CreateResumeExperienceEntry {
  const CreateResumeExperienceEntry({
    this.company = '',
    this.title = '',
    this.type = '',
    this.location = '',
    this.department = '',
    this.startMonth = '',
    this.startYear = '',
    this.endMonth = '',
    this.endYear = '',
    this.current = false,
    this.responsibilities = '',
    this.projects = '',
    this.achievements = '',
    this.tools = '',
  });

  final String company;
  final String title;
  final String type;
  final String location;
  final String department;
  final String startMonth;
  final String startYear;
  final String endMonth;
  final String endYear;
  final bool current;
  final String responsibilities;
  final String projects;
  final String achievements;
  final String tools;

  bool get isBlank =>
      company.isEmpty &&
      title.isEmpty &&
      location.isEmpty &&
      department.isEmpty &&
      startYear.isEmpty &&
      responsibilities.isEmpty &&
      projects.isEmpty &&
      achievements.isEmpty &&
      tools.isEmpty;

  CreateResumeExperienceEntry copyWith({
    String? company,
    String? title,
    String? type,
    String? location,
    String? department,
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    bool? current,
    String? responsibilities,
    String? projects,
    String? achievements,
    String? tools,
  }) => CreateResumeExperienceEntry(
    company: company ?? this.company,
    title: title ?? this.title,
    type: type ?? this.type,
    location: location ?? this.location,
    department: department ?? this.department,
    startMonth: startMonth ?? this.startMonth,
    startYear: startYear ?? this.startYear,
    endMonth: endMonth ?? this.endMonth,
    endYear: endYear ?? this.endYear,
    current: current ?? this.current,
    responsibilities: responsibilities ?? this.responsibilities,
    projects: projects ?? this.projects,
    achievements: achievements ?? this.achievements,
    tools: tools ?? this.tools,
  );

  Map<String, dynamic> toJson() => {
    'company': company,
    'title': title,
    'type': type,
    'location': location,
    'department': department,
    'start_month': startMonth,
    'start_year': startYear,
    'end_month': endMonth,
    'end_year': endYear,
    'current': current,
    'responsibilities': responsibilities,
    'projects': projects,
    'achievements': achievements,
    'tools': tools,
  };

  factory CreateResumeExperienceEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeExperienceEntry(
        company: json['company'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? '',
        location: json['location'] as String? ?? '',
        department: json['department'] as String? ?? '',
        startMonth: json['start_month'] as String? ?? '',
        startYear: json['start_year'] as String? ?? '',
        endMonth: json['end_month'] as String? ?? '',
        endYear: json['end_year'] as String? ?? '',
        current: json['current'] as bool? ?? false,
        responsibilities: json['responsibilities'] as String? ?? '',
        projects: json['projects'] as String? ?? '',
        achievements: json['achievements'] as String? ?? '',
        tools: json['tools'] as String? ?? '',
      );
}

/// One `education[]` entry (`ENTRY_FIELDS['education']`, confirmed
/// directly) — this kind has no `end_month`/`start_month` (only years),
/// matching the server's own field list exactly.
class CreateResumeEducationEntry {
  const CreateResumeEducationEntry({
    this.qualification = '',
    this.degree = '',
    this.specialization = '',
    this.institution = '',
    this.location = '',
    this.startYear = '',
    this.endYear = '',
    this.current = false,
    this.grade = '',
    this.coursework = '',
    this.achievements = '',
  });

  final String qualification;
  final String degree;
  final String specialization;
  final String institution;
  final String location;
  final String startYear;
  final String endYear;
  final bool current;
  final String grade;
  final String coursework;
  final String achievements;

  bool get isBlank =>
      qualification.isEmpty &&
      degree.isEmpty &&
      specialization.isEmpty &&
      institution.isEmpty &&
      location.isEmpty &&
      startYear.isEmpty &&
      endYear.isEmpty &&
      grade.isEmpty &&
      coursework.isEmpty &&
      achievements.isEmpty;

  CreateResumeEducationEntry copyWith({
    String? qualification,
    String? degree,
    String? specialization,
    String? institution,
    String? location,
    String? startYear,
    String? endYear,
    bool? current,
    String? grade,
    String? coursework,
    String? achievements,
  }) => CreateResumeEducationEntry(
    qualification: qualification ?? this.qualification,
    degree: degree ?? this.degree,
    specialization: specialization ?? this.specialization,
    institution: institution ?? this.institution,
    location: location ?? this.location,
    startYear: startYear ?? this.startYear,
    endYear: endYear ?? this.endYear,
    current: current ?? this.current,
    grade: grade ?? this.grade,
    coursework: coursework ?? this.coursework,
    achievements: achievements ?? this.achievements,
  );

  Map<String, dynamic> toJson() => {
    'qualification': qualification,
    'degree': degree,
    'specialization': specialization,
    'institution': institution,
    'location': location,
    'start_year': startYear,
    'end_year': endYear,
    'current': current,
    'grade': grade,
    'coursework': coursework,
    'achievements': achievements,
  };

  factory CreateResumeEducationEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeEducationEntry(
        qualification: json['qualification'] as String? ?? '',
        degree: json['degree'] as String? ?? '',
        specialization: json['specialization'] as String? ?? '',
        institution: json['institution'] as String? ?? '',
        location: json['location'] as String? ?? '',
        startYear: json['start_year'] as String? ?? '',
        endYear: json['end_year'] as String? ?? '',
        current: json['current'] as bool? ?? false,
        grade: json['grade'] as String? ?? '',
        coursework: json['coursework'] as String? ?? '',
        achievements: json['achievements'] as String? ?? '',
      );
}

/// The 4 `SKILL_CATEGORIES` keys (`technical`, `functional`, `soft`,
/// `tools`), confirmed directly.
class CreateResumeSkills {
  const CreateResumeSkills({
    this.technical = const [],
    this.functional = const [],
    this.soft = const [],
    this.tools = const [],
  });

  final List<String> technical;
  final List<String> functional;
  final List<String> soft;
  final List<String> tools;

  CreateResumeSkills copyWith({
    List<String>? technical,
    List<String>? functional,
    List<String>? soft,
    List<String>? tools,
  }) => CreateResumeSkills(
    technical: technical ?? this.technical,
    functional: functional ?? this.functional,
    soft: soft ?? this.soft,
    tools: tools ?? this.tools,
  );

  Map<String, dynamic> toJson() => {
    'technical': technical,
    'functional': functional,
    'soft': soft,
    'tools': tools,
  };

  factory CreateResumeSkills.fromJson(Map<String, dynamic> json) =>
      CreateResumeSkills(
        technical: (json['technical'] as List?)?.cast<String>() ?? const [],
        functional: (json['functional'] as List?)?.cast<String>() ?? const [],
        soft: (json['soft'] as List?)?.cast<String>() ?? const [],
        tools: (json['tools'] as List?)?.cast<String>() ?? const [],
      );
}

/// The full builder form state, plus 2 fields the server also expects on
/// every submission (`template`, `order`) and 1 purely local field
/// (`draftId`) this app uses to know whether "Save" creates or updates.
class CreateResumeFormState {
  const CreateResumeFormState({
    this.draftId,
    this.template = 'classic',
    this.personal = const CreateResumePersonalInfo(),
    this.summary = '',
    this.skills = const CreateResumeSkills(),
    this.experience = const [],
    this.education = const [],
  });

  /// `null` for a resume never saved yet; set once the first successful
  /// `draft_save` response names an id, after which every further Save
  /// updates that same draft instead of creating another one.
  final int? draftId;

  final String template;
  final CreateResumePersonalInfo personal;
  final String summary;
  final CreateResumeSkills skills;
  final List<CreateResumeExperienceEntry> experience;
  final List<CreateResumeEducationEntry> education;

  CreateResumeFormState copyWith({
    int? draftId,
    bool clearDraftId = false,
    String? template,
    CreateResumePersonalInfo? personal,
    String? summary,
    CreateResumeSkills? skills,
    List<CreateResumeExperienceEntry>? experience,
    List<CreateResumeEducationEntry>? education,
  }) => CreateResumeFormState(
    draftId: clearDraftId ? null : (draftId ?? this.draftId),
    template: template ?? this.template,
    personal: personal ?? this.personal,
    summary: summary ?? this.summary,
    skills: skills ?? this.skills,
    experience: experience ?? this.experience,
    education: education ?? this.education,
  );

  /// The request body every `preview`/`pages`/`pdf` call sends, and the
  /// `data` field of a `draft_save` call — matches `normalize()`'s own
  /// `raw.get(...)` keys exactly. Sections this phase doesn't yet edit
  /// (`projects`, `certifications`, `achievements`, `internships`,
  /// `volunteering`, `languages`, `additional`) are sent as empty, which
  /// `normalize()`/`build_document()` already treat as "not provided," not
  /// an error.
  Map<String, dynamic> toRequestJson() => {
    'template': template,
    'personal': personal.toJson(),
    'summary': summary,
    'skills': skills.toJson(),
    'experience': [for (final e in experience) e.toJson()],
    'education': [for (final e in education) e.toJson()],
    'projects': const [],
    'certifications': const [],
    'achievements': const [],
    'internships': const [],
    'volunteering': const [],
    'languages': const [],
    'additional': const {},
    'order': const {},
  };

  factory CreateResumeFormState.fromDraftData(
    Map<String, dynamic> data, {
    int? draftId,
  }) => CreateResumeFormState(
    draftId: draftId,
    template: kCreateResumeTemplates.contains(data['template'])
        ? data['template'] as String
        : 'classic',
    personal: CreateResumePersonalInfo.fromJson(
      (data['personal'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    summary: data['summary'] as String? ?? '',
    skills: CreateResumeSkills.fromJson(
      (data['skills'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    experience: [
      for (final e in (data['experience'] as List? ?? const []))
        CreateResumeExperienceEntry.fromJson(
          (e as Map).cast<String, dynamic>(),
        ),
    ],
    education: [
      for (final e in (data['education'] as List? ?? const []))
        CreateResumeEducationEntry.fromJson((e as Map).cast<String, dynamic>()),
    ],
  );
}
