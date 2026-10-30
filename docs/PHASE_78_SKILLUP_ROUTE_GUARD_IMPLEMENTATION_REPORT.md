# Phase 78 — Skill-Up Route Guard Coverage Implementation Report

See `docs/PHASE_78_SKILLUP_ROUTE_GUARD_AUDIT.md` for the full audit this
report implements.

## Summary

No access-control defect was found — every one of the 8 Skill-Up routes
already behaved correctly, matching the real `skillup_hub` Django view's
plain `@login_required` (no employer-specific block). This phase closes the
test-coverage gap Phase 77 flagged: the 6 older routes had no dedicated
route-guard test, and none of the 8 routes had any test for employer
access specifically. One file was changed; no production code was touched.

## Files changed and reasons

- **`test/app/router/route_guards_test.dart`** — added one new group,
  `'Phase 78 — the 6 older Skill Up routes (and a re-check of the 2 Tech
  Center ones)'`, with 4 tests covering all 8 routes via a shared loop
  (not 6 near-duplicate copies of Phase 77's group). The existing `'Phase
  77 — Tech Center routes'` group (3 tests) was left completely untouched.

No other file was modified. No production code changed, since no defect
was found to fix.

## New tests added

1. `'none of the 8 Skill Up routes is in any special route list'` —
   confirms `skillUp`, `skillUpSections`, `skillUpCertifications`,
   `skillUpLesson`, `skillUpNonIt`, `skillUpNonItRoles`,
   `techCenterDepartments`, `techCenterRoles` are absent from
   `publicRoutes`, `universalRoutes`, and `employerProtectedRoutes`.
2. `'an unauthenticated hit on any of the 8 routes bounces to the student
   login, not the employer one'` — exercises `computeRedirect` directly
   for each route with `AuthUnauthenticated()`, asserting `RoutePaths.login`.
3. `'an authenticated candidate reaches all 8 routes without any redirect'`
   — exercises `computeRedirect` with a candidate `AuthAuthenticated`,
   asserting `null` for each route.
4. `'an authenticated employer also reaches all 8 routes without any
   redirect'` — the new coverage dimension: exercises `computeRedirect`
   with an employer `AuthAuthenticated(isEmployer: true)`, asserting `null`
   for each route, directly matching the real `skillup_hub` view's absence
   of any employer/portal branch (confirmed by reading its full source this
   phase).

All 4 tests exercise the actual `computeRedirect` function with real
`AuthState` values and real `RoutePaths` constants — not a check that a
route name merely exists in a list.

## Confirmed defects fixed

None. No access-control defect was found in the audit; this phase is
coverage-only.

## Exact commands executed and results

- `flutter analyze test/app/router/route_guards_test.dart` → No issues
  found!
- `flutter test test/app/router/route_guards_test.dart` → **44/44 passed**
  (40 pre-existing + 4 new; the 3 Phase 77 Tech Center tests are among the
  40 and pass unchanged).
- `dart format --output=none --set-exit-if-changed
  test/app/router/route_guards_test.dart` → initially reported 1 file would
  change (new code not yet formatted); `dart format
  test/app/router/route_guards_test.dart` applied the fix; re-running
  `--set-exit-if-changed` afterward → **0 files changed, exit code 0**.
- `flutter test test/features/skill_up/ test/app/router/route_guards_test.dart
  test/shared/widgets/app_nav_drawer_test.dart test/features/auth/
  test/app/client_flow_test.dart` → **279/279 passed** (Skill-Up screens/
  navigation/deep-links/lesson URL/WebView/Non-IT/Tech Center, employer
  drawer + identity, auth + route guards, and the broader integration-style
  client-flow suite, which exercises logout).
- `flutter analyze` (whole project) → **No issues found!**
- `flutter test` (complete suite) → **2,889 tests, all passed, 0
  failures** (2,885 from before this phase + 4 new).

No pre-existing failures were found; nothing needed to be distinguished
from a newly-introduced one.

## Emulator verification (distinguished from automated tests)

- Used the existing `Android_Emulator_34` AVD. It had shut down since
  Phase 77's session; it was **relaunched** (`flutter emulators --launch
  Android_Emulator_34`), not wiped or recreated — the same AVD, just
  restarted.
- Captured screenshots under `docs/audit_evidence/phase78/`:
  - `01_guest_home.png` — guest home loads cleanly.
  - `02_guest_drawer.png` — guest drawer opens, unchanged.
  - `03_skillup_expanded.png` — the Skill Up submenu expands; "Skill Up"
    itself is an `ExpansionTile` toggle, not a navigable link (confirmed
    live, matching the Phase 71 drawer design).
  - `04_drawer_scrolled.png` — scrolled to reveal "Certifications" (maps to
    `RoutePaths.skillUpCertifications`), a route not previously exercised
    live in any prior phase's evidence.
  - `05_guest_certifications_login_gate.png` — tapping "Certifications" as
    a guest correctly redirects to the Job Seeker (student) login screen —
    live confirmation of one of the 6 previously-untested-live routes,
    distinct from the "Tech" item already verified live in Phases 76/77.
- **This is genuine, live, on-device confirmation that a guest cannot
  reach a Skill-Up destination directly — it is a real interaction on a
  real emulator, not source inspection.** It is also, necessarily, the
  full extent of what guest-only emulator access can show: nothing past
  the login screen (any authenticated candidate or employer behavior) was
  or could be exercised this way.
- **No authenticated candidate or employer device verification was
  performed.** No authorized test account is available. The authenticated
  behavior claims in the audit report (candidate and employer both reach
  all 8 routes) are automated-test-verified (via `computeRedirect`
  directly) and source-verified (the real `skillup_hub` view), not
  live-device-verified — this distinction is stated explicitly, not
  blurred.

## Focused test totals

- `route_guards_test.dart`: 44/44.
- Combined Skill-Up/employer/auth/client-flow regression run: 279/279.

## Full test-suite total

2,889/2,889, 0 failures.

## Analyzer and formatting results

- `flutter analyze` (whole project): No issues found!
- `dart format` on the one changed file: compliant after one formatting
  pass (confirmed via `--set-exit-if-changed`).

## Remaining limitations and recommendations

- The `state.extra! as ...` null-crash risk (8 occurrences across the
  router, not Skill-Up-specific) remains unaddressed — a systemic,
  pre-existing characteristic of this router's `extra`-threading pattern,
  not an access-control defect, and out of this phase's declared scope.
  Recommended as its own, separate robustness-focused phase if ever
  prioritized.
- The real site's `?section=grp-tech-*`/`role-tech-*`/`grp-nonit-*`/
  `role-nonit-*` deep-link capability (confirmed present in
  `riya_bot/skillup_views.py`'s `_TECH_ROLE_RE`) has no Flutter equivalent
  yet. This is a content/navigation feature gap, not an access-control
  issue — explicitly out of this phase's scope ("not an authentication
  redesign"). Flagged for a future phase's consideration, not implemented.
- Authenticated (candidate and employer) live device verification of all 8
  routes remains a recommended follow-up once a test account is available.

## Scope-safety confirmation

- Exactly one file was changed, and it is inside the Flutter project:
  `test/app/router/route_guards_test.dart`. This phase's two reports and 5
  new screenshots under `docs/audit_evidence/phase78/` were also added.
- Both Django reference directories (`royalStaffing_CB01`,
  `Career_Buddy_LMS`) remain read-only: confirmed no tracked-source file in
  either directory has a modification time after this phase's work began;
  `Career_Buddy_LMS` still carries only the same pre-existing, unrelated
  diff noted in every report since Phase 73.
- No backend API, database schema, migration, authentication/authorization
  logic, subscription rule, or deployment/signing configuration was
  changed.
- No existing, uncommitted work from Phases 52–77 was discarded — confirmed
  by the full 2,889-test suite passing (includes every prior phase's own
  tests) and by live emulator verification matching the previously-verified
  guest drawer/Skill-Up-gate structure.
- No new dependency was added.
- Nothing was committed or pushed.

## Stop point

Per the task brief, this phase is complete and this is the final
deliverable for Phase 78. No Phase 79 or other expanded-scope work has been
prepared or started; proceeding requires explicit approval.
