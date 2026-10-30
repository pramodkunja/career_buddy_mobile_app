# Phase 78 — Skill-Up Route Guard Coverage & Access-Control Audit

## Scope

A focused audit of route protection for the 8 Skill-Up route paths, closing
the test-coverage gap Phase 77 identified: `techCenterDepartments`/
`techCenterRoles` had dedicated route-guard tests, but `skillUp`,
`skillUpSections`, `skillUpCertifications`, `skillUpLesson`, `skillUpNonIt`,
and `skillUpNonItRoles` did not.

## Routes audited

`skillUp`, `skillUpSections`, `skillUpCertifications`, `skillUpLesson`,
`skillUpNonIt`, `skillUpNonItRoles`, `techCenterDepartments`,
`techCenterRoles` — the exact `RoutePaths` constants, read directly from
`lib/app/router/route_paths.dart`, not assumed from their names.

## What the real site actually requires (read directly, not assumed)

All 8 Flutter routes correspond to content reached only by navigating
within, or from, **one single real Django view**:
`riya_bot.skillup_views.skillup_hub` (`royalStaffing_CB01/riya_bot/
skillup_views.py:61-91`, read in full this phase):

```python
@login_required
@xframe_options_sameorigin
def skillup_hub(request):
    ...
```

- `@login_required` has **no `login_url=` override**, so an unauthenticated
  hit uses the project's global `LOGIN_URL = '/users/login/'`
  (`business_english_lms/settings.py:338`) — the **student** login, not the
  employer one.
- The view body (read in full) has **no employer-specific branch, no
  `request.session.get('portal')` check, and no role-based block of any
  kind** — any authenticated user, candidate or employer, gets the exact
  same rendered hub. The only content restriction inside the view is
  Free-plan locking (`has_full_skillup(request.user)`), which is unrelated
  to role and is enforced entirely server-side regardless of who's logged
  in.
- The `#depth-nonit` and `#depth-tech` department/role content (Non-IT
  Center, Tech Center) are sub-articles of this same page, not separate
  Django views — they share this exact same gate.
- Individual lesson pages (`skillUpLesson`) are plain static files gated by
  `SkillUpAccessMiddleware` (established in Phase 38/75) — a content-level
  restriction, not a Flutter-route-level one; the Flutter route itself is
  only reachable by navigating from an already-gated hub screen.

**This confirms, from source, that all 8 Flutter routes should share one
identical access policy**: bounce an unauthenticated user to the student
login; let any authenticated user (candidate or employer) through with no
redirect. Nothing in the Django reference establishes a different rule for
any one of the 8.

## Guest access

| Route | Expected | Actual (this phase's new tests) |
|---|---|---|
| `skillUp` | Redirect to student login | ✅ Confirmed |
| `skillUpSections` | Redirect to student login | ✅ Confirmed |
| `skillUpCertifications` | Redirect to student login | ✅ Confirmed |
| `skillUpLesson` | Redirect to student login | ✅ Confirmed |
| `skillUpNonIt` | Redirect to student login | ✅ Confirmed |
| `skillUpNonItRoles` | Redirect to student login | ✅ Confirmed |
| `techCenterDepartments` | Redirect to student login (already tested, Phase 77) | ✅ Still passes |
| `techCenterRoles` | Redirect to student login (already tested, Phase 77) | ✅ Still passes |

None of the 8 routes is in `RoutePaths.publicRoutes` or
`RoutePaths.universalRoutes` — confirmed by a new test that checks all 8 at
once, not assumed from the absence of a prior failure.

**Query parameters/extras during redirection**: `computeRedirect` receives
only `state.matchedLocation` — GoRouter's own matched *path*, with no query
string (confirmed by reading `app_router.dart:112-118` directly) — so a
guest hitting `skillUpSections?section=depth-tech` is redirected to the bare
login path with the query param correctly dropped, not carried onto the
login screen. This is the intended behavior (a content-anchor query param
has no meaning on the login page) and was not changed.

**Nested-route bypass** (`skillUpNonItRoles`/`techCenterRoles`, both of
which require a route `extra`): a direct hit on either path with no `extra`
would hit `state.extra! as ...` and throw — but this is a **pre-existing,
systemic pattern across 8 different routes in this router** (confirmed by
grep: `state.extra! as` appears 8 times in `app_router.dart`, not just for
these 2), the app has no `web/` target (confirmed: no `web/` directory
exists) and no external deep-link wiring was found, so this is not a
reachable guest-access bypass in practice — a crash-hardening question for
the whole router, not an access-control defect specific to Skill-Up or to
this phase's scope. Documented, not fixed (see "Existing limitations"
below).

## Authenticated candidate access

A new test confirms an authenticated candidate (`AuthAuthenticated(AuthUser
(username: 'jane'))`) reaches all 8 routes with `computeRedirect` returning
`null` (no redirect). Matches `skillup_hub`'s own plain `@login_required`
(any authenticated user passes).

## Employer access

**This is the genuinely new coverage dimension this phase adds** — Phase 77
never tested employer access for the 2 Tech Center routes, and no prior
phase tested it for the other 6 either.

A new test confirms an authenticated employer (`AuthAuthenticated(AuthUser
(username: 'acme', isEmployer: true))`) also reaches all 8 routes with no
redirect — directly matching the real `skillup_hub` view's own absence of
any employer/portal check. `route_guards.dart`'s own `computeRedirect`
(read in full) only special-cases two things for an authenticated session:
(1) `employerProtectedRoutes` membership + non-employer → redirect to the
student dashboard; (2) an exact hit on `RoutePaths.dashboard` while employer
→ redirect to the employer dashboard. None of the 8 Skill-Up routes is in
`employerProtectedRoutes` (confirmed by the same new test), and none of
them is `RoutePaths.dashboard`, so neither special case applies — an
employer session falls through to `return null` for all 8, exactly as
confirmed.

**Existing employer-specific routes and the Phase 73/74 employer drawer
identity**: unaffected — this phase touched no employer-facing file.
Re-ran `app_nav_drawer_test.dart`'s full 51-test suite (employer branch
included) and `test/features/auth/` in full — both pass unchanged.

## Subscription and content restrictions

Flutter's route guard is, and remains, purely a client-side UX convenience
— it never replaces or duplicates `SkillUpAccessMiddleware`'s or
`has_full_skillup()`'s server-side enforcement. No code in this phase
touches `SkillUpLessonScreen`'s cookie-forwarding or the server's own
Free-plan gating. `SkillUpLessonScreen`'s existing 403→locked-view handling
(Phase 38, re-verified in Phase 75/77) is the only client-side reaction to
this restriction, and it is unchanged. **Whether the server's own
Free-plan restriction actually blocks a real non-Free lesson for a real
Free-plan account could not be verified live this phase** — no authorized
test account is available; this is explicitly marked unverified, not
assumed working.

## Logout and account switching

Inspected whether any Skill-Up-related state could leak across a
login/logout cycle:
- `kTechCenterDepartments` (Phase 76) and `SkillUpData` (Batch 7) are both
  compile-time `const` catalogs with no per-user field anywhere in their
  type signatures — there is no user-specific value to leak, by
  construction.
- `skillUpNonItDepartmentsProvider` loads a bundled local JSON asset
  (`SkillUpNonItAssetDataSource.load()`) — identical for every account, not
  fetched per-user, and (confirmed by grep) not referenced anywhere in
  `AuthController._invalidateUserScopedProviders()`. This is correct, not a
  gap: there is nothing account-specific in this data to invalidate.
- The WebView's own native cookie store (separate from the app's Dio
  cookie jar, per Phase 38) is a platform-level, shared-across-WebViews
  store — the same way a real browser's cookies are shared across tabs.
  Logging out already calls Django's own `logout(request)` server-side
  (`users/views.py:279-284`, confirmed in Phase 73/74's own investigation),
  which invalidates the session **server-side** regardless of which cookie
  value a stale WebView-internal jar entry might still hold — so a leftover
  cookie from a previous session cannot be used to view content as that
  previous user after logout; the server will simply treat it as an expired
  session. This was verified by reasoning from the confirmed server-side
  invalidation behavior, not by reproducing it with two real accounts
  (unavailable). No reproducible defect was found, so no change was made —
  consistent with this phase's explicit instruction not to introduce
  unnecessary cache-clearing without evidence of a real problem.
- `test/features/auth/` (including `auth_controller_test.dart`'s own
  cross-account-leak regression suite) was re-run in full this phase — all
  pass, confirming no regression in the existing invalidation mechanism.

## Confirmed defects vs. existing limitations

**No access-control defect was found.** Every one of the 8 routes already
had the correct, source-matching behavior before this phase; the only gap
was missing *test coverage*, now closed.

**Existing limitations, documented but not fixed (out of this phase's
scope)**:
- The `state.extra! as ...` null-crash risk is systemic across 8 router
  destinations in this codebase, not specific to Skill-Up; fixing it for
  only 2 of them would be an arbitrary partial fix. A general
  route-argument-safety pass (if ever wanted) is a separate, larger phase.
- The real site's own `?section=` mechanism also accepts `grp-tech-*`/
  `role-tech-*`/`grp-nonit-*`/`role-nonit-*` values (confirmed via
  `_TECH_ROLE_RE` in `riya_bot/skillup_views.py:39`), meaning the real site
  supports deep-linking directly to a specific Tech Center/Non-IT
  department or role anchor. Flutter's `techCenterDepartments`/
  `techCenterRoles` routes currently accept no such parameter. This is a
  **content/navigation feature gap**, not an access-control defect, and is
  explicitly out of this phase's scope ("not an authentication redesign,"
  "no invented access rules," "no broad... UI changes") — flagged here for
  a future phase, not implemented.

## Unverified behavior

- Live, authenticated candidate and employer device verification of any of
  the 8 routes — no authorized test account is available (consistent with
  every prior phase of this project).
- Whether the server's Free-plan restriction actually blocks a real
  non-Free lesson for a real Free-plan account, live.
- Whether a stale WebView-internal cookie genuinely cannot access a
  previous account's content post-logout — reasoned from confirmed
  server-side session invalidation, not empirically reproduced with two
  real accounts.

**On test scope**: a passing `computeRedirect` unit test confirms the
*client-side routing decision* is correct — it is not, and cannot be, proof
that the *server* actually enforces the same rule. Every server-side claim
in this report is backed by directly reading the real Django view/decorator
source, not inferred from the Flutter test passing.
