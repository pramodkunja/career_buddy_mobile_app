# Phase 71 — Navigation Menu Parity Implementation Report

See `docs/PHASE_71_NAVIGATION_PARITY_AUDIT.md` for the full navigation matrix and exact
Django source references. This report covers what changed, what was tested, and what was
verified live.

## Summary of corrections implemented

1. **Unified the guest and authenticated-non-employer drawer branches into one shared item
   list**, matching the real site's own structure (`site_nav.html`'s `{% else %}` branch
   covers both). Previously these were two almost entirely different branches.
2. **Added the full Skill Up submenu (10 items)** and **Resources submenu (6 items)**, in the
   real site's own order and labels, each routed to its correct existing Flutter screen. Every
   destination is already real and built — no new screens were created.
3. **Added "About Us", "Industries", and "Contact Us"** as top-level items that navigate to
   `Home` and scroll to the real, already-rendered landing-page section the real site's own
   anchor points to (`#why`/`#choose-path`/`#contact`).
4. **Added "Dashboard"** to the shared list, visible only when authenticated — the one real
   difference between the guest and authenticated branches on the real site.
5. **Repositioned "Create Resume"** to its real position in the site's own order (after
   Industries, before Contact Us) — its destination and behavior are unchanged from Phase 67.
6. **Removed "Resume Parsing" and "Job Openings"** as flat authenticated-drawer items —
   confirmed these are no longer linked from the real site's nav menu at all (only from the
   page footer, which is a different, unrelated Flutter surface). Both routes remain fully
   reachable elsewhere in the app (ARIA chat action routes, the Home screen's own CTAs, the
   dashboard), so no functionality was removed — only this one now-stale entry point.
7. **Moved "Pro"** from a specially-styled top-level badge into the Resources submenu as
   "CareerBuddy Pro", matching the real site's current structure.

## Files changed and reason for each change

**`lib/shared/widgets/app_nav_drawer.dart`** — the core change. Replaced the guest (`else`)
and authenticated-non-employer (`else if (user != null)`) branches with one shared branch
containing: Home, About Us, Skill Up (`ExpansionTile`, 10 items), Resources (`ExpansionTile`,
6 items), Dashboard (conditional on `user != null`), Industries, Create Resume, Contact Us,
then a divider and either the 2 login tiles (guest) or Profile + Logout (authenticated). The
employer branch (`user.isEmployer`) is untouched — outside this phase's scope, per the audit.
Switched the drawer's root `ListView` to an eager `SingleChildScrollView` + `Column`: with
both submenus open this list can reach ~30 tiles, and a `ListView`'s lazy sliver virtualization
was leaving tiles un-mounted until scrolled near — a real effect on a short device, not just a
test artifact. A bounded, always-eagerly-built `Column` is simpler and correct for a menu this
size.

**`lib/features/home/presentation/providers/home_scroll_request_provider.dart`** (new) — a
small `Notifier<HomeScrollTarget?>` (`HomeScrollTarget` = `about`/`choosePath`/`tutorials`/
`contact`) that the drawer writes to and `HomeScreen` reads/listens to, mirroring the existing
`BuddyOverlayOpenRequestController` pattern already used elsewhere in this codebase for the
identical "ask a possibly-not-yet-mounted widget to do something" problem.

**`lib/features/home/presentation/screens/home_screen.dart`** — added 4 `GlobalKey`s (for
About/Choose-Path/Tutorials/the footer), a post-frame check in `initState` for a scroll request
already pending when the screen first mounts, a `ref.listen` for a request made while the
screen is already on screen, and `_scrollToTarget()`, which calls `Scrollable.ensureVisible` on
the matching key's context (bottom-aligned specifically for the footer, since it's taller than
the viewport and top-aligning would leave the copyright/contact line below the fold; top-
aligned, the default, for the other 3 — their own content sits near each section's top).
Guards for a `null` `currentContext` (the authenticated home body doesn't render the 3 guest-
only sections) so this is a harmless no-op rather than a crash for that combination.

**`lib/features/home/presentation/widgets/public_home_body.dart`** — added 3 optional `Key?`
constructor parameters (`aboutSectionKey`/`choosePathSectionKey`/`tutorialsSectionKey`),
applied to `HomeAboutSection`/`HomeChoosePath`/`HomeTutorialsSection` respectively. `null` for
every other existing caller of this widget — no behavior change for anything else.

**Test files updated to match the new, correct structure** (not weakened — each reflects a
real, confirmed navigation change):
- `test/shared/widgets/app_nav_drawer_test.dart` — rewritten.
- `test/features/home/presentation/screens/home_screen_test.dart` — added a new test group;
  all 47 pre-existing tests still pass unchanged.
- `test/app/client_flow_test.dart` — a real end-to-end integration test driving the actual
  `App()` widget and router (not an isolated test router). Updated 4 flows whose drawer steps
  moved: "Activities" and "Grammar" now go through their new submenus; "Browse All" (no longer
  a real item — the real site has no such entry either) replaced with "English Learning",
  which opens the same tab; "Resume Parsing" (removed from the drawer, confirmed absent from
  the real site's nav) replaced with "Resources → Sitemap", preserving the test's original
  intent of confirming a real screen opens, not `ComingSoonScreen`, for an item that moved;
  "Pro" updated to "Resources → CareerBuddy Pro".
- `test/features/dashboard/presentation/screens/dashboard_screen_test.dart` — one assertion
  updated from checking for "Activities" (now nested) to "Resources" (still a reliable,
  always-visible top-level marker that the drawer rendered real content).

## Before/after navigation behavior

**Before**: a guest saw Home + Create Resume + 2 login tiles only — no About Us, no Skill Up,
no Resources, no Industries, no Contact Us. An authenticated candidate saw a *differently
structured* drawer (Skill Up accordion with only 4 items, 2 of which were genuinely
mislabeled relative to the current site, plus Sitemap/Resume Parsing/Grammar/Job Openings as
flat items, Activities, Dashboard, a gold Pro badge, avatar, Logout) with no About Us,
Resources, Industries, or Contact Us either.

**After**: both a guest and an authenticated non-employer candidate see the same 7-item list
(Home, About Us, Skill Up, Resources, [Dashboard if authenticated], Industries, Create Resume,
Contact Us) plus the appropriate trailing area — matching the real site's own structure
exactly, including which items are visible (all of them, to both) vs. which are merely
destination-gated (every Skill Up/Resources item, exactly as the real site gates them).

## Automated test results and exact counts

- `flutter test test/shared/widgets/app_nav_drawer_test.dart`: **37/37 passed**
- `flutter test test/features/home/presentation/screens/home_screen_test.dart`: **50/50
  passed** (47 pre-existing + 3 new groups covering 6 new tests)
- `flutter test test/app/client_flow_test.dart`: **8/8 passed**
- `flutter test test/features/dashboard/presentation/screens/dashboard_screen_test.dart`:
  **4/4 passed**
- `flutter test` (complete suite): **2,829/2,829 passed**
- `flutter analyze` (whole project): **No issues found.**

These are this session's actual results, not assumed from any historical baseline.

Tests cover, per the task's explicit requirements:
1. Expected guest navigation items and their exact order (`[guest] shows every top-level item
   from the real site's own order, collapsed by default`).
2. Submenu contents and hierarchy — all 10 Skill Up items and all 6 Resources items, asserted
   individually, for both guest and authenticated states.
3. Expand/collapse behavior — each submenu independently, and both open simultaneously.
4. Correct navigation destinations for every single menu selection, including the 2 pairs that
   deliberately share a destination (English Learning/Vocabulary & Idioms; the two
   Certifications entries) and the 4 that open `activity_list` pre-filtered to the real
   category.
5. Authentication-dependent visibility (`Dashboard` guest/authenticated; Profile+Logout vs. the
   2 login tiles) using the existing testable `AuthUser`/`authRepositoryProvider` override
   pattern — no access control was weakened to make this testable.
6. Regression coverage for Create Resume (still present, still navigates correctly) and
   existing login navigation (both login tiles still work).
7. A 320px-wide viewport with both submenus expanded — no layout overflow.
8. Semantic labels — every top-level tile's accessible label contains its own visible text.

No test asserts only that a widget renders; every test checks actual item presence, actual
submenu contents, actual navigation outcomes, or actual scroll-target state.

## Emulator verification

Used the existing Android emulator (`emulator-5554`, already running — not wiped or
recreated). Launched the real app, verified the **guest** flow live, since no authorized test
account exists for a safe authenticated check (consistent with this project's established
convention from Phase 67 — same stated reason, no credentials were invented):

- Opened the drawer: confirmed the exact 7-item top-level list (Home, About Us, Skill Up,
  Resources, Industries, Create Resume, Contact Us) plus the 2 login tiles, matching the audit
  exactly.
- Expanded Skill Up: confirmed all 10 items, in order, with correct labels.
- Expanded Resources independently (with Skill Up still open): confirmed all 6 items, in
  order, and that expanding one never affects the other.
- Tapped "Industries": confirmed it navigates to Home and scrolls straight to the "Choose Your
  Path" section.
- Tapped "About Us": confirmed it navigates to Home and scrolls straight to the "Why job
  seekers and employers choose CareerBuddy" section.
- Tapped "Contact Us": confirmed it navigates to Home and scrolls all the way to the footer,
  landing on the real copyright/link-columns content.
- Tapped "Certifications" (inside Skill Up): confirmed it correctly redirects an unauthenticated
  session to the Job Seeker Sign In screen — the exact behavior the audit predicted from
  `NAV_MAP`'s `protected=True` default, now confirmed live, not just inferred from source.
- Tapped "Create Resume": confirmed it still opens the real, guest-accessible Create Resume
  builder with no login prompt — unchanged regression check.

No login was attempted with any credential; no form was submitted; no state-changing request
was made. Authenticated and employer-branch navigation were verified only via the automated
widget tests above, for the same access-limitation reason stated in Phase 67's own emulator
report.

**Screenshot evidence** (`docs/audit_evidence/phase71/`, all captured at 1080×1920 physical
pixels on the emulator described above):

| File | What it shows |
|---|---|
| `01_guest_drawer_top_level_1080x1920px.png` | The 7-item top-level guest list, collapsed |
| `02_guest_skillup_expanded_1080x1920px.png` | Skill Up expanded, first 8 items visible |
| `03_guest_skillup_full_10_items_1080x1920px.png` | Scrolled to show all 10 Skill Up items + collapsed Resources |
| `04_guest_both_submenus_expanded_1080x1920px.png` | Both Skill Up and Resources expanded simultaneously |
| `05_guest_resources_full_6_items_1080x1920px.png` | All 6 Resources items, plus Industries/Create Resume/Contact Us below |
| `06_industries_scrolls_to_choose_path_1080x1920px.png` | Result of tapping Industries — Choose Your Path section |
| `07_about_us_scrolls_to_about_section_1080x1920px.png` | Result of tapping About Us — the "Why CareerBuddy" section |
| `08_contact_us_scrolls_to_footer_1080x1920px.png` | Result of tapping Contact Us — the real footer, copyright visible |
| `09_certifications_guest_redirects_to_login_1080x1920px.png` | Result of tapping a Skill Up item as a guest — redirected to login, matching the real site |
| `10_create_resume_still_works_1080x1920px.png` | Create Resume still opens correctly — regression check |

## Remaining gaps, blocked destinations, and recommended follow-up

- **English Learning/Vocabulary & Idioms/Aptitude/Tech all open the same "Sections in depth"
  tab** rather than a distinct sub-section within it — a pre-existing `SkillUpScreen`
  limitation from before this phase, documented as PARTIAL in the audit. Fixing it would mean
  adding sub-section deep-linking inside `SkillUpScreen` itself — content/feature work on that
  screen, not a navigation-menu change, so left for a dedicated future phase if desired.
- **For an authenticated session, "About Us"/"Industries"/"Tutorials" resolve to Home but find
  no matching section to scroll to**, since `AuthenticatedHomeBody` doesn't render the guest
  marketing content (a pre-existing, separate scope decision). Verified this is a harmless
  no-op, not a crash. Not fixed, since doing so would mean adding marketing content to the
  authenticated home body — feature work beyond this phase's navigation-menu scope.
- **The employer branch's own real-site structure** (3 items: Employer Dashboard/Jobs/Company
  Profile) was not compared or changed — outside this phase's named recheck list, and Phase
  67's doc comment already documents the existing 6-item consolidation as deliberate.
- No destination required inventing a route — every single item in the final matrix maps to
  an already-existing, already-built Flutter screen or an already-rendered section of the
  existing Home screen. **Nothing in this phase was classified BLOCKED.**

## Confirmation of scope discipline

- Only Flutter project files were modified. Both Django reference directories
  (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout; no backend code,
  database file, secret, credential, signing file, or production data was touched.
- `git status` confirms the diff is limited to exactly: `app_nav_drawer.dart`,
  `home_screen.dart`, `public_home_body.dart`, the new `home_scroll_request_provider.dart`,
  their 4 corresponding/related test files, this report, the parity audit, and
  `docs/audit_evidence/phase71/`'s 10 screenshots. Every other file already modified or
  untracked in the working tree belongs to prior phases (52–70) and was not touched.
- No auth/OTP/authorization/subscription/payment logic was changed — only navigation entry
  points to already-existing, already-gated screens.
- No placeholder screens or fake functionality were created to make the menu appear complete;
  every new tile routes to a real, already-built destination.
- No duplicate destinations were added; the 2 deliberately-shared destinations (English
  Learning/Vocabulary & Idioms; the two Certifications entries) mirror the real site's own
  design, not an invented shortcut.
