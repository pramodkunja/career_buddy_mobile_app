# Phase 71 — Navigation Menu Parity Audit

## Reference source files inspected

**Updated Django site** (`royalStaffing_CB01`, read-only):
- `templates/includes/site_nav.html` (262 lines, read in full) — the one and only navbar in
  the project (confirmed by its own top-of-file comment: "The old Bootstrap navbar that used
  to live inline in base.html is gone; this is the only navigation markup left in the
  project"). Included by both `base.html` (every logged-in app page) and `landing.html` (the
  public home page).
- `templates/base.html` lines 25-81 — confirms `base.html` has no nav of its own; it simply
  includes `site_nav.html`.
- `core/navigation.py` (129 lines, read in full) — the `NAV_MAP` dict every `{% url 'nav_go'
  key %}` link resolves through, including each destination's real view, query string, and
  `protected` (login-required) flag.
- `core/nav_views.py` (38 lines, read in full) — the `/go/<key>/` gateway view itself, and its
  redirect-to-login behavior for an unauthenticated request.
- `templates/landing.html` — spot-checked the anchor-target sections (`#why`, `#choose-path`,
  `#create-resume`, `#videos`, `#contact`) and the footer's own link columns.
- Spot-checked `subject_views.py`, `career_app/views.py` (`pro_page`), `activities/views.py`
  (`activity_list`), `riya_bot/skillup_views.py` (`skillup_hub`) for `@login_required`
  decorators, and `jobs_app/employer_urls.py`/`jobs_app/views.py` (`job_openings`).
- The original `Career_Buddy_LMS` reference was not needed — nothing here was ambiguous
  enough to require the historical comparison.

**Flutter project** (the only directory modified):
- `lib/shared/widgets/app_nav_drawer.dart` (pre-Phase-71 version) and its test,
  `test/shared/widgets/app_nav_drawer_test.dart`.
- `docs/PHASE_67_UI_PARITY_AUDIT.md` / `docs/PHASE_67_UI_PARITY_IMPLEMENTATION_REPORT.md` —
  read in full for prior findings (`UI-A-010`, `UI-N-001`), which this audit does **not** take
  on faith — both are re-verified against the current source below, and one is found stale.
- `lib/app/router/route_paths.dart` and `lib/app/router/app_router.dart` — every route this
  audit references was confirmed to have a real screen builder (not a `ComingSoonScreen`
  placeholder) by reading the actual `GoRoute` registration, and checked against
  `RoutePaths.publicRoutes`/`universalRoutes` to determine guest reachability.
- `lib/features/home/presentation/screens/home_screen.dart` and its widget tree
  (`public_home_body.dart`, `home_about_section.dart`, `home_choose_path.dart`,
  `home_tutorials_section.dart`, `home_landing_footer.dart`) — to determine which landing-page
  sections Flutter already renders, as candidates for the website's anchor-link nav items.

## Correction to Phase 67 (read this first)

Phase 67's `UI-A-010` finding — "Nav drawer Skill-Up sub-items (authenticated) —
'English & Vocabulary'/'Aptitude'/'Tech'/'Browse All' all route to the same destination" — is
**stale**. The site has been restructured since Phase 67: there is no longer a separate
`base.html` nav at all; `base.html` now just includes the same `site_nav.html` the landing
page uses. In the current source, every Skill Up and Resources item resolves through
`{% url 'nav_go' key %}` to a **distinct, mapped destination** (`core/navigation.py`'s
`NAV_MAP`, confirmed by reading all 19 entries). Only one pairing is deliberately shared
("English Learning" and "Vocabulary & Idioms" both open `skill_up?section=depth-english`, by
the file's own comment) — not "all four go to the same place."

The single largest, newly-confirmed structural finding this audit makes: **the real site does
not show a guest a stripped-down menu and an authenticated candidate a different, richer
one.** `site_nav.html`'s `{% else %}` branch (line 205) covers *both* an anonymous guest and
an authenticated non-employer candidate with the **same item list** — the only difference is
one extra "Dashboard" link inserted once authenticated. Flutter's pre-Phase-71 drawer did the
opposite: two almost entirely different branches (guest: Home + Create Resume + 2 logins;
authenticated: a differently-structured Skill Up accordion + 5 flat items + Pro badge +
avatar). This is corrected below.

## Top-level navigation matrix (guest and authenticated-non-employer — one shared branch)

| # | Website item | Source | Destination type | Flutter route | PASS/PARTIAL/MISSING/BLOCKED |
|---|---|---|---|---|---|
| 1 | Home | `site_nav.html:194` | Real view (`home`) | `RoutePaths.home` | **PASS** (already existed) |
| 2 | About Us | `:206`, `{% url 'home' %}#why` | Anchor → `landing.html` `id="why"` section | `RoutePaths.home` + scroll to `HomeAboutSection` | **MISSING → IMPLEMENTED** |
| 3 | Skill Up (submenu, 10 items) | `:211-220` | Mixed: `nav_go` gateway (login-gated) | see submenu matrix below | **MISSING → IMPLEMENTED** |
| 4 | Resources (submenu, 6 items) | `:227-232` | Mixed: `nav_go` gateway + 1 plain anchor | see submenu matrix below | **MISSING → IMPLEMENTED** |
| 5 | Dashboard (authenticated only) | `:236-238`, `{% url 'student_dashboard' %}` | Real view | `RoutePaths.dashboard` | **PASS** (already existed, now correctly positioned in the shared list) |
| 6 | Industries | `:240`, `{% url 'home' %}#choose-path` | Anchor → the IT/Non-IT career-path picker, same flow as `RoutePaths.careerDepartments`/`careerRoles` | `RoutePaths.home` + scroll to `HomeChoosePath` | **MISSING → IMPLEMENTED** |
| 7 | Create Resume | `:241`, `{% url 'home' %}#create-resume` | Anchor → the free-form resume builder | `RoutePaths.createResumeBuilder` | **PASS** (fixed in Phase 67, unchanged this phase, repositioned to match real order) |
| 8 | Contact Us | `:242`, `{% url 'home' %}#contact` | Anchor → the page footer (no dedicated contact form/email/phone exists at this anchor) | `RoutePaths.home` + scroll to the footer | **MISSING → IMPLEMENTED** |
| 9 | Job Seeker Login (guest only) | `:247`, `{% url 'login' %}` | Real view | `RoutePaths.login` | **PASS** (already existed) |
| 10 | Employer Login (guest only) | `:249`ish, `{% url 'employer_portal:employer_login' %}` | Real view | `RoutePaths.employerLogin` | **PASS** (already existed) |
| 11 | Profile (authenticated only) | `:245-ish` | Real view | `RoutePaths.profile` | **PASS** (already existed) |
| 12 | Logout (authenticated only) | — | Form POST | `authControllerProvider.notifier.logout()` | **PASS** (already existed) |

## Skill Up submenu — full matrix (`site_nav.html:211-220`, cross-referenced with `core/navigation.py`'s `NAV_MAP`)

| # | Label (as shown) | `nav_go` key | Target view + query | Guest visibility | Flutter destination | Status |
|---|---|---|---|---|---|---|
| 1 | English Learning | `english-learning` | `skill_up?section=depth-english` (`@login_required`) | Visible; click → login | `RoutePaths.skillUpSections` | **IMPLEMENTED** |
| 2 | Grammar | `grammar` | `subject` (`@login_required`, separate module) | Visible; click → login | `RoutePaths.grammar` | **IMPLEMENTED** |
| 3 | Vocabulary & Idioms | `vocabulary` | `skill_up?section=depth-english` — **same target as #1, deliberately** | Visible; click → login | `RoutePaths.skillUpSections` | **IMPLEMENTED** |
| 4 | Speaking & Presentation | `speaking` | `activity_list?category=speaking` | Visible; click → login | `RoutePaths.activitiesWithCategory('speaking')` | **IMPLEMENTED** |
| 5 | Writing & Correspondence | `writing` | `activity_list?category=writing` | Visible; click → login | `RoutePaths.activitiesWithCategory('writing')` | **IMPLEMENTED** |
| 6 | Negotiation & Meetings | `negotiation` | `activity_list?category=negotiation` | Visible; click → login | `RoutePaths.activitiesWithCategory('negotiation')` | **IMPLEMENTED** |
| 7 | Interactive Roleplay | `workshop` | `activity_list?category=workshop` (`navigation.py`'s own internal label for this key is "Interactive Workshop" — the template's visible text, "Interactive Roleplay", is what's used here) | Visible; click → login | `RoutePaths.activitiesWithCategory('workshop')` | **IMPLEMENTED** |
| 8 | Aptitude | `aptitude` | `skill_up?section=depth-aptitude` | Visible; click → login | `RoutePaths.skillUpSections` (same tab as #1/#3 — see note below) | **PARTIAL** (correct tab, no deeper sub-section selection) |
| 9 | Tech | `tech` | `skill_up?section=depth-tech` | Visible; click → login | `RoutePaths.skillUpSections` (same tab) | **PARTIAL** (same reason as Aptitude) |
| 10 | Certifications | `certifications` | `skill_up?section=section-certifications` | Visible; click → login | `RoutePaths.skillUpCertifications` | **IMPLEMENTED** |

**Note on the 3 PARTIAL items (English Learning/Vocabulary/Aptitude/Tech all → `skillUpSections`):**
`SkillUpScreen` (`RoutePaths.skillUpSections`'s own doc comment, written in an earlier phase)
reproduces the real web's single static-HTML "Sections in depth" tab as one Flutter tab, with
no further per-topic (English vs. Aptitude vs. Tech) sub-navigation inside it yet. This is a
pre-existing, already-documented simplification from before this phase — not something Phase
71 introduces. Fixing it would mean adding a sub-section selector inside `SkillUpScreen`
itself, which is content/feature work on that screen, not a navigation-menu change — outside
this phase's scope. The menu *item* itself is correctly present, labeled, and routes to the
correct tab; only the deeper in-tab selection is unimplemented. Documented here rather than
silently left unclear.

## Resources submenu — full matrix (`site_nav.html:227-232`)

| # | Label | `nav_go` key / anchor | Target | Guest visibility | Flutter destination | Status |
|---|---|---|---|---|---|---|
| 1 | Skill Up Hub | `skill-up-hub` | `skill_up` (hub root, no section) | Visible; click → login | `RoutePaths.skillUp` | **IMPLEMENTED** |
| 2 | Activities | `activities` | `activity_list` (no category filter) | Visible; click → login | `RoutePaths.activities` | **IMPLEMENTED** |
| 3 | Certifications | `certifications` | `skill_up?section=section-certifications` — same target as Skill Up's own Certifications, deliberately shared | Visible; click → login | `RoutePaths.skillUpCertifications` | **IMPLEMENTED** |
| 4 | Tutorials: How CareerBuddy Works | plain anchor, **not** a `nav_go` key | `{% url 'home' %}#videos` — no login gate at all | Visible; works for anyone | `RoutePaths.home` + scroll to `HomeTutorialsSection` | **MISSING → IMPLEMENTED** |
| 5 | Sitemap | `sitemap` | `skill_up?section=section-sitemap` — a section of the hub, not its own page | Visible; click → login | `RoutePaths.sitemap` | **IMPLEMENTED** |
| 6 | CareerBuddy Pro | `pro` | `pro_page` | Visible; click → login | `RoutePaths.pro` | **IMPLEMENTED** |

## Expand/collapse behavior

The real site uses `<button class="mm-trigger">` + a sibling `<div class="mm-panel">` for both
Skill Up and Resources (`site_nav.html:208-222`, `224-234`) — no `<details>` element, no
nested/multi-level accordion, each panel independent. This is a flat, single-level accordion
per item, which matches Flutter's `ExpansionTile` exactly. Verified live and via automated
tests that both submenus can be expanded independently and simultaneously, and collapsing one
never affects the other.

## Guest vs. authenticated visibility differences (confirmed)

- **Only one item differs**: "Dashboard", shown only when `user.is_authenticated`
  (`site_nav.html:236-238`). Implemented identically in Flutter (`if (user != null)`).
- The bottom account/CTA area differs as expected: guest sees "Job Seeker Login" +
  "Employer Login"; authenticated candidate sees the Profile tile + "Logout". Unchanged from
  before this phase, just repositioned to sit after the now-shared item list instead of being
  the entirety of two separate branches.
- Every Skill Up/Resources item is **visible to a guest**, exactly as the real site shows it —
  only the *destination* is gated (every `nav_go` key in `NAV_MAP` defaults to
  `protected=True`, with no override in the file, confirmed by reading all 19 entries, and the
  underlying views are independently `@login_required`). Flutter reproduces this automatically
  and correctly: none of `skillUp`/`skillUpSections`/`skillUpCertifications`/`grammar`/
  `activities`/`pro`/`sitemap` are members of `RoutePaths.publicRoutes` or
  `RoutePaths.universalRoutes`, so the existing route guard (`route_guards.dart`) already
  redirects an unauthenticated tap to `/login` — confirmed live on the emulator (tapping
  "Certifications" as a guest lands on the Job Seeker Sign In screen, not a crash or a blank
  screen). No new guest/authenticated branching logic had to be written to achieve this parity
  — reusing the existing route guard was sufficient.

## Employer branch — unrelated to this phase's named recheck list

The real site's employer branch (`site_nav.html:199-204`) is only 3 items (Employer Dashboard,
"Jobs", Company Profile) — much shorter than Flutter's existing 6-item employer drawer branch.
Flutter's employer branch comes from a *different* real template
(`templates/employer_base.html`'s sidebar), and Phase 67's own doc comment in
`app_nav_drawer.dart` already documents this as a deliberate consolidation of two separate real
web surfaces into one drawer, since there is no room on mobile for a second, persistent nav
panel. Not in this phase's named recheck list (Home, Job Seeker Login, Employer Login, Create
Resume, About Us, Skill Up, Resources, Industries, Contact Us); left untouched.

## Flutter cross-reference — what already existed vs. what's new

Every Skill Up/Resources destination already had a real, built Flutter screen before this
phase (`SkillUpScreen`, `GrammarIndexScreen`, `ActivityListScreen`, `SubscriptionScreen`) — the
gap was entirely that the **drawer had no entry points to them for a guest, and a differently-
labeled/structured, partially-overlapping set of entry points for an authenticated candidate**.
No new Flutter screen, controller, or backend call was created to close this gap — only the
drawer's own menu structure changed, plus one small addition to `HomeScreen` (see below) to
make the 4 anchor-only items (About Us/Industries/Tutorials/Contact Us) resolve to something
real instead of nowhere.

**New, minimal plumbing added**: `HomeScreen` already rendered the exact sections these 4
anchors point to (`HomeAboutSection`, `HomeChoosePath`, `HomeTutorialsSection`,
`HomeLandingFooter`) — it simply had no way for another widget (the drawer) to tell it which
section to scroll to. A new `homeScrollRequestProvider` (mirroring the existing
`buddyOverlayOpenRequestProvider` pattern already used in this codebase for the identical
"request an action on a possibly-not-yet-mounted widget" problem) and 4 `GlobalKey`s on those
existing sections close this gap. This is wiring, not a new destination — the content being
scrolled to already existed and was already correct.

## Remaining uncertainties / honest limitations

- **Aptitude/Tech/English Learning/Vocabulary & Idioms all landing on the same "Sections in
  depth" tab** rather than a specific sub-section within it (documented above as PARTIAL) — a
  pre-existing `SkillUpScreen` limitation, not something this phase's scope covers (content
  work inside that screen, not a navigation-menu change).
- **For an authenticated session, "About Us"/"Industries"/"Tutorials" link to `Home`, but
  `AuthenticatedHomeBody` (the body an authenticated candidate actually sees) has no such
  marketing sections to scroll to** — this is a pre-existing, separate scope decision from
  before this phase (the authenticated home body deliberately omits the guest marketing
  content). The scroll request becomes a harmless no-op in that case (verified by an automated
  test: no exception, no crash) rather than scrolling to nothing or crashing. "Contact Us"
  still resolves correctly for an authenticated candidate, since the footer renders for both
  branches. This is flagged here as an honest, real limitation — not silently glossed over —
  and was not "fixed" by adding marketing content to the authenticated home body, since that
  would be feature work beyond this phase's navigation-menu scope.
- Did not trace `static/js/site_nav.js`/`static/css/site_nav.css` line-by-line for the exact
  client-side toggle mechanism (class name, ARIA state) — not needed, since `ExpansionTile`'s
  own interaction category (tap header, panel appears below) already matches the HTML
  structure (`<button>` + sibling panel `<div>`, no `<details>`).
- `job_home` (the employer branch's "Jobs" link) was not cross-checked against an existing
  Flutter route, since the employer branch is outside this phase's named recheck list.
