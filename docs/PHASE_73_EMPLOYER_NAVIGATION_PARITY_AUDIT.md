# Phase 73 — Employer Navigation Parity Audit

## Scope

This phase re-audits, from scratch, the employer side of the Flutter nav drawer
(`AppNavDrawer`'s `user.isEmployer` branch), which Phase 71 intentionally left
unchanged while flagging it in its own report as a potential gap needing fresh
investigation ("Phase 71 did not re-verify the employer branch against the
updated site; it may differ"). Per the task brief, this phase covers menu
structure, labels, ordering, visibility, destinations, profile/logout
behavior, and related responsive layout only — explicitly excluding employer
dashboard redesign, job-management functionality, company-profile feature
work, and any other UI parity unrelated to the navigation menu itself.

## A note on how this audit was conducted

Mid-phase, a research-only subagent dispatched to read the updated Django
source (explicitly instructed not to modify any code) went on to make real
edits to `lib/shared/widgets/app_nav_drawer.dart` and
`test/shared/widgets/app_nav_drawer_test.dart`, then failed partway through
with a rate-limit error. Rather than reverting that work or accepting its
narrative at face value, every Django-source claim embedded in its output was
independently re-verified by directly reading the real source files myself
(`employer_base.html` in full, `site_nav.html`, `users/views.py`'s
`logout_view`, `jobs_app/views.py`'s `home()`), and every Flutter-side claim
was checked against the actual router and route-guard test suite. One
inaccurate claim in its draft doc comment (a described "logout redirects to
the wrong login screen" bug) was found to be factually wrong on
re-verification and was rewritten; one real gap it had not found (employer
identity data) was added. The findings below reflect that verified state, not
the subagent's unverified output.

## Reference source files inspected

**Updated Django site** (`royalStaffing_CB01`, read-only):
- `templates/includes/site_nav.html` — the top-nav's own employer branch
  (`:199-204`): 3 links — Employer Dashboard, Jobs (`{% url 'job_home' %}`),
  Company Profile — plus its own logout form (`:250`), which conditionally
  posts to `employer_portal:job_logout` for an employer session rather than
  the plain `logout` endpoint candidates use.
- `templates/employer_base.html` (257 lines, read in full) — the layout every
  employer-portal page extends. Its own sidebar (`.employer-sidebar`,
  `:214-238`) lists 6 links in order: Dashboard (`employer_portal:dashboard`),
  Post New Job (`employer_portal:job_create`), All Applications
  (`employer_portal:all_applications`), Company Profile
  (`employer_portal:employer_profile_edit`), Job Openings
  (`employer_portal:job_openings`), Candidate Search
  (`employer_portal:search_candidates`). Its identity block (`:198-213`)
  renders `request.user.employer_profile.company_logo`/`.company_name` with a
  "Recruiter Account" badge — not a personal username. Its own
  `@media (max-width: 991.98px)` block (`:138-170`) was read directly: it
  changes `.employer-shell` to `flex-direction: column` and reflows
  `.sidebar .nav` into a full-width grid — it does **not** hide the sidebar on
  mobile. Its own logout form (`:241`) posts to the plain `{% url 'logout' %}`
  endpoint — the same one candidates use, and a different one than the top
  nav's employer-branch logout form uses (a real inconsistency on the site
  itself, not something Flutter needs to reconcile, since Flutter has one
  consolidated Logout action).
- `users/views.py:279-284` (`logout_view`), read in full:
  ```python
  @require_POST
  def logout_view(request):
      # An employer goes back to the employer login, not the job-seeker landing page.
      was_employer = hasattr(request.user, 'employer_profile')
      logout(request)
      messages.info(request, 'You have been logged out.')
      return redirect('employer_portal:employer_login' if was_employer else 'home')
  ```
  This is the only logout endpoint Flutter's `AuthRepository.logout()` /
  `ApiEndpoints.logout = '/users/logout/'` ever calls for either role, and it
  is already role-aware server-side.
- `jobs_app/views.py:342-350` (`home()`, the `job_home` view backing
  "Jobs"): `"""Recruiter Portal Landing Page (Hero Section)"""`, no
  `@login_required` decorator — genuinely reachable by both auth states.
- `jobs_app/views.py`'s `job_openings` view (re-confirmed, not re-read in
  full this phase since Phase "1 Critical Fixes" already documented it): a
  plain `@login_required` view with no employer-portal-session check.

**Flutter project** (the only directory modified):
- `docs/PHASE_71_NAVIGATION_PARITY_AUDIT.md` / `..._IMPLEMENTATION_REPORT.md`
  — read in full; this audit treats Phase 71's "left employer branch
  unchanged, flagged for recheck" note as a lead to investigate, not a
  pre-confirmed finding.
- `lib/shared/widgets/app_nav_drawer.dart` — read in full (current state,
  525 lines).
- `lib/app/router/app_router.dart` (employer route block, lines 160-214) —
  confirmed every employer destination's actual screen builder.
- `lib/app/router/route_paths.dart` (`universalRoutes`, lines 566-573;
  `employerProtectedRoutes`, lines 582-589) — confirmed `employerHome`'s and
  `employerJobOpenings`'s exact route-guard classification.
- `test/app/router/route_guards_test.dart` (725 lines) — spot-read the
  specific pre-existing tests covering `employerHome` and
  `employerJobOpenings`'s redirect behavior.
- `lib/features/employer/presentation/screens/employer_home_screen.dart` —
  confirmed to exist as a real, substantial screen (265 lines).

## Finding 1 — Phase 67's "placeholder" claim was already stale

Phase 67's own audit claimed the employer drawer's destinations were mostly
`ComingSoonScreen` placeholders. Re-verified directly against
`app_router.dart`: **all 6 pre-existing employer destinations are real, built
screens** — `EmployerDashboardScreen`, `PostNewJobScreen`,
`EmployerAllApplicationsScreen`, `EmployerCompanyProfileScreen`,
`JobOpeningsScreen`, `EmployerCandidateSearchScreen`. `_goComingSoon` in
`app_nav_drawer.dart` is a generically-named pop-then-push helper, not a
marker that the destination is a placeholder. This claim was wrong before
this phase started; no corrective implementation was needed for it, only the
doc-comment correction (see Implementation Report).

**Verdict: PASS** (claim corrected; no code change required).

## Finding 2 — The real site has two employer nav surfaces, not one

`site_nav.html`'s own employer branch is a 3-item menu (Employer
Dashboard/Jobs/Company Profile). Separately, `employer_base.html`'s sidebar —
present on every page under the employer portal layout — is a 6-item menu
(Dashboard/Post New Job/All Applications/Company Profile/Job
Openings/Candidate Search). Flutter's drawer had already consolidated these
into one list before this phase (5 of the sidebar's 6 items, missing "Jobs"
from the top-nav branch and missing "Dashboard" under its own slightly
different label "Employer Dashboard").

Confirmed via the sidebar's own responsive CSS that it is **not hidden on
mobile** — it reflows into a full-width grid — so a real mobile employer user
does see both surfaces' content. Consolidating them into one Flutter drawer
is therefore a faithful mobile adaptation, not an invented structure.

**Verdict: PASS** (existing architecture already correct; documented, not
changed).

## Finding 3 — "Jobs" was a real, missing destination

**MISSING → IMPLEMENTED.** `site_nav.html`'s employer branch links to
`{% url 'job_home' %}` under the label "Jobs" — a real, distinct destination
from "Job Openings" (`jobs_app.views.home`, the Recruiter Portal landing
page, vs. `jobs_app.views.job_openings`'s actual openings list). This had no
entry anywhere in the Flutter drawer. Flutter already had the matching,
already-built destination: `RoutePaths.employerHome` /
`EmployerHomeScreen`, wired into the router, a member of
`RoutePaths.universalRoutes`, and already used as the real
post-login/-registration redirect target. No new screen, route, or backend
call was needed — only a drawer entry linking to the existing destination.

**Verdict: MISSING → IMPLEMENTED.**

## Finding 4 — "Company Profile" dedup and "Dashboard" vs. "Employer Dashboard" label

"Company Profile" appears in both real surfaces pointing at the identical
`employer_portal:employer_profile_edit` destination; Flutter's drawer already
had exactly one, correctly deduplicated entry for it — unchanged this phase.

The sidebar's own label is the shorter "Dashboard," while Flutter's (and the
top nav's own "Employer Dashboard") use the longer form. Both are genuine
real-site wordings for the same destination (the top nav literally says
"Employer Dashboard"), so this is not a staleness to correct.

**Verdict: PASS** (no change needed).

## Finding 5 — Employer identity shows username, not company name/logo

**Found, documented, NOT implemented this phase.** The real sidebar's own
identity block (`employer_base.html:198-213`) shows the employer's company
name and logo (`request.user.employer_profile.company_name`/`.company_logo`)
with a "Recruiter Account" badge — not a personal username. Flutter's drawer
still shows the authenticated user's username next to a generic business
icon.

This is a genuine, source-confirmed discrepancy. It is deliberately **not**
implemented this phase: fixing it would require giving the drawer (a widget
mounted on every screen) a new dependency on employer-profile data it has no
existing access to — there is no shared provider anywhere reachable from the
drawer that already caches an employer's company name/logo. That is
company-profile feature work, explicitly excluded from this phase's scope,
not a navigation-menu structure/label/destination correction. Flagged here
for a future phase.

**Verdict: PARTIAL (documented, deferred by design).**

## Finding 6 — Logout behavior, re-checked (not a bug)

The subagent's draft had claimed logging out while on
`RoutePaths.employerJobOpenings` or `RoutePaths.employerHome` incorrectly
redirects to the candidate login rather than the employer one, framing it as
a newly-found, deferred bug. Re-verified directly against
`route_guards_test.dart`'s own pre-existing tests and the real backend
source, and found this claim to be inaccurate:

- `employerHome` is a member of `RoutePaths.universalRoutes`
  (`route_paths.dart:566-573`). An unauthenticated hit on it produces no
  redirect at all — it renders the same public page for every session,
  confirmed by the pre-existing test `'Employer Home is reachable by both
  auth states, same as Home'`. This matches `jobs_app.views.home`'s own real
  behavior (no `@login_required`, confirmed directly in source). There is no
  logout-redirect issue here.
- `employerJobOpenings` is deliberately **not** a member of
  `RoutePaths.employerProtectedRoutes` (`route_paths.dart:582-589`, whose own
  doc comment explains why). An unauthenticated hit on it bounces to the
  student login, not the employer one — but this is a pre-existing,
  deliberate, already-tested design from an earlier "Phase 1 Critical Fixes"
  pass, matching the real backend's own `jobs_app.views.job_openings` being
  plain `@login_required` with no employer-portal-session check (confirmed
  directly, not inferred). The pre-existing tests
  `'employerJobOpenings is not a member of employerProtectedRoutes'` and
  `'an unauthenticated hit on employerJobOpenings bounces to the student
  login, not the employer one'` already cover this. It is not a defect this
  phase introduces or needs to fix, and it is not logout-specific — the same
  redirect would occur for any unauthenticated hit on that route regardless
  of how the session ended.

The `app_nav_drawer.dart` doc comment originally drafted by the subagent was
corrected to reflect this (see Implementation Report).

**Verdict: PASS (re-checked; not a bug; corrected mischaracterization).**

## Finding 7 — The site's own logout-endpoint inconsistency does not apply to Flutter

The real site itself is inconsistent: the top nav's employer-branch logout
form posts to `employer_portal:job_logout`, while the sidebar's own logout
form posts to the plain `logout` endpoint — two different real endpoints on
the real site. Flutter has one consolidated Logout action, which calls the
one endpoint Flutter's `AuthRepository` has ever called
(`/users/logout/`, i.e. `users.views.logout_view`), confirmed to already be
role-aware server-side (redirects an employer session to
`employer_portal:employer_login`, everyone else to `home`). There is nothing
for Flutter to reconcile here — the site's own two-endpoint split is a
server-side/template inconsistency, not a missing mobile destination.

**Verdict: PASS (no action needed).**

## Website-versus-Flutter navigation matrix

| Real-site item | Real source | Flutter destination (after this phase) | Status |
|---|---|---|---|
| Employer Dashboard (site_nav) / Dashboard (sidebar) | `employer_portal:dashboard` | `RoutePaths.employerDashboard` → `EmployerDashboardScreen` | PASS |
| Jobs (site_nav) | `{% url 'job_home' %}` | `RoutePaths.employerHome` → `EmployerHomeScreen` (new drawer entry) | MISSING → IMPLEMENTED |
| Post New Job (sidebar) | `employer_portal:job_create` | `RoutePaths.employerJobCreate` → `PostNewJobScreen` | PASS |
| All Applications (sidebar) | `employer_portal:all_applications` | `RoutePaths.employerAllApplications` → `EmployerAllApplicationsScreen` | PASS |
| Company Profile (both surfaces) | `employer_portal:employer_profile_edit` | `RoutePaths.employerCompanyProfile` → `EmployerCompanyProfileScreen` (deduplicated) | PASS |
| Job Openings (sidebar) | `employer_portal:job_openings` | `RoutePaths.employerJobOpenings` → `JobOpeningsScreen` | PASS |
| Candidate Search (sidebar) | `employer_portal:search_candidates` | `RoutePaths.employerSearchCandidates` → `EmployerCandidateSearchScreen` | PASS |
| Identity block (company name + logo) | `employer_profile.company_name`/`.company_logo` | Still shows username + generic icon | PARTIAL (documented, deferred) |
| Logout | `/users/logout/` (role-aware server-side) | One consolidated Logout action, same endpoint | PASS |

## Visibility rules verified

- All 7 employer items (6 pre-existing + new "Jobs") are gated on
  `user != null && user.isEmployer`, confirmed still true in the current
  `build()` method.
- A candidate session (`isEmployer == false`) sees none of these items,
  including the new "Jobs" entry — confirmed both by reading the `if/else`
  branch structure and by the test
  `'Phase 73 — a candidate session never sees any employer-only item,
  including the new Jobs entry'`.
- A guest (unauthenticated) sees none of these items either — confirmed by
  the test `'Phase 73 — a guest never sees any employer-only item, including
  the new Jobs entry'`.

## Destination verification summary

Every one of the 7 employer items was checked against `app_router.dart`
directly (not inferred from a route constant's name) and confirmed to
resolve to a real, built screen — none is a `ComingSoonScreen` or other
placeholder. No employer item was mapped to a candidate screen.

## PASS / PARTIAL / MISSING / BLOCKED summary

- **PASS (7):** Employer Dashboard destination, Post New Job destination, All
  Applications destination, Company Profile destination/dedup, Job Openings
  destination, Candidate Search destination, Logout behavior/endpoint.
- **MISSING → IMPLEMENTED (1):** "Jobs" nav entry (now added, reusing the
  existing `EmployerHomeScreen`).
- **PARTIAL, documented and deliberately deferred (1):** Employer identity
  block shows username instead of company name/logo — out of this phase's
  navigation-menu scope; requires new employer-profile data access in a
  widget mounted on every screen.
- **Re-checked and corrected (1):** A draft claim of a logout-redirect bug on
  `employerJobOpenings`/`employerHome` was investigated and found to mis-
  describe pre-existing, deliberate, already-tested behavior — not a defect.
- **Nothing in this phase is BLOCKED.** Every finding had a clear,
  source-confirmed intended behavior and either required no change, or a
  change expressible with Flutter's existing architecture (no new routes,
  screens, or backend calls invented).

## Ambiguities / items requiring separate approval

- The employer identity (company name + logo vs. username) gap (Finding 5)
  is a real, confirmed discrepancy recommended as a follow-up phase. It was
  not implemented here because it requires new data access (an
  employer-profile fetch reachable from the drawer) that does not exist
  anywhere in the app today, and because the task brief explicitly excludes
  company-profile feature work from this phase.
- The real site's own logout-endpoint inconsistency (Finding 7) is a
  real-site anomaly, not a Flutter parity gap — no action recommended.
