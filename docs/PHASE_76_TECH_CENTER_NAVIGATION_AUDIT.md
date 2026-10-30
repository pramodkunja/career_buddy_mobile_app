# Phase 76 — Tech Center Lesson Discovery & Navigation Audit

## Scope

Implements a maintainable navigation path for the 383 nested Tech Center
lesson pages Phase 75 confirmed had no Flutter entry point. Revalidates
Phase 75's own findings against current source before building anything.

## Files and architecture inspected

**Flutter project:**
- `docs/PHASE_75_SKILLUP_WEBVIEW_ACCESSIBILITY_AUDIT.md` /
  `..._IMPLEMENTATION_REPORT.md`, `docs/PHASE_51_FINAL_PARITY_MATRIX.md` —
  read in full for the historical claim and its original framing.
- `lib/features/skill_up/data/skill_up_data.dart` (729 lines) — confirmed
  the existing 29 flat `TechCenter/*.html` entries and the `SkillUpSection`/
  `SkillUpSubsection`/`SkillUpLesson` model shape they use.
- `lib/features/skill_up/domain/entities/skill_up_lesson.dart` — confirmed
  its `chip`/`description` fields are specific to the hand-curated "Sections
  in depth" card UI, not a good fit for 383 generated entries without
  inventing content for fields the real page doesn't actually have at the
  lesson level.
- `lib/features/skill_up/presentation/screens/skill_up_nonit_departments_screen.dart`,
  `skill_up_nonit_roles_screen.dart`, `widgets/skill_up_nonit_role_sheet.dart`
  — read in full as the direct structural precedent: a 2-screen department →
  role drill-down plus a bottom sheet for the role's own course action,
  already used for the real site's structurally identical Non-IT
  department/role data.
- `lib/app/router/route_paths.dart` / `app_router.dart` — the exact
  `skillUpNonIt`/`skillUpNonItRoles` route registration pattern (plain
  `extra`-threaded object, no query params, not in any public/universal/
  employer-protected list) mirrored for the two new routes.
- `lib/features/skill_up/presentation/screens/skill_up_screen.dart` — the
  `_SectionInDepthArticle`/`_NonItCenterArticle` widgets, confirming exactly
  where and how the Non-IT entry point ("Browse departments" button) is
  placed, as the model for this phase's own entry point.
- `pubspec.yaml`/`pubspec.lock` — confirmed `html` 0.15.7 was already a
  resolved transitive dependency (not previously declared directly).

**Updated Django reference** (`royalStaffing_CB01`, read-only):
- `static/001 Career Buddy/TechCenter/` — recounted directly: 29 flat files
  + 383 nested files across 10 department subdirectories (exact department
  breakdown re-confirmed identical to Phase 75's own count).
- **The key finding this phase made**: `static/001 Career Buddy/index.html`
  itself — not just the filesystem. Phase 51 and Phase 75 both concluded "no
  Flutter screen or data source links to any of these 383 files." That
  conclusion was incomplete: `index.html`'s own `#depth-tech` article
  continues, immediately after the 29 already-transcribed flat lesson
  cards, into 10 `<div class="sub" id="grp-tech-<dept>">` department groups,
  each containing `<div class="card" id="role-tech-<dept>--<role>">` role
  cards with a real `<h4>` title, a real `<span class="chip">` category, and
  a `<div class="tc-courses">` list of the exact same
  `#load=<relativePath>&title=<title>` links every other Skill Up lesson in
  this app already uses. This is the SAME page `skill_up_data.dart` is
  already "hand-transcribed verbatim" from (its own doc comment) — the
  383-file block was simply never transcribed, not genuinely unlinked.
- `core/skillup_access.py` — re-confirmed `FREE_PREFIXES`/`FREE_FILES`;
  `TechCenter/**` (apart from the one named free file, already handled)
  remains outside the Free allowlist, gated server-side exactly as before.

## Verified source hierarchy

Department → Role → Course (no deeper or shallower level exists in either
the filesystem or `index.html`'s own markup — confirmed consistently across
all 10 departments). Per-role course counts vary genuinely by department (1,
3, 4, or 5 courses per role) — not an inconsistency to normalize, a real
difference in how much content each role has.

A small number of role slugs are intentionally reused across two different
departments on the real site itself (`devops-engineer` under both
`development` and `devops-infrastructure`; `manual-qa-tester-test-analyst`
under both `quality-assurance-qa-testing` and `devops-infrastructure`;
`product-marketing-manager-pmm` under both `sales-and-marketing` and
`product-management`) — confirmed by direct inspection, not a parsing
artifact. The data model (and every uniqueness check) therefore uses the
compound key (department slug, role slug), never role slug alone.

## Exact file inventory and counting method

`tool/generate_tech_center_catalog.dart` (new, kept in the repo) parses
`index.html`'s `#depth-tech` article using the `html` package's real DOM
parser (not regex), extracting every department/role/course, then
cross-validates the result against the real on-disk
`TechCenter/<dept>/<role>/*.html` files — in both directions (every on-disk
file has a link; every link resolves to a real file).

Actual run output (this phase, against the current `royalStaffing_CB01`
checkout):
```
Parsed 10 departments, 93 roles, 383 courses from index.html.
Found 383 nested .html files on disk under TechCenter/.
Cross-validation: every on-disk nested file is linked, and every linked path exists on disk. Exact match.
```
No missing-from-page files, no missing-on-disk links, no duplicate
`relativePath` values — the script would have printed and flagged any of
these had they existed. This confirms Phase 75's 383 count exactly, with a
corrected explanation and zero excluded files.

## Manifest design and mapping rules

- **Department**: `slug` (= the real `TechCenter/<slug>/` directory name,
  confirmed 1:1), `title` (the group's own `<h3>` text, e.g. "DevOps /
  Infrastructure"), `roles`.
- **Role**: `slug` (the `role-tech-<dept>--<slug>` id's own trailing
  segment), `title` (the card's own `<h4>` text), `category` (the card's own
  `<span class="chip">` text — exactly 2 real values across the whole
  dataset, "Product and Engineering" and "Business and Support"), `courses`.
- **Course**: `title` (the link's own `title=` query-param text, URL-decoded
  — the identical sourcing convention `SkillUpLesson.displayTitle` already
  uses), `relativePath` (the link's own `#load=` path, URL-decoded, passed
  to the existing `buildSkillUpLessonUrl` unchanged).

Deliberately **not** carried into the manifest: the role card's own `<p>`
course-name-preview summary and the `skills`/`courses` meta-count chips —
both are fully redundant with data already in the manifest (derivable as
`courses.map((c) => c.title).join(' · ')` and `courses.length`), so
including them as separate stored fields would be invented duplication, not
a new verified fact.

The generated file (`lib/features/skill_up/data/tech_center_catalog.g.dart`)
carries a "GENERATED — do not hand-edit" header with its own regeneration
command, matching this codebase's existing convention
(`aria_welcome_catalog.g.dart`'s identical header style).

## Exceptions, duplicate titles, unusual paths, and unresolved mappings

- **Reused role slugs across departments** (3 cases, listed above) — a real
  characteristic of the source, handled by the compound-key data model, not
  an error to resolve away.
- **Uneven per-role course counts** (1/3/4/5 depending on department) — a
  real, verified difference in content depth per role; the UI shows the
  real count ("1 course" vs. "N courses"), not a padded or invented one.
- **No unresolved mappings.** Every one of the 383 files has a complete,
  unambiguous department/role/course mapping; nothing required a guess.

## Access-control behavior found in the reference

`TechCenter/**` (the nested files included) is gated by the same
`SkillUpAccessMiddleware` as every other non-Free Skill Up lesson, and
Flutter's own route guard already requires a non-guest session before any
Skill Up screen is reachable at all (`app_nav_drawer.dart`'s own doc
comment: no Skill Up route is in `publicRoutes`/`universalRoutes`). Neither
behavior needed any change — the new routes (`RoutePaths.techCenterDepartments`/
`techCenterRoles`) were deliberately **not** added to any guard allowlist,
so they inherit the same default-protected behavior as `skillUpNonIt`/
`skillUpNonItRoles` and every other Skill Up destination, confirmed live on
the emulator (see Implementation Report).

## Planned screens, routes, and integration points

- **`TechCenterDepartmentsScreen`** (`RoutePaths.techCenterDepartments`) —
  lists all 10 departments with their role counts; mirrors
  `SkillUpNonItDepartmentsScreen`'s shape, simplified to a plain
  `StatelessWidget` since the catalog is `const` (generated once, not
  fetched) rather than loaded via a `FutureProvider`.
- **`TechCenterRolesScreen`** (`RoutePaths.techCenterRoles`, `extra:
  TechCenterDepartment`) — lists a department's roles with category +
  course-count badge; mirrors `SkillUpNonItRolesScreen`.
- **`TechCenterRoleSheet`** (bottom sheet, not a 3rd screen) — lists a
  role's own courses, each opening the existing `SkillUpLessonScreen` via
  the existing `RoutePaths.skillUpLesson` + `SkillUpLessonRouteArgs` +
  `buildSkillUpLessonUrl`, unchanged. Mirrors `SkillUpNonItRoleSheet`,
  extended to list 1-5 "Start course" rows instead of a single button, since
  a Tech Center role (unlike a Non-IT role) can have multiple real courses.
- **Entry point**: a "Browse departments & roles" `OutlinedButton` added to
  `_SectionInDepthArticle` only when rendering the Tech Center section
  (`section.id == 'depth-tech'`), placed after that section's existing flat
  lesson cards — matching the real page's own placement of the
  department/role grid immediately after its own flat cards, within the
  same `#depth-tech` article.
