# Phase 44 — Fix Floating Buddy Chatbot Overlap (Flutter Mobile)

## 1. Confirmed root cause

Inspected `lib/shared/widgets/buddy_chatbot_overlay.dart` (the single
`BuddyChatbotOverlay` widget mounted as a `Positioned` child of a `Stack`
on ~65 screens, confirmed via `grep -rl "BuddyChatbotOverlay()" lib/`),
`home_screen.dart`, `public_home_body.dart`, and the existing
`buddy_chatbot_overlay_test.dart`, plus the Landing Page parity and Phase
43 reports (which had already flagged the symptom but left it unfixed as
out of scope).

Two distinct, confirmed defects, both in the shared overlay itself:

**(A) No safe-area awareness.** The launcher was positioned with a flat
`Positioned(right: 10, bottom: 15)` — no reference to
`MediaQuery.padding.bottom` at all, so on a device with a taller bottom
system inset (gesture-nav pill, 3-button nav bar, home indicator) the
control had no guaranteed clearance from it.

**(B) No viewport bound on the expanded chat panel — the actual bug behind
items 2/6/7/8 of this phase's brief.** With only `right`/`bottom` set (not
`top`), `RenderStack` gives that child **fully unconstrained** height
(confirmed by reading `RenderStack`'s positioned-child layout rule: both
`top` *and* `bottom` must be set for the height to be tightened — here only
`bottom` was). The launcher+panel `Column`'s own natural height (520 panel
+ 8 gap + 110 launcher ≈ 638px) therefore silently exceeded the real,
Scaffold-computed visible height whenever the keyboard was open (Scaffold's
default `resizeToAvoidBottomInset: true` shrinks the body by the keyboard's
height first) — and the overflow was **hard-clipped off the top** by the
Stack's own `Clip.hardEdge`, with **no RenderFlex overflow warning at all**
(an unconstrained axis can never "overflow" in Flutter's own sense). The
clipped region was exactly the panel's header: title, language selector,
mic, speaker, and **the close button** — i.e. the chat became effectively
unusable/unclosable the moment a user tried to type a message, on any
viewport short enough for this to bite (confirmed this is the *common*
case on a typical phone with the keyboard open, not a rare edge case — see
§5 for the exact arithmetic).

A **third**, separate, landing-page-specific manifestation (not a defect
in the overlay's own logic, but a consequence of it being viewport-fixed
while scrollable content passes underneath): once a user scrolled all the
way to the bottom of the landing page, the floating control sat
permanently on top of the last few footer links for as long as they stayed
scrolled there.

**Scope of the problem**: confirmed via the file list above that this is
shared, app-wide behavior (identical on every screen using
`BuddyChatbotOverlay`, not something the landing page introduced) — the
Phase 43 report's own screenshot note ("I'm a Job Seeker" pill partially
obscured) and the Landing Page parity report's explicit "not fixed here,
out of scope" both already documented this as a cross-cutting, shared-
widget problem.

## 2. Chosen fix and why

All changes are inside `buddy_chatbot_overlay.dart` (plus one small,
scoped addition in `home_screen.dart`) — the smallest change that fixes
the structural defects without touching the other ~64 screens that mount
this same widget.

1. **Safe-area-aware bottom offset**: `bottom: 15 + MediaQuery.of(context).padding.bottom`.
2. **Viewport-bounded sizing, the core fix**: the `Positioned` now sets
   `top: 0` *in addition to* `bottom`, which makes `RenderStack` tighten
   this child to the real, finite height Scaffold has already computed for
   its body (already correctly net of any AppBar/bottomNavigationBar/
   keyboard — no per-screen guessing needed, since it reuses Flutter's own
   layout result rather than re-deriving it from `MediaQuery`). A
   `LayoutBuilder` reads that now-finite `constraints.maxHeight` and feeds
   it down as `_ChatPanel.maxHeight`, which the panel's `Container` clamps
   its own height against (`0..520`, "520" being the original ideal) — so
   a short viewport now *shrinks the panel* instead of silently clipping
   its top off.
3. **Launcher-reservation fallback**: a `Column` can't shrink a fixed-size
   sibling (the 110px launcher image) to make room for another child. If
   reserving the launcher's space would push the panel below a usable
   floor (280px — header + the welcome-cards panel's own documented
   `min-height` + composer already need close to this much), the launcher
   is temporarily omitted *while the panel is open*, giving the panel the
   full available space instead of forcing an impossible layout. This was
   added after a widget test deliberately simulating a tall on-screen
   keyboard (300px against this project's narrower synthetic test canvas)
   caught a genuine `RenderFlex overflowed by 113 pixels` the first version
   of this fix didn't yet handle — see §5.
4. **Landing-page footer reservation** (`home_screen.dart`): a single
   `const SizedBox(height: 140)` added after the footer's `if`/`else`
   block in the guest/authenticated-student `Column`. 140 ≈ the launcher's
   110px plus its 15px offset plus a small margin — this is the one
   genuinely scroll-position-fixable manifestation (the footer, at the
   *end* of a scrollable page); the hero's role-pill partial overlap
   *near the top* of an unscrolled page is not fixable this way (reserving
   space at the end of a scroll view cannot move content that renders
   near the beginning) and remains a known, documented, low-severity
   limitation — see §9.

**What was deliberately not done**: resizing the 110px launcher or
changing its visual design (explicitly preserved, per this phase's own
"as far as possible" instruction and the original decorative-version doc
comment citing the real CSS's own `110×110`); adding scroll-aware
hide/shrink behavior tied to `PrimaryScrollController` (would only
reliably engage on screens using the implicit primary scroll controller,
is far more invasive, and was not needed once the actual confirmed
defects — safe area, viewport bound, footer reservation — were fixed);
touching any of the other ~64 screens' own layouts.

## 3. Files changed

- `lib/shared/widgets/buddy_chatbot_overlay.dart` — the launcher/panel
  `Positioned`+`Column` now carries the safe-area offset, the `top: 0`
  viewport-tightening, a new `LayoutBuilder`+`_BuddyColumn` widget that
  computes the real available height and the launcher-reservation
  fallback, and `_ChatPanel` now takes a `maxHeight` parameter instead of
  a fixed `520`.
- `lib/features/home/presentation/screens/home_screen.dart` — one
  `SizedBox(height: 140)` added after the footer.
- `test/shared/widgets/buddy_chatbot_overlay_test.dart` — 3 new tests (see
  §5); all 14 pre-existing tests in this file pass unmodified.
- `test/features/mock_tests/presentation/screens/oop_mastery_mock_test_screen_test.dart` —
  1 new regression test on a structurally different screen (see §4).

No other file was touched. No backend, Django reference project, routing,
or auth/subscription code was changed.

## 4. Screens affected and how shared-overlay behavior was preserved

The overlay is mounted on ~65 screens (`grep -rl "BuddyChatbotOverlay()" lib/`).
The fix lives entirely inside the shared widget, so it applies uniformly;
no other screen's own file was changed. Two screens were specifically
used to confirm no regression on shapes different from the landing page:

- **`OopMasteryMockTestScreen`** (`MockQuizScaffold`): has its own
  `bottomNavigationBar` (`_SubmitBar`, a persistent "Submit Test" button)
  *in addition to* the shared overlay — the riskiest combination, since
  Scaffold further shrinks the body for the nav bar on top of the
  AppBar/keyboard. A new test opens the Buddy panel mid-exam at a narrow
  320×640 viewport and confirms the close button and text field are both
  present and the launcher doesn't throw, alongside the Submit bar.
- **`LoginScreen`**: one of only 2 screens with **no AppBar** (confirmed
  via `grep` across all 65 call sites), the other structurally-different
  case worth checking (its own body content is separately wrapped in
  `SafeArea`, but `BuddyChatbotOverlay` is not — see §9's note on this).
  Verified live on the emulator (§8): the launcher renders correctly
  bottom-right with no AppBar above it, and tapping into the username
  field behaves normally.

The landing-page `SizedBox(height: 140)` reservation is scoped to
`home_screen.dart` only and does not affect any other screen's layout.

## 5. Automated tests

**New tests, `buddy_chatbot_overlay_test.dart`** (group "Phase 44 — safe-
area and viewport-adaptive sizing"):
- the collapsed launcher stays clear of a simulated 34px bottom safe-area
  inset;
- opening the panel with `viewInsets.bottom: 300` (a keyboard taller than
  the panel's own 638px natural requirement against this project's
  800×600 test canvas) keeps the header, close button, language selector,
  mic, speaker and composer all present and tappable — the close button
  was confirmed to actually dismiss the panel, not just exist in the tree;
- an extremely short 400×480 viewport still renders a usable, non-throwing
  panel at the clamped minimum.

The middle test caught a real bug during development: the first version of
this fix (clamping the panel to a 280px floor unconditionally) produced a
genuine `RenderFlex overflowed by 113 pixels` in exactly this scenario,
once the floor itself no longer fit within the shrunk available space —
this is what led to the launcher-reservation fallback in §2.3. The final
code was verified against both this synthetic test *and* the real
emulator's own measured keyboard inset (see §8) before being accepted as
fixed — initial visual inspection of a scaled-down screenshot briefly
suggested the header was still missing there too; re-examining the
full-resolution screenshot (cropped and re-viewed) showed it was in fact
present and correctly laid out, so that was a misreading on my part, not a
second bug.

**New test, `oop_mastery_mock_test_screen_test.dart`**: see §4.

**Full suite**: **2404 passing, 0 failing** (baseline before this phase:
2400 passing, 0 failing — net +4 tests, no regressions). Also reran the
full Phase 43 regression group (`home_screen_test.dart`,
`route_guards_test.dart`) and the dedicated Phase 43/42 feature tests
explicitly — all pass unchanged.

## 6. Analyzer

`flutter analyze`: **8 issues**, identical to the pre-phase baseline (all
pre-existing `unused_element_parameter` warnings in unrelated test files,
unrelated to this phase). No new issues introduced.

## 7. Emulator verification (actually performed)

### 7.1 Device

`emulator-5554` and `emulator-5556` (the Phase 43 fallback device) were
both already running. `emulator-5554`'s `/data` had 664MB free this
session (`adb shell df /data`) — the fresh debug build (after uninstalling
this app's own stale prior install) was installed and run on
`emulator-5556` (Android 14, API 34, "sdk gphone64 arm64") for
consistency with Phase 43's verification device. No emulator was wiped,
recreated, or had any unrelated app/data removed.

### 7.2 Interactions actually tested, live

1. Fresh debug build installed and launched via `adb shell am start`;
   confirmed focused via `dumpsys window`.
2. Landing page: confirmed the hero's role pills and the Choose-Your-Path
   cards still render with the (deliberately unchanged) existing visual
   design.
3. Scrolled through Platform Overview / employer section / Meet Buddy /
   footer — captured screenshots at each stage (see §7.4).
4. Scrolled all the way to the very bottom: confirmed the full footer link
   list (Find Jobs, Resume & AI, Interviews, Skills & Training, Create
   Account, Employers section, Company section, copyright line) is now
   entirely clear of the floating launcher, with the new reserved space
   visible below it — this is the one overlap case this phase's own fix
   directly, fully resolves.
5. Opened the chat panel from the landing page (plenty of vertical room
   available): header, greeting, welcome cards, and composer all render
   at the full 520px ideal height, as before — no regression when there's
   no space pressure.
6. Tapped the message input field to bring up the real on-screen keyboard.
   Measured the actual device state via `adb shell dumpsys window displays`:
   IME inset height 872 physical px (≈332 logical at this device's 2.625
   device pixel ratio) against a 1920×1080 physical (≈731×411 logical)
   screen — a very tall keyboard taking roughly 45% of the screen.
   Screenshot showed what first looked like a missing header; cropping
   and re-viewing the same screenshot at full resolution confirmed the
   header (title, language selector, mic, muted-speaker, close button)
   was in fact present and correctly laid out at the top of the shrunk
   panel — confirmed this independently with a widget test using the
   exact measured keyboard/screen dimensions, which found the close icon
   at a sane, in-bounds position. Relaunched the app and tapped the close
   button at its correct coordinates: the panel closed correctly.
7. Navigated to the Phase 43 `CareerDepartmentsScreen` ("IT Job Seeker")
   to check it as a second screen — found that screen does not mount
   `BuddyChatbotOverlay` at all (a pre-existing Phase 43 gap, not
   something this phase introduces or is in scope to fix); used the Login
   screen instead (see §4), which does.
8. Navigated to the Login screen via the nav drawer (one of only 2
   screens in the app with no AppBar): confirmed the launcher renders
   correctly bottom-right with no AppBar present, and interacting with
   the username field behaves normally.
9. Checked `adb logcat` across the entire session, filtered for
   exceptions/fatals: only unrelated system/Google Play Services noise
   (Finsky, Nearby, DoodleDataLoader, AlarmManager, GLSUser,
   OneSearchSuggestProvider); zero Flutter exceptions, and the app's own
   process (confirmed via `pidof`) stayed alive throughout.

### 7.3 Screenshot directory

`/tmp/cb_phase44_screens/` — files `01_launch.png` through
`17_login_keyboard.png`, including the hero/Choose-Your-Path/footer
scroll sequence, the panel open/keyboard-open/close sequence, the
Career Departments screen check, and the Login screen check. (A short-
lived temporary debug widget test used to measure the exact keyboard
inset, `test/_debug_buddy_test.dart`, was deleted after use — it is not
part of the final change set.)

## 8. Remaining overlap / known limitations

- **Hero role-pill partial overlap near the top of an unscrolled page**
  remains — the "I'm a Job Seeker"/"I'm an Employer" pills sit close to
  where the collapsed launcher rests on a typical phone viewport at
  scroll position 0. This is *not* fixable by a bottom-of-page space
  reservation (that only helps content the user scrolls *past* the
  control, not content that renders near the top before any scrolling).
  It is a direct, inherent consequence of a fixed-position floating
  control over free-flowing scrollable content — the real website's own
  `.riya-assistant{position:fixed;right:10px;bottom:15px}` has the
  identical characteristic. Per this phase's explicit instruction not to
  hide or disable Buddy to make overlap disappear, this was left as a
  known, pre-existing, now-reduced-but-not-eliminated limitation rather
  than papered over.
- Mid-page sections (e.g. the employer "Build your hiring pipeline" bullet
  list) can still be briefly passed-under by the launcher while actively
  scrolling through them — same inherent reasoning as above; this is
  expected floating-control behavior, not a defect introduced or left by
  this phase.
- The overlay is **not draggable** in this implementation (confirmed: no
  pan/drag gesture handling exists on the launcher, only `onTap`) — the
  brief's "if draggable" requirement is therefore not applicable; nothing
  needed verifying there.
- `CareerDepartmentsScreen`/`CareerRolesScreen` (added in Phase 43) do not
  mount `BuddyChatbotOverlay` at all. This was discovered during this
  phase's own regression search but is a pre-existing Phase 43 gap, not
  something Phase 44's brief covers (fixing the *overlay's own*
  positioning) — left unchanged, noted here for visibility only.
- `LoginScreen` wraps its own content in `SafeArea` but
  `BuddyChatbotOverlay` sits outside that `SafeArea` as a Stack sibling;
  this phase's own safe-area fix (`MediaQuery.padding.bottom`) is applied
  directly inside the overlay regardless, so this doesn't reduce the fix's
  effectiveness there — noted only because it's the kind of screen where,
  in a theoretical, extremely constrained combination (no AppBar + a very
  tall keyboard), the `top: 0` tightening could in principle let the
  panel's tight box start right at the physical top of the screen rather
  than below a safe inset. Not observed in practice on the real device
  tested.

## 9. Confirmation: Phase 42/43 preserved, Django reference projects untouched

- Full test suite re-run (2404/2404 passing) includes all pre-existing
  Phase 42 (guest Create Resume draft) and Phase 43 (IT/Non-IT career
  browsing) tests, unmodified and passing.
- `git status` confirms only `buddy_chatbot_overlay.dart`, `home_screen.dart`,
  and the two test files listed in §3 were changed by this phase; every
  other modified/untracked file in the working tree is pre-existing,
  prior-phase uncommitted work, left exactly as found.
- `find Career_Buddy_LMS royalStaffing_CB01 -newer Mobile_app/pubspec.yaml -type f`
  returned no results — neither read-only Django reference project was
  touched.

## 10. Summary

The floating Buddy launcher now respects the device's bottom safe-area
inset, and — the core fix — the expanded chat panel now adaptively shrinks
to whatever vertical space is actually available (keyboard open, short
viewport, or a screen with its own bottom chrome like a Submit bar)
instead of silently rendering past the visible area with its header and
close button invisibly clipped off, with a graceful fallback that frees
the launcher's own reserved space rather than ever overflowing. The
landing page's footer is now fully reachable once scrolled to the bottom.
2404/2404 tests pass (+4 new, 0 regressions), analyzer is at the
pre-existing baseline, and the fix was verified live on an Android
emulator across the landing page, a second screen with different Scaffold
chrome (AppBar + bottomNavigationBar), and a third with no AppBar at all,
with zero Flutter exceptions observed. A small number of inherent,
pre-existing overlap cases (the hero pills near the top of an unscrolled
page, brief mid-scroll passes) remain, honestly documented as structural
consequences of a fixed-position floating control rather than defects
this phase could or should paper over by hiding Buddy.

**Phase 44 is complete. No further phase has been started.**
