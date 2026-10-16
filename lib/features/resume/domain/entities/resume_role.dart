/// One role-specific skill group (`role['fields']`, `resume_roles.py`'s
/// `_role()`: `{'key': slugify(label)[:40], 'label': label, 'options': [...]}`)
/// — rendered as a checkable chip group in Career & Skills, bound to
/// `ManualResumeSkills.groups[key]` (Phase 26, verified against the real
/// builder's `chipGroup()`, `landing.html:8491-8499`/`8578-8579`).
class ResumeRoleSkillField {
  const ResumeRoleSkillField({
    required this.key,
    required this.label,
    this.options = const [],
  });

  final String key;
  final String label;
  final List<String> options;
}

/// `role['levels'][level]` (`resume_roles.py`'s `_level()`) — suggested
/// skills/responsibilities/project ideas/training for one experience level,
/// shown as suggestion chips once that level is picked (verified,
/// `landing.html:8580-8582`, `8501-8513`, `8601-8602`). Never pre-selected.
class ResumeRoleLevelSuggestions {
  const ResumeRoleLevelSuggestions({
    this.skills = const [],
    this.responsibilities = const [],
    this.projects = const [],
    this.training = const [],
  });

  final List<String> skills;
  final List<String> responsibilities;
  final List<String> projects;
  final List<String> training;
}

/// One role from `manual_resume_roles` (`career_app/resume_roles.py`'s
/// `client_payload(full=True)['roles']`, confirmed by direct source read).
/// Phase 22/23's Role-Fit Picker only used [slug]/[title]/[category]/
/// [categoryLabel]/[subtitle]; Phase 26 (the Manual Resume Builder's real
/// form) additionally needs the role's own form data — [fields] (skill
/// groups), [levels] (per-experience-level suggestions), [summaries]
/// (editable summary templates per level), [recommendedSkills],
/// [certifications] (suggestion chips), and [experienceLabel] — all parsed
/// from the exact same response, previously discarded by
/// `parseManualResumeRoles`. Every new field defaults to empty so existing
/// Role Picker call sites are unaffected.
class ResumeRole {
  const ResumeRole({
    required this.slug,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.subtitle,
    this.fields = const [],
    this.levels = const {},
    this.summaries = const {},
    this.recommendedSkills = const [],
    this.certifications = const [],
    this.experienceLabel = 'Professional Experience',
  });

  final String slug;

  /// `title` — the exact string the `role=` query parameter must carry
  /// (`career_app/role_fit.py`'s `_template_roles()` keys roles by
  /// `r['title']`, confirmed directly).
  final String title;

  /// `category` — one of `'it'`/`'tech'`/`'nt'` (`CATEGORY_LABELS`).
  /// **Not** the same string the `track=` query parameter needs — see
  /// [track].
  final String category;

  /// `category_label` — the human-readable form ("IT Role", "Non-IT ·
  /// Technical", "Non-IT · Non-Technical") for display only.
  final String categoryLabel;

  /// `subtitle` — the exact string the `dept=` query parameter must carry
  /// (same `_template_roles()` keying as [title]'s doc comment). Despite
  /// the parameter being named `dept`, this is the role's own subtitle
  /// field (e.g. "Frontend, backend, full-stack"), not a department name —
  /// confirmed directly against `pickRole()`'s own JS (`landing.html:8738`,
  /// `dept: r.sub` where `r.sub` is mapped from `subtitle` at line 7767).
  final String subtitle;

  /// The `track=` query parameter value — confirmed directly against both
  /// `pickRole()`'s JS (`landing.html:8738`, `track: r.c === 'it' ?
  /// 'tech' : 'nonit'`) and `role_fit.py`'s `_template_roles()` key
  /// construction (`'tech' if r['category'] == 'it' else 'nonit'`): only
  /// an `'it'`-category role maps to `'tech'`; **both** other categories
  /// (`'tech'`/`'nt'`) map to `'nonit'` — the role's own [category] string
  /// and this value share the word "tech" but are never interchangeable.
  String get track => category == 'it' ? 'tech' : 'nonit';

  /// `role['fields']` — this role's own skill-group checkboxes.
  final List<ResumeRoleSkillField> fields;

  /// `role['levels']` — keyed by experience level (`'fresher'`/`'1-3'`/
  /// `'3-5'`/`'5+'`, `resume_roles.py`'s `LEVEL_KEYS`).
  final Map<String, ResumeRoleLevelSuggestions> levels;

  /// `role['summaries']` — editable professional-summary template strings,
  /// keyed by experience level (`resume_roles.py`'s `summary_templates()`).
  final Map<String, List<String>> summaries;

  /// `role['recommended_skills']` — folded into the "Suggested" skill chips
  /// alongside `levels[level].skills` (verified, `landing.html:8580-8582`).
  final List<String> recommendedSkills;

  /// `role['certifications']` — suggestion chips in the Education step that
  /// each create a new certification entry named from the chip (verified,
  /// `landing.html:8601`).
  final List<String> certifications;

  /// `role['experience_label']` — e.g. "Professional Experience" vs a
  /// role-specific label; defaults match the Python side's own default.
  final String experienceLabel;
}
