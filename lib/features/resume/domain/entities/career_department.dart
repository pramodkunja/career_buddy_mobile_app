/// Phase 43 — the real "Choose Your Path" department/role browsing tree
/// (`templates/landing.html`'s IT departments IIFE, `:8148-8323`, and the
/// inline Non-IT `DEPTS` array, `:7772-8040`). One role's skills, grouped —
/// IT roles have several labeled groups (one per "Category: a, b, c" source
/// line, confirmed directly in `itRole()`); Non-IT roles have exactly one
/// group, labeled "Role skills" (confirmed directly in `customRole()`'s own
/// call site inside the `raBuild` handler), since the source data gives a
/// Non-IT role only one comma-separated skills string.
class CareerRoleSkillGroup {
  const CareerRoleSkillGroup({required this.label, required this.skills});

  final String label;
  final List<String> skills;
}

/// One role inside a [CareerDepartment].
class CareerRole {
  const CareerRole({required this.name, required this.skillGroups, this.coursePath});

  final String name;
  final List<CareerRoleSkillGroup> skillGroups;

  /// Phase 47 — the role's Skill Up lesson, when one exists: the optional
  /// 3rd array element of a role entry in `static/data/nonit_departments.json`
  /// (`initNonIt()`'s `r.course`), relative to `static/001 Career Buddy/`
  /// exactly like [SkillUpLesson.relativePath]. `null` for every role parsed
  /// from the Phase 43 career-browsing asset (that file has no such field),
  /// and for IT roles, which are not linked to lesson content this way on
  /// the real site — only Non-IT Skill Up roles ever set this.
  final String? coursePath;

  /// All skills, flattened — used for the role card's "N skills" subtitle
  /// and as the fallback skill list when building a synthetic resume role.
  List<String> get allSkills => [for (final g in skillGroups) ...g.skills];
}

/// One department — the IT JSON's `[name, icon, roles]` triples and the
/// Non-IT array's `{c, i, n, r}` objects both reduce to this same shape.
class CareerDepartment {
  const CareerDepartment({
    required this.category,
    required this.icon,
    required this.name,
    required this.roles,
  });

  /// `'it'` / `'tech'` (Non-IT · Technical) / `'nt'` (Non-IT ·
  /// Non-Technical) — the same 3-value category `ResumeRole.category`
  /// already uses, confirmed directly against `pickRole()`'s own
  /// `track: r.c === 'it' ? 'tech' : 'nonit'` mapping.
  final String category;

  /// The source's own short icon key (e.g. `'code'`, `'search'`, `'hat'`) —
  /// mapped to a Material icon in the presentation layer, the same
  /// "reproduce with Material icons, not downloaded web art" convention
  /// already used throughout this app's other Phase 40/landing-page work.
  final String icon;

  final String name;
  final List<CareerRole> roles;
}

/// A [CareerDepartment] list grouped under one heading — IT's own 2 groups
/// ("Product and Engineering" / "Business and Support", confirmed directly
/// in `it_departments.json`'s own top-level array) and Non-IT's 2 tracks
/// ("Non-IT Technical" / "Non-IT Non-Technical", `landing.html:6746-6753`'s
/// `cp-ph` headings) are the same kind of grouping, just two different real
/// data sources — reproduced here as one shape so both tracks render
/// through the same screen.
class CareerDepartmentGroup {
  const CareerDepartmentGroup({required this.label, required this.departments});

  final String label;
  final List<CareerDepartment> departments;
}
