/// Phase 76 — the Tech Center's own department → role → course structure
/// (`static/001 Career Buddy/index.html`'s `#depth-tech` article, the
/// `<div class="sub" id="grp-tech-<dept>">` groups that come after the 29
/// already-transcribed flat lesson cards). Confirmed by direct, reproducible
/// counting to cover all 383 nested `TechCenter/<dept>/<role>/*.html` files
/// Phase 75 found unreachable — every one of them already has a real link,
/// with a real title, inside this exact block of the real page; nothing
/// here is inferred from the filesystem or invented.
///
/// Generated, not hand-maintained — see `tool/generate_tech_center_catalog
/// .dart` and `lib/features/skill_up/data/tech_center_catalog.g.dart`'s own
/// header.
class TechCenterCourse {
  const TechCenterCourse({required this.title, required this.relativePath});

  /// The real `title=` query-param text on the course's own
  /// `#load=TechCenter/<dept>/<role>/<file>.html&title=...` link — the same
  /// sourcing convention already used for every other [displayTitle]-style
  /// field in this feature (see `SkillUpLesson.displayTitle`'s own doc
  /// comment).
  final String title;

  /// Relative to `static/001 Career Buddy/` — pass to the existing
  /// `buildSkillUpLessonUrl` unchanged, exactly like every other Skill Up
  /// lesson.
  final String relativePath;
}

/// One `<div class="card" id="role-tech-<dept>--<role>">` — a real job role
/// within a department, with its own course list.
class TechCenterRole {
  const TechCenterRole({
    required this.slug,
    required this.title,
    required this.category,
    required this.courses,
  });

  /// The `role-tech-<dept>--<slug>` id's own trailing segment — stable,
  /// deterministic, taken directly from the real page's own markup, never
  /// generated at runtime. Not globally unique on its own (a small number
  /// of role slugs are intentionally reused across two different
  /// departments on the real site, e.g. `devops-engineer` under both
  /// `development` and `devops-infrastructure`) — always pair with the
  /// owning [TechCenterDepartment.slug] as the real identity.
  final String slug;

  /// The card's own `<h4>` text, e.g. "Software Developer".
  final String title;

  /// The card's `<span class="chip">` — the real page's own 2-value
  /// top-level grouping ("Product and Engineering" / "Business and
  /// Support"), not invented here.
  final String category;

  final List<TechCenterCourse> courses;
}

/// One `<div class="sub" id="grp-tech-<slug>">` — a real Tech Center
/// department, e.g. "Development", "Quality Assurance (QA) / Testing".
class TechCenterDepartment {
  const TechCenterDepartment({
    required this.slug,
    required this.title,
    required this.roles,
  });

  /// The `grp-tech-<slug>` id's own trailing segment — matches the real
  /// on-disk `TechCenter/<slug>/` directory name exactly (confirmed
  /// 1:1 by the generator script).
  final String slug;

  /// The group's own `<h3>` text, e.g. "DevOps / Infrastructure".
  final String title;

  final List<TechCenterRole> roles;
}
