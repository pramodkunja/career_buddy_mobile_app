# Phase 43 — IT / Non-IT Career Browsing Flow (Flutter Mobile)

## 1. Objective

Replace the placeholder behavior of the landing page's "Choose Your Path"
section — where both the IT and Non-IT cards opened the same generic
Role Picker screen — with the real IT / Non-IT career-browsing experience
that exists on the production web app, reusing existing mobile
functionality wherever it already correctly supports this flow.

## 2. Source inspection (read-only — Task 1)

Both Django reference projects (`Career_Buddy_LMS/` and
`royalStaffing_CB01/`) were inspected read-only; neither was modified
(confirmed again at the end of this phase — see §9).

### 2.1 Data sources

- **IT departments**: `static/data/it_departments.json` (the real web
  fetches this via `fetch(panel.dataset.src)`,
  `landing.html:6742`). Structure confirmed by direct JSON parsing:
  `[[GroupName, [[DeptName, iconKey, [[RoleName, [skillLine, ...]]]]]]]`.
  Verified counts: 2 groups ("Product and Engineering" — 6 departments/58
  roles, "Business and Support" — 4 departments/35 roles), 10 departments,
  93 roles total. Each role's skill lines are category-labeled strings,
  e.g. `"Core Languages: Python, Java, C++, or C#"`.
- **Non-IT departments**: confirmed this is **not**
  `static/data/nonit_departments.json` (that file serves a separate
  feature, the Skill-Up Non-IT Center — the Choose-Your-Path panels have
  no `data-src` attribute pointing at it). The real data is the inline
  JS literal `var DEPTS = [...]` at `landing.html:7772-8040`, shaped
  `{c: 'tech'|'nt', i: iconKey, n: deptName, r: [[roleName,
  skillsCommaString], ...]}`. Extracted verbatim via a Node.js script
  (`require()`-ing the literal directly, never hand-transcribed) to avoid
  any transcription error. Verified counts: 21 departments (15 under
  `'tech'` → "Non-IT · Technical", 6 under `'nt'` → "Non-IT ·
  Non-Technical"), 202 roles total. Each role has one
  comma/semicolon-separated skills string, not labeled sub-groups.

### 2.2 Click-to-action behavior

Read the real click handling in `landing.html` (~lines 8040-8420 and
8728-8800). A single global listener —
`document.addEventListener('click', ... pickRole(b))` — intercepts every
role-card click, for both IT (`data-it-role`) and Non-IT (`data-idx`,
since Non-IT roles are pre-pushed into the global `ROLES` array at page
load via `mkRole()`). It always opens the `pickRole()` 3-action dialog,
regardless of URL hash; an alternate hash-based "skills view" exists in
the source but is reachable only via a direct deep-link URL, never
through normal clicking. This confirms the 3-action dialog (Skills /
Build Resume / Resume Parsing & Interview) is the real, only
practically-reachable interaction — matching an earlier Phase 40 finding.

- **`pickRole(b)`** (`landing.html:8729-8742`): builds
  `{role, dept, track}` with `track: r.c === 'it' ? 'tech' : 'nonit'` (an
  `'it'`-category role maps to track `'tech'`; both Non-IT categories map
  to `'nonit'`), and shows the 3-action dialog.
- **"Build Resume"** (`landing.html:8765-8771`): always intercepted by JS
  via `customRole()`, opening the inline Manual Resume Builder modal
  (role-driven, with suggestions) — **not** the newer Create Resume
  feature. `customRole(n, c, sub, groups, ind)`
  (`landing.html:8755-8763`) builds a synthetic role on the fly:
  `slug = 'custom-' + slugify(n)`, flattened skills, empty responsibilities/
  path — this exact logic was ported to Dart.
- **"Resume Parsing & Interview"**: href built from
  `URLSearchParams({role, dept, track})` against
  `resume_builder?role=&dept=&track=` — this is the existing
  `ResumeRepository.selectTargetRole({role, dept, track})` method, already
  implemented and `@login_required` server-side.
- **"Skills"**: the dialog's third action, showing the role's own skill
  breakdown (the lines/groups from the data source).

### 2.3 Existing mobile code reused

- `ResumeRepository.selectTargetRole()` and
  `ResumeBuilderController.setTargetRole()` — unchanged, called by the new
  flow exactly as the existing `RolePickerScreen` calls them.
- `ResumeRole` entity, `ManualResumeBuilderScreen` — unchanged; a synthetic
  `ResumeRole` is constructed from department-tree data, mirroring the web's
  own `customRole()`.
- `AppLoader` / `AppErrorView` — reused for the new departments screen's
  loading/error states (same pattern as `grammar_index_screen.dart`).
- The existing `GrammarDataSource` (`assets/data/grammar_data.json` +
  `rootBundle.loadString()` + simple in-memory caching) was the precedent
  followed for bundling and loading the two new JSON data files.
- The existing `RolePickerScreen` (Phase 22/23, reached only from inside
  `ResumeBuilderScreen`) was **not** touched — different entry point, out
  of this phase's scope.

## 3. Web-behavior → Flutter mapping

| Web behavior | Flutter implementation |
|---|---|
| IT card → `it_departments.json` fetch → department/role tree | `CareerDepartmentsScreen(track: 'it')` → `CareerDepartmentsAssetDataSource.load('it')` reading bundled `assets/data/it_departments.json` |
| Non-IT card → inline `DEPTS` array → department/role tree | `CareerDepartmentsScreen(track: 'non-it')` → `CareerDepartmentsAssetDataSource.load('non-it')` reading bundled `assets/data/nonit_departments.json` (Node-extracted from the real inline literal) |
| Click role card → `pickRole()` 3-action dialog | Tap role card → `showModalBottomSheet` → `CareerRoleActionSheet` with the same 3 actions |
| "Skills" → inline skill breakdown | `CareerRoleSkillsView` bottom sheet, one card per skill group, chips for each skill |
| "Build Resume" → `customRole()` + inline Manual Resume Builder modal | Synthetic `ResumeRole` built from the selected department/role, pushed to the existing `ManualResumeBuilderScreen` |
| "Resume Parsing & Interview" → `resume_builder?role=&dept=&track=` (login required) | `ResumeRepository.selectTargetRole(role, dept, track)` → on success, `ResumeBuilderController.setTargetRole()` → push existing `ResumeBuilderScreen`; on failure (e.g. guest/expired session), show the real error inline, no navigation |

## 4. Files changed

**New:**
- `lib/features/resume/domain/entities/career_department.dart` — `CareerRoleSkillGroup`, `CareerRole`, `CareerDepartment`, `CareerDepartmentGroup` entities.
- `lib/features/resume/data/career_departments_asset_datasource.dart` — loads/parses both bundled JSON assets; Dart port of the web's `splitSk()` skill-splitting logic (comma/semicolon split with paren-depth tracking, `and|or` prefix stripping, capitalization); in-memory caching per track.
- `lib/features/resume/presentation/screens/career_departments_screen.dart` — department list grouped by category, loading/error/empty states, icon mapping (`careerIconFor`).
- `lib/features/resume/presentation/screens/career_roles_screen.dart` — role list for a selected department.
- `lib/features/resume/presentation/widgets/career_role_action_sheet.dart` — the 3-action bottom sheet (Skills / Build Resume / Resume Parsing & Interview).
- `lib/features/resume/presentation/widgets/career_role_skills_view.dart` — skills breakdown bottom sheet with an "Explore Skill Up" CTA.
- `assets/data/it_departments.json` — byte-for-byte copy of the real source file.
- `assets/data/nonit_departments.json` — Node-extracted (never hand-authored) clean JSON of the real inline `DEPTS` literal.

**Modified:**
- `pubspec.yaml` — registered both new asset files.
- `lib/app/router/route_paths.dart` — added `careerDepartments` (`/careers`) and `careerRoles` (`/careers/roles`) routes to `universalRoutes` (the real `career_path()` view has no `@login_required`).
- `lib/app/router/app_router.dart` — registered the two new routes.
- `lib/features/resume/presentation/providers/resume_providers.dart` — added `careerDepartmentsAssetDataSourceProvider` and `careerDepartmentsProvider` (`FutureProvider.family`).
- `lib/features/home/presentation/widgets/public_home_body.dart` — IT/Non-IT card callbacks now push `RoutePaths.careerDepartments` with `extra: 'it'` / `'non-it'` instead of the generic Role Picker.
- `lib/features/home/presentation/widgets/home_choose_path.dart` — doc-comment update only.

**Tests (new):**
- `test/features/resume/data/career_departments_asset_datasource_test.dart` (7 tests, against the real bundled assets)
- `test/features/resume/presentation/screens/career_departments_screen_test.dart` (5 tests)
- `test/features/resume/presentation/widgets/career_role_action_sheet_test.dart` (5 tests)

**Tests (modified):**
- `test/features/home/presentation/screens/home_screen_test.dart` — IT/Non-IT card navigation tests updated for the new destination.
- `test/app/router/route_guards_test.dart` — added a group confirming the new routes are universal, and that `resumeBuilder`/`manualResumeBuilder` remain protected (no regression).

No backend files, migrations, or production data were touched.

## 5. Data/API assumptions and how they were verified

- Both department/role JSON sources were obtained from the live web
  source files/literal, not fabricated — the IT file is a byte-identical
  copy, and the Non-IT data was machine-extracted from the exact inline
  JS array via Node's own parser (not hand-transcribed), eliminating
  transcription risk.
- `ResumeRepository.selectTargetRole` and `ResumeBuilderController` were
  not changed — this phase only calls them with real role/dept/track
  values, exactly as the pre-existing `RolePickerScreen` does.
- No new backend endpoint was invented; "Resume Parsing & Interview"
  uses the existing, already-implemented `resume_builder_home` endpoint.

## 6. Automated tests

- Focused new/updated tests: all passing (20 new or updated test cases
  across the 5 files above).
- Full suite: **2400 passing, 0 failing** (baseline before this phase:
  2380 passing, 0 failing — net +20 tests, no regressions).

## 7. Static analysis

`flutter analyze`: **8 issues**, identical to the pre-phase baseline (all
pre-existing `unused_element_parameter` warnings in unrelated test files).
No new issues introduced.

## 8. Emulator verification (actually performed)

### 8.1 Device

- Original target `emulator-5554` (Pixel_9a, API level unspecified) hit a
  structural storage ceiling: `adb shell dumpsys diskstats` showed its
  `/data` partition has a hard ~6GB cap with only 8% free, and install
  failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE` even after safely
  uninstalling the app's own stale prior build and removing this
  session's own leftover debug screenshot/XML files from `/sdcard`
  (~17MB). The emulator itself was not wiped, recreated, or had any
  unrelated app/data removed.
- Pivoted to a second, **pre-existing** (not newly created) AVD,
  `Android_Emulator_34`, launched via `flutter emulators --launch
  Android_Emulator_34`. It came up as `emulator-5556` (Android 14, API 34,
  "sdk gphone64 arm64") with 3.7GB free. The debug build installed and
  ran there successfully.

### 8.2 Interactions actually tested, live

1. App launched cleanly via `adb shell am start`; confirmed focused via
   `dumpsys window`; logcat showed no Flutter exceptions throughout.
2. Landing page hero and "Choose Your Path" section (IT Job Seeker /
   Non-IT Job Seeker cards) confirmed rendering with unchanged layout.
3. Tapped **IT Job Seeker** → `CareerDepartmentsScreen(track: 'it')`
   loaded the real "Product and Engineering" / "Business and Support"
   groups with correct department names, icons, and role counts
   (Development: 10 roles, Product Management: 10, Design/UX/UI: 7, QA/
   Testing: 10, DevOps/Infrastructure: 11, Project Management: 10).
4. Tapped **Development** → role list loaded (Software Developer: 16
   skills, Frontend Developer: 21, Backend Developer: 23, etc.).
5. Tapped **Software Developer** → 3-action sheet opened with the correct
   role/department header.
6. Tapped **Skills** → real labeled skill groups rendered ("Core
   Languages": Python, Java, C++, C# — confirming the `or C#` → `C#`
   stripping works live), with "Explore Skill Up" CTA.
7. System Back closed the skills sheet; tapped a role card again (**Java
   Developer**) → new action sheet opened cleanly, confirming no stuck
   state.
8. Tapped **Build Resume** → correctly redirected to the **Login** screen,
   because `manualResumeBuilder` is a protected route and the session was
   a guest — confirming the existing auth guard is preserved, not
   bypassed. System Back from Login correctly returned to the roles list
   with no lost selection.
9. Tapped **Software Developer → Resume Parsing & Interview** as a guest
   → loading spinner, then **"Your session has expired. Please sign in
   again."** shown inline on the sheet, no navigation — confirming the
   `UnauthorizedFailure` path works identically to the automated test.
10. Navigated back to the landing page (3× system Back); Choose Your Path
    section still rendered correctly.
11. Tapped **Non-IT Job Seeker** → `CareerDepartmentsScreen(track:
    'non-it')` loaded the real "Non-IT · Technical" group with its
    departments (Engineering Recruitment & Technical Staffing, IT/Digital
    & Technology Staffing, EPC Project Workforce Solutions, PMC Workforce
    Solutions, HSE/Fire & Industrial Safety Workforce, Shutdown/Turnaround
    & Rapid Mobilization, each correctly showing 10 roles).
12. Tapped **Engineering Recruitment & Technical Staffing** → role list
    loaded, including **Lead Technical Recruiter (Engineering)** with 6
    skills (matching the automated test fixture exactly).
13. Tapped that role → **Skills** → single "Role skills" group rendered
    with all 6 skills, including **"ATS management (Workday/Bullhorn)"**
    as one unsplit chip — confirming the parentheses-aware comma-splitting
    logic works correctly on real data, live on-device.

Screenshots captured to `/tmp/cb_phase43_screens/` (01 through 15,
covering both entry points, both department screens, both role screens,
the skills view for an IT and a Non-IT role, the Build Resume
auth-redirect, and the guest Resume Parsing error state).

### 8.3 Logcat review

`adb logcat` filtered for exceptions/fatals across the whole session
showed only unrelated system/Google Play Services noise (Finsky,
Nearby, DoodleDataLoader, AlarmManager) — no Flutter exceptions, no
crashes from the app's own process.

## 9. Confirmation: Django reference projects untouched

`find Career_Buddy_LMS royalStaffing_CB01 -newer Mobile_app/pubspec.yaml
-type f` returned no results — no file in either read-only reference
project was modified, added, or deleted during this phase. No backend
code, migrations, or production data were touched at any point.

## 10. Remaining gaps / known limitations

- "Build Resume" and "Resume Parsing & Interview" both require an
  authenticated session (matching the real web's own `@login_required`
  behavior on `resume_builder_home`) — this was verified live as a guest
  and behaves correctly (redirect-to-login / inline error respectively),
  but a full authenticated run-through of "Build Resume" successfully
  opening `ManualResumeBuilderScreen`, and "Resume Parsing" successfully
  reaching `ResumeBuilderScreen`, was not performed live on-device in this
  session (no test account was used, per the standing "no fabricated
  production accounts" instruction). Both paths are covered by the
  automated widget tests using a fake repository, which exercise the
  success branch directly.
- The "Explore Skill Up" button inside the skills view was confirmed to
  render in both the IT and Non-IT skills views but was not tapped live
  on-device in this session (it reuses the existing, already-shipped
  `skillUpSections` route unchanged).
- As documented in the skills-view widget itself, the real web deep-links
  to a specific role's section within Skill-Up; the mobile "Explore Skill
  Up" button opens the general Skill-Up section index instead, since the
  existing Skill-Up screen has no per-role deep-link target yet. This is
  a deliberate, documented, justified simplification, not a fabrication.

## 11. Summary

The "Choose Your Path" IT and Non-IT cards now open the real
department → role → action browsing flow, sourced faithfully from the
production web app's own data (one file copied byte-for-byte, the other
machine-extracted from its real inline JS literal), reusing all existing
resume-builder infrastructure and auth/subscription protections without
modification. 2400/2400 tests pass (+20 new), analyzer is at the
pre-existing baseline (8 issues), and the full flow was verified live on
an Android emulator for both tracks, including the guest-auth-restricted
paths, with no crashes or Flutter exceptions observed.

**Phase 43 is complete. No further phase has been started.**
