# W013 — Workshop Dashboard: Web → Flutter

> **Update (later batch, superseding §4/§6 below):** both limitations this
> doc originally documented are now fixed. (1) "Enter Workshop" for all
> three practice types now pushes the real `GdTopicScreen`/
> `JamTopicsScreen`/`RoleplayHomeScreen` — none of them is a
> `ComingSoonScreen` anymore. (2) The Free Plan under-counting bug (§4) is
> fixed: `WorkshopDashboardController` now calls a dedicated
> `ActivitiesRepository.getWorkshopModules()`, which scrapes the real,
> unconditionally-ungated `/activities/workshop/` page directly
> (`ApiEndpoints.workshopDashboardHtml`) instead of reusing the Free-Plan-
> gated general Activities list — no backend change was needed after all;
> the same `parseActivityListHtml` parser already handled this page's
> identical card markup. The rest of this document (web behavior
> inspection, per-card field mapping) remains accurate.

## 1. Web files inspected

- `activities/urls.py:6` — `path('workshop/', views.workshop_dashboard, name='workshop_dashboard')`
- `activities/views.py:862-885` — `workshop_dashboard()` (`@login_required`)
- `templates/activities/workshop_dashboard.html` — the full, 61-line template (read in full)
- `activities/models.py:31-` — `Activity` model (`category`, `level`, `objective`, `icon_class`, `color_class`, `is_active`, `order`), `CATEGORY_CHOICES` (`'workshop'` → `'Interactive Workshop'`)
- `activities/views.py:618-` — `_activity_list_data()` and `activities/views.py:778-` — `activity_list_api()` (the existing JSON endpoint this reuses)
- `templates/activities/modules/roleplay_home.html:125` — the only other template referencing `workshop_dashboard` at all (a "back to workshop dashboard" link, confirming there is no forward link into this page from anywhere else in the web's own navigation)
- `dashboard.html:283-303` (previously inspected, W002) — confirmed the dashboard's own "Workshop" Quick Start chip goes to `activity_list?category=workshop` (the *generic* filtered Activities list), a different page from this one

## 2. Web behavior

**Layout**: page header ("Interactive Workshop" + subtitle), a "Back to all Activities" link, then a grid of cards — one per `Activity` row where `category='workshop'` and `is_active=True`, ordered by `order`.

**Per-card fields** (all from the `Activity` row, computed in `workshop_dashboard()` with no completion/lock logic at all — this view has no `get_completion_rate`/free-plan access check, unlike `activity_list()`):
- `#{{ forloop.counter }}` — position-based numbering, not the activity's id
- `level` badge
- a static "Workshop" badge (hardcoded copy, not data)
- `title`
- `objective`, truncated to 110 characters (`|truncatechars:110`)
- a static "Real-time Interaction" line (hardcoded, not data-driven)
- an "Enter Workshop" button linking to `activity.url`

**`activity.url` routing** (`activities/views.py:870-874`, computed from a case-insensitive title match): `'group discussion'` → `/gd/`, `'jam'` → `/jam/`, `'role play'` → `/roleplay/`, anything else → `#` (a dead link on the web itself).

**States**: no loading state (server-rendered), no explicit empty state (an empty `workshop_modules` list just renders an empty grid, no message), no error state, no lock/completion indicators anywhere on this specific page.

**Data source**: no JSON API exists for this specific view — `workshop_dashboard()` is plain server-rendered HTML built from `Activity.objects.filter(category='workshop', is_active=True).order_by('order')`.

## 3. Flutter files changed

New:
- `lib/features/activities/presentation/controllers/workshop_dashboard_controller.dart`
- `lib/features/activities/presentation/screens/workshop_dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/workshop_entry_card.dart`
- `test/features/activities/workshop_dashboard_controller_test.dart`
- `test/features/activities/presentation/screens/workshop_dashboard_screen_test.dart`

Modified:
- `lib/app/router/route_paths.dart` — new `workshopDashboard` route constant
- `lib/app/router/app_router.dart` — new route entry
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — new entry point card (both tablet and phone layouts)

## 4. API/data integration (Case A — existing JSON API reused)

No new endpoint. `workshop_dashboard()` has no JSON sibling, but the exact same underlying data (`Activity` rows) is already exposed by `activity_list_api` (`GET /activities/api/?category=workshop`), which the app's existing `ActivitiesRepository.getActivityList(category:)` already calls (built in W002/W003). `WorkshopDashboardController` calls this with `category: 'workshop'` and additionally filters the result to `category == 'workshop'` client-side.

**Why the client-side filter is necessary (a confirmed, documented limitation — not a bug)**: `_activity_list_data()` (`activities/views.py:618-`) only applies the `?category=` filter for full-access (paid) users. For a **Free Plan** user, the `category` parameter is ignored entirely and the response is always their fixed `FREE_PLAN_ACTIVITY_TITLES` selection — which is not guaranteed to be workshop-only. The dedicated `workshop_dashboard()` web view has **no such restriction at all** (no free-plan check, no lock check) — so for a Free Plan user, this Flutter screen may show **fewer** workshop modules than the real web page would (potentially zero, if no workshop titles are in their free selection), because it is built on an endpoint that was designed for a different page's access rules. A Full-Access (paid) user sees the identical, correct set either way. This cannot be fixed without a backend change, which is out of scope — documented here rather than silently accepted.

## 5. Functionality implemented

- Real API-backed list of workshop `Activity` rows (title, objective, level), reproducing the exact fields the web page shows and no others
- Position-based numbering (`#1`, `#2`, …), matching `forloop.counter`
- 110-character objective truncation with an ellipsis, matching Django's `truncatechars:110` exactly
- Static "Workshop" badge and "Real-time Interaction" line, matching the web's own hardcoded copy
- "Enter Workshop" real navigation for every card, title-keyword routed (Group Discussion / JAM / Role Play / unknown), each to a distinct `ComingSoonScreen` — none of these three practice features exist in Flutter yet (Role Play practice is explicitly out of scope as a separate task); every case is real, working navigation, never a dead tap target (this app's established convention, applied even where the web's own link is `href="#"`)
- Loading / retryable-error / `UnauthorizedFailure`-triggers-logout states, matching this app's standard pattern (`ActivityListScreen`, `DashboardScreen`)
- A minimal, clearly-labeled empty state ("No workshop activities available right now.") — the web has none at all for this case (an empty grid); a fully blank screen is not acceptable mobile UX, so this is a deliberate, documented, minimal addition, not fabricated data
- A new dashboard entry point (`WorkshopEntryCard`) — the web page itself is not linked from anywhere reachable in normal navigation (confirmed: the only other template reference is a "back" link *from* Role Play), so this app surfaces it directly, the same documented pattern already used for W020's Mock Tests entry card

## 6. Known limitations

- **Free Plan users may see fewer workshop modules than the real web page** — see §4. Not fixable without a backend change.
- Icon/color styling (`icon_class`/`color_class`, Bootstrap/FontAwesome-specific strings) is not reproduced literally — these are presentation-only CSS/FontAwesome class names with no meaningful Flutter equivalent; a single consistent app-themed badge style is used instead. No informational content is lost.
- "Enter Workshop" for all three practice types (Group Discussion, JAM, Role Play) and any unmatched title leads to a `ComingSoonScreen`, not a working practice session — none of those are implemented in Flutter (Role Play practice is explicitly a separate, out-of-scope task).

## 7. Tests

```
flutter analyze: PASS
flutter test: 336/336 PASS
```

11 new tests: 4 controller (`workshop_dashboard_controller_test.dart`), 7 screen (`workshop_dashboard_screen_test.dart` — rendering, truncation, navigation for a recognized and an unrecognized title, empty state, error/retry, 320px/1024px responsive). No existing test was modified or weakened. Two genuine `RenderFlex` overflow bugs were found by the new responsive test and fixed in `workshop_dashboard_screen.dart` (the badge row and the "Real-time Interaction" row).

## 8. Web integrity

```
Web project modified: NO
```

`git status --short` / `git diff --stat` against the Django project show only the same pre-existing, unrelated working-tree changes confirmed at the end of every prior phase (W020-W023) — nothing touched by this task.
