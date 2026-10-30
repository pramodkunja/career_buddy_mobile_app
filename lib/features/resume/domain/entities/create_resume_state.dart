/// The Create Resume builder's own form state — a faithful model of
/// `career_app.create_resume.normalize()`'s return shape (verified directly
/// against the source). Phase 39 implemented the first 5 of the real web's
/// 10 section tabs (personal details, summary, skills, experience,
/// education). Phase 70 adds the remaining 5 tabs — Projects,
/// Certifications & Training, Achievements & Awards, Internships &
/// Volunteering (one tab, two repeatable lists), and Languages &
/// Additional Information (one tab, a repeatable list plus 6 flat fields)
/// — confirmed directly against `career_app/create_resume.py`'s own
/// `SECTIONS`/`REPEATABLE`/`ENTRY_FIELDS`/`ADDITIONAL_FIELDS` and
/// `static/js/create_resume.js` (the builder's only template — the real
/// page has no static HTML of its own, `create_resume.js` fills an empty
/// `<div>` entirely). See `docs/PHASE_70_RESUME_BUILDER_IMPLEMENTATION_REPORT.md`.
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
    this.profileUrl = '',
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

  /// `personal.profile_url` ("Professional profile URL",
  /// `static/js/create_resume.js:354`). Phase 39's own doc comment claimed
  /// the real builder never populates this field — re-confirmed this phase
  /// (Phase 70) that claim was wrong: the JS does render and accept it,
  /// right after `website`. Added now alongside the other 5 new sections
  /// since it's the same Personal step being revisited.
  final String profileUrl;
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
    String? profileUrl,
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
    profileUrl: profileUrl ?? this.profileUrl,
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
    'profile_url': profileUrl,
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
        profileUrl: json['profile_url'] as String? ?? '',
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

/// One `projects[]` entry (`ENTRY_FIELDS['projects']`,
/// `create_resume.py:74-77,115-116`, confirmed directly). Only `title` is
/// required for completeness.
class CreateResumeProjectEntry {
  const CreateResumeProjectEntry({
    this.title = '',
    this.type = '',
    this.organization = '',
    this.role = '',
    this.technologies = '',
    this.url = '',
    this.startMonth = '',
    this.startYear = '',
    this.endMonth = '',
    this.endYear = '',
    this.current = false,
    this.overview = '',
    this.responsibilities = '',
    this.outcomes = '',
  });

  final String title;
  final String type;
  final String organization;
  final String role;
  final String technologies;
  final String url;
  final String startMonth;
  final String startYear;
  final String endMonth;
  final String endYear;
  final bool current;
  final String overview;
  final String responsibilities;
  final String outcomes;

  bool get isBlank =>
      title.isEmpty &&
      organization.isEmpty &&
      role.isEmpty &&
      technologies.isEmpty &&
      url.isEmpty &&
      startYear.isEmpty &&
      overview.isEmpty &&
      responsibilities.isEmpty &&
      outcomes.isEmpty;

  CreateResumeProjectEntry copyWith({
    String? title,
    String? type,
    String? organization,
    String? role,
    String? technologies,
    String? url,
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    bool? current,
    String? overview,
    String? responsibilities,
    String? outcomes,
  }) => CreateResumeProjectEntry(
    title: title ?? this.title,
    type: type ?? this.type,
    organization: organization ?? this.organization,
    role: role ?? this.role,
    technologies: technologies ?? this.technologies,
    url: url ?? this.url,
    startMonth: startMonth ?? this.startMonth,
    startYear: startYear ?? this.startYear,
    endMonth: endMonth ?? this.endMonth,
    endYear: endYear ?? this.endYear,
    current: current ?? this.current,
    overview: overview ?? this.overview,
    responsibilities: responsibilities ?? this.responsibilities,
    outcomes: outcomes ?? this.outcomes,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'organization': organization,
    'role': role,
    'technologies': technologies,
    'url': url,
    'start_month': startMonth,
    'start_year': startYear,
    'end_month': endMonth,
    'end_year': endYear,
    'current': current,
    'overview': overview,
    'responsibilities': responsibilities,
    'outcomes': outcomes,
  };

  factory CreateResumeProjectEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeProjectEntry(
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? '',
        organization: json['organization'] as String? ?? '',
        role: json['role'] as String? ?? '',
        technologies: json['technologies'] as String? ?? '',
        url: json['url'] as String? ?? '',
        startMonth: json['start_month'] as String? ?? '',
        startYear: json['start_year'] as String? ?? '',
        endMonth: json['end_month'] as String? ?? '',
        endYear: json['end_year'] as String? ?? '',
        current: json['current'] as bool? ?? false,
        overview: json['overview'] as String? ?? '',
        responsibilities: json['responsibilities'] as String? ?? '',
        outcomes: json['outcomes'] as String? ?? '',
      );
}

/// One `certifications[]` entry (`ENTRY_FIELDS['certifications']`,
/// `create_resume.py:78-79,117-118`, confirmed directly). No "current" flag
/// — certifications have no ongoing state. `name`/`issuer` required for
/// completeness.
class CreateResumeCertificationEntry {
  const CreateResumeCertificationEntry({
    this.name = '',
    this.issuer = '',
    this.issueMonth = '',
    this.issueYear = '',
    this.expMonth = '',
    this.expYear = '',
    this.credentialId = '',
    this.url = '',
    this.description = '',
  });

  final String name;
  final String issuer;
  final String issueMonth;
  final String issueYear;
  final String expMonth;
  final String expYear;
  final String credentialId;
  final String url;
  final String description;

  bool get isBlank =>
      name.isEmpty &&
      issuer.isEmpty &&
      issueYear.isEmpty &&
      expYear.isEmpty &&
      credentialId.isEmpty &&
      url.isEmpty &&
      description.isEmpty;

  CreateResumeCertificationEntry copyWith({
    String? name,
    String? issuer,
    String? issueMonth,
    String? issueYear,
    String? expMonth,
    String? expYear,
    String? credentialId,
    String? url,
    String? description,
  }) => CreateResumeCertificationEntry(
    name: name ?? this.name,
    issuer: issuer ?? this.issuer,
    issueMonth: issueMonth ?? this.issueMonth,
    issueYear: issueYear ?? this.issueYear,
    expMonth: expMonth ?? this.expMonth,
    expYear: expYear ?? this.expYear,
    credentialId: credentialId ?? this.credentialId,
    url: url ?? this.url,
    description: description ?? this.description,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'issuer': issuer,
    'issue_month': issueMonth,
    'issue_year': issueYear,
    'exp_month': expMonth,
    'exp_year': expYear,
    'credential_id': credentialId,
    'url': url,
    'description': description,
  };

  factory CreateResumeCertificationEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeCertificationEntry(
        name: json['name'] as String? ?? '',
        issuer: json['issuer'] as String? ?? '',
        issueMonth: json['issue_month'] as String? ?? '',
        issueYear: json['issue_year'] as String? ?? '',
        expMonth: json['exp_month'] as String? ?? '',
        expYear: json['exp_year'] as String? ?? '',
        credentialId: json['credential_id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

/// One `achievements[]` entry (`ENTRY_FIELDS['achievements']`,
/// `create_resume.py:80-81,119`, confirmed directly). `title` is the only
/// field required for completeness.
class CreateResumeAchievementEntry {
  const CreateResumeAchievementEntry({
    this.title = '',
    this.organization = '',
    this.month = '',
    this.year = '',
    this.url = '',
    this.description = '',
  });

  final String title;
  final String organization;
  final String month;
  final String year;
  final String url;
  final String description;

  bool get isBlank =>
      title.isEmpty &&
      organization.isEmpty &&
      year.isEmpty &&
      url.isEmpty &&
      description.isEmpty;

  CreateResumeAchievementEntry copyWith({
    String? title,
    String? organization,
    String? month,
    String? year,
    String? url,
    String? description,
  }) => CreateResumeAchievementEntry(
    title: title ?? this.title,
    organization: organization ?? this.organization,
    month: month ?? this.month,
    year: year ?? this.year,
    url: url ?? this.url,
    description: description ?? this.description,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'organization': organization,
    'month': month,
    'year': year,
    'url': url,
    'description': description,
  };

  factory CreateResumeAchievementEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeAchievementEntry(
        title: json['title'] as String? ?? '',
        organization: json['organization'] as String? ?? '',
        month: json['month'] as String? ?? '',
        year: json['year'] as String? ?? '',
        url: json['url'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

/// One `internships[]` entry (`ENTRY_FIELDS['internships']`,
/// `create_resume.py:82-85,120-121`, confirmed directly).
/// `organization`/`title`/`start_year` required for completeness — the
/// same "end date required unless ongoing" rule as Experience applies
/// here (`END_REQUIRED`), unlike Volunteering below.
class CreateResumeInternshipEntry {
  const CreateResumeInternshipEntry({
    this.organization = '',
    this.title = '',
    this.location = '',
    this.startMonth = '',
    this.startYear = '',
    this.endMonth = '',
    this.endYear = '',
    this.current = false,
    this.responsibilities = '',
    this.projects = '',
    this.achievements = '',
    this.skills = '',
  });

  final String organization;
  final String title;
  final String location;
  final String startMonth;
  final String startYear;
  final String endMonth;
  final String endYear;
  final bool current;
  final String responsibilities;
  final String projects;
  final String achievements;
  final String skills;

  bool get isBlank =>
      organization.isEmpty &&
      title.isEmpty &&
      location.isEmpty &&
      startYear.isEmpty &&
      responsibilities.isEmpty &&
      projects.isEmpty &&
      achievements.isEmpty &&
      skills.isEmpty;

  CreateResumeInternshipEntry copyWith({
    String? organization,
    String? title,
    String? location,
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    bool? current,
    String? responsibilities,
    String? projects,
    String? achievements,
    String? skills,
  }) => CreateResumeInternshipEntry(
    organization: organization ?? this.organization,
    title: title ?? this.title,
    location: location ?? this.location,
    startMonth: startMonth ?? this.startMonth,
    startYear: startYear ?? this.startYear,
    endMonth: endMonth ?? this.endMonth,
    endYear: endYear ?? this.endYear,
    current: current ?? this.current,
    responsibilities: responsibilities ?? this.responsibilities,
    projects: projects ?? this.projects,
    achievements: achievements ?? this.achievements,
    skills: skills ?? this.skills,
  );

  Map<String, dynamic> toJson() => {
    'organization': organization,
    'title': title,
    'location': location,
    'start_month': startMonth,
    'start_year': startYear,
    'end_month': endMonth,
    'end_year': endYear,
    'current': current,
    'responsibilities': responsibilities,
    'projects': projects,
    'achievements': achievements,
    'skills': skills,
  };

  factory CreateResumeInternshipEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeInternshipEntry(
        organization: json['organization'] as String? ?? '',
        title: json['title'] as String? ?? '',
        location: json['location'] as String? ?? '',
        startMonth: json['start_month'] as String? ?? '',
        startYear: json['start_year'] as String? ?? '',
        endMonth: json['end_month'] as String? ?? '',
        endYear: json['end_year'] as String? ?? '',
        current: json['current'] as bool? ?? false,
        responsibilities: json['responsibilities'] as String? ?? '',
        projects: json['projects'] as String? ?? '',
        achievements: json['achievements'] as String? ?? '',
        skills: json['skills'] as String? ?? '',
      );
}

/// One `volunteering[]` entry (`ENTRY_FIELDS['volunteering']`,
/// `create_resume.py:86-88,122-123`, confirmed directly). Shares its tab
/// with [CreateResumeInternshipEntry] (`SECTION_OF['volunteering'] ==
/// 'internships'`) but has its own entry shape — `role`, not `title`, and
/// `contributions` instead of `projects`. Only `organization`/`role` are
/// required for completeness — unlike Internships, there is no "end date
/// required unless ongoing" rule here (confirmed: `volunteering` is not in
/// `END_REQUIRED`).
class CreateResumeVolunteeringEntry {
  const CreateResumeVolunteeringEntry({
    this.organization = '',
    this.role = '',
    this.location = '',
    this.startMonth = '',
    this.startYear = '',
    this.endMonth = '',
    this.endYear = '',
    this.current = false,
    this.responsibilities = '',
    this.contributions = '',
    this.achievements = '',
  });

  final String organization;
  final String role;
  final String location;
  final String startMonth;
  final String startYear;
  final String endMonth;
  final String endYear;
  final bool current;
  final String responsibilities;
  final String contributions;
  final String achievements;

  bool get isBlank =>
      organization.isEmpty &&
      role.isEmpty &&
      location.isEmpty &&
      startYear.isEmpty &&
      responsibilities.isEmpty &&
      contributions.isEmpty &&
      achievements.isEmpty;

  CreateResumeVolunteeringEntry copyWith({
    String? organization,
    String? role,
    String? location,
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    bool? current,
    String? responsibilities,
    String? contributions,
    String? achievements,
  }) => CreateResumeVolunteeringEntry(
    organization: organization ?? this.organization,
    role: role ?? this.role,
    location: location ?? this.location,
    startMonth: startMonth ?? this.startMonth,
    startYear: startYear ?? this.startYear,
    endMonth: endMonth ?? this.endMonth,
    endYear: endYear ?? this.endYear,
    current: current ?? this.current,
    responsibilities: responsibilities ?? this.responsibilities,
    contributions: contributions ?? this.contributions,
    achievements: achievements ?? this.achievements,
  );

  Map<String, dynamic> toJson() => {
    'organization': organization,
    'role': role,
    'location': location,
    'start_month': startMonth,
    'start_year': startYear,
    'end_month': endMonth,
    'end_year': endYear,
    'current': current,
    'responsibilities': responsibilities,
    'contributions': contributions,
    'achievements': achievements,
  };

  factory CreateResumeVolunteeringEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeVolunteeringEntry(
        organization: json['organization'] as String? ?? '',
        role: json['role'] as String? ?? '',
        location: json['location'] as String? ?? '',
        startMonth: json['start_month'] as String? ?? '',
        startYear: json['start_year'] as String? ?? '',
        endMonth: json['end_month'] as String? ?? '',
        endYear: json['end_year'] as String? ?? '',
        current: json['current'] as bool? ?? false,
        responsibilities: json['responsibilities'] as String? ?? '',
        contributions: json['contributions'] as String? ?? '',
        achievements: json['achievements'] as String? ?? '',
      );
}

/// One `languages[]` entry (`ENTRY_FIELDS['languages']`,
/// `create_resume.py:89,124`, confirmed directly) — the only repeatable
/// section where the select field (`proficiency`), not just the free-text
/// one, is required for completeness (both `name` and `proficiency` are in
/// `ENTRY_REQUIRED['languages']`). The real builder also rejects a
/// case-insensitive duplicate `name` (`create_resume.py:323-327`,
/// `"{name} is already listed."`) — surfaced here only as a server error
/// via [CreateResumeValidationError], not re-implemented client-side,
/// consistent with this feature's existing "no separate client validator"
/// design.
class CreateResumeLanguageEntry {
  const CreateResumeLanguageEntry({this.name = '', this.proficiency = ''});

  final String name;
  final String proficiency;

  bool get isBlank => name.isEmpty && proficiency.isEmpty;

  CreateResumeLanguageEntry copyWith({String? name, String? proficiency}) =>
      CreateResumeLanguageEntry(
        name: name ?? this.name,
        proficiency: proficiency ?? this.proficiency,
      );

  Map<String, dynamic> toJson() => {'name': name, 'proficiency': proficiency};

  factory CreateResumeLanguageEntry.fromJson(Map<String, dynamic> json) =>
      CreateResumeLanguageEntry(
        name: json['name'] as String? ?? '',
        proficiency: json['proficiency'] as String? ?? '',
      );
}

/// `additional.*` — a flat dict, not a repeatable list (`additional` is
/// absent from the `REPEATABLE` tuple, confirmed directly). The exact 6
/// keys and their order come from `ADDITIONAL_FIELDS`
/// (`create_resume.py:29-31`, verbatim: `memberships`, `publications`,
/// `research`, `activities`, `hobbies`, `other`). All 6 are optional —
/// `additional` has no entry in `ENTRY_REQUIRED` at all, since it isn't a
/// repeatable kind.
class CreateResumeAdditionalInfo {
  const CreateResumeAdditionalInfo({
    this.memberships = '',
    this.publications = '',
    this.research = '',
    this.activities = '',
    this.hobbies = '',
    this.other = '',
  });

  final String memberships;
  final String publications;
  final String research;
  final String activities;
  final String hobbies;
  final String other;

  bool get isBlank =>
      memberships.isEmpty &&
      publications.isEmpty &&
      research.isEmpty &&
      activities.isEmpty &&
      hobbies.isEmpty &&
      other.isEmpty;

  CreateResumeAdditionalInfo copyWith({
    String? memberships,
    String? publications,
    String? research,
    String? activities,
    String? hobbies,
    String? other,
  }) => CreateResumeAdditionalInfo(
    memberships: memberships ?? this.memberships,
    publications: publications ?? this.publications,
    research: research ?? this.research,
    activities: activities ?? this.activities,
    hobbies: hobbies ?? this.hobbies,
    other: other ?? this.other,
  );

  Map<String, dynamic> toJson() => {
    'memberships': memberships,
    'publications': publications,
    'research': research,
    'activities': activities,
    'hobbies': hobbies,
    'other': other,
  };

  factory CreateResumeAdditionalInfo.fromJson(Map<String, dynamic> json) =>
      CreateResumeAdditionalInfo(
        memberships: json['memberships'] as String? ?? '',
        publications: json['publications'] as String? ?? '',
        research: json['research'] as String? ?? '',
        activities: json['activities'] as String? ?? '',
        hobbies: json['hobbies'] as String? ?? '',
        other: json['other'] as String? ?? '',
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
    this.projects = const [],
    this.certifications = const [],
    this.achievements = const [],
    this.internships = const [],
    this.volunteering = const [],
    this.languages = const [],
    this.additional = const CreateResumeAdditionalInfo(),
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
  final List<CreateResumeProjectEntry> projects;
  final List<CreateResumeCertificationEntry> certifications;
  final List<CreateResumeAchievementEntry> achievements;
  final List<CreateResumeInternshipEntry> internships;
  final List<CreateResumeVolunteeringEntry> volunteering;
  final List<CreateResumeLanguageEntry> languages;
  final CreateResumeAdditionalInfo additional;

  CreateResumeFormState copyWith({
    int? draftId,
    bool clearDraftId = false,
    String? template,
    CreateResumePersonalInfo? personal,
    String? summary,
    CreateResumeSkills? skills,
    List<CreateResumeExperienceEntry>? experience,
    List<CreateResumeEducationEntry>? education,
    List<CreateResumeProjectEntry>? projects,
    List<CreateResumeCertificationEntry>? certifications,
    List<CreateResumeAchievementEntry>? achievements,
    List<CreateResumeInternshipEntry>? internships,
    List<CreateResumeVolunteeringEntry>? volunteering,
    List<CreateResumeLanguageEntry>? languages,
    CreateResumeAdditionalInfo? additional,
  }) => CreateResumeFormState(
    draftId: clearDraftId ? null : (draftId ?? this.draftId),
    template: template ?? this.template,
    personal: personal ?? this.personal,
    summary: summary ?? this.summary,
    skills: skills ?? this.skills,
    experience: experience ?? this.experience,
    education: education ?? this.education,
    projects: projects ?? this.projects,
    certifications: certifications ?? this.certifications,
    achievements: achievements ?? this.achievements,
    internships: internships ?? this.internships,
    volunteering: volunteering ?? this.volunteering,
    languages: languages ?? this.languages,
    additional: additional ?? this.additional,
  );

  /// The request body every `preview`/`pages`/`pdf` call sends, and the
  /// `data` field of a `draft_save` call — matches `normalize()`'s own
  /// `raw.get(...)` keys exactly. `order` is always sent empty: the server
  /// defaults a missing/empty entry to `'auto'` (`create_resume.py:197`),
  /// and this builder has no manual-reorder control (neither the 5 original
  /// sections nor these 5 new ones), so `'auto'` is always the correct,
  /// honest value, not an omission.
  Map<String, dynamic> toRequestJson() => {
    'template': template,
    'personal': personal.toJson(),
    'summary': summary,
    'skills': skills.toJson(),
    'experience': [for (final e in experience) e.toJson()],
    'education': [for (final e in education) e.toJson()],
    'projects': [for (final e in projects) e.toJson()],
    'certifications': [for (final e in certifications) e.toJson()],
    'achievements': [for (final e in achievements) e.toJson()],
    'internships': [for (final e in internships) e.toJson()],
    'volunteering': [for (final e in volunteering) e.toJson()],
    'languages': [for (final e in languages) e.toJson()],
    'additional': additional.toJson(),
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
    projects: [
      for (final e in (data['projects'] as List? ?? const []))
        CreateResumeProjectEntry.fromJson((e as Map).cast<String, dynamic>()),
    ],
    certifications: [
      for (final e in (data['certifications'] as List? ?? const []))
        CreateResumeCertificationEntry.fromJson(
          (e as Map).cast<String, dynamic>(),
        ),
    ],
    achievements: [
      for (final e in (data['achievements'] as List? ?? const []))
        CreateResumeAchievementEntry.fromJson(
          (e as Map).cast<String, dynamic>(),
        ),
    ],
    internships: [
      for (final e in (data['internships'] as List? ?? const []))
        CreateResumeInternshipEntry.fromJson(
          (e as Map).cast<String, dynamic>(),
        ),
    ],
    volunteering: [
      for (final e in (data['volunteering'] as List? ?? const []))
        CreateResumeVolunteeringEntry.fromJson(
          (e as Map).cast<String, dynamic>(),
        ),
    ],
    languages: [
      for (final e in (data['languages'] as List? ?? const []))
        CreateResumeLanguageEntry.fromJson((e as Map).cast<String, dynamic>()),
    ],
    additional: CreateResumeAdditionalInfo.fromJson(
      (data['additional'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}
