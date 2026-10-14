# Phase 20 — Updated Home/Landing Page Parity Audit

**Audit-only phase.** No Flutter application source, test, or configuration
file was created, edited, or deleted. Neither Django tree was modified. The
only new file is this report.

## 1. Scope and methodology

- Read first: `docs/PHASE_15_UPDATED_WEB_DISCOVERY_REPORT.md`,
  `docs/UPDATED_WEB_CHANGE_INVENTORY.md`,
  `docs/UPDATED_WEB_MOBILE_GAP_ANALYSIS.md`,
  `docs/PHASE_15_UPDATED_WEB_CONVERSION_ROADMAP.md`,
  `docs/PHASE_19_RESUME_ANALYSIS_COUNTER_REPORT.md` — all already
  established that the home page was fully replaced and flagged a full
  re-audit as a necessary first step before sizing any Home-area phase
  (gap analysis §10). This phase is that re-audit.
- `git status` confirmed a clean baseline (only Phase 19's resume-counter
  changes present) before starting, and again at the end (§10).
- The updated landing page (`royalStaffing_CB01/templates/landing.html`,
  9054 lines) was mapped via a dedicated research pass (every finding
  below cites exact line numbers from that pass), and the highest-value/
  most surprising claims were independently re-verified by directly
  reading the same line ranges myself afterward — every one matched
  exactly on re-check (the hero's auth conditional at line 6556, the
  Final CTA's missing auth gate at 7320-7345, and the zero-occurrence
  grep for `featured_activities`/`total_activities` in `landing.html`
  were all personally re-confirmed, not taken on trust alone).
- The navbar include (`templates/includes/site_nav.html`, 262 lines) and
  the `core/navigation.py`/`core/nav_views.py` gateway it depends on were
  read in full, personally, not delegated.
- The Flutter side (`lib/features/home/`, `lib/shared/widgets/app_nav_drawer.dart`,
  `lib/shared/widgets/app_footer.dart`, `lib/app/router/app_router.dart`,
  `lib/app/router/route_paths.dart`) was read directly, personally, in
  full for the files most relevant to this audit.
- No live device, emulator, or production URL was used anywhere in this
  phase. No application file was modified to test a hypothesis.

## 2. The updated web landing page — route, view, template

- Route: `''` → `activities.views.home` (named `home`) — confirmed
  identical in both Django trees except for one thing: the **template**
  changed from `home.html` (1944 lines, original) to `landing.html`
  (9054 lines, updated) — `activities/views.py:104` in the updated repo.
  The view function itself computes the same context in both repos
  (`featured_activities`, first 6 active `Activity` rows excluding
  "Professional Speaking", plus `total_activities`), with one addition:
  an optional `build_role` context key (updated repo only,
  `activities/views.py:90-99`) used by the `?build=role` deep-link flow
  from a failed resume check (see §3, role-fit picker).
- An employer session is redirected away from this page entirely before
  it renders (`activities/views.py:79-80`, `redirect('job_home')`) — this
  template's body is never actually seen by a logged-in employer.
- The same template is reused by `career_path(request, track)`
  (`activities/views.py:120`) for `/careers/<track>/`-style pages — those
  pages swap the "Choose Your Path" section (§3) into its track-detail
  view instead of the picker-card view, but are otherwise the same page.
- The navbar is **not** inline in either `landing.html` or `base.html`
  — both include `templates/includes/site_nav.html` (`landing.html:6531`),
  a complete rewrite of the old inline Bootstrap navbar (confirmed by
  that file's own comment: "The old Bootstrap navbar that used to live
  inline in base.html is gone; this is the only navigation markup left
  in the project"). The Buddy chat widget is likewise an include
  (`templates/includes/aria_assistant.html`, `landing.html:7563`), shared
  site-wide, not landing-page-specific.

## 3. Page structure and key interactions (updated `landing.html`)

In page order, with line ranges:

| Section | Lines | Gated by auth? |
|---|---|---|
| Navbar (include) | 6531 | Heavily — see §4 |
| Hero | 6536-6588 | Only 2 small role-pills (6556-6565); all 3 main CTAs are unconditional |
| Trust strip (5 badges) | 6590-6609 | No |
| Features grid (6 cards) | 6611-6671 | No |
| Career Journey (6-step timeline, decorative) | 6674-6723 | No |
| Choose Your Path (role browser) | 6729-6778 | No (track-detail vs picker-card view toggles on URL, not auth) |
| `cpModal` auto-popup (path picker) | 6781-6837 | Shown only when `not track` (i.e. on `/`, not `/careers/...`) |
| Job Seeker marketing | 6839-6891 | No |
| Employer marketing | 6894-6945 | No |
| Skill Up category grid (8 cards) | 6948-6982 | No |
| Resume + AI marketing (fake "87/100" score card) | 6985-7033 | No |
| Buddy marketing (6 cards + Ask Buddy button) | 7036-7098 | No |
| Why CareerBuddy (8 cards) | 7101-7150 | No |
| Create Resume (manual builder entry, `#crApp`) | 7155-7181 | Data attributes only (`data-auth`/`data-uid`, 7167-7168) |
| Videos/Tutorials | 7184-7204 | No |
| Mentor (1 hardcoded success story) | 7207-7241 | No |
| Stories/testimonials (6 hardcoded cards) | 7246-7317 | No |
| Final CTA | 7320-7345 | **None** (see §4, removed-feature note) |
| Footer (5-column) | 7349-7402 | No |
| `roleAct`/`rm` role-picker + manual-resume-builder modals | 7589-7731 | n/a (triggered by JS, not server-gated) |
| Scripts (role data, pickers, builder logic) | 7735-9051 | n/a |

**Role-fit / role-picker mechanics** (directly relevant to the Phase 18
audit's role-fit picker, now seen in its full UI context): every role
card (`.role-card3`) opens a 3-option `roleAct` modal — **Skills** (an
in-page skills breakdown), **Build Resume** (opens the manual-resume-
builder modal, a large separate feature), and **Resume Parsing &
Interview** (the already-known `?role=&dept=&track=` link to
`resume_builder`, confirmed verbatim against Phase 18's findings). Role
data comes from three distinct sources: a server-rendered inline JSON
block (`{% manual_resume_data %}`, predefined template roles), a
hardcoded JS array for Non-IT departments (typed directly into this
template, ~270 lines), and a `fetch()` of the public static
`it_departments.json` for IT departments only (with explicit loading/
error states). A separate lazy `fetch()` of `role_profiles.json` backs
role-overview text, and a real Django endpoint
(`{% url 'manual_resume_roles' %}`) supplies the resume-builder form
fields per role on demand — both with explicit loading/error states.

**Manual resume builder**: a full 5-step wizard, state kept in
`sessionStorage`, generating a preview/PDF via real POST endpoints
(`manual_resume_preview`/`manual_resume_pages`/`manual_resume_pdf`) —
already flagged in the Phase 15 roadmap as the single largest new
feature area; this phase adds no new scope to that, only confirms the
exact UI entry points (the "Create Resume" nav link/section, and every
role card's "Build Resume" option) that would need to exist in Flutter
to reach it.

## 4. Comparison with the original web version

The `home()` view's own logic is nearly unchanged; **only the template
was replaced**, so every behavior difference below is a template/content
difference, not a backend one. Confirmed, directly comparing against
`Career_Buddy_LMS/templates/home.html` (1944 lines):

1. **Auth-aware hero removed.** The original hero
   (`home.html:1178-1329`) had three distinct layouts: anonymous (two
   portal-picker cards with stat bubbles), logged-in student (hero
   images + "Parse Your Resume"/"My Dashboard"/"Browse Activities"), and
   logged-in employer (different hero image + "Employer Dashboard"/
   "Find Candidates"). The new hero (6536-6588) is now **one fixed
   layout for every visitor** — only 2 small role-pills disappear after
   login (6556). Personally re-verified at 6536-6588.
2. **Real, DB-backed "Popular Activities" grid removed.** The original
   (`home.html:1434-1477`) looped over real `Activity` rows with an
   auth-gated per-card link (unlocked `Explore →` vs a locked
   `Explore 🔒` that redirects through login). The view still computes
   `featured_activities`/`total_activities` every request
   (`activities/views.py:86-89`), but **`landing.html` never references
   either variable** — personally confirmed via a zero-result grep. This
   data is now dead context, computed for no template-visible purpose.
3. **Final CTA lost its auth gate.** The original's closing CTA
   (`home.html:1926`, `{% if not user.is_authenticated %}`) hid itself
   once logged in. The new Final CTA (7320-7345) has no such conditional
   — personally re-verified — and shows "Get Started" → `/users/register/`
   even to an already-registered, logged-in visitor.
4. **Quantified employer stats removed.** The original's employer stat
   bubbles ("1.5L+ Monthly Reg", "50L+ Active Seekers", "30m Hire Time")
   have no equivalent in the new employer-marketing section — it now
   uses only a generic bullet list. (Flutter's `PublicHomeBody` still
   shows these exact old numbers — see §5, Gap 3.)
5. **Testimonial photos replaced with initials avatars** — a cosmetic
   change, same names/quotes largely carried over.

## 5. Web-to-Flutter parity matrix

| # | Web section/behavior | Flutter status | Evidence |
|---|---|---|---|
| 1 | Navbar: brand → home | **Matches** | `AppNavDrawer`'s "Home" tile → `RoutePaths.home` |
| 2 | Navbar: "About Us" (`#why`), "Industries" (`#choose-path`), "Create Resume" (`#create-resume`), "Contact Us" (`#contact`) | **Missing** | Zero equivalent tiles in `app_nav_drawer.dart` — these are home-page anchors, which presume a long-scrolling home page Flutter's `HomeScreen` doesn't have |
| 3 | Navbar: Skill Up mega-menu (10 specific links) | **Partial** | Drawer's "Skill Up" expands to only 4 generic items (English & Vocabulary/Aptitude/Tech/Browse All, `app_nav_drawer.dart:97-101`) vs the web's 10 (English Learning, Grammar, Vocabulary & Idioms, Speaking, Writing, Negotiation, Roleplay, Aptitude, Tech, Certifications) — most of the underlying destinations (Grammar, Activities-by-category, Skill-Up sections) already exist as real Flutter screens, just not individually linked here |
| 4 | Navbar: Resources mega-menu (Skill Up Hub, Activities, Certifications, Tutorials, Sitemap, Buddy Assistant, Pro) | **Partial** | Drawer has Sitemap, Resume Parsing (unrelated item, not "Resources"), Grammar, Job Openings, Activities, Pro separately placed, not grouped as "Resources"; no distinct "Certifications" or "Tutorials" tile |
| 5 | Navbar: Dashboard (authenticated only) | **Matches** | `app_nav_drawer.dart:112-119`, real route |
| 6 | Navbar: Pro pill "ACTIVE" badge for paid plans | **Missing (documented)** | `AppNavDrawer`'s own doc comment already states this — no profile/plan-type field exists on `AuthUser` yet |
| 7 | Navbar: account dropdown (avatar, Profile/Company Profile, Admin-if-staff, Logout) | **Partial** | Drawer has avatar-initials + username + Profile/Logout tiles but no staff-only "Admin" link equivalent (reasonable — no in-app admin surface exists) |
| 8 | Hero: unified layout, 3 CTAs (Get Started Free, Find Jobs, Create Resume) | **Missing** | `HomeScreen` has no equivalent hero at all — it still branches entirely on auth state (`PublicHomeBody`/`AuthenticatedHomeBody`), matching the **removed** old hero model, not the current one |
| 9 | Hero: 2 role-pills for anon visitors | **Partial** | `PublicHomeBody`'s portal-card Login/Register buttons cover the same destinations (`/users/register/`, employer register) but in the old portal-card presentation, not the new pill style |
| 10 | Trust strip (5 badges) | **Missing** | No equivalent anywhere |
| 11 | Features grid (6 cards) | **Missing** | No equivalent section; several individual destinations (Skill Up, Resume, Activities, Buddy) already exist elsewhere in the app, just not as this preview grid |
| 12 | Career Journey timeline | **Missing** | Decorative only; no functional loss |
| 13 | Choose Your Path / role-fit picker | **Missing** | Confirmed in Phase 18 as reproducible without a backend change; this phase adds the full in-page UI mechanics (3-option modal) as additional, not-yet-sized scope |
| 14 | Job Seeker/Employer marketing sections | **Partial** | `PublicHomeBody`'s two `PortalCard`s cover similar ground, but with the **old** stat numbers ("1.5L+ Monthly Reg", "50L+ Active Seekers", "30m Hire Time") that the current web no longer shows (see §4.4) — these may now be factually stale rather than merely absent |
| 15 | Skill Up category grid (8 cards) | **Partial** | The underlying `SkillUpScreen` feature is large and real (721-line screen, full domain/data layers) — the gap is specifically the home-page preview/teaser card, not the feature itself |
| 16 | Resume + AI marketing card | **Partial** | `ResumeBuilderScreen` is fully real and built (Phases 18-19) — the gap is the home-page marketing preview card (with its illustrative "87/100" score graphic), not the feature |
| 17 | Buddy marketing card + "Ask Buddy" button | **Partial** | `BuddyChatbotOverlay` already exists and is wired into `HomeScreen` (`home_screen.dart:58`) — the actual chat function already matches; only the marketing copy card around it is missing |
| 18 | Why CareerBuddy (8 cards) | **Missing** | Marketing copy only, no functional loss |
| 19 | Create Resume (manual builder) | **Missing** | Confirmed large, new, real feature (Phase 15 roadmap already flagged this); this phase adds the exact entry points (nav link + every role card's "Build Resume" option) |
| 20 | Videos/Tutorials section | **Missing** | Low functional value — several tutorial videos are themselves "coming soon" placeholders on the web (confirmed via the research pass's citation of the `soon()` fallback) |
| 21 | Mentor story + testimonials | **Missing** | Static marketing content |
| 22 | Final CTA | **Missing** | Redundant with other CTAs already covered; if ever built, should match the web's current **unconditional** (not auth-gated) behavior, not the old gated one |
| 23 | Footer (5-column link footer) | **Partial/Unverified** | Flutter's `AppFooter` is a different, minimal footer built against the **separate** `base.html` footer (brand/stats/copyright only), not this page-specific one — whether `base.html`'s own footer changed in the update was not verified this phase (out of this phase's home/landing scope; flagged as a question for whoever next touches footer parity) |
| 24 | Dead `featured_activities`/`total_activities` context | **N/A (web-only artifact)** | Confirmed Flutter doesn't reference this unused data either — correctly not building against dead context |

## 6. Prioritized gaps

**P1 — Important user-facing feature/major parity gap**
- **Gap 8/9: Hero/home-screen structural mismatch.** Flutter's entire
  home-screen model (auth-branching body) reproduces the web's **removed**
  old hero pattern, not its current unified one. User impact: a mobile
  user's first-screen experience no longer matches what a web user on
  the same account sees; copy/CTA labels ("Get Started Free"/"Find
  Jobs"/"Create Resume") that are now the primary web hero actions have
  no mobile equivalent at all. Flutter can reproduce the destinations
  (`/users/register/`→register, `nav_go 'job-match'`→already-existing
  resume-analytics screen if built, `#create-resume`→the not-yet-built
  manual builder) using existing routes for 2 of 3 CTAs without any
  backend change; the third needs Gap 19 first. Proposed as its own
  focused phase: redesign `HomeScreen`'s content to match the new
  unified hero, decoupled from the larger Create-Resume build.
- **Gap 13: Choose Your Path / role-fit picker.** Already scoped as
  feasible without backend change in Phase 18; this phase's additional
  finding is the 3-option modal (Skills/Build Resume/Resume Parsing)
  — the first and third options are small, the second depends on Gap 19.
  Needs a product decision on scope (full department catalog vs a
  curated subset — same open question Phase 18 raised).
- **Gap 19: Create Resume (manual builder).** Already the single
  largest new-feature item in the Phase 15 roadmap; this phase confirms
  its real, working backend contract (4 endpoints, all already fetched
  by the web via plain JSON POST/GET, none requiring new backend work)
  and its exact entry points. No new recommendation beyond re-affirming
  this as its own, separately-scoped, large phase.

**P2 — Secondary functionality/meaningful UX inconsistency**
- **Gap 14: Stale stat numbers in `PublicHomeBody`.** Flutter currently
  shows specific numeric claims ("50L+ Active Seekers", "30m Hire Time")
  that the current web no longer makes anywhere on this page. This is a
  factual-accuracy risk (showing a stat the business may not consider
  current), not just a missing feature — recommend a product decision
  (confirm with the project owner whether these numbers are still
  accurate messaging, independent of any larger Home redesign) before
  either removing or keeping them.
- **Gap 3/4/15/16/17: Marketing-preview sections for already-real
  features** (Trust strip, Features grid, Skill Up grid, Resume/AI card,
  Buddy card). Each surfaces a feature Flutter already has — the gap is
  purely a home-page discovery/wayfinding one, not a missing capability.
  Low implementation risk (static content + existing navigation), useful
  as a bundled "home page content refresh" phase once the hero
  restructuring (Gap 8/9) is decided.
- **Gap 6: Pro "ACTIVE" badge.** Already a documented, known limitation
  (no plan-type field on `AuthUser`); needs the same profile-endpoint
  dependency flagged in earlier phases, not new to this audit.

**P3 — Cosmetic/low-impact**
- Gap 10 (trust strip), 12 (career journey timeline), 18 (why cards), 20
  (videos/tutorials — itself partly unfinished on the web), 21 (mentor/
  testimonials), 22 (final CTA, redundant with other entry points).

**No P0 found.** Nothing in this audit represents a critical access,
security, or core-flow failure — the core signup/login/dashboard/
resume/activities flows all continue to function in Flutter via their
own existing, real screens; what's missing is home-page *discovery* and
*wayfinding* content, plus two large net-new feature areas (role-fit
picker, manual resume builder) already known from Phase 15/18 and not
newly discovered as broken here.

## 7. Existing data sources/endpoints that could support future work

- **Role-fit picker**: fully reproducible without a backend change —
  the public static JSON role catalog, the no-login `roles_api` JSON
  endpoint, and the session-setting GET already confirmed in Phase 18.
- **Manual resume builder**: 4 real, working endpoints already
  confirmed by this phase's read of `landing.html`'s own JS —
  `manual_resume_roles` (GET, role form fields), `manual_resume_preview`/
  `manual_resume_pages`/`manual_resume_pdf` (POST, JSON in / JSON or PDF
  blob out) — all already JSON-based, no HTML-scraping needed for this
  one feature area (confirmed no-login-required per `manual_resume_views.py`,
  previously read in Phase 18).
- **Featured Activities home-page preview**: the data the web computes
  (`featured_activities`) is dead in the current template, so there is
  *no live page to scrape it from* — however, Flutter's own, already-
  built `ActivitiesRemoteDataSource.getActivityList()` mechanism proves
  real activity data is fetchable in principle; that specific method is
  `@login_required`-gated server-side (`activities/views.py:536`,
  confirmed directly) and therefore cannot back an anonymous home-page
  preview. If a home-page activities preview is ever wanted, it would
  need either a public source (none currently exists) or to be shown
  only to authenticated users (reusing the existing, already-login-
  gated mechanism).
- **Skill Up/Resume/Buddy preview cards**: no new data source needed —
  these are static marketing copy on the web itself; Flutter can
  reproduce them as static widgets pointing at its own already-real
  destinations.

## 8. Unresolved questions / unverifiable items

- Whether `base.html`'s own footer (distinct from `landing.html`'s
  page-specific one) changed in the update was not checked this phase —
  out of this phase's home/landing scope, flagged for whoever next
  audits footer/shared-chrome parity.
- `static/js/create_resume.js` and `static/js/site_nav.js` were not
  read (separate static files, not part of the templates this phase
  scoped to) — any claim about their exact internal behavior beyond the
  data attributes/endpoints they're given is not verified.
- `is_minimal_nav`/`is_employer_dashboard_nav` context flags: confirmed
  via repo-wide grep that no Python view sets them as plain context
  keys (only passed via two `{% include %}` tags inside `base.html`,
  not read in full) — confirmed irrelevant to `landing.html` itself
  (which passes neither), so the home page's navbar is always the full,
  non-minimal version; which other specific pages use the minimal
  variant was not traced.
- The exact current numeric accuracy of `PublicHomeBody`'s stat bubbles
  (Gap 14) is a product/business question, not something resolvable
  from source code alone.

## 9. Proposed implementation order for a future phase

Not committed to in this phase — for the project owner's review:

1. **Home-screen hero restructuring** (P1, Gap 8/9) — smallest
   self-contained piece: redesign `HomeScreen`'s top section to match
   the unified hero (3 CTAs), independent of the two large features
   below. Low risk — touches only the home feature, reuses existing
   register/login routes for 2 of 3 CTAs.
2. **Stat-bubble accuracy decision** (P2, Gap 14) — a quick product
   decision, can run in parallel with (1), not a dependency of it.
3. **Role-fit picker** (P1, Gap 13) — depends on a product decision on
   role-catalog scope (already flagged in Phase 18); the "Resume
   Parsing & Interview" and "Skills" modal options can ship without the
   manual builder; the "Build Resume" option depends on (4).
4. **Manual resume builder** (P1, Gap 19) — the largest, most
   self-contained new feature; has its own real, confirmed, JSON-based
   backend contract, so it can be built and tested independently of the
   home page's visual refresh, then wired into the hero's "Create
   Resume" CTA and every role card's "Build Resume" option once ready.
5. **Home-page marketing-preview content refresh** (P2, Gap 3/4/15/16/17)
   — lowest risk, purely additive static content pointing at existing
   screens; best sequenced last so it can link to whichever of the
   above are actually done by the time it ships, rather than linking to
   placeholders.

Dependencies: (3)'s "Build Resume" option depends on (4); everything
else is independent and could in principle be parallelized across
separate phases.

## 10. Final Git status

```
git status --short
```
showed the exact same state at the end of this phase as at the start
(only Phase 19's resume-counter changes, carried over untouched) —
**zero new or modified application files**. The only file added this
phase is this report, at the exact required path,
`Mobile_app/docs/PHASE_20_HOME_LANDING_PARITY_AUDIT.md`. Neither Django
tree was modified (read-only throughout, confirmed by file modification
times predating this session on every file read).

---

Phase 20 is complete. No implementation occurred. Awaiting explicit
review and approval before any Phase 21 or implementation work begins.
