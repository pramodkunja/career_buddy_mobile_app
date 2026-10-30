# Phase 79 — Skill-Up Department & Role Deep-Link Parity Implementation Report

See `docs/PHASE_79_SKILLUP_DEEP_LINK_AUDIT.md` for the full audit this report
implements.

## Summary

Implemented all 4 deep-link categories the audit confirmed the real site
supports (`grp-tech-*`, `role-tech-*`, `grp-nonit-*`, `role-nonit-*`) by
reusing existing routes, catalog data, and screens — no new route, endpoint,
or identifier format was invented. Phase 72's `depth-*` section links and
Phase 77/78's route-guard/access-control behavior are unchanged.

## Files changed and reasons

**New files:**
- `lib/features/skill_up/domain/skill_up_deep_link.dart` — pure parsing
  (`parseSkillUpDeepLinkId`, mirroring `_TECH_ROLE_RE` exactly) and
  catalog-lookup functions (`findTechCenterDepartment`/`findTechCenterRole`/
  `slugifyNonItName`/`findNonItDepartment`/`findNonItRole`). Kept dependency
  -free of GoRouter/BuildContext so it's unit-testable directly.
- `lib/features/skill_up/presentation/providers/
  skill_up_nonit_role_open_request_provider.dart` — a `Notifier<String?>`
  mirroring the existing `HomeScrollRequestController`/
  `BuddyOverlayOpenRequestController` "shared request" pattern, used to tell
  `SkillUpNonItRolesScreen` which role to auto-open once it mounts.
- `lib/features/skill_up/presentation/screens/
  skill_up_nonit_deep_link_screen.dart` — a thin resolver screen that waits
  for the async Non-IT catalog (`skillUpNonItDepartmentsProvider`) to load,
  resolves the department/role, and `pushReplacement`s to the existing
  `SkillUpNonItRolesScreen` using its unchanged `extra: CareerDepartment`
  contract — needed because the Non-IT catalog loads asynchronously, unlike
  Tech Center's synchronous `const` data.
- `lib/app/router/skill_up_sections_route.dart` — `buildSkillUpSectionsScreen`,
  the pure destination-resolution logic extracted from the `skillUpSections`
  `GoRoute` builder, for the same direct-testability reason
  `route_guards.dart` keeps `computeRedirect` free of router types.

**Modified files:**
- `lib/features/skill_up/presentation/screens/
  tech_center_roles_screen.dart` — added an optional `highlightRoleSlug`
  constructor parameter; on mount, if set and resolvable, scrolls that
  role's card into view via `Scrollable.ensureVisible` (the same pattern as
  the Phase 71 nav-drawer anchor scroll). **Converted the body from a lazy
  `ListView` to an eager `SingleChildScrollView`+`Column`** — required
  because a `ListView`'s un-mounted off-screen items have no
  `RenderObject`/`GlobalKey.currentContext` for `ensureVisible` to resolve
  against (the same virtualization gotcha Phase 71 first identified for the
  nav drawer); proved necessary, not just theoretical, with a new test using
  an 11-role department (the real `devops-infrastructure` department's own
  role count, the largest of any real Tech Center department).
- `lib/features/skill_up/presentation/screens/
  skill_up_nonit_roles_screen.dart` — converted from `StatelessWidget` to
  `ConsumerStatefulWidget` to add an `initState` that checks
  `skillUpNonItRoleOpenRequestProvider` and, if a pending role name matches
  one of this department's roles, opens the existing role sheet
  automatically (reusing the screen's own pre-existing
  `showModalBottomSheet(... SkillUpNonItRoleSheet(...))` call, not a new
  one). The existing tap-to-open flow and `_RoleCard`/list body are
  unchanged.
- `lib/app/router/app_router.dart` — the `skillUpSections` `GoRoute`
  builder now calls `buildSkillUpSectionsScreen(state.uri.queryParameters
  ['section'])` instead of constructing `SkillUpScreen` directly; this is
  the only router wiring change. The route's path, guard, and position in
  the router are unchanged.

No backend, database, authentication, subscription, or deployment file was
touched. No existing route path, identifier format, or screen was removed.

## Deep-link categories implemented and exact mapping behavior

| Category | Example real id | Resolves to | Behavior |
|---|---|---|---|
| Tech Center department | `grp-tech-development` | `TechCenterRolesScreen(department: development)` | Opens the department's role list (existing Phase 76 screen) |
| Tech Center role | `role-tech-development--software-developer` | `TechCenterRolesScreen(department: development, highlightRoleSlug: 'software-developer')` | Opens the parent department's role list, scrolled to that role's card |
| Non-IT department | `grp-nonit-<dept>` | `SkillUpNonItDeepLinkScreen` → `SkillUpNonItRolesScreen(department: ...)` | Resolves asynchronously, then opens the department's role list |
| Non-IT role | `role-nonit-<dept>--<role>` | `SkillUpNonItDeepLinkScreen` → `SkillUpNonItRolesScreen(department: ...)` with that role's sheet auto-opened | Resolves asynchronously, opens the department's role list, then auto-opens the role's existing skill-chip sheet |

**Role-parent resolution approach**: a role id is always resolved through
its declared parent department (`(departmentSlug, roleSlug)` compound, both
halves required), never by role slug alone — role slugs are reused across
departments on the real site (confirmed real example: `devops-engineer`
exists under both `development` and `devops-infrastructure`). A dedicated
test (`skill_up_sections_route_test.dart`) exercises this exact
reused-slug case against the real `kTechCenterDepartments` data and confirms
each id resolves to its own distinct department.

**Fallback behavior**: a well-formed id whose department or role doesn't
exist in the catalog (deleted/renamed) falls through to the pre-existing
`SkillUpScreen(initialTabIndex: 1, initialSectionId: sectionId)` path — the
identical fallback an unrecognized `depth-*` id already received before this
phase, not a new behavior.

## Tests added/modified

- `test/features/skill_up/domain/skill_up_deep_link_test.dart` (new, 18
  tests) — `parseSkillUpDeepLinkId` for all 4 categories, the `depth-*`/
  null/empty/malformed-id null-return cases, the reused-role-slug parsing
  case, `findTechCenterDepartment`/`findTechCenterRole` resolution and
  cross-department scoping, `slugifyNonItName` against two real names, and
  `findNonItDepartment`/`findNonItRole` resolution/scoping.
- `test/app/router/skill_up_sections_route_test.dart` (new, 10 tests) —
  exercises `buildSkillUpSectionsScreen` directly against the real
  `kTechCenterDepartments` data: correct screen type and department/role for
  each category, the real reused-role-slug case, Non-IT ids routing to the
  resolver screen, unresolvable-but-well-formed ids falling back to
  `SkillUpScreen`, the pre-existing `depth-*` ids and a missing id remaining
  unchanged, and malformed ids not crashing.
- `test/features/skill_up/presentation/screens/
  tech_center_roles_screen_test.dart` (modified, +3 tests in a new "Phase 79
  — role deep-link highlighting" group) — no-highlight case unchanged;
  scrolling the 11th role of an 11-role department into a 700px-tall
  viewport (asserting its resolved `topLeft.dy` ends up inside the
  viewport); an unknown `highlightRoleSlug` doesn't crash. The pre-existing
  Phase 77 5-course-overflow test was adapted to the new `_pump` helper
  signature (passing `surfaceSize` instead of setting `tester.view`
  directly) with no change to its own assertions.
- `test/features/skill_up/presentation/screens/
  skill_up_nonit_roles_screen_test.dart` (modified, +4 tests in a new "Phase
  79 — role deep-link auto-open" group) — a pending request opens the
  correct role's sheet automatically; the request is cleared after being
  consumed (verified via a `ProviderContainer`, so it doesn't reopen on
  rebuild); a pending request for a role that doesn't exist in this
  department is silently ignored (no crash); no pending request leaves
  normal navigation unchanged.
- `test/features/skill_up/presentation/screens/
  skill_up_nonit_deep_link_screen_test.dart` (new, 5 tests) — a loading
  indicator shows while the catalog is still fetching (held open with a
  `Completer`); a department id resolves and navigates correctly; a role id
  resolves, navigates, and auto-opens that role's sheet; an unresolvable
  department id falls back to the plain departments list without crashing;
  a catalog load failure shows the existing retryable `AppErrorView`.

## Exact commands executed and results

- `dart format --output=none --set-exit-if-changed <12 Phase 79 files>` →
  initially reported 11 of 12 files would change (1 already compliant);
  `dart format` (no `--output=none`) applied the fix; re-running
  `--set-exit-if-changed` → **0 files changed, exit code 0**.
- `flutter analyze` (whole project, after formatting) → found 3 pre-existing
  **info**-level lint issues (`curly_braces_in_flow_control_structures`) in
  2 of the new files — fixed by adding braces to the 3 single-line `if`
  bodies; re-formatted those 2 files; re-ran `flutter analyze` →
  **No issues found!**
- `flutter test test/features/skill_up/ test/app/router/
  test/shared/widgets/app_nav_drawer_test.dart` → **219/219 passed**
  (Skill-Up screens/navigation/deep-links/lesson URL/WebView/Non-IT/Tech
  Center, all router/route-guard tests including Phase 77/78's groups, and
  the full nav-drawer suite including Phase 73's employer branch).
- `flutter test` (complete suite) → **2,929 tests, all passed, 0 failures**
  (2,878 from before this phase + 51 new Phase 79 tests).

No pre-existing failures were found; nothing needed to be distinguished from
a newly-introduced one.

## Emulator verification (distinguished from automated tests)

- Used the already-running `Android_Emulator_34` AVD (`emulator-5554`) — not
  wiped, recreated, or newly created.
- `flutter run -d emulator-5554` built and launched the app successfully
  (confirmed via the Dart VM Service URL and steady frame rendering in the
  run log; the earlier Kotlin-Gradle-Plugin warning is a pre-existing,
  unrelated plugin notice, not a build failure).
- Captured screenshots under `docs/audit_evidence/phase79/`:
  - `01_guest_home.png` — guest home loads cleanly, including the existing
    "Which path suits you?" popup.
  - `02_guest_drawer.png` — the nav drawer opens unchanged.
  - `03_skillup_expanded.png` — the Skill Up submenu expands, showing the
    existing "Tech" item (Phase 72's `depth-tech` destination, the catalog
    this phase's Tech Center deep links also read from) unaffected.
  - `04_guest_tech_login_gate.png` — tapping "Tech" as a guest correctly
    redirects to the Job Seeker Sign In screen — **live confirmation that
    `skillUpSections`'s route guard still fires before any of this phase's
    new deep-link resolution logic runs**, since `depth-tech` and all 4 new
    deep-link categories share the exact same guarded route.
- **This is genuine, live, on-device confirmation that the route guard
  protecting `skillUpSections` is unchanged and still blocks guest access**
  — a real interaction on a real emulator, not source inspection.
- **No authenticated candidate or employer device verification of the 4 new
  deep-link categories was performed.** No authorized test account is
  available (consistent with every prior phase of this project). Each
  category's actual resolution (correct department opens, correct role
  highlighted/auto-opened, correct parent department for a reused role
  slug, graceful fallback for an unresolvable id) is verified by the 51 new
  automated tests above — which exercise the real `kTechCenterDepartments`
  catalog and realistic Non-IT fixtures directly — and by direct reading of
  the real Django view/regex and the real static bundle's own ids, not by
  live authenticated navigation.

## Focused test totals

- Skill-Up + router + nav-drawer regression run: 219/219.
- Phase 79's own 5 new/modified test files: 51/51 (18 + 10 + 10 + 8 + 5).

## Full test-suite total

2,929/2,929, 0 failures.

## Analyzer and formatting results

- `flutter analyze` (whole project): No issues found! (3 info-level lint
  issues found mid-phase were fixed, not suppressed or ignored.)
- `dart format` on all 12 changed/new Phase 79 files: compliant, confirmed
  via `--set-exit-if-changed` returning exit code 0 with 0 files changed.

## Remaining limitations and unverified behavior

- Authenticated (candidate and employer) live device verification of all 4
  new deep-link categories remains a recommended follow-up once a test
  account is available — see "Emulator verification" above for exactly
  what live verification could and couldn't cover as a guest.
- The `state.extra! as ...` null-crash risk flagged in Phase 78 as a
  systemic, router-wide characteristic (not Skill-Up-specific) remains
  unaddressed — unchanged from Phase 78's own assessment, and still out of
  this phase's declared scope.
- Non-IT department-level (`grp-nonit-*`) deep links have no confirmed
  real-site UI that generates them (only `role-nonit-*` links were found
  being generated, from `landing.html`'s Career Paths explorer) — they are
  implemented because the server's own regex accepts them and the hub's
  internal "back" link format implies they're a reachable, intentional
  shape, but no live example of the real site itself navigating to one was
  observed this phase (none was available without an authenticated
  session).

## Scope-safety confirmation

- Every changed/new file is inside the Flutter project
  (`Mobile_app/lib/...`, `Mobile_app/test/...`,
  `Mobile_app/docs/audit_evidence/phase79/...`). Confirmed via `git status`
  scoped to this repository, which is rooted at `Mobile_app/` — both Django
  reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) live
  outside this repository entirely and were only ever read, never written.
- No backend API, database schema, migration, authentication/authorization
  logic, subscription rule, or deployment/signing configuration was
  changed.
- No existing, uncommitted work from Phases 52–78 was discarded — confirmed
  by the full 2,929-test suite passing (includes every prior phase's own
  tests) and by live emulator verification matching the previously-verified
  guest drawer/Skill-Up-gate structure.
- Phase 72's `depth-*` section ids and Phase 77/78's route-guard/
  access-control behavior are unchanged — confirmed by
  `skill_up_sections_route_test.dart`'s own `depth-*`-id regression test and
  by `route_guards_test.dart`'s full 44-test suite (Phase 77/78's groups
  included) passing unchanged.
- No new dependency was added.
- Nothing was committed or pushed.

## Stop point

Per the task brief, this phase is complete and this is the final
deliverable for Phase 79. No Phase 80 or other expanded-scope work has been
prepared or started; proceeding requires explicit approval.
