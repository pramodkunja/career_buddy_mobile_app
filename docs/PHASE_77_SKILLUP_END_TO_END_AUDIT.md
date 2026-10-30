# Phase 77 — Skill-Up End-to-End Parity & Regression Audit

## Scope

A focused end-to-end audit of the Skill-Up feature's cumulative state after
Phases 71–76: navigation, the Tech Center catalog, lesson URL
construction/WebView behavior, access controls, layout, and regression
coverage. Audit first; only confirmed defects were fixed.

## A. Navigation and route registration

**Inspected**: `lib/app/router/route_paths.dart`, `app_router.dart`, the
drawer (`app_nav_drawer.dart`), `skill_up_screen.dart`'s entry points,
`tech_center_departments_screen.dart`/`tech_center_roles_screen.dart`/
`tech_center_role_sheet.dart`.

- Every Skill Up / Tech Center route path is a distinct string literal
  (`skillUp`, `skillUpSections`, `skillUpCertifications`, `skillUpLesson`,
  `skillUpNonIt`, `skillUpNonItRoles`, `techCenterDepartments`,
  `techCenterRoles`) and registered in `app_router.dart` **exactly once
  each** (verified by direct grep count — no duplicate `GoRoute` for any of
  them).
- Department → role → course → lesson navigation, and back-navigation at
  each level (departments list → roles list → course sheet → lesson
  WebView, and the reverse), are exercised directly by this phase's own
  re-run of Phase 76's test suite (`tech_center_departments_screen_test.dart`,
  `tech_center_roles_screen_test.dart`) — all still pass, no regression.
- The existing flat Tech Center lessons (29 entries in `skill_up_data.dart`)
  and the Non-IT Center's own department/role flow are untouched; their own
  test suites still pass in full.
- Employer navigation: `app_nav_drawer_test.dart`'s full 51-test suite
  (guest/candidate/employer branches, including the Phase 73/74 employer
  identity tests) passes unchanged — nothing in this phase touches any
  employer-facing code path.
- Deep links/query parameters (`RoutePaths.skillUpSectionsFor`, the Phase 72
  section-anchor deep-linking) are unaffected — their own tests in
  `skill_up_screen_test.dart` still pass; this phase added no query
  parameters anywhere.

**Verdict: PASS.** No broken, duplicated, or regressed navigation entry
found.

## B. Tech Center catalog integrity

**Inspected**: `tool/generate_tech_center_catalog.dart`,
`tech_center_catalog.g.dart`, `tech_center_catalog.dart` (entities),
`tech_center_catalog_test.dart`.

Re-ran the generator against the current `royalStaffing_CB01` checkout:
```
Parsed 10 departments, 93 roles, 383 courses from index.html.
Found 383 nested .html files on disk under TechCenter/.
Cross-validation: every on-disk nested file is linked, and every linked path exists on disk. Exact match.
```
The Django source has not changed since Phase 76 — counts are identical.
**Diffed the freshly-regenerated file against the one already committed in
the working tree: byte-for-byte identical (after `dart format`, which is
already applied to the checked-in file).** The generator is deterministic
and reproducible, confirmed by an actual second run, not assumed. It still
takes the Django root as a required CLI argument — no hardcoded machine
path exists anywhere in the script or the generated output.

All 7 catalog validation tests pass, including the uniqueness checks for
the 3 real cross-department role-slug reuses (`devops-engineer`,
`manual-qa-tester-test-analyst`, `product-marketing-manager-pmm`) and the
path-nesting check that would catch a mismatched parent reference.

**Verdict: PASS.** No missing, orphaned, duplicate, or incorrectly-linked
entries; generation is reproducible and un-hand-edited.

## C. Lesson URL construction and WebView behavior

**Inspected**: `buildSkillUpLessonUrl`, `skill_up_lesson_url_test.dart`,
`skill_up_lesson_screen.dart`, `skill_up_lesson_screen_test.dart`,
`EnvironmentConfig`.

- `lib/app/config/environment.dart` and
  `lib/features/skill_up/domain/skill_up_lesson_url.dart` have **zero
  uncommitted changes** (confirmed via `git diff --stat`, empty output) —
  neither file has been touched by any phase up to and including this one.
  Environment selection and the production-default behavior are unchanged.
- All 383 nested `relativePath` values in the generated catalog contain
  only alphanumerics, hyphens, underscores, dots, and `/` — none need
  percent-encoding beyond what `buildSkillUpLessonUrl`'s existing
  per-segment `Uri.encodeComponent` already does safely for every other
  lesson path in this app. No double-encoding or path-duplication risk was
  found for Tech Center's own paths specifically.
- Android back-navigation (`PopScope` + `WebViewController.canGoBack`/
  `goBack`, added in Phase 75) was re-run via
  `skill_up_lesson_screen_test.dart`'s full 8-test suite — still passes,
  confirming the WebView-internal-history-first behavior is intact and
  unaffected by Phase 76's unrelated changes (Phase 76 never touched this
  file).
- Fullscreen/custom-widget handling: re-confirmed via a repo-wide grep that
  no code anywhere under `lib/` calls `setCustomWidgetCallbacks` or
  references `WebChromeClient`/`onShowCustomView` — the
  `webview_flutter_android` package's own default fullscreen handler
  (confirmed present in Phase 75) remains unoverridden and therefore still
  active; nothing in Phases 76–77 could have broken it, since nothing
  touches this surface.
- `WebViewController` (the `webview_flutter` 4.14.1 app-facing class) has
  **no `dispose()` method in its public API at all** — confirmed by reading
  the package source directly. `SkillUpLessonScreen` correctly has no
  `dispose()` override; there is nothing to call. This is not a resource
  leak — the underlying platform view is released automatically by
  Flutter's own widget-tree disposal when `WebViewWidget` is removed, the
  same way every other platform view in this app works. **Not a defect.**
- Loading/error/empty/retry states (403-locked view, main-frame vs.
  sub-resource error handling, retry re-triggering the load) were
  re-verified via the same 8-test suite — all pass, unchanged since Phase
  75.
- No change in this phase weakens authentication or exposes protected
  lesson content — `SkillUpAccessMiddleware`'s server-side gating and the
  cookie-forwarding `_loadLesson()` logic are both untouched.

**Verdict: PASS.** No defect found in URL construction or WebView behavior.

## D. Authentication and access controls

**Inspected**: `route_paths.dart`'s `publicRoutes`/`universalRoutes`/
`employerProtectedRoutes`, `route_guards.dart`, `route_guards_test.dart`.

- Confirmed directly: `techCenterDepartments` and `techCenterRoles` appear
  in `route_paths.dart` **only at their own definitions** — not in any of
  the 3 special-purpose route lists. This was previously verified only
  informally in Phase 76; this phase adds **explicit, dedicated test
  coverage** (3 new tests in `route_guards_test.dart`, see Section F) that
  would fail immediately if either route were ever accidentally added to an
  allowlist in the future.
- An unauthenticated hit on either route bounces to the student login
  (`computeRedirect` returns `RoutePaths.login`); an authenticated candidate
  session reaches both with no redirect — both confirmed by the new tests,
  not just source reading.
- Employer navigation and role rules: unaffected, confirmed by the full
  `app_nav_drawer_test.dart` suite passing unchanged.
- Subscription restrictions: unaffected — Tech Center's own server-side
  gating is `SkillUpAccessMiddleware`'s existing `TechCenter/**` prefix
  check (established in Phase 38/75), not re-implemented or touched here.
- **Logout/account switching and stale content**: `kTechCenterDepartments`
  is a compile-time `const` catalog with **zero per-user state** — no
  provider, no fetch, no cache keyed by account. There is nothing for a
  logout or account switch to leave stale, by construction, not by a
  cleanup mechanism that could regress. This was verified by inspection
  (the catalog and both new screens take no user-specific input anywhere in
  their type signatures), not asserted without basis.
- **No authorized test credentials were available**, so no authenticated
  live flow was exercised on-device this phase (see emulator section
  below) — this is an explicit, acknowledged limitation, not a gap this
  phase could close.

**Verdict: PASS**, with authenticated live verification explicitly marked
**not verified** (no credentials available).

## E. Layout, accessibility, and error handling

**Inspected**: `tech_center_departments_screen.dart`,
`tech_center_roles_screen.dart`, `tech_center_role_sheet.dart`,
`skill_up_screen.dart`'s entry-point button.

**Confirmed defect (fixed this phase)**: `TechCenterRoleSheet` overflowed
vertically on a short/landscape-sized viewport (reproduced at
`Size(800, 320)`, logical) for a role with 5 courses and a long title — a
real, existing data case (e.g. "VP Sales & Marketing / Chief Commercial
Officer (CCO)" genuinely has 5 courses in the generated catalog). Root
cause: the sheet's content was a plain, non-scrolling `Column` inside
`SafeArea`. Severity: **Medium** — not a crash, but real content below the
fold would be genuinely unreachable/overflowing on an affected device
orientation/size. Evidence: a reproducible widget test at the above surface
size threw a `FlutterError` ("A RenderFlex overflowed by 111 pixels on the
bottom") before the fix, and passes clean after it. Fixed by wrapping the
content in a `SingleChildScrollView` (see Implementation Report).

**Re-checked, no defect found**:
- `_DepartmentCard`'s and `_RoleCard`'s title text wraps safely (Flutter's
  default `Text` behavior) for long department/role names like "Project
  Management / Agile & Delivery" or "Quality Assurance (QA) / Testing" —
  no fixed-height container constrains it, so multi-line wrap is graceful,
  not an overflow.
- The Phase 76 role-card category-text overflow (long category strings like
  "Product and Engineering" combined with the course-count badge) was
  already found and fixed **during Phase 76 itself** (confirmed by reading
  the current source: the category `Text` is wrapped in `Flexible` with
  ellipsis, and the role title uses `maxLines: 2` with ellipsis) — re-run
  here as a regression check, still passing, not a new finding.
- Empty-state handling (`TechCenterDepartmentsScreen` with zero departments,
  `TechCenterRolesScreen` with zero roles) is present and tested; both
  render a plain, muted message with no exception.
- Tap targets use the same `InkWell` + stable `Key` convention already
  established by `SkillUpNonItDepartmentsScreen`/`...RolesScreen` — no
  inconsistency found.

**Verdict: 1 confirmed defect (fixed), no other layout/accessibility
defects found.**

## F. Regression coverage

Reviewed existing coverage before adding anything new. Added:
- **3 new tests** in `route_guards_test.dart` (Section D) — a confirmed
  gap: neither `techCenterDepartments` nor `techCenterRoles` had any
  dedicated route-guard test before this phase (Phase 76 only verified this
  informally by source reading).
- **1 new test** in `tech_center_roles_screen_test.dart` — the confirmed
  overflow defect (Section E), as a permanent regression guard using the
  real 5-course-role shape.

Did **not** add: broad new test infrastructure, coverage for routes outside
this phase's declared scope, or speculative tests for scenarios this audit
did not actually find evidence for.

## Findings summary

| # | Finding | Category | Severity |
|---|---|---|---|
| 1 | `TechCenterRoleSheet` overflows on a short/landscape viewport for a real 5-course role | Confirmed defect | Medium — fixed |
| 2 | Neither new Tech Center route had dedicated route-guard regression coverage | Confirmed gap (coverage, not behavior) | Low — fixed |
| 3 | No pre-existing Skill Up route (not just the 2 new ones) has dedicated `route_guards_test.dart` coverage | Existing limitation, pre-dates Phase 71–76 | Out of this phase's scope — documented, not fixed |
| 4 | Generator reproducibility, catalog integrity, WebView back-nav, fullscreen handling, `WebViewController.dispose()` absence, environment-config stability | Re-verified, no defect | N/A |
| 5 | Authenticated live navigation/content verification | Unverified — no test account available | N/A |

## What could not be verified

- Any authenticated session's live navigation through
  `TechCenterDepartmentsScreen`/`TechCenterRolesScreen` into a real nested
  lesson's WebView — blocked by the absence of an authorized test account,
  the same limitation stated in every prior phase of this project.
- Whether `SkillUpAccessMiddleware` gates a sample of the 383 nested pages
  identically to the already-verified flat ones, live — not re-tested this
  phase (the middleware's own `TechCenter/**` prefix check was already
  established in Phase 38/75 and was not touched).
