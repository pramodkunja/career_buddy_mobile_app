# Phase 77 — Skill-Up Regression Implementation Report

See `docs/PHASE_77_SKILLUP_END_TO_END_AUDIT.md` for the full audit this
report implements.

## Summary

One confirmed layout defect was fixed (a bottom-sheet overflow for a real
5-course Tech Center role on short/landscape viewports), and one confirmed
test-coverage gap was closed (no dedicated route-guard regression test for
Phase 76's 2 new routes). Everything else audited across navigation, catalog
integrity, lesson URL/WebView behavior, and access control was re-verified
correct with no defect found — no other code changes were made.

## Files changed and why

- **`lib/features/skill_up/presentation/widgets/tech_center_role_sheet.dart`**
  — wrapped the sheet's content in a `SingleChildScrollView` (was a plain,
  non-scrolling `Column` inside `SafeArea`). Fixes a confirmed, reproduced
  overflow for a role with 5 courses and a long title on a short/landscape
  viewport. No other behavior changed.
- **`test/app/router/route_guards_test.dart`** — added a new `'Phase 77 —
  Tech Center routes'` group (3 tests): confirms `techCenterDepartments`/
  `techCenterRoles` are in none of `publicRoutes`/`universalRoutes`/
  `employerProtectedRoutes`; confirms an unauthenticated hit on either
  redirects to login; confirms an authenticated candidate reaches both with
  no redirect.
- **`test/features/skill_up/presentation/screens/tech_center_roles_screen_test.dart`**
  — added a fixture matching the real max case (5 courses, a long title,
  taken from the real "VP Sales & Marketing / CCO" role) and one new test
  reproducing the overflow at `Size(800, 320)`, confirming it's fixed.
- **`lib/features/skill_up/data/tech_center_catalog.g.dart`** — regenerated
  via the existing `tool/generate_tech_center_catalog.dart` against the
  current Django reference, to confirm reproducibility. **Byte-for-byte
  identical** to the version already in the working tree (diffed directly,
  not assumed) — recorded here as a file this phase touched during
  verification, even though its content did not change.

No other file was modified. No new dependency was added.

## Exact fixes made and their evidence

**Fix 1 — `TechCenterRoleSheet` overflow.**
- Before: `SafeArea(child: Padding(..., child: Column(mainAxisSize: min,
  ...)))`.
- After: `SafeArea(child: SingleChildScrollView(padding: ..., child:
  Column(mainAxisSize: min, ...)))`.
- Evidence: a widget test pumping the sheet for a 5-course role at
  `tester.view.physicalSize = Size(800, 320)` threw `FlutterError: A
  RenderFlex overflowed by 111 pixels on the bottom` before the fix;
  `tester.takeException()` returns `null` and all 5 course titles are found
  after it. This exact test is now a permanent regression guard (see below).

**Fix 2 — Tech Center route-guard coverage.** No code behavior changed —
this closes a test-coverage gap, not a behavioral defect. The 3 new tests
pass against the existing, unmodified `route_guards.dart`/`route_paths.dart`,
confirming the existing (correct) behavior is now pinned down by an explicit
test rather than only by source inspection.

## Tests added or modified

- `test/app/router/route_guards_test.dart`: +3 tests (`'Phase 77 — Tech
  Center routes'` group).
- `test/features/skill_up/presentation/screens/tech_center_roles_screen_test.dart`:
  +1 test, +2 fixture constants (`_fiveCourseRole`,
  `_departmentWithFiveCourseRole`).

## Commands executed and actual results

- `dart run tool/generate_tech_center_catalog.dart
  /Users/kunjapramodmahajan/Flutter\ Projects/Career_Buddy_LMS/royalStaffing_CB01`
  → `Parsed 10 departments, 93 roles, 383 courses from index.html. Found
  383 nested .html files on disk under TechCenter/. Cross-validation: every
  on-disk nested file is linked, and every linked path exists on disk.
  Exact match.`
- `diff` of the freshly-regenerated file against the previously-committed
  one (both passed through `dart format`) → **no differences** (exit code
  0).
- `flutter analyze lib/features/skill_up/data/tech_center_catalog.g.dart` →
  No issues found!
- `flutter test test/features/skill_up/data/tech_center_catalog_test.dart`
  → 7/7 passed.
- `flutter test test/app/router/route_guards_test.dart` → **40/40 passed**
  (37 pre-existing + 3 new).
- `flutter test test/features/skill_up/presentation/screens/tech_center_roles_screen_test.dart`
  → **7/7 passed** (6 pre-existing + 1 new).
- `flutter test test/features/skill_up/presentation/screens/skill_up_lesson_screen_test.dart`
  → 8/8 passed (regression check, no change to this file).
- `flutter test test/features/skill_up/ test/app/router/route_guards_test.dart
  test/app/client_flow_test.dart` → **112/112 passed**, including the
  broader integration-style `client_flow_test.dart` suite.
- `flutter test test/shared/widgets/app_nav_drawer_test.dart` → 51/51
  passed (employer-navigation regression check).
- `flutter analyze` (whole project, including `tool/`) → **No issues
  found!**
- `flutter test` (complete suite) → **2,885 tests, all passed, 0
  failures** (2,881 from before this phase + 4 new: 3 route-guard + 1
  overflow regression).

No pre-existing failures were found or needed to be distinguished from new
ones — every run was a clean pass both before and after this phase's 2
changes.

## Emulator/device checks, separately from automated tests

- Used the existing `Android_Emulator_34` AVD (already running from prior
  phases, not wiped or recreated), device id `emulator-5554`.
- Captured screenshots under `docs/audit_evidence/phase77/`:
  - `01_guest_home.png` — guest home loads cleanly with this phase's code
    present.
  - `02_skillup_drawer_expanded.png` — the Skill Up drawer submenu
    (English Learning/Grammar/Vocabulary & Idioms/.../Aptitude/Tech),
    unchanged.
  - `03_guest_tech_login_gate.png` — tapping "Tech" as a guest correctly
    redirects to the Job Seeker login screen.
- **This is the full extent of guest-visible, on-device verification
  possible.** The "Browse departments & roles" button, and everything past
  it (department list, role list, course sheet, lesson WebView), sits
  *inside* the Skill Up hub, which itself requires a non-guest session to
  reach at all — a guest cannot tap past the login screen shown in
  `03_guest_tech_login_gate.png` to reach any of it. This is pre-existing,
  intentional gating (established well before Phase 76), not something this
  phase could additionally exercise live without credentials.
- **Authenticated navigation through departments → roles → a course → the
  lesson WebView was NOT verified live.** No authorized test account is
  available. This was instead verified through the automated widget-test
  suite (Phase 76's own `tech_center_departments_screen_test.dart`/
  `tech_center_roles_screen_test.dart`, re-run clean this phase), which
  exercises the real generated catalog data against the real widget tree —
  a real test, not a live account, and not claimed as live verification.

## Remaining gaps and recommended next steps

- No pre-existing Skill Up route (`skillUp`, `skillUpSections`,
  `skillUpCertifications`, `skillUpLesson`, `skillUpNonIt`,
  `skillUpNonItRoles`) has dedicated `route_guards_test.dart` coverage
  either — this predates Phase 71 and is out of this phase's declared
  scope (which covers Phase 71–76's cumulative work, not a general
  route-guard coverage backfill). Flagged as a reasonable, low-cost future
  improvement, not implemented here to avoid scope creep.
- Live, authenticated, on-device verification of the full Tech Center
  browsing flow remains a recommended follow-up once a test account is
  available.

## Scope-safety confirmation

- Every file changed is inside the Flutter project: 1 production file, 2
  test files, the regenerated (byte-identical) catalog, this phase's two
  reports, and 3 new screenshots under `docs/audit_evidence/phase77/`.
- Both Django reference directories (`royalStaffing_CB01`,
  `Career_Buddy_LMS`) remain read-only: confirmed no tracked-source file in
  either directory has a modification time after this phase's work began;
  `Career_Buddy_LMS` still carries only the same pre-existing, unrelated
  diff noted in every report since Phase 73.
- No backend API, database schema, migration, authentication/authorization
  logic, subscription rule, or deployment/signing configuration was
  changed.
- No existing, uncommitted work from Phases 52–76 was discarded — confirmed
  by the full 2,885-test suite passing (includes every prior phase's own
  tests) and by live emulator verification matching the previously-verified
  guest drawer/Skill-Up-gate structure exactly.
- No new dependency was added.
- Nothing was committed or pushed.

## Stop point

Per the task brief, this phase is complete and this is the final
deliverable for Phase 77. No Phase 78 or other expanded-scope work has been
prepared or started; proceeding requires explicit approval.
