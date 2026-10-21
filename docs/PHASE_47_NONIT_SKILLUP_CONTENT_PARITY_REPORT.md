# Phase 47 — Non-IT Skill-Up Content Parity

## 1. Original finding and confirmed current state

Phase 40's audit flagged ~21 Non-IT departments / ~202 lessons as missing
from Skill Up. Phase 43 later added Non-IT **career-browsing** (the "Choose
Your Path" department/role picker), but — per this phase's own explicit
warning — that is a different real feature from the Skill-Up **curriculum**
content, backed by a different real data source. This phase re-verified
directly against `royalStaffing_CB01` (not the older audit) before writing
any code:

- The real `static/001 Career Buddy/index.html` has a 4th "Sections in
  depth" article, `#depth-nonit` (`index.html:3886-3896`), rendered
  dynamically by a JS function `initNonIt()` (`index.html:5303-5425`) from
  `static/data/nonit_departments.json` (`data-src` attribute) — distinct
  from the 3 existing hand-transcribed static sections (English & Vocabulary,
  Aptitude & Reasoning, Tech Center).
- That data source is **a different file from the identically-named asset
  Phase 43 already bundled** (`Mobile_app/assets/data/nonit_departments.json`,
  extracted from `landing.html`'s inline `DEPTS` literal for career
  browsing). The real Skill-Up source adds a 3rd, optional array element per
  role: the relative path to that role's lesson HTML page. Confirmed by
  direct JSON inspection of both files — Phase 43's asset has no such field,
  the real `static/data/nonit_departments.json` has it on every single role.
- Filesystem count of `static/001 Career Buddy/NonITCenter/` confirmed
  **21 departments** (15 under `technical/`, 6 under `non-technical/`) and
  **202 lesson HTML files** total (one per role, no department index/hub
  file), matching the JSON's own role counts exactly, department by
  department.
- `core/skillup_access.py` confirmed every `NonITCenter/**.html` lesson is
  **plan-gated** (`FREE_PREFIXES`/`FREE_FILES` cover only CEFR/Vocabulary/
  Grammar/one Tech Center file — Non-IT Center is never free), returning
  HTTP 403 with a locked-page body for a Free-plan or anonymous request.

Conclusion before writing any code: Non-IT Skill-Up content was **entirely
missing** from the Flutter app (0 of 21 departments, 0 of 202 lessons) —
Phase 43's work does not substitute for it, exactly as this task's brief
warned.

## 2. Exact web sources used

- `royalStaffing_CB01/static/001 Career Buddy/index.html:3886-3896` — the
  `#depth-nonit` article's exact header copy/icon/tag.
- `royalStaffing_CB01/static/001 Career Buddy/index.html:5303-5485` —
  `initNonIt()` in full: data parsing, the 4-level hash-routed view
  hierarchy (`grid()` → `trackView()` → `deptView()` → `roleView()`), and
  the `GROUP_INFO` track metadata (`index.html:5338-5341`).
- `royalStaffing_CB01/static/data/nonit_departments.json` — the real,
  authoritative curriculum data (2 groups, 21 departments, 202 roles, each
  with an optional lesson-path 3rd field; confirmed all 202 roles have one).
- `royalStaffing_CB01/core/skillup_access.py` — `SkillUpAccessMiddleware`,
  `FREE_PREFIXES`/`FREE_FILES`, confirming Non-IT Center lessons are
  paid-plan-only, server-enforced regardless of client.
- One real lesson file read directly (`NonITCenter/non-technical/
  skill-development-workforce-readiness/01_workforce_capability_architect.html`)
  — confirmed a standalone, self-contained HTML document with its own
  embedded CSS/JS, the same shape as every other Skill-Up lesson page
  already handled by the existing `SkillUpLessonScreen`.

## 3. Source-to-mobile inventory

| Requirement | Status | Evidence |
|---|---|---|
| All 21 departments (15 technical + 6 non-technical) | **Implemented** | `assets/data/nonit_skillup_departments.json`, verified by `skill_up_nonit_asset_datasource_test.dart` |
| All 202 roles, real titles/skills/ordering | **Implemented** | Same asset (byte-for-byte copy); counts verified in tests |
| Role → lesson linkage (coursePath) | **Implemented** | `CareerRole.coursePath`, verified non-null for all 202 roles |
| Department → role navigation | **Implemented** | `SkillUpNonItDepartmentsScreen` → `SkillUpNonItRolesScreen` |
| Lesson content rendering | **Implemented (reused)** | Existing `SkillUpLessonScreen`/`buildSkillUpLessonUrl`, unmodified |
| Entry point from Skill Up hub | **Implemented** | New "Non-IT Center" article in both "Sections in depth" and "Sitemap" tabs |
| Plan-gated/locked-lesson behavior | **Implemented (reused, unmodified)** | Existing `SkillUpAccessMiddleware` + `SkillUpLessonScreen`'s 403→`SkillUpLockedView` handling applies generically to any lesson URL, including Non-IT ones — no new code needed or written |
| Phase 38 session-cookie forwarding | **Preserved, unmodified** | `SkillUpLessonScreen._loadLesson()` untouched |
| Live authenticated-session verification | **Not performed — documented limitation** | See §7 |

Track-level "grid" and per-department "preview of first 4 roles" steps from
the real page's finer hash-routing are intentionally **not** reproduced as
separate screens — both tracks' departments are shown together on one
screen, the same simplification Phase 43's own `CareerDepartmentsScreen`
already uses for the structurally identical Non-IT career-browsing groups.
Every department and role is still reachable; this is one fewer tap, not
missing content.

## 4. Files changed

**New:**
- `assets/data/nonit_skillup_departments.json` — byte-for-byte copy of the
  real `static/data/nonit_departments.json`.
- `lib/features/skill_up/data/skill_up_nonit_asset_datasource.dart` —
  parses the asset into `List<CareerDepartmentGroup>`.
- `lib/features/skill_up/presentation/providers/skill_up_providers.dart` —
  `skillUpNonItAssetDataSourceProvider`/`skillUpNonItDepartmentsProvider`.
- `lib/features/skill_up/presentation/screens/skill_up_nonit_departments_screen.dart`
- `lib/features/skill_up/presentation/screens/skill_up_nonit_roles_screen.dart`
- `lib/features/skill_up/presentation/widgets/skill_up_nonit_role_sheet.dart`
- 3 new test files (see §5).

**Modified:**
- `lib/features/resume/domain/entities/career_department.dart` — added one
  optional, nullable `CareerRole.coursePath` field (default `null`). Zero
  impact on Phase 43's own existing construction sites.
- `lib/features/skill_up/presentation/screens/skill_up_screen.dart` — added
  a `_NonItCenterArticle` widget (exact real header/copy/icon) to both the
  "Sections in depth" and "Sitemap" tabs, with a "Browse departments" action.
- `lib/app/router/route_paths.dart` / `lib/app/router/app_router.dart` —
  added `RoutePaths.skillUpNonIt` / `RoutePaths.skillUpNonItRoles`.
- `pubspec.yaml` — registered the new asset.
- `test/features/skill_up/presentation/screens/skill_up_screen_test.dart` —
  added tests for the new entry point (existing tests untouched).

Why `CareerDepartment`/`CareerRole`/`CareerDepartmentGroup` were reused
rather than duplicated: their own doc comments already describe them as a
source-agnostic "department/role browsing tree" shape, unifying 2 different
real data sources for Phase 43's own career-browsing feature; the identical
real-world shape here (group → department → role) made reuse the
"use existing models... where appropriate" choice, following the exact
precedent already set elsewhere in this codebase (`InterviewAnalyticsResult`
reusing the dashboard feature's `RecommendedJob` entity). The 15 Non-IT
department icon keys in the new JSON (`wallet`, `brain`, `clip`, `shield`,
`trend`, `globe`, `cart`, `crown`, `code`, `people`, `bolt`, `search`,
`box`, `hat`, `gear`) are all already mapped by the existing
`careerIconFor()` in `career_departments_screen.dart`, reused as-is with no
changes.

## 5. Lesson navigation / rendering mechanics

Confirmed directly in `initNonIt()`: a role's "Start course" action opens
`#load=<coursePath>&title=<roleName>` — **the exact same in-page lesson
viewer** already used by every other Skill-Up lesson (English/Aptitude/Tech
Center), already fully implemented in Flutter. Non-IT lessons therefore
reuse `SkillUpLessonScreen`/`buildSkillUpLessonUrl` completely unmodified:
tapping "Start course" in `SkillUpNonItRoleSheet` pushes
`RoutePaths.skillUpLesson` with a `SkillUpLessonRouteArgs(title: role.name,
url: buildSkillUpLessonUrl(role.coursePath!))`, identical to how every
existing lesson card already navigates.

## 6. Auth / subscription / locked-lesson behavior

No new access-control code was written or needed. `SkillUpLessonScreen`'s
existing Phase 38 cookie-forwarding and HTTP-403→`SkillUpLockedView`
handling operate on the request URL generically, regardless of which
Skill-Up section it came from — confirmed by reading that screen's
unmodified source and `core/skillup_access.py` directly:
`SkillUpAccessMiddleware` locks every `NonITCenter/**.html` page to
`normal`/`pro` plan users exactly like it already locks Aptitude/Tech
Center pages, and the existing `SkillUpLockedView`'s own copy ("Upgrade to
unlock Aptitude, the Tech Center, **the Non-IT Center** and certifications")
already explicitly named the Non-IT Center before this phase's work. No
guest-local data is sent anywhere; department/role browsing itself needs no
login beyond the existing requirement that the whole Skill Up hub is an
authenticated-only route (unchanged).

## 7. Test results

**Focused (`test/features/skill_up` + `test/features/resume`):** 518
passing, 0 failing (was 501 before this phase; +17 new).

**Full suite:** 2,458 passing, 0 failing (baseline 2,441; +17 new — exactly
matching the focused-suite delta, confirming no tests elsewhere were
touched).

New tests added:
- `test/features/skill_up/data/skill_up_nonit_asset_datasource_test.dart`
  (6) — real counts (21 departments, 202 roles), category mapping,
  every role has a non-null `coursePath`, no duplicate role names per
  department, a known role's exact skills/coursePath verified against the
  source, caching.
- `test/features/skill_up/presentation/screens/skill_up_nonit_departments_screen_test.dart`
  (4) — renders real data, error+retry, department tap navigates to roles,
  back nav returns.
- `test/features/skill_up/presentation/screens/skill_up_nonit_roles_screen_test.dart`
  (4) — role cards show skill count/"1 course" badge, role sheet shows
  skills + Start Course, a role with no `coursePath` shows no Start Course
  action, Start Course navigates to the real lesson route with the correct
  built URL.
- `test/features/skill_up/presentation/screens/skill_up_screen_test.dart`
  (+3) — the new "Non-IT Center" entry renders the real header/copy/tag in
  both "Sections in depth" and "Sitemap", and "Browse departments"
  navigates correctly.

No existing test was modified beyond the router-helper addition in
`skill_up_screen_test.dart` needed to add the new route; no existing
assertion was weakened, deleted, or had its expected value changed.

**Analyzer:** 8 issues, identical to the pre-Phase-47 baseline (all 8 are
pre-existing unused-test-parameter warnings in unrelated resume-controller
test files) — 0 new issues introduced.

## 8. Emulator verification

Device: `emulator-5556`, Android 14 (API 34), via `flutter run -d
emulator-5556 --debug`.

- Confirmed: app builds and launches cleanly, no `FlutterError`/exception
  in the run log at any point, no renderer crash.
- Confirmed live: this build resolves to the **production** backend
  (`https://careerbuddy4u.com`) by default (Phase 35's documented behavior —
  no `--dart-define=ENV=dev` was used). Per this task's own safety
  boundaries (no production accounts, no fabricated test accounts, no
  auth bypass), **no login was attempted**.
- Confirmed live, as a guest: the nav drawer shows only Home/Job Seeker
  Login/Employer Login — Skill Up (and therefore the new Non-IT Center
  entry nested inside it) is unreachable without authentication, exactly
  the existing, unmodified behavior (`RoutePaths.skillUp` is not in
  `publicRoutes`/`universalRoutes`). This matches Phase 46's own identical,
  explicitly-documented finding for the resume feature.
- **Not performed, honestly**: interactively browsing the new Non-IT
  departments/roles screens, opening a representative lesson, or exercising
  the locked-lesson path on-device — all of these require an authenticated
  session, and this project has no previously-established legitimate test
  account (confirmed by checking Phase 45/46's own reports, neither of
  which used one either). Fabricating one was correctly out of scope. This
  functionality is instead covered by the automated widget tests in §7,
  which exercise the full department→role→"Start course"→lesson-route
  navigation chain, the role-sheet rendering, and the count/title data
  against the real source.
- Screenshots captured in
  `/private/tmp/claude-501/-Users-kunjapramodmahajan-Flutter-Projects-Career-Buddy-LMS/c536c444-170e-4e2d-b1fa-059604770772/scratchpad/phase47/`
  (`01_launch.png`, `02_drawer.png`, `03_scrolled.png`, `04_scrolled2.png`)
  — these are session-scratch files, not part of the repository.

## 9. Remaining missing / blocked / unverified

- Interactive, on-device verification of the new Non-IT department/role
  browsing UI and the locked-lesson 403 path — blocked on no legitimate
  authenticated test session being available in this environment (see §8).
  Covered instead by automated tests.
- The Sitemap tab's real per-track paginated department-card pager
  (`initDeptPager`) is not reproduced pixel-for-pixel — the Sitemap tab
  instead shows the same "Non-IT Center" entry/copy and a "Browse
  departments" action into the same full browsing screens used from
  "Sections in depth". All 21 departments/202 roles remain reachable from
  there; only the finer in-page pagination UI itself differs.
- Department-level icon keys in the real JSON are parsed and carried on the
  `CareerDepartment` entity but are not rendered by the real `initNonIt()`
  JS either (confirmed: only the 2 track-level icons, `precision_
  manufacturing`/`groups`, are actually used in the real rendering) — this
  Flutter implementation renders them anyway via `careerIconFor()` for a
  better list affordance, which is a presentation choice, not invented
  content (the icon keys themselves are the real source data).

## 10. Confirmation of prior-phase integrity and scope boundaries

- Phases 42–46's own features/tests are unaffected: re-ran their full test
  files as part of the §7 focused and full suite runs — all pass unchanged.
- Both Django trees (`Career_Buddy_LMS/`, `royalStaffing_CB01/`) were only
  ever read, never modified — confirmed via `git status`/`git diff`
  awareness throughout; no file under either tree was written to.
- No backend endpoints, migrations, or schema/production-data changes were
  made.
- No auth/OTP/authorization/role/subscription logic was changed — the one
  touched access-adjacent file (`SkillUpLessonScreen`) was read only, never
  edited.
- No signing material was inspected or touched; no release build, upload,
  or Play Store action was taken.
- All pre-existing uncommitted work in the working tree (home-page redesign
  in progress, other in-flight resume-feature files, etc., confirmed via
  `git status` before starting) was left untouched — only the files listed
  in §4 were created or edited.
