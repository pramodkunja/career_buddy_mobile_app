# Phase 49 — Landing-Page Popup Parity: Web to Flutter

## 1. Executive summary

Confirmed, by direct inspection of both the current web source and the
current Flutter code, that Phase 40's finding was still accurate: the real
landing page's auto-shown "path picker" popup (`<dialog id="cpModal">`,
"Which path suits you?") had **no Flutter equivalent at all**. The existing
`HomeChoosePath` widget (an earlier phase's work) already has a doc comment
explicitly noting the popup exists on the web and was deliberately not
built — only its "Find your fit" eyebrow text was reused for the
always-visible inline section. This phase implements the popup itself:
the same content, the same 5-second auto-trigger, the same 2-step
IT/Non-IT → Technical/Non-Technical choice, and the same no-persistence
behavior (confirmed: the real page has no `localStorage`/cookie suppression
— it reshows on every fresh landing-page load, by design, not an oversight
to "fix"). The pre-existing, always-visible `HomeChoosePath` section is
unchanged and untouched.

## 2. Exact web source files and functions inspected

- `templates/landing.html:6781-6836` — the `<dialog id="cpModal">` markup:
  step 1 (`#cpmStep1`: "Which path suits you?", IT Job Seeker link,
  Non-IT Job Seeker button), step 2 (`#cpmStep2`: "Technical or
  Non-Technical?", 2 links to `career_path 'technical'`/`'non-technical'`),
  and the footer (`#cpmBack`, `.skip` "Maybe later").
- `templates/landing.html:7574-7585` — the trigger script in full:
  `var t = setTimeout(function () { if (!document.querySelector
  ('dialog[open]')) { step(false); m.showModal() } }, 5000);`, the
  `step(two)` helper toggling between the 2 `<div>`s, and the Non-IT card's
  own click handler (`$c('cpNonIt')...clearTimeout(t); step(true); m
  .showModal()`) which opens the *same* dialog directly at step 2 instead
  of navigating immediately.
- `templates/landing.html:6724-6775` — the always-visible "Choose Your
  Path" section (`{% if track %}...{% else %}...{% endif %}`), confirmed
  to be a **separate, differently-worded** block from the popup (e.g. the
  popup's IT copy is "Software, data, AI, cloud, testing and security
  roles."; the inline section's is "Explore IT roles, build skills and get
  matched with top opportunities.") — not two renderings of one string.
- `activities/views.py:78-108` (`home()`) and `activities/views.py:120-125`
  (`career_path()`) — confirmed the popup's `{% if not track %}` guard:
  `home()` never sets `track` (popup always eligible to show), `career_path
  ()` always sets it (popup never shows on a track-specific page); and
  confirmed `home()`'s only exclusion is an authenticated employer
  (redirected to `job_home` before `landing.html` ever renders) — an
  authenticated non-employer student is not excluded by the Django view
  itself.
- Confirmed, by grep, **no** `localStorage`/`sessionStorage`/cookie
  read-or-write anywhere in the popup's script or `cpModal`'s markup — the
  "every landing-page load" in the script's own comment is literal.

## 3. Source-to-mobile comparison

| Aspect | Web (verified) | Flutter (this phase) |
|---|---|---|
| Trigger | `setTimeout(..., 5000)` on every page load | `Timer(Duration(seconds: 5), ...)` started in `HomeScreen.initState` |
| Suppressed if | any `<dialog>` already open (checked at fire time) | the route is no longer the top of the navigator stack (`ModalRoute.of(context)?.isCurrent`) — the closest same-intent equivalent, since `context.push` (unlike a real page navigation) never unmounts `HomeScreen` or cancels its pending timer |
| Audience | guests and authenticated non-employer students (`home()` has no auth check beyond excluding employers) | guests only — `AuthenticatedHomeBody` has no "Choose Your Path" equivalent to begin with (a separate, pre-existing scope decision from an earlier Home redesign, not reopened here); see §10 |
| Content | 2-step wizard, exact copy in §2 | Reproduced verbatim — step 1 "Which path suits you?"/"Pick a track...", step 2 "Technical or Non-Technical?"/"Choose the kind..." |
| IT Job Seeker action | `<a href="{% url 'career_path' 'it' %}">`, direct navigation | `context.push(RoutePaths.careerDepartments, extra: 'it')` — the same existing destination `HomeChoosePath`'s own IT card already uses |
| Non-IT Job Seeker action | Advances to step 2, no navigation yet | Advances to step 2 (local dialog state), no navigation |
| Step 2 "Technical" / "Non-Technical" | 2 distinct backend routes (`career_path('technical')`/`'non-technical'`), each filtering to one sub-group | Both push the same existing `RoutePaths.careerDepartments` (track `'non-it'`) — the same simplification Phase 43's `CareerDepartmentsScreen` and `HomeChoosePath`'s own Non-IT card already use (that screen already shows both Non-IT groups together); see §10 |
| Close ("×") | Native `<dialog>` form-submit close | `IconButton` calling `Navigator.of(context).pop()` |
| Backdrop dismissal | Native `<dialog>` default: **not** dismissible by clicking the backdrop (no `click` listener on it; closing is only via the × / "Maybe later" / a card) | **Fixed in Phase 50** — `barrierDismissible: false` now matches this exactly; see the Phase 50 addendum |
| Back button (step 2 → step 1) | `#cpmBack` button | `TextButton.icon` "Back", same behavior |
| "Maybe later" | Closes via the native form | `TextButton` calling `Navigator.of(context).pop()` |
| Persistence across visits | **None** — confirmed no storage/cookie anywhere | None added — reshows on every fresh `HomeScreen` mount, matching the verified source |
| Display frequency | Once per page load (5s delay, barring the suppression above) | Once per `HomeScreen` mount, via the `_popupHandled` flag preventing a second show for that instance |

## 4. Root cause of the confirmed gap

`HomeChoosePath` (built in an earlier Home-redesign phase) already shows
its own doc comment acknowledged the real popup's existence and explicitly
chose, at the time, to reuse only its eyebrow text rather than build the
popup itself — this phase closes that explicitly-flagged, still-open gap.

## 5. Files created or modified and why

**New:**
- `lib/features/home/presentation/widgets/home_path_picker_popup.dart` —
  the dialog content widget (`HomePathPickerPopup`), a 2-step
  `StatefulWidget` with its own internal step state, reusing `AppColors`/
  `AppRadius`/`AppSpacing` and a small private card widget styled
  consistently with `HomeChoosePath`'s own `_PathCard`.

**Modified:**
- `lib/features/home/presentation/screens/home_screen.dart` — converted
  `HomeScreen` from `ConsumerWidget` to `ConsumerStatefulWidget` (it had no
  instance state before) to own the 5-second `Timer`, the `_popupHandled`/
  route-current guards, and the `_choosePath` wrapper that cancels the
  timer the instant a path is chosen directly (mirrors the web's
  `clearTimeout(t)`).
- `lib/features/home/presentation/widgets/public_home_body.dart` — the
  `onItJobSeeker`/`onNonItJobSeeker` destinations, previously hardcoded
  inside this widget, are now passed in as constructor parameters from
  `HomeScreen` (the only call site) — needed so `HomeScreen` can wrap them
  with the popup-canceling logic above. No destination changed.
- `lib/features/home/presentation/widgets/home_choose_path.dart` — doc
  comment only, updated to record that the popup this file's own comment
  referenced is now implemented, and that both widgets share the same
  callbacks rather than duplicating destinations.

No backend, routing table, authentication, or subscription file was
touched. No new route or screen was created — the popup reuses the
existing `RoutePaths.careerDepartments` destination exclusively.

## 6. Tests added and their coverage

All added to `test/features/home/presentation/screens/home_screen_test.dart`
(a new `'Phase 49 — path picker popup'` group, 13 tests):

- Does not appear before 5 seconds; appears at 5 seconds for a guest, with
  the exact real copy (verified distinct from `HomeChoosePath`'s own
  wording, not a duplicate string).
- Never appears for an authenticated (non-employer) user.
- IT Job Seeker card: navigates to `Career Departments Screen: it` and
  dismisses the popup.
- Non-IT Job Seeker card: advances to step 2, does **not** navigate.
- Step 2 Back returns to step 1.
- Step 2 Technical / Non-Technical: both navigate to
  `Career Departments Screen: non-it` and dismiss the popup.
- Close (×) and "Maybe later": both dismiss without navigating.
- Choosing a path directly (before 5s) permanently cancels the pending
  popup — it does not appear later even after 5+ more seconds elapse.
- Navigating away before 5s via an unrelated CTA (hero "Get Started Free")
  also suppresses the popup.
- Renders without a `takeException()` failure at 320/360/390px widths,
  including step 2's content.

No existing test was weakened or deleted. The pre-existing "tapping IT/
Non-IT Job Seeker in Choose Your Path" tests (verifying the always-visible
inline section, unaffected by this phase) still pass unchanged.

## 7. Test results

- **Focused** (`test/features/home`): 45 passing, 0 failing (was 32 before
  this phase; +13, matching §6's list exactly).
- **Full suite**: **2,480 passing, 0 failing** (Phase 48 baseline 2,467;
  +13 new, exactly matching the 13 tests listed in §6).

## 8. Static analysis

**8 issues** — identical to the Phase 48 baseline, same pre-existing
unused-test-parameter warnings in unrelated resume-controller test files.
0 new issues.

## 9. Emulator verification

Device: `emulator-5556`, Android 14 (API 34). Storage checked first (host:
203Gi free; emulator `/data`: 667MB free) — not wiped or reset. The popup
is fully guest-reachable, so this phase's live verification needed no
authenticated session and no limitation was hit.

- **Confirmed live**: app launches cleanly, no exception or overflow
  anywhere in the run log.
- **Confirmed live**: the popup appears ~5 seconds after Home loads, with
  the exact real copy, correctly layered above the page content and below/
  beside the floating Buddy launcher (not obscuring it) — screenshot
  `02_popup_after_5s.png`.
- **Confirmed live**: tapping "Non-IT Job Seeker" advances to step 2
  ("Technical or Non-Technical?") with no navigation yet — screenshot
  `03_step2.png`.
- **Confirmed live**: tapping "Technical" navigates to the real Non-IT
  career-departments screen and the popup is gone — screenshot
  `04_after_technical_tap.png`.
- **Confirmed live**: returning to Home afterward does **not** re-show the
  popup (the path was already chosen for this screen instance) —
  screenshot `05_back_to_home.png`.
- Screenshots and the full run log saved to
  `/private/tmp/claude-501/-Users-kunjapramodmahajan-Flutter-Projects-Career-Buddy-LMS/c536c444-170e-4e2d-b1fa-059604770772/scratchpad/phase49/`
  — session-scratch files, not part of the repository.

## 10. Remaining missing / blocked / unverified behavior

- ~~Backdrop dismissal does not match the web.~~ **Fixed in Phase 50** —
  see the addendum below.
- **Step 2's Technical/Non-Technical distinction is not separately
  destination-routed.** Both options reach the same combined Non-IT
  screen, per the Phase 43 simplification already in place for the inline
  section's own Non-IT card — building 2 genuinely separate, filtered
  destinations was out of this phase's scope (no new screens/endpoints
  directive) and was already a standing, previously-made decision, not a
  new gap this phase introduced.
- **The popup is guest-only — an existing, deliberate parity limitation,
  not a bug.** The inspected Django `home()` view (`activities/views.py:
  78-108`) allows an authenticated non-employer student to render
  `landing.html` too (it only redirects an authenticated *employer* away,
  to `job_home`), so on the real web that student would also see this
  popup. The current Flutter `HomeScreen` renders a structurally different
  `AuthenticatedHomeBody` for any authenticated user, and that body has no
  "Choose Your Path" section at all — a pre-existing decision from an
  earlier Home-redesign phase, not something Phase 49 or Phase 50
  introduced or is scoped to revisit. Adding the popup to that branch
  without its underlying section would mean inventing navigation for a
  flow that branch doesn't otherwise offer, which is outside "implement
  only confirmed gaps." This is recorded here as a known, intentional
  scope boundary of the current authenticated Home structure, not as an
  overlooked requirement.

## 11. Confirmation: both Django reference directories untouched

Neither `Career_Buddy_LMS/` nor `royalStaffing_CB01/` was edited, created
in, or deleted from — every file under both trees was only read this
phase.

## 12. Confirmation: no backend/auth/subscription/signing/deployment/publishing changes

- No Django view, template, URL, model, or settings file was modified.
- No authentication, OTP, or subscription-gating logic was touched; the
  popup's audience check (`AuthAuthenticated`) only reads the existing
  `authControllerProvider` state, never alters it.
- No production account was used; the one live emulator session only
  interacted with guest-accessible content (the popup itself requires no
  login).
- No signing material was inspected or touched; no release build, APK/AAB
  upload, or Play Store action was taken.

---

## Phase 50 addendum — backdrop-dismissal correction

### Root cause and exact fix

Re-confirmed directly against `royalStaffing_CB01/templates/landing.html`
before changing anything: `#cpModal`'s own script (`:7574-7585`) never
attaches a `click` listener to the dialog or its `::backdrop`
(`:4078`), and a native `<dialog>` shown via `.showModal()` does not close
on a backdrop click by default — Phase 49's finding was accurate. The
mismatch was that Flutter's `showDialog` defaults to `barrierDismissible:
true`, so tapping outside the popup closed it when the real page does
nothing. Fix: one parameter added to the single `showDialog` call in
`_maybeShowPathPicker` (`home_screen.dart`) —
`barrierDismissible: false`. Android system back was deliberately left at
its own default (it still pops the dialog route), since the real
`<dialog>` also never prevents its `cancel` event (the Escape-key
equivalent) for `cpModal` specifically (confirmed: the only `cancel`
listener in the whole file, `:8904`, belongs to a different dialog,
`rbConfirm`) — so leaving Android back free to dismiss the popup is the
closest match to the verified source, not a newly invented behavior.

### Files changed

- `lib/features/home/presentation/screens/home_screen.dart` — added
  `barrierDismissible: false` to the popup's `showDialog` call, with a doc
  comment recording the evidence above. No other line in this file changed.
- `test/features/home/presentation/screens/home_screen_test.dart` — 2 new
  tests added to the existing `'Phase 49 — path picker popup'` group (see
  below). No existing test was modified.
- `home_path_picker_popup.dart` and `home_choose_path.dart` — **not
  touched** this phase, confirmed via `git status`.

### Tests added

1. "tapping outside the dialog (the barrier) does not dismiss it" —
   taps a point near the screen's top-left corner (clearly outside the
   dialog's own content box, inside the modal barrier) and asserts the
   popup is still showing.
2. "repeated pumps/rebuilds after the popup appears never produce a 2nd
   dialog" — pumps several more frames after the popup is shown (covering
   the Buddy launcher's own continuously-repeating animation, which keeps
   triggering rebuilds) and asserts `find.byType(Dialog)` still finds
   exactly one.

Both are deterministic widget tests using `tester.pump(Duration(...))` to
advance the existing 5-second timer — no real-time delays, no flakiness
introduced. All of Phase 49's original 13 tests (5-second trigger, close
button, "Maybe later", step 2 Back, IT/Non-IT navigation and dismissal,
direct-path-selection cancellation, route-change guard, narrow-width
rendering) were re-run unchanged and still pass, confirming none of that
behavior regressed.

### Focused test results

- The `'Phase 49 — path picker popup'` group in `home_screen_test.dart`:
  **15 passing, 0 failing** (13 carried over from Phase 49 + 2 new).
- The whole `test/features/home` directory (`home_screen_test.dart` +
  the pre-existing, untouched `home_hero_test.dart`): **47 passing, 0
  failing**.

### Full test suite results

**2,482 passing, 0 failing.** Phase 49's baseline was 2,480 — this phase
added exactly 2 new tests and changed none, so the full-suite delta (+2)
matches the focused delta exactly.

### Static analysis compared with baseline

**8 issues** — re-run and compared directly against Phase 49's own
baseline (not assumed unchanged): identical 8 pre-existing
unused-test-parameter warnings in unrelated resume-controller test files,
same files and line numbers as before. 0 new issues introduced.

### Emulator verification

Device: `emulator-5556`, Android 14 (API 34). Storage checked first (host:
203Gi free; emulator `/data`: 667MB free, 89% used but sufficient) — not
wiped, reset, or recreated.

- **Confirmed live**: the popup appears ~5 seconds after Home loads
  (screenshot `01_popup_shown.png`).
- **Confirmed live**: tapping a point outside the dialog's content (near
  the top-left corner, clearly within the dimmed barrier) leaves the popup
  open — the exact regression this phase fixes (screenshot
  `02_after_backdrop_tap.png`, visually identical to the pre-tap state).
- **Confirmed live**: the close (×) button dismisses the popup, returning
  cleanly to the Home screen underneath (screenshot
  `03_after_close_button.png`).
- **Not independently re-verified live this phase** (relied on the passing
  automated test suite instead, since the underlying mechanism —
  `Navigator.of(context).pop()` — is identical and was already live-
  verified in Phase 49): "Maybe later", step 2 Back, and the IT/Non-IT
  step navigation. Marking these "not independently verified live in
  Phase 50" rather than claiming a redundant on-device re-check that
  wasn't actually performed.
- No Flutter exception, layout overflow, or crash appeared anywhere in the
  run log for this session.
- Screenshots and the run log saved to
  `/private/tmp/claude-501/-Users-kunjapramodmahajan-Flutter-Projects-Career-Buddy-LMS/c536c444-170e-4e2d-b1fa-059604770772/scratchpad/phase50/`
  — session-scratch files, not part of the repository (this project has no
  documented convention for committing verification screenshots).

### Remaining known limitations

- Step 2's Technical/Non-Technical distinction still reaches one combined
  Non-IT screen (unchanged from Phase 49 — a standing Phase 43 decision,
  not reopened this phase; no new screens or backend routes were created).
- The popup remains guest-only; see the corrected, more precise wording in
  §10 above — the Django `home()` view itself would also show this to an
  authenticated non-employer student, but Flutter's authenticated Home
  branch has no equivalent section to attach it to, which this phase was
  explicitly told not to redesign.

### Confirmation: both Django reference directories untouched

Neither `Career_Buddy_LMS/` nor `royalStaffing_CB01/` was written to —
both were only read this phase (`templates/landing.html`'s dialog markup
and script, re-confirmed directly, as described above).

### Confirmation: no backend/publishing/signing/deployment changes

No Django file, API, database, authentication, OTP, or subscription logic
was touched. No signing material was inspected. No release build, APK/AAB
upload, or Play Store action was taken. No production account was used —
the live verification session only interacted with guest-accessible
content.
