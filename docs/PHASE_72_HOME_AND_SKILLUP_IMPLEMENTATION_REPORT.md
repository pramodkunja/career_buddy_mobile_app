# Phase 72 — Authenticated Home & Skill Up Deep-Link Implementation Report

See `docs/PHASE_72_HOME_AND_SKILLUP_PARITY_AUDIT.md` for the full source references and the
website-vs-Flutter matrix. This report covers what changed, what was tested, and what was
verified live.

## Summary of corrections implemented

**Workstream A** — `AuthenticatedHomeBody`'s non-employer branch now renders `HomeChoosePath`,
`HomeAboutSection`, and `HomeTutorialsSection` below the existing `HomeHero`, reusing the exact
same widgets `PublicHomeBody` already uses (no content duplicated or invented). The same
`GlobalKey`s `HomeScreen` already created for Phase 71's `homeScrollRequestProvider` are now
also threaded into this branch, so "About Us"/"Industries"/"Resources → Tutorials" resolve to a
real, visible section for an authenticated candidate, not a silent no-op. The employer branch
and the rest of this screen's layout are untouched.

**Workstream B** — `SkillUpScreen` gained an `initialSectionId` parameter; its "Sections in
depth" tab now scrolls to the matching `SkillUpSection` (keyed by the section's own pre-existing
`id` field — `depth-english`/`depth-aptitude`/`depth-tech`) when one is requested, using the
same `Scrollable.ensureVisible` + `GlobalKey` pattern already used elsewhere in this exact
screen. A new `RoutePaths.skillUpSectionsFor(sectionId)` helper builds the deep-link URL
(mirroring the existing `activitiesWithCategory` pattern), and the drawer's "English Learning"/
"Vocabulary & Idioms" (both → `depth-english`, matching the real site's own deliberately shared
destination) and "Aptitude"/"Tech" (→ their own distinct sections) now use it.

## Files changed and reasons

**`lib/app/router/route_paths.dart`** — added `RoutePaths.skillUpSectionsFor(String sectionId)`,
documented against the real site's own `?section=` mechanism (`core/navigation.py`,
`riya_bot/skillup_views.py`).

**`lib/app/router/app_router.dart`** — the `skillUpSections` route builder now reads
`state.uri.queryParameters['section']` and passes it to `SkillUpScreen` as `initialSectionId`.

**`lib/features/skill_up/presentation/screens/skill_up_screen.dart`** — added
`SkillUpScreen.initialSectionId`; converted `_SectionsInDepthTab` from `StatelessWidget` to
`StatefulWidget` holding one `GlobalKey` per `SkillUpSection.id`; its `initState` schedules a
post-frame `Scrollable.ensureVisible` to the matching key if `initialSectionId` is set and
recognized — an unrecognized or missing id is a silent no-op (the tab simply opens at its own
top, identical to every pre-existing caller's behavior). No pre-existing caller
(`RoutePaths.skillUp`/`sitemap`/`skillUpCertifications`) passes this new parameter, so their
behavior is unchanged.

**`lib/shared/widgets/app_nav_drawer.dart`** — "English Learning"/"Vocabulary & Idioms" now use
`RoutePaths.skillUpSectionsFor('depth-english')`; "Aptitude"/"Tech" now use
`RoutePaths.skillUpSectionsFor('depth-aptitude')`/`'depth-tech'` respectively, replacing the
previous bare `RoutePaths.skillUpSections` for all 4.

**`lib/features/home/presentation/widgets/authenticated_home_body.dart`** — added
`onItJobSeeker`/`onNonItJobSeeker` callbacks and `aboutSectionKey`/`choosePathSectionKey`/
`tutorialsSectionKey` (all optional, `null`-safe) constructor parameters; the non-employer
branch's body is now a `Column` of `HomeHero` → `HomeChoosePath` → `HomeAboutSection` →
`HomeTutorialsSection` (matching the real page's own relative ordering of these 3 sections,
even though the sections between them on the real page aren't reproduced here, per this
phase's deliberately narrow scope). The employer branch is byte-for-byte unchanged.

**`lib/features/home/presentation/screens/home_screen.dart`** — the `AuthenticatedHomeBody(...)`
call site now passes the same 3 `GlobalKey`s already created for `PublicHomeBody`, plus 2 new
closures (`onItJobSeeker`/`onNonItJobSeeker`) using the identical `RoutePaths.careerDepartments`
destinations the guest branch's own `HomeChoosePath` already uses (not wrapped in `_choosePath`,
since the guest-only auto-popup-cancel logic that wrapper exists for never fires once
authenticated).

**Test files updated or added to**, all following this project's existing conventions (no
access control weakened, no isolated-router substitute where the real router was warranted):
- `test/features/home/presentation/screens/home_screen_test.dart` — replaced one now-false-
  premise test ("a scroll request... has no matching section... for an authenticated session",
  which was true before this phase and is no longer true for a non-employer session) with: 3
  new positive tests (one per About Us/Industries/Tutorials) confirming the target now resolves
  to a real, on-screen section for an authenticated candidate; a new employer-specific no-op
  test (the one combination that genuinely still has nothing to scroll to, since `home()`
  redirects an employer away from `landing.html` entirely); and an explicit guest-regression
  test confirming the authenticated-body change didn't affect guest behavior.
- `test/features/skill_up/presentation/screens/skill_up_screen_test.dart` — added a
  `initialSectionId`-threading parameter to the file's existing isolated-router test harness;
  added a new test group covering: each of the 3 real sections scrolling to its own first-lesson
  marker (not just the top of the tab); the existing no-section-requested behavior being
  unchanged; an unrecognized section id falling back safely (no crash, same as no id); and a
  plain assertion on `RoutePaths.skillUpSectionsFor`'s own query-string output.
- `test/shared/widgets/app_nav_drawer_test.dart` — the fake `skillUpSections` route now echoes
  back the `section` query param it received, and the existing "English Learning and Vocabulary
  & Idioms"/"Aptitude and Tech" destination tests now assert the exact section id reached
  (`depth-english` for both of the first pair; `depth-aptitude`/`depth-tech` distinctly for the
  second), not just that *a* Skill Up Sections screen opened.
- `test/app/client_flow_test.dart` — **uses the real app router and real drawer**, not an
  isolated test router, per the task's explicit preference for meaningful integration coverage.
  Extended the existing "Dashboard -> Grammar -> Back, Skill-Up(+Certifications) -> Back, Mock
  Tests -> Back" flow (narrowed to a realistic phone viewport for this one assertion, restored
  afterward) to confirm "English Learning" lands with its own first lesson on screen, and added
  a new "Aptitude" sub-flow confirming it lands on a *different* section than English Learning
  did (not just "a screen opened").

## Behavior before and after

**Before**: an authenticated candidate selecting "About Us"/"Industries"/"Resources →
Tutorials" was returned to Home with no visible change — the scroll request found nothing to
scroll to. All 4 of "English Learning"/"Vocabulary & Idioms"/"Aptitude"/"Tech" opened the
"Sections in depth" tab at the exact same scroll position (its own top).

**After**: an authenticated candidate selecting those 3 items now actually reaches the matching
section on Home, identical in content to what a guest sees (confirmed this matches the real
site's own behavior, not an invented addition). "English Learning" and "Vocabulary & Idioms"
both scroll to the `depth-english` article (matching the real site's own deliberately shared
destination); "Aptitude" and "Tech" each scroll to their own distinct article.

## Tests added/updated and exact results

- `flutter test test/features/home/presentation/screens/home_screen_test.dart`: **54/54
  passed** (up from Phase 71's 50 — net +4 for the rewritten/added assertions; the employer
  no-op and guest-regression tests are new, the 3 "resolves now" tests replace the 1 stale one).
- `flutter test test/features/skill_up/presentation/screens/skill_up_screen_test.dart`:
  **20/20 passed** (up from 15 before this phase).
- `flutter test test/shared/widgets/app_nav_drawer_test.dart`: **37/37 passed** (unchanged
  count — existing tests strengthened in place, not added to).
- `flutter test test/app/client_flow_test.dart`: **4/4 passed**.
- `flutter test` (complete suite): **2,839/2,839 passed**.
- `flutter analyze` (whole project): **No issues found.**

These are this session's actual results, not assumed from any historical baseline.

## Emulator verification

Used the existing Android emulator (`emulator-5554`, already running — not wiped or recreated).
Launched the real app and verified the **guest** flow live (consistent with every prior phase's
stated access limitation — no authorized authenticated test account exists, so no credentials
were invented or attempted):

- Opened the drawer, expanded Skill Up, tapped "Aptitude" — confirmed it navigates through the
  real router to `/skill-up/sections?section=depth-aptitude`, which the existing route guard
  (unchanged by this phase) correctly redirects an unauthenticated session to the Job Seeker
  Sign In screen — exactly the same login-gated behavior already confirmed in Phase 71's own
  live check of "Certifications", now confirmed for this new deep-link path too. **This
  confirms the new query-param routing reaches the correct URL, but Skill Up's actual on-screen
  content (and therefore the real, visible scroll-to-section behavior) is login-gated on the
  real site and in Flutter alike, so it could not be viewed live without a test account.**
- Re-opened the drawer, tapped "About Us" as a guest — confirmed it still correctly scrolls to
  the "Why job seekers and employers choose CareerBuddy" section, exactly as before this phase:
  a regression check confirming the `AuthenticatedHomeBody` changes did not affect the
  guest (`PublicHomeBody`) path at all.
- No login was attempted with any credential; no form was submitted; no state-changing request
  was made.

**Authenticated flows that could not be verified live** (and were instead verified only through
the automated tests listed above, run against the real screen/widget code, in the Aptitude/Tech
case also through the real app router):
- The actual appearance of `HomeChoosePath`/`HomeAboutSection`/`HomeTutorialsSection` on an
  authenticated candidate's Home screen, and the scroll landing correctly on each.
- The actual on-screen appearance of the `depth-english`/`depth-aptitude`/`depth-tech`
  "Sections in depth" articles and the scroll landing on each distinctly, since reaching them
  at all requires a logged-in session.

**Screenshot evidence** (`docs/audit_evidence/phase72/`, all captured at 1080×1920 physical
pixels on the emulator described above):

| File | What it shows |
|---|---|
| `01_guest_drawer_open_1080x1920px.png` | The drawer open, guest session, unchanged top-level structure |
| `02_skillup_expanded_aptitude_tech_visible_1080x1920px.png` | Skill Up submenu expanded, Aptitude/Tech items visible |
| `03_aptitude_tap_guest_redirects_to_login_1080x1920px.png` | Result of tapping "Aptitude" as a guest — correctly redirected to login, confirming the new deep-link route is reached |
| `04_guest_about_us_regression_check_1080x1920px.png` | Result of tapping "About Us" as a guest — unchanged, confirms no regression from the authenticated-body change |

## Remaining limitations and recommended follow-up

- The actual visual confirmation of the authenticated Home sections and the 3 distinct Skill Up
  articles exists only via automated test evidence, not a live screenshot, for the access
  reason stated above. If an authorized test account becomes available in a future phase, a
  live confirmation pass would be straightforward given the wiring is already in place and
  already tested.
- As flagged in the audit, the real site also shows several *other* landing-page sections
  identically to guest and candidate sessions (Platform Overview, Career Journey, the portal
  story cards, Meet Buddy, Resume Maker Teaser, Testimonials) that are not targets of any nav
  item and were deliberately not added to `AuthenticatedHomeBody` this phase, to stay within
  this phase's named scope. Whether to pursue full Home-page content parity for authenticated
  users is a separate product decision, not something this phase decided on its own.
- "Vocabulary & Idioms" could technically scroll to a more specific `grp-english-vocab`
  sub-anchor that exists in the real page's markup but that the real site's own nav doesn't
  use — deliberately not implemented, since doing so would exceed the real site's own parity
  rather than match it (see the audit's own note on this).

## Confirmation of scope discipline

- Only Flutter project files were modified. Both Django reference directories
  (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout; no backend code,
  database file, authentication/authorization logic, subscription/payment logic, or production
  data was touched.
- `git status` confirms the diff is limited to exactly: `route_paths.dart`, `app_router.dart`,
  `skill_up_screen.dart`, `app_nav_drawer.dart`, `authenticated_home_body.dart`,
  `home_screen.dart`, their corresponding/related test files, this report, the parity audit,
  and `docs/audit_evidence/phase72/`'s 4 screenshots. Every other file already modified or
  untracked in the working tree belongs to prior phases (52–71) and was not touched.
- Employer navigation was not touched (the employer branch of both `AppNavDrawer` and
  `AuthenticatedHomeBody` is byte-for-byte unchanged).
- No general UI redesign, unrelated feature work, or broad refactoring was performed — the
  changes are narrowly scoped to the 2 named gaps, reusing existing widgets and an existing
  scroll-request/route-parameter pattern rather than inventing new architecture.
