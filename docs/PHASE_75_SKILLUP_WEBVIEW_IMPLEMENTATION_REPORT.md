# Phase 75 — Skill-Up WebView & Lesson Accessibility Implementation Report

See `docs/PHASE_75_SKILLUP_WEBVIEW_ACCESSIBILITY_AUDIT.md` for the full
source-backed investigation this report implements.

## Summary

One confirmed, reproducible defect was fixed: Android back ignored the
WebView's own internal navigation history, always leaving the lesson screen
entirely instead of stepping back through pages a lesson had navigated to
internally (demonstrated with real content: `Vocabulary/Basicindex.html`'s
own links to its 10 phonics pages). The historical "383 unreachable Tech
Center pages" claim was re-verified as still numerically accurate but
re-attributed to its real cause (an empty lesson catalog/missing browsing
UI, not the unrelated JSON file Phase 51 blamed) and is documented, not
implemented, as a large feature build outside this phase's "targeted fixes"
scope. The historical "fullscreen blocked" uncertainty was resolved at the
source level: the currently pinned `webview_flutter_android` version already
provides a default fullscreen handler, and `skill_up_lesson_screen.dart`
never overrides it — no code change was needed or made for fullscreen.

## Each confirmed issue addressed and its root cause

### 1. Android back navigation ignored WebView-internal history (fixed)

**Root cause**: `SkillUpLessonScreen`'s `build()` returned a plain
`Scaffold` with no `PopScope`/back interception at all — the system back
button always triggered the default `Navigator.pop()`, regardless of
whether the WebView itself had somewhere to go back to first.

**Fix**: Wrapped the `Scaffold` in `PopScope(canPop: false,
onPopInvokedWithResult: ...)` (matching this codebase's own existing
convention, e.g. `mock_quiz_scaffold.dart`). The handler
(`_handleBack`) checks `await _controller.canGoBack()`: if the WebView has
internal history, it calls `_controller.goBack()` instead of leaving the
screen; otherwise it pops the route normally. The check runs
unconditionally, regardless of the `_loading`/`_error`/`_locked` overlay
state, since it reflects the WebView's own navigation history independent
of what's currently shown on top of it.

### 2. 383 unreachable Tech Center pages (documented, not implemented)

**Root cause** (corrected from Phase 51's misattribution): `skill_up_data.dart`'s
hand-maintained lesson catalog has entries for all 29 flat `TechCenter/*.html`
files but none of the 383 nested `TechCenter/<dept>/<role>/*.html` files, and
no department → role → course browsing screens exist for them.

**Why not implemented this phase**: closing this requires a new ~383-entry
data manifest (department/role/course → relative path) that doesn't exist
in any form today, plus 2-3 new browsing screens and routes mirroring the
real site's Tech Center navigation depth. This is a large, genuine feature
build, not a "targeted fix" — the task brief explicitly excludes "an
unrelated redesign or refactor," and Phase 4 of the brief only authorizes
implementing issues that are both confirmed AND fixable as a focused change.
Recommended as its own future phase (see "Remaining issues" below).

### 3. Fullscreen WebView support (no code change — resolved by existing dependency)

**Finding**: `webview_flutter_android` 4.14.1 (the version already pinned in
`pubspec.lock`) auto-registers a default `onShowCustomWidget`/
`onHideCustomWidget` handler (confirmed by reading
`android_webview_controller.dart:1193-1248` in the installed package)
whenever the app hasn't registered its own — which
`skill_up_lesson_screen.dart` never does. No defect was found to fix; no
code was changed.

## Files changed and reasons

- **`lib/features/skill_up/presentation/screens/skill_up_lesson_screen.dart`**
  — added `_handleBack()` and wrapped the `Scaffold` in `PopScope(canPop:
  false, onPopInvokedWithResult: ...)`. No other behavior changed: loading,
  error, locked-view, and cookie-forwarding logic are all untouched.
- **`pubspec.yaml`** — added `webview_flutter_platform_interface: ^2.15.1`
  as a `dev_dependency` (already a transitive dependency at the same
  version via `webview_flutter`), following this project's own established
  pattern (`video_player_platform_interface`, `open_file_platform_interface`,
  `path_provider_platform_interface` are already added the same way, each
  with the same "otherwise a transitive-only dependency" justification) —
  needed to build a fake `WebViewPlatform` for testing, since this screen
  had zero test coverage before this phase.
- **`pubspec.lock`** — updated by `flutter pub get` after the above.
- **`test/features/skill_up/presentation/screens/skill_up_lesson_screen_test.dart`**
  (new file) — this screen's first-ever test suite (see below).

## Tests added and their results

All tests are new; this screen had zero test coverage before this phase
(confirmed: no `WebViewPlatform` fake existed anywhere in the codebase). A
minimal `_FakeWebViewPlatform`/`_FakeWebViewPlatformController`/
`_FakeNavigationDelegate`/`_FakeWebViewWidget` set was hand-written
(matching this codebase's consistent hand-rolled-fake convention — no
mocking library was introduced), implementing only the exact surface
`skill_up_lesson_screen.dart` actually calls; every other
`PlatformWebViewController`/`PlatformNavigationDelegate` method keeps its
safe default (`throws UnimplementedError`) from the base class, since this
screen never calls them. The fake WebView widget deliberately sizes itself
to fill all given space (`SizedBox.expand`), matching how a real platform
view actually lays out — a shrink-to-fit fake was tried first and produced
a spurious `BuddyChatbotOverlay` layout overflow, an artifact of the fake's
sizing, not a defect in the real app (documented here for transparency; the
fix was to the fake, not to `BuddyChatbotOverlay`, which was never touched).

Test results — `flutter test
test/features/skill_up/presentation/screens/skill_up_lesson_screen_test.dart`:
**8 tests, all passed**:
1. Shows a loading indicator, then the WebView once the page finishes loading.
2. Sends the lesson URL built from the route args as the real request.
3. Phase 38 regression: a 403 from `SkillUpAccessMiddleware` shows the
   locked view, not a generic error (pre-existing behavior, now covered for
   the first time).
4. A non-403 HTTP error is not treated as locked content.
5. A main-frame web resource error shows a retryable error view, and Retry
   reloads the lesson.
6. A sub-resource (non-main-frame) error is ignored, matching real
   browser-tab behavior.
7. **Phase 75** — pops the lesson screen when the WebView has no internal
   history.
8. **Phase 75** — navigates within the WebView instead of leaving the
   screen when internal history exists (the back-navigation fix).

## Focused and full-suite test results

- `flutter test test/features/skill_up/presentation/screens/skill_up_lesson_screen_test.dart`
  → 8/8 passed.
- `flutter test test/features/skill_up/` (full feature regression) → 48/48
  passed, no regressions in any other Skill-Up screen.
- `flutter test` (complete suite) → **2,862 tests, all passed, 0
  failures** (2,854 from before this phase + 8 new).
- `flutter analyze` (whole project) → **No issues found!**

## Emulator verification

- Used the existing `Android_Emulator_34` AVD (already running from prior
  phases, not wiped or recreated), device id `emulator-5554`.
- Relaunched the app and captured screenshots under
  `docs/audit_evidence/phase75/`:
  - `01_guest_home.png` — guest home loads cleanly with the Phase 75 code
    present.
  - `02_guest_drawer.png` — guest nav drawer unaffected.
  - `03_skillup_expanded.png` — the Skill Up submenu expands correctly,
    listing English Learning/Grammar/Vocabulary & Idioms/Speaking &
    Presentation/Writing & Correspondence/Negotiation & Meetings/
    Interactive Roleplay/Aptitude/Tech — unchanged from Phase 71/72's
    verified structure.
  - `04_guest_skillup_login_redirect.png` — tapping "English Learning" as a
    guest correctly redirects to the Job Seeker login screen, confirming
    the Skill-Up login gate (documented in the audit) is unaffected and
    still enforced.
- **Authenticated lesson access, live back-navigation through real lesson
  content, and live fullscreen behavior were NOT verified on-device.** Every
  lesson screen requires a logged-in, non-employer session to reach at all,
  and no authorized test account is available — consistent with the
  limitation stated in every prior phase of this project. The back-navigation
  fix and all other screen states were instead verified through the
  automated widget-test suite above, built directly from the real template
  markup (`Vocabulary/Basicindex.html`'s actual internal links,
  `SkillUpAccessMiddleware`'s actual 403 behavior), not a live account.

## Flows not verified, and why

- Authenticated candidate reaching any Skill-Up lesson live: blocked, no
  test account.
- Live, on-device fullscreen entry/exit for any of the 585
  `exam_guard.js`/inline-fullscreen lesson pages: blocked, same reason —
  these all sit behind the same login gate. Addressed instead via direct
  package-source verification (see audit report).
- Whether the 383 currently-unreachable Tech Center pages' own content
  renders correctly in a WebView: not applicable — they have no Flutter
  entry point to test from, by design of this phase's scope decision.

## Remaining issues, limitations, and recommended next steps

- **383 Tech Center nested lesson pages remain unreachable** — a confirmed,
  real, large gap. Recommended as its own future phase: build a data
  manifest (department → role → course → relative path, covering all 383
  files) and 2-3 new browsing screens/routes mirroring the real site's Tech
  Center depth, reusing `SkillUpLessonScreen`/`buildSkillUpLessonUrl`
  unchanged (both already support nested paths with zero changes, confirmed
  by `skill_up_lesson_url.dart`'s own per-segment percent-encoding).
- **Live fullscreen/back-navigation confirmation on an authenticated
  session** remains a recommended follow-up once a test account is
  available, to confirm the source-level findings hold on a real device.

## Scope-safety confirmation

- Every file changed is inside the Flutter project: the lesson screen, the
  new test file, `pubspec.yaml`/`pubspec.lock`, this phase's two reports,
  and 4 new screenshots under `docs/audit_evidence/phase75/`.
- Both Django reference directories (`royalStaffing_CB01`,
  `Career_Buddy_LMS`) remain read-only: confirmed no tracked-source file in
  either directory has a modification time after this phase's work began;
  `Career_Buddy_LMS` still carries only the same pre-existing, unrelated
  September diff noted in Phases 73/74's own reports.
- No backend API, database schema, migration, authentication/authorization
  logic, subscription rule, or deployment configuration was changed.
- No existing, uncommitted work from Phases 52–74 was discarded — confirmed
  by the full 2,862-test suite passing (includes every prior phase's own
  tests) and by live emulator verification matching the Phase 71/73/74
  -verified guest drawer structure exactly.
- Guest navigation and the Skill-Up login gate are unchanged — confirmed
  both by source (the fix is entirely inside `SkillUpLessonScreen`, reached
  only after authentication) and live on the emulator.

## Stop point

Per the task brief, this phase is complete and this is the final
deliverable for Phase 75. No Phase 76 or other cleanup/refactor work has
been prepared or started; proceeding requires explicit approval.
