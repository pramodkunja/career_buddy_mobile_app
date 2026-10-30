# Phase 79 — Skill-Up Department & Role Deep-Link Parity Audit

## Scope

Phase 78 flagged, as an out-of-scope "existing limitation," that the real
site's `?section=` contract accepts more than the `depth-*` ids Flutter
already implements (Phase 72). This phase closes that specific gap: 4 new
deep-link categories — Tech Center department, Tech Center role, Non-IT
department, Non-IT role — resolved through the existing Flutter routes,
catalog data, and screens, with Phase 72's `depth-*` links and Phase 77/78's
access-control behavior left unchanged.

## The real Django contract (read directly, not assumed)

`riya_bot/skillup_views.py` (`royalStaffing_CB01`, read in full this phase):

```python
# Tech and Non-IT Center departments and roles (#grp-tech-<dept>,
# #role-nonit-<dept>--<role>, ...), linked from the career-path role pages; the hub
# opens that department or role.
_TECH_ROLE_RE = re.compile(r"(grp|role)-(tech|nonit)-[a-z0-9-]{1,150}")
...
requested_section = request.GET.get("section", "")
allowed = requested_section in ALLOWED_SECTIONS or _TECH_ROLE_RE.fullmatch(requested_section)
section = requested_section if allowed else ""
```

- `ALLOWED_SECTIONS` (`core/navigation.py`) is the pre-existing `depth-*`
  allowlist Phase 72 already implements — unrelated to, and unaffected by,
  this phase.
- `_TECH_ROLE_RE.fullmatch` accepts exactly 4 shapes: `grp-tech-<slug>`,
  `role-tech-<slug>`, `grp-nonit-<slug>`, `role-nonit-<slug>`, where a role
  id's `<slug>` is itself `<department-slug>--<role-slug>` (a double-hyphen
  separator — confirmed below). The regex has no `re.I` flag, so uppercase
  input is rejected, not normalized.
- There is **no decorator or view branch anywhere in `skillup_hub`** that
  treats these 4 new kinds differently from a `depth-*` id — they all flow
  through the same single `@login_required` gate and the same `section`
  template variable. **This phase changes nothing about who can reach
  `skillUpSections` — only what a resolvable `?section=` value now does once
  an authenticated user is already there.**

## Real identifier examples (read directly from the static bundle, not invented)

The Skill-Up static bundle actually served at this `index.html` (`static/001
Career Buddy/index.html` under both reference directories) contains the real
ids this phase targets:

- Tech Center departments are static `id="grp-tech-<slug>"` anchors on
  server-rendered `<article>` elements, e.g. `id="grp-tech-development"`,
  `id="grp-tech-devops-infrastructure"` (10 total, one per Tech Center
  department — matches the 10 `kTechCenterDepartments` entries from Phase
  76's generated catalog).
- Tech Center roles are static `id="role-tech-<dept-slug>--<role-slug>"`
  anchors nested inside their department's article, e.g.
  `id="role-tech-business-analysis--business-analyst-ba"`.
- Non-IT department/role links (`#grp-nonit-<dept-slug>`,
  `#role-nonit-<dept-slug>--<role-slug>`) appear only as `<a href="#...">`
  hrefs inside a comment-flagged block — `<!-- NON-IT CENTER (built from
  static/data/nonit_departments.json; see initNonIt) -->` — confirmed there
  is **no static `id="grp-nonit-..."` element anywhere in the file**: Non-IT
  content is rendered entirely client-side by a separate JS router
  (`initNonIt()`), not present as server-rendered markup the way Tech Center
  is.
- `landing.html`'s own Career Paths explorer (a different real page, not the
  hub itself) generates `role-nonit-*` and `role-tech-*` "Start Learning"/
  "Learn" deep links dynamically from role/department names using this exact
  JS slugify function:
  `s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')` — this
  is the function ported verbatim into `slugifyNonItName` (see below). No
  department-level (`grp-nonit-*`/`grp-tech-*`) link generator was found in
  `landing.html`; those ids are only ever followed from the hub's own
  internal "back" links or typed/bookmarked directly, which is why the
  Non-IT implementation resolves them as its own entry point rather than
  assuming they always arrive mid-session.

## The two architectures are genuinely different (read directly, not assumed)

Reading both real client-side routers in full (not inferring from visual
similarity) showed Tech Center and Non-IT Center behave fundamentally
differently once a `grp-*`/`role-*` id is reached:

- **Tech Center** (`render()` in the hub's own inline script): a non-`#load=`
  hash is treated as a **pure `scrollIntoView` target on an already fully
  rendered static page** — no view-swap, no fetch. The department/role
  content a `grp-tech-*`/`role-tech-*` id points to is already in the DOM;
  the hash just scrolls to it.
- **Non-IT Center** (`initNonIt()`, a separate, self-contained hash router):
  fetches `static/data/nonit_departments.json` and **replaces `#niBody`'s
  content** between `grid()` (all departments) / `deptView()` (one
  department's roles) / `roleView()` (one role's skills + "Start Learning"
  link) depending on the hash. A Non-IT role deep link on the real site
  shows a dedicated, content-replaced role view, not a scroll position.

This difference is why the Flutter implementation is intentionally
asymmetric (see "Flutter implementation approach" below): matching each
real behavior as closely as Flutter's existing architecture allows, not
forcing both into one identical mechanism.

## Existing Flutter behavior before this phase

- `RoutePaths.skillUpSections`'s `GoRoute` builder passed
  `state.uri.queryParameters['section']` straight to
  `SkillUpScreen(initialTabIndex: 1, initialSectionId: sectionId)`, which
  only understands the Phase 72 `depth-*` ids — any `grp-*`/`role-*` value
  landed on the Sections tab with no scroll and no resolution, silently
  doing nothing useful (not a crash, just a no-op).
- `TechCenterDepartmentsScreen` → `TechCenterRolesScreen` → course sheet and
  `SkillUpNonItDepartmentsScreen` → `SkillUpNonItRolesScreen` → role sheet
  (Phase 76) were reachable only by tapping through the UI; nothing could
  jump straight to a specific department or role via a `?section=` value.
- Phase 77/78's route-guard coverage for `skillUpSections` (and the Tech
  Center routes it now also serves) is unaffected by any of this — the
  guard runs on `state.matchedLocation` before the query string is ever
  read.

## Identifier-to-catalog mapping implemented

- `parseSkillUpDeepLinkId` (`lib/features/skill_up/domain/
  skill_up_deep_link.dart`) mirrors `_TECH_ROLE_RE` exactly: same 4
  `kind`/`catalog` combinations, same lowercase-only `[a-z0-9-]{1,150}`
  slug charset, no case normalization. A role id's compound slug is split on
  the **first** `--` occurrence — verified safe by grepping the generated
  Tech Center catalog for any slug containing `--` (zero matches), so no
  real slug can be misparsed by this choice.
- Tech Center ids resolve against the existing `kTechCenterDepartments`
  compile-time catalog (Phase 76) via `findTechCenterDepartment`/
  `findTechCenterRole` — a role is always resolved through its **declared
  parent department**, never by role slug alone, because role slugs are
  reused across departments (confirmed real example:
  `devops-engineer` exists under both `development` and
  `devops-infrastructure`, re-confirmed again this phase against the actual
  generated catalog).
- Non-IT ids resolve against `skillUpNonItDepartmentsProvider`'s loaded
  `List<CareerDepartmentGroup>` via `findNonItDepartment`/`findNonItRole`.
  Non-IT department/role entities have no stored slug field (confirmed by
  reading `career_department.dart` in full), so `slugifyNonItName` derives
  one from the display name at lookup time using the real site's own JS
  slugify logic, ported exactly.

## Proposed (and implemented) Flutter approach

- **Tech Center department id** → open `TechCenterRolesScreen` for the
  resolved department (the existing Phase 76 screen, no new screen needed).
- **Tech Center role id** → open the same `TechCenterRolesScreen` for the
  role's parent department, with the matching role card scrolled into view
  (`Scrollable.ensureVisible`, the same established pattern as the Phase 71
  nav-drawer anchor scroll) — matching the real site's own scroll-only
  behavior for Tech Center.
- **Non-IT department id / Non-IT role id** → a new thin resolver screen,
  `SkillUpNonItDeepLinkScreen`, because the Non-IT catalog loads
  asynchronously (`FutureProvider`, unlike Tech Center's synchronous
  `const` data): it waits for `AsyncData`, then `pushReplacement`s to the
  existing `SkillUpNonItRolesScreen` for the resolved department — and, for
  a role id, first records the target role name in a small shared
  `Notifier<String?>` (`skillUpNonItRoleOpenRequestProvider`, the same
  "shared request" pattern as `HomeScrollRequestController`/
  `BuddyOverlayOpenRequestController`) so the roles screen auto-opens that
  role's existing sheet on mount — matching the real site's `roleView()`
  content-replacement behavior as closely as Flutter's modal-sheet pattern
  allows, without inventing a new "role detail page."
- An unresolvable-but-well-formed id (a real department/role slug that
  doesn't exist, or a department/role that was renamed) falls back to the
  existing `SkillUpScreen(initialSectionId: ...)` path — the identical
  fallback an unrecognized `depth-*` id already receives, not a new
  behavior invented for this phase.
- All of this logic lives in one pure function, `buildSkillUpSectionsScreen`
  (`lib/app/router/skill_up_sections_route.dart`), extracted from the
  `GoRoute` builder for the same testability reason `route_guards.dart`'s
  own `computeRedirect` is kept free of `BuildContext`/`GoRouterState`.

## Access-control considerations

- **No route path changed and no new route was added.** All 4 new
  categories are resolved from the existing `skillUpSections` query
  parameter, which is already covered by Phase 78's route-guard tests (the
  guard runs on the matched path, before `buildSkillUpSectionsScreen` or
  the query string is ever consulted).
- Tech Center and Non-IT Center's own routes
  (`techCenterDepartments`/`techCenterRoles`,
  `skillUpNonIt`/`skillUpNonItRoles`) are unchanged destinations reached via
  `pushReplacement`/direct `build()` — their own pre-existing route-guard
  coverage (Phase 77/78) applies identically whether reached by tapping
  through the UI or via one of this phase's new deep links, because it is
  the exact same route.
- No employer-specific branch exists in the real `skillup_hub` view (Phase
  78's own finding, re-confirmed this phase by re-reading the same source)
  — this phase introduces no new access distinction between candidate and
  employer sessions.

## Confirmed gaps/risks going into implementation

- `TechCenterRolesScreen`'s existing body was a `ListView` — Phase 71's own
  precedent (the nav drawer) already established that a plain
  lazily-virtualized `ListView` can silently fail `Scrollable.ensureVisible`
  for an off-screen item, since un-mounted items have no `RenderObject` to
  scroll to. This needed to be converted to an eager
  `SingleChildScrollView`+`Column` for the new role-highlight feature to be
  reliable for every department, including the largest
  (`devops-infrastructure`, 11 roles — confirmed via the generated catalog).
- `SkillUpNonItRolesScreen` was a `StatelessWidget`; auto-opening a role's
  sheet on mount requires `initState`, so it needs to become a
  `ConsumerStatefulWidget` — this is a widget-type change, not a
  behavior change to its existing tap-to-open flow, which this phase leaves
  untouched.
