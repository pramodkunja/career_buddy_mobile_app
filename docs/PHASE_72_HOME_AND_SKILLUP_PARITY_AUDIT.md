# Phase 72 — Authenticated Home & Skill Up Deep-Link Parity Audit

## Reference source files and implementation details inspected

**Updated Django site** (`royalStaffing_CB01`, read-only):
- `activities/views.py`'s `home()` view (lines 78-109), read in full — the exact
  authenticated-vs-guest branching logic for the Home URL.
- `templates/landing.html` — spot-checked the hero's `is_authenticated` conditionals (the only
  2 conditionals in the whole template; neither gates `#why`/`#choose-path`/`#videos`).
- `riya_bot/skillup_views.py`'s `skillup_hub` view (101 lines), read in full — the `?section=`
  query-parameter handling.
- `core/navigation.py` — re-confirmed the exact `english-learning`/`vocabulary`/`aptitude`/
  `tech` `NAV_MAP` entries and the `ALLOWED_SECTIONS` allow-list.
- `templates/skillup/skillup_hub.html` (lines 35-75) — the hash-restore script and its own
  inline comment explaining *why* `?section=` exists (URL fragments can't survive a login
  redirect, so the server-side query param stands in for one).
- `static/001 Career Buddy/index.html` — located and read the `depth-english` (line 2383),
  `depth-aptitude` (line 2600), and `depth-tech` (line 2759) `<article>` blocks, confirming
  each has genuinely distinct headings and lesson/course content, not just 3 scroll positions
  on identical content.

**Flutter project** (the only directory modified):
- `docs/PHASE_71_NAVIGATION_PARITY_AUDIT.md` / `..._IMPLEMENTATION_REPORT.md` — read in full;
  this audit does not take Phase 71's "PARTIAL" findings on faith, re-verifying both against
  current source and current Flutter code below.
- `lib/shared/widgets/app_nav_drawer.dart`, `lib/features/home/presentation/screens/
  home_screen.dart`, `lib/features/home/presentation/widgets/public_home_body.dart`,
  `lib/features/home/presentation/providers/home_scroll_request_provider.dart`,
  `lib/features/home/presentation/widgets/authenticated_home_body.dart` — read in full.
- `lib/features/skill_up/presentation/screens/skill_up_screen.dart` (781 lines) and
  `lib/features/skill_up/data/skill_up_data.dart` — read in full, including every
  `SkillUpSection`'s own `id` field.
- `lib/app/router/route_paths.dart` / `app_router.dart` — the existing `skillUpSections`/
  `skillUpCertifications`/`sitemap` tab-index wiring and the `activitiesWithCategory`
  query-parameter pattern already established for a structurally identical problem.

## Workstream A — Authenticated Home section navigation

### Current behavior found (before this phase)

`HomeScreen` branches on `authControllerProvider`: a guest renders `PublicHomeBody` (which
includes `HomeAboutSection`, `HomeChoosePath`, and `HomeTutorialsSection`, each wrapped in a
`GlobalKey` Phase 71 wired up); an authenticated user renders `AuthenticatedHomeBody`, which —
for a non-employer student — rendered only `HomeHero`. None of the 3 target sections existed
in that branch, so `homeScrollRequestProvider`'s `about`/`choosePath`/`tutorials` targets found
a `null` `currentContext` and silently did nothing for an authenticated candidate (Phase 71's
own `_scrollToTarget` already guarded this safely — no crash, just no scroll).

### Verified intended behavior, with source references

`activities/views.py:78-82`:
```python
def home(request):
    if request.user.is_authenticated and (request.session.get('portal') == 'employer' or hasattr(request.user, 'employer_profile')):
        return redirect('job_home')
    ...
    response = render(request, 'landing.html', context)
```
The view's own comment (lines 100-103) states explicitly that the Skill Up/Resources menus'
`/go/<key>/` gateway "handles the candidate-login check, so **the same markup serves
signed-in and anonymous visitors**." Only an **employer** session is redirected away, to
`job_home` — a separate view/template already confirmed out of this phase's scope.

`landing.html` was checked for any `{% if user.is_authenticated %}` branching around the 3
sections in question; none exists. The only 2 conditionals in the whole template hide 2 sign-up
pills in the hero once authenticated and set a `data-auth` attribute for an unrelated JS hook —
neither gates `#why`, `#choose-path`, or `#videos`.

**Verdict: PASS (gap confirmed real, now closed).** The real site genuinely shows the
About/Choose-Your-Path/Tutorials sections to an authenticated non-employer candidate — there is
no separate authenticated home template, and `/dashboard/` (a different, `@login_required`
view) is not what the nav's "Home" link or `{% url 'home' %}#...` anchors resolve to. This is a
real Flutter content gap, not a deliberate site difference Flutter was correctly leaving alone.

### Scope decision (and why the narrower fix, not a full rebuild)

The real site's `landing.html` also includes several *other* sections identical for guest and
candidate (Platform Overview, Career Journey, the job-seeker/employer portal story cards, Meet
Buddy, Resume Maker Teaser, Testimonials) — none of which are targets of any nav-drawer item
this or the prior phase named. Rebuilding `AuthenticatedHomeBody` to mirror the *entire*
landing page would be genuine content-parity work for the whole Home screen — explicitly out
of this phase's scope ("This phase does not include ... general UI redesign ... or broad
refactoring"). The implementation below adds **only** the 3 sections the 3 affected nav items
actually target, reusing the existing widgets verbatim (no content duplicated or invented),
leaving the rest of `AuthenticatedHomeBody`'s layout and the employer branch untouched.

## Workstream B — Skill Up deep-linking

### Current behavior found (before this phase)

`SkillUpScreen`'s "Sections in depth" tab (`initialTabIndex: 1`) rendered all of
`SkillUpData.sections` in one scrollable column with no way to pre-select or scroll to any one
of them. The nav drawer's "English Learning", "Vocabulary & Idioms", "Aptitude", and "Tech"
items all pushed the bare `RoutePaths.skillUpSections` path, landing every one of them at the
same scroll position (the top of the tab).

### Verified intended behavior, with source references

`riya_bot/skillup_views.py:63-94` (`skillup_hub`): `?section=<id>` is validated against
`ALLOWED_SECTIONS` (`core/navigation.py:116-123`) — an invalid value is safely dropped to `""`.
The validated id is passed into the template, which (`templates/skillup/skillup_hub.html:41-62`)
runs `window.history.replaceState(null, "", pathname + "#" + section)` before the hub's own
on-load router scrolls to that hash — **a purely client-side, one-time hash-scroll mechanism,
never a server-side content filter**. The view's own comment explains exactly why this
indirection exists: a URL fragment can't survive the login redirect a gated section triggers,
so the query param stands in for one.

`core/navigation.py:57-64` confirms the exact targets:
```python
"english-learning": Destination("English Learning", "skill_up", {"section": "depth-english"}),
"vocabulary": Destination("Vocabulary & Idioms", "skill_up", {"section": "depth-english"}),  # deliberate, same target
"aptitude": Destination("Aptitude", "skill_up", {"section": "depth-aptitude"}),
"tech": Destination("Tech", "skill_up", {"section": "depth-tech"}),
```
"English Learning" and "Vocabulary & Idioms" are **confirmed identical destinations on the real
site itself** — not a bug to "improve" by inventing a more granular Flutter-only distinction
(e.g. a separate vocabulary sub-anchor that exists in the HTML but that the real nav doesn't
actually use). "Aptitude" and "Tech" are genuinely distinct: `static/001 Career Buddy/
index.html`'s `depth-aptitude` (line 2600, "Aptitude & Reasoning" — quant/logical/verbal/
situational/cognitive-speed tracks) and `depth-tech` (line 2759, "Tech Center" — 10
departments, 93 roles) have real, different headings and lesson/course lists, confirmed by
reading both articles directly.

**Verdict: PASS (gap confirmed real, now closed) for 3 distinct destinations, not 4.** Flutter
already had equivalent internal structure to distinguish them: `SkillUpSection.id` (confirmed
in `skill_up_data.dart`, pre-existing before this phase) is already set to the literal real
anchor ids `depth-english`/`depth-aptitude`/`depth-tech` — the data model already named the
distinction; only the screen's own scroll behavior was missing.

## Website-versus-Flutter destination and selection matrix

| Item | Real destination | Content distinct? | Flutter destination (after this phase) | Status |
|---|---|---|---|---|
| About Us | `#why` on `landing.html`, same for guest/candidate | — | `Home` → scroll to `HomeAboutSection`, now rendered in both `PublicHomeBody` and `AuthenticatedHomeBody` | **MISSING → IMPLEMENTED** |
| Industries | `#choose-path` on `landing.html`, same for guest/candidate | — | `Home` → scroll to `HomeChoosePath`, now rendered in both bodies | **MISSING → IMPLEMENTED** |
| Resources → Tutorials | `#videos` on `landing.html`, same for guest/candidate, not even login-gated | — | `Home` → scroll to `HomeTutorialsSection`, now rendered in both bodies | **MISSING → IMPLEMENTED** |
| Skill Up → English Learning | `nav_go('english-learning')` → `depth-english` | Shared with Vocabulary & Idioms, by design | `RoutePaths.skillUpSectionsFor('depth-english')` → scrolls to that `SkillUpSection` | **PARTIAL → IMPLEMENTED** |
| Skill Up → Vocabulary & Idioms | `nav_go('vocabulary')` → `depth-english` (same as above) | Same as English Learning, by design | `RoutePaths.skillUpSectionsFor('depth-english')` (same) | **PARTIAL → IMPLEMENTED** (correctly shared, not over-distinguished) |
| Skill Up → Aptitude | `nav_go('aptitude')` → `depth-aptitude` | Distinct (quant/reasoning content) | `RoutePaths.skillUpSectionsFor('depth-aptitude')` → scrolls to its own `SkillUpSection` | **PARTIAL → IMPLEMENTED** |
| Skill Up → Tech | `nav_go('tech')` → `depth-tech` | Distinct (10 departments, 93 roles) | `RoutePaths.skillUpSectionsFor('depth-tech')` → scrolls to its own `SkillUpSection` | **PARTIAL → IMPLEMENTED** |

## PASS / PARTIAL / MISSING / BLOCKED summary

- **Gap 1 (About Us/Industries/Tutorials for authenticated candidates): MISSING → IMPLEMENTED.**
  Confirmed via direct source reading that the real site shows these sections to an
  authenticated non-employer candidate; Flutter's `AuthenticatedHomeBody` was missing them
  entirely. Closed by reusing the existing section widgets, not by rebuilding the screen.
- **Gap 2 (Skill Up Aptitude/Tech/English/Vocabulary deep-linking): PARTIAL → IMPLEMENTED.**
  Confirmed the real site's own mechanism is a client-side hash-scroll with 3 genuinely
  distinct destinations (not 4); Flutter already had the matching data-level distinction
  (`SkillUpSection.id`) but no scroll wiring. Closed with the same `Scrollable.ensureVisible` +
  `GlobalKey` pattern already used elsewhere in this exact screen (`_HomeTab`'s own "Featured
  tracks" button) and in `HomeScreen` itself (Phase 71).
- **Nothing in this phase is BLOCKED.** Both gaps had clear, source-confirmed intended
  behavior and an existing Flutter architecture capable of expressing it without inventing
  content, endpoints, or backend behavior.

## Ambiguities / product decisions surfaced (not guessed past)

- The real site's own richer per-section interaction (a collapsible card with Edit/Done +
  reorder, confirmed in earlier phases' own audits of other repeatable UI) does not apply
  here — Skill Up's "Sections in depth" is a flat scroll-to-anchor list on the real site too,
  so no such interaction was invented for parity.
- Whether a *future* phase should pursue full Home-page content parity for authenticated users
  (Platform Overview, Career Journey, the portal story cards, Meet Buddy, Resume Maker Teaser,
  Testimonials — all also identical for guest/candidate per the same `home()` evidence) is a
  real, larger product decision this phase deliberately does not make — flagged here as
  recommended follow-up, not silently expanded into.
- "Vocabulary & Idioms" could, in principle, be made to scroll to the more specific
  `grp-english-vocab` sub-anchor that does exist inside the `depth-english` article on the real
  page (confirmed present in `static/001 Career Buddy/index.html`) — but the real site's own
  nav deliberately does not do this (`core/navigation.py`'s own literal destination values).
  Implementing that finer distinction would exceed the real site's own parity, not match it, so
  it was not done.
