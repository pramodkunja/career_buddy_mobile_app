import '../../resume/domain/entities/career_department.dart';
import 'entities/tech_center_catalog.dart';

/// Phase 79 — the real site's own `?section=` deep-link contract also
/// covers 4 categories beyond the `depth-*` ids [RoutePaths.skillUpSections]
/// already handles (confirmed directly in `riya_bot/skillup_views.py:39`):
///
/// ```python
/// _TECH_ROLE_RE = re.compile(r"(grp|role)-(tech|nonit)-[a-z0-9-]{1,150}")
/// ```
///
/// used with `.fullmatch()` — case-sensitive (no `re.I`), lowercase
/// `[a-z0-9-]` only. A value that doesn't match this pattern (and isn't one
/// of `ALLOWED_SECTIONS`) is silently dropped to `""` by the real view, the
/// same safe fallback `SkillUpScreen` already gives an unrecognized
/// `depth-*` id. [parseSkillUpDeepLinkId] mirrors that exact grammar.
sealed class SkillUpDeepLinkId {
  const SkillUpDeepLinkId();
}

/// `grp-tech-<departmentSlug>` — e.g. `grp-tech-development`.
class TechCenterDepartmentId extends SkillUpDeepLinkId {
  const TechCenterDepartmentId(this.departmentSlug);
  final String departmentSlug;

  @override
  bool operator ==(Object other) =>
      other is TechCenterDepartmentId && other.departmentSlug == departmentSlug;
  @override
  int get hashCode => departmentSlug.hashCode;
}

/// `role-tech-<departmentSlug>--<roleSlug>` — e.g.
/// `role-tech-development--software-developer`. A small number of role
/// slugs are intentionally reused across different departments on the real
/// site (confirmed in Phase 76/77), so the department half is always
/// required and always resolved together with the role half — never the
/// role slug alone.
class TechCenterRoleId extends SkillUpDeepLinkId {
  const TechCenterRoleId(this.departmentSlug, this.roleSlug);
  final String departmentSlug;
  final String roleSlug;

  @override
  bool operator ==(Object other) =>
      other is TechCenterRoleId &&
      other.departmentSlug == departmentSlug &&
      other.roleSlug == roleSlug;
  @override
  int get hashCode => Object.hash(departmentSlug, roleSlug);
}

/// `grp-nonit-<departmentSlug>` — e.g.
/// `grp-nonit-engineering-recruitment-technical-staffing`. Unlike Tech
/// Center, the Non-IT catalog (`CareerDepartment`) has no stored slug field
/// — the real site's own `initNonIt()` JS derives this slug from the
/// department's display name at render time, so [findNonItDepartment]
/// reproduces that exact derivation instead of inventing a new field.
class NonItDepartmentId extends SkillUpDeepLinkId {
  const NonItDepartmentId(this.departmentSlug);
  final String departmentSlug;

  @override
  bool operator ==(Object other) =>
      other is NonItDepartmentId && other.departmentSlug == departmentSlug;
  @override
  int get hashCode => departmentSlug.hashCode;
}

/// `role-nonit-<departmentSlug>--<roleSlug>` — e.g.
/// `role-nonit-engineering-recruitment-technical-staffing--lead-technical-recruiter-engineering`.
class NonItRoleId extends SkillUpDeepLinkId {
  const NonItRoleId(this.departmentSlug, this.roleSlug);
  final String departmentSlug;
  final String roleSlug;

  @override
  bool operator ==(Object other) =>
      other is NonItRoleId &&
      other.departmentSlug == departmentSlug &&
      other.roleSlug == roleSlug;
  @override
  int get hashCode => Object.hash(departmentSlug, roleSlug);
}

final _deepLinkIdPattern = RegExp(
  r'^(grp|role)-(tech|nonit)-([a-z0-9-]{1,150})$',
);

/// Returns `null` for anything that isn't one of the 4 real categories —
/// including `depth-*` ids, empty/missing values, wrong casing, or a
/// malformed `grp`/`role` value — exactly mirroring the real view's own
/// "not `ALLOWED_SECTIONS`, not `_TECH_ROLE_RE` → drop to empty" behavior.
/// Callers fall back to the existing `SkillUpScreen(initialSectionId: ...)`
/// handling for a `null` result, which already behaves safely for an
/// unrecognized id.
SkillUpDeepLinkId? parseSkillUpDeepLinkId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match = _deepLinkIdPattern.firstMatch(raw);
  if (match == null) return null;

  final kind = match.group(1)!; // "grp" | "role"
  final catalog = match.group(2)!; // "tech" | "nonit"
  final rest = match.group(3)!;

  if (kind == 'grp') {
    return catalog == 'tech'
        ? TechCenterDepartmentId(rest)
        : NonItDepartmentId(rest);
  }

  // A real slug (from either this app's Phase 76 generator or the real
  // site's own JS `slug()`, which collapses every run of non-alphanumeric
  // characters to one hyphen) can never itself contain "--", so the first
  // occurrence is unambiguously the dept/role separator.
  final separator = rest.indexOf('--');
  if (separator <= 0 || separator + 2 >= rest.length) return null;
  final departmentSlug = rest.substring(0, separator);
  final roleSlug = rest.substring(separator + 2);

  return catalog == 'tech'
      ? TechCenterRoleId(departmentSlug, roleSlug)
      : NonItRoleId(departmentSlug, roleSlug);
}

/// Looks up a [TechCenterDepartmentId]'s target directly against the
/// existing generated catalog — `TechCenterDepartment.slug` already matches
/// the real `grp-tech-<slug>` id's own trailing segment exactly (confirmed
/// 1:1 by the Phase 76 generator), so no derivation is needed.
TechCenterDepartment? findTechCenterDepartment(
  List<TechCenterDepartment> departments,
  String departmentSlug,
) {
  for (final department in departments) {
    if (department.slug == departmentSlug) return department;
  }
  return null;
}

/// Looks up a [TechCenterRoleId]'s target. Resolves the department first,
/// then searches only that department's own roles — a role slug is only
/// ever meaningful paired with its department (see [TechCenterRoleId]'s own
/// doc comment).
({TechCenterDepartment department, TechCenterRole role})? findTechCenterRole(
  List<TechCenterDepartment> departments,
  String departmentSlug,
  String roleSlug,
) {
  final department = findTechCenterDepartment(departments, departmentSlug);
  if (department == null) return null;
  for (final role in department.roles) {
    if (role.slug == roleSlug) return (department: department, role: role);
  }
  return null;
}

/// Mirrors the real site's own `initNonIt()` slugify function verbatim
/// (`static/001 Career Buddy/index.html`):
/// ```js
/// const slug = s => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
/// ```
/// `CareerDepartment`/`CareerRole` (Phase 43) have no stored slug field —
/// this derives the same slug from `.name` at lookup time rather than
/// adding one, keeping this shared Resume-Builder entity untouched.
String slugifyNonItName(String name) {
  final lower = name.toLowerCase();
  final collapsed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Looks up a [NonItDepartmentId]'s target across every track/group.
CareerDepartment? findNonItDepartment(
  List<CareerDepartmentGroup> groups,
  String departmentSlug,
) {
  for (final group in groups) {
    for (final department in group.departments) {
      if (slugifyNonItName(department.name) == departmentSlug) {
        return department;
      }
    }
  }
  return null;
}

/// Looks up a [NonItRoleId]'s target — resolves the department first (same
/// reasoning as [findTechCenterRole]), then its roles.
({CareerDepartment department, CareerRole role})? findNonItRole(
  List<CareerDepartmentGroup> groups,
  String departmentSlug,
  String roleSlug,
) {
  final department = findNonItDepartment(groups, departmentSlug);
  if (department == null) return null;
  for (final role in department.roles) {
    if (slugifyNonItName(role.name) == roleSlug) {
      return (department: department, role: role);
    }
  }
  return null;
}
