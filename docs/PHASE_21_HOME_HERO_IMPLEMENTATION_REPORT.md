# Phase 21 — Flutter Home-Screen Hero Update Report

**Scope:** a focused replacement of the Home screen's hero section, matching
the updated web's unified 3-CTA hero. No Django file was modified in either
tree. No role-fit picker, manual resume builder, marketing sections,
mega-menus, or footer work was done.

## 1. Files changed

**New:**
- `lib/features/home/presentation/widgets/home_hero.dart` — the new
  `HomeHero` widget: brand badge, headline, subtitle, and the 3 stacked
  full-width CTAs (Get Started/Find Jobs/Create Resume). Shared by both the
  anonymous and authenticated-student branches (see §4); takes 3 callbacks
  so it carries no navigation/auth logic of its own.
- `test/features/home/presentation/widgets/home_hero_test.dart` — isolated
  widget tests for `HomeHero` (labels, callback wiring, responsive layout
  at 320-430px).

**Modified:**
- `lib/features/home/presentation/widgets/public_home_body.dart` — adds
  `HomeHero` above the existing, **unchanged** job-seeker/employer portal
  cards. 3 new required callbacks (`onGetStarted`/`onFindJobs`/
  `onCreateResume`); existing `onLogin`/`onRegister`/`onEmployerLogin`/
  `onEmployerRegister` untouched.
- `lib/features/home/presentation/widgets/authenticated_home_body.dart` —
  the employer branch (`isEmployer: true`) is **byte-for-byte unchanged**
  in behavior (same cards, same button labels/destinations) — see §4 for
  why. The non-employer (student) branch now renders the same `HomeHero`
  instead of the old hero-image-cards + "Parse Your Resume"/"My Dashboard"/
  "Browse Activities" button row. Constructor changed: `onParseResume`/
  `onDashboard`/`onBrowseActivities` replaced by `onGetStarted`/
  `onFindJobs`/`onCreateResume` (the employer-only `onEmployerDashboard`/
  `onFindCandidates` are untouched). `onBrowseActivities` was removed
  entirely, not deprecated — it had no other caller and no replacement
  slot in the new 3-CTA hero (Activities remains reachable via the nav
  drawer, which this phase does not touch).
- `lib/features/home/presentation/screens/home_screen.dart` — wires the 3
  CTA callbacks differently per branch (full reasoning in §3-4); updated
  its own doc comment to cite `landing.html` instead of the now-superseded
  `home.html`.
- `test/features/home/presentation/screens/home_screen_test.dart` — updated
  the 3 authenticated-student tests that asserted the now-removed old hero
  content/buttons; added new tests for the unified hero (labels, all 3 CTA
  destinations per branch, a responsive-overflow check). The guest-portal-
  card and all 3 employer tests needed **no changes** and still pass
  unmodified — confirming those paths are genuinely untouched.

## 2. What the updated hero looks like and how it adapts to mobile

Reproduces the web hero's headline verbatim ("Build skills. Craft
capability. Claim your career.", `landing.html:6542`) and a shortened
version of its lead paragraph, inside a navy gradient card (`AppColors
.primary`→`primaryDark`, matching the brand token set already used
elsewhere, e.g. `ResumeBuilderScreen`'s own hero) with a small "AI-powered
career platform" badge, mirroring the web's eyebrow text.

The 3 CTAs are **stacked, full-width buttons** rather than the web's
horizontal row (`landing.html:6545`) — every width this app targets is
narrower than where that row would still read cleanly, so a vertical stack
is the natural mobile adaptation, not a literal copy of desktop proportions.
"Get Started" is the filled/primary button (gold accent, matching the
brand's `.btn-primary` token); "Find Jobs"/"Create Resume" are outlined,
white-on-navy, matching the web's own `.btn-outline`/`.btn-navy` secondary
treatment. All 3 are 48px tall, full-width, single-tap targets.

Confirmed via a new isolated widget test (`home_hero_test.dart`) to render
without horizontal overflow at 320/360/390/430px.

## 3. Verified CTA destinations

All three were verified against the actual Django source (updated repo),
not assumed from the Phase 20 summary alone, per this phase's own
instruction.

**Get Started** (`landing.html:6546`, `/users/register/`, unconditional —
even for an already-logged-in visitor, a confirmed real web quirk):
- Anonymous → `context.push(RoutePaths.register)` — the exact same
  destination the existing "Register Free" button already uses.
- Authenticated (student or employer) → `context.go(RoutePaths.dashboard)`
  / `context.go(RoutePaths.employerDashboard)` respectively — **not**
  Register, per this phase's own explicit instruction not to send an
  already-authenticated user into a re-registration flow. This is a
  deliberate divergence from the web's literal (and, per the Phase 20
  audit, itself-unconditional-and-arguably-undesirable) behavior.

**Find Jobs** (`core/navigation.py`: `"job-match": Destination("Find Jobs",
"resume_analytics")`, `protected=True` by default): confirmed by direct
read that `resume_analytics` (`career_app/views.py:1775`) is
`@login_required`, additionally gated behind `_can_access_interview`
(paid plan), and falls back to `resume_builder` when the user has no
existing interview session at all — i.e. the web's own "Find Jobs" is
itself a funnel entry point, not a plain jobs list, for most first-time
visitors. Flutter has no screen that reproduces this exact funnel (doing
so would mean either inventing a new route or modifying the Mock
Interview feature's own start-up behavior, both out of this phase's
scope — `MockInterviewScreen`'s `start()` always creates a **new**
interview session, confirmed directly, so pointing "Find Jobs" at it would
misrepresent the destination entirely). Instead:
- Every branch (anonymous and authenticated student) →
  `context.push(RoutePaths.dashboard)`. Verified directly that
  `student_dashboard`'s own view (`activities/views.py:270-303`) computes
  `recommended_jobs` via the **same** `_get_matched_jobs` function
  `resume_analytics`/`resume_job_match` use, gated only on "has a passed
  interview session" — no paid-plan interview-access redirect, no
  "upload a resume first" redirect. Flutter's existing `DashboardScreen`
  already renders this via its real, built `RecommendedJobsSection`
  (`dashboard_screen.dart:114,149`) — confirmed this is live, working
  functionality, not a placeholder.
- For an anonymous visitor, `RoutePaths.dashboard` is not in
  `publicRoutes`/`universalRoutes` (`route_paths.dart`, confirmed directly),
  so the **existing, already-tested** auth guard
  (`route_guards.dart`/`route_guards_test.dart`) redirects to `/login`
  automatically — no new login-check code was added, matching the real
  `dashboard()` view's own `@login_required`.
- This is a **documented adaptation, not a literal 1:1 destination copy**:
  Dashboard is the most honest, already-real, zero-new-code destination
  available for "job recommendations" today, chosen specifically because
  it carries the identical underlying data the web's own "Find Jobs"
  ultimately surfaces once a user qualifies for it.

**Create Resume** (`landing.html:6552`, `#create-resume` anchor → the
not-yet-built manual resume builder, confirmed Missing in Phase 20):
- Every branch → `context.push(RoutePaths.resumeBuilder)` — the existing,
  fully real `ResumeBuilderScreen` (Phases 18-19). This is **not** the
  manual builder the web's own "Create Resume" literally scrolls to; it is
  the honest, existing, closest-available destination per this phase's own
  explicit instruction ("do not pretend the new manual resume builder is
  already implemented... use only an honest, existing destination").
  `resume_builder_home`/`resume_job_match` are `@login_required`
  (confirmed, Phase 18), so an anonymous tap is likewise auto-redirected
  to `/login` by the same existing guard — no special-casing needed.

## 4. Anonymous, authenticated-student, and employer behavior

- **Anonymous**: sees `HomeHero` above the unchanged portal cards.
- **Authenticated student**: sees the identical `HomeHero` (same labels),
  with "Get Started"/"Find Jobs" both routed to Dashboard and "Create
  Resume" to Resume Builder — matching the real web's own hero being
  identical for anonymous and logged-in-student visitors alike (confirmed
  in Phase 20: only 2 small role-pills vary by auth in `landing.html`, and
  neither survives into any authenticated view regardless).
- **Authenticated employer**: sees **exactly the same content as before
  this phase** — the "Learn Business English"/"Manage Your Hiring
  Pipeline" hero cards and "Employer Dashboard"/"Find Candidates" buttons,
  unchanged. This is deliberate, not an oversight: the real `home()` view
  redirects an authenticated employer to `job_home` **before**
  `landing.html` ever renders (`activities/views.py:79-80`, confirmed
  directly) — an employer never actually sees the new unified hero on the
  real site at all. Flutter's existing conditional-render architecture
  (branching inside one screen rather than performing a true navigation
  redirect) already achieves the equivalent user-facing outcome — an
  employer never sees student-oriented CTAs — without needing to add an
  actual redirect, which would have been a larger, riskier change than
  this phase's scope called for.
- No change was made to authentication state management, OTP, role logic,
  or any existing route guard — `route_guards.dart`/`computeRedirect` is
  untouched; every new CTA relies on it exactly as every pre-existing
  protected-route navigation in this app already does.

## 5. Tests added and exact results

- `test/features/home/presentation/widgets/home_hero_test.dart` (new, 3
  tests): headline + all 3 CTA labels render; each CTA's callback fires
  independently and the correct number of times; no overflow at
  320/360/390/430px.
- `test/features/home/presentation/screens/home_screen_test.dart`:
  - Guest group: 3 new tests (hero + labels render above the portal cards;
    Get Started → registration placeholder; Find Jobs/Create Resume push
    the dashboard/resume-builder routes, with a code comment explaining
    the real app's separately-tested auth-guard redirect). The pre-existing
    portal-card test needed no changes.
  - Authenticated (student) group: the 3 tests asserting old hero
    content/buttons were replaced with 3 new ones (unified hero renders,
    old content is gone; Get Started → Dashboard, not re-registration;
    Find Jobs → Dashboard; Create Resume → resume-builder placeholder,
    same destination as the old "Parse Your Resume").
  - Authenticated-employer group: **unmodified**, all 3 tests still pass,
    confirming the employer branch is genuinely untouched.
  - New responsive group: full-screen overflow check at 360/390/430px for
    both guest and student branches (320px excluded here — see §7).

**Commands and results:**
```
flutter test test/features/home/
→ 21 passed, 0 failed

flutter test
→ 1978 passed, 0 failed (full suite; 1969 prior + 9 new this phase)
```

## 6. `flutter analyze` result

```
flutter analyze
No issues found! (ran in 2.3s)
```
Run scoped to `lib/features/home/`/`test/features/home/` during
development and whole-project at the end — clean both times.

## 7. Functionality that remains unavailable or differs from the web, and one pre-existing bug found

- **Find Jobs** does not reproduce the web's exact funnel (paid-plan gate
  → existing-session check → fallback to resume upload) — it goes
  straight to Dashboard's job-recommendations section instead, which
  shows the same underlying data without that gate. See §3 for the full
  reasoning; this is a documented adaptation, not an oversight.
- **Create Resume** goes to the existing AI resume-upload/analysis flow,
  not the new manual, template-driven resume builder — which does not
  exist in Flutter at all yet (confirmed Missing, Phase 15/20). Building
  it is already flagged as its own, separately-scoped future phase.
- **A pre-existing, unrelated overflow bug was found, not fixed**: the
  new responsive test initially included 320px and caught a real
  `RenderFlex` overflow (3.5px) — traced by direct debugging to
  `portal_card.dart:96`, a file this phase does not touch and did not
  modify. This bug predates Phase 21 (it affects the guest home screen's
  existing, unmodified portal cards) and was simply never caught before,
  since no prior test pumped this screen at 320px. Per this phase's own
  scope boundary against changing the portal cards without stopping to
  ask first, it was **not fixed** — the 320px case was excluded from the
  full-screen responsive test (with a comment explaining exactly why),
  and `HomeHero` itself was separately confirmed overflow-free at 320px
  in isolation. Flagging this clearly for a decision on a separate fix,
  rather than silently leaving it undiscovered or silently patching
  `portal_card.dart` outside this phase's approved scope.

## 8. Confirmation that both Django trees were untouched

Every Django file read this phase (`landing.html`, `includes/site_nav.html`,
`career_app/views.py`, `activities/views.py`, `core/navigation.py`,
`core/nav_views.py`) has a modification time predating this session,
confirmed via `stat`. Neither tree was written to.

## 9. Final Git status

```
git status --short
```
shows exactly the files listed in §1 as modified/new, plus the
unrelated, pre-existing Phase 19/20 changes (resume-counter feature,
Phase 20's own report) carried over untouched. `Career_Buddy_LMS/`'s own
pre-existing uncommitted state (unrelated to this engagement's Flutter
work) was confirmed unchanged from before this phase.

**Verified vs. manually tested**: every claim above about rendering,
navigation, and overflow behavior comes from the automated test suite
(§5) and direct source reads (§3) — no live device, emulator, or
production URL was used anywhere in this phase, and no manual on-device
navigation was performed.

---

Phase 21 is complete. Stopping here per instruction — awaiting explicit
review and approval before beginning Phase 22 or any other phase.
