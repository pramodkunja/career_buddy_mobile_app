# Phase 7 — Wire Language Selection into GD and JAM

Scope: the GD/JAM language-selection gap from
`docs/PHASE_5_REMAINING_PARITY_REVIEW.md`. Read first:
`docs/PHASE_5_REMAINING_PARITY_REVIEW.md`,
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`,
`docs/PHASE_2_PARITY_AUDIT_REPORT.md`,
`docs/PHASE_6_EMPLOYER_STATUS_SAFETY_REPORT.md`. Git status confirmed
unchanged from Phase 6's end state in both repositories before any edit.

## 1. The original gap and fresh source verification

**Re-confirmed, not assumed**: an exhaustive `grep -rn "\.setLanguage(" lib/`
found `GdSessionController.setLanguage`/`JamSessionController.setLanguage`
still defined (`gd_session_controller.dart:136`,
`jam_session_controller.dart:146`) with **zero call sites** in either
`lib/features/group_discussion/` or `lib/features/jam/` — the exact gap
Phase 5 described, still accurate today. The same grep also surfaced
**five existing, working language pickers elsewhere in this app**
(`ai_writing_screen.dart`, `ai_speaking_screen.dart`,
`ai_reading_screen.dart`, `ai_listening_screen.dart`,
`roleplay_practice_screen.dart`), each independently duplicating the same
small `DropdownButton<String>` widget and local-state pattern — confirming
a reusable, already-reviewed UI convention exists, so this phase does not
introduce a new one.

## 2. Verified web behavior — read directly, not assumed uniform

- **Shared language list, confirmed from the actual shared template**:
  `templates/includes/language_dropdown.html`'s own doc comment states it
  is "shared by the activity modules and the Interactive Workshop apps
  (Group Discussion, JAM, Role Play)" — exactly 4 options:
  `english` (default, `selected`), `vietnam`, `arabic`, `russian`. Included
  in `GD_app/home.html`, `GD_app/room.html`, `jam/dashboard.html`, and
  `jam/session.html`.
- **GD's actual effect, read from `GD_app/consumers.py`**: `self.language`
  is set **only** inside the `'start'` action handler (line 62,
  `data.get('language')`), then used for every agent reply
  (`get_agent_response`) and the final report
  (`analyze_user_performance`). No other action handler reads `language`
  server-side. **Changing the dropdown after a discussion has already
  started has no server-side effect on that session** — it would only take
  effect on a subsequent `'start'` (a fresh session, since `gd.js`'s own
  "Resume" button re-sends the same `action: 'start'`).
- **JAM's actual effect, read from `jam_app/views.py`**: `session.language`
  is set inside `save_audio` (line 211), with an in-code comment
  explicitly stating *"session.html has always posted this from the
  header dropdown... Persisted because feedback is generated in a later
  request."* This is read once per recording upload — **genuinely
  different from GD**: each individual recording's feedback can reflect
  whatever language was selected at the moment *that* recording was
  uploaded, not a value frozen at session start.
- **Mobile already matched both of these contracts internally**, confirmed
  by re-reading both controllers: `GdSessionController.sendStart`/
  `sendUserMessage` (lines 180, 274) and
  `JamSessionController._uploadAndAdvance` (line 240) all already read
  `_language` at exactly the same points their real server counterparts
  do. **The only missing piece was ever a UI control calling
  `setLanguage`** — not a controller or contract defect.

## 3. Files changed and why

| File | Why |
|---|---|
| `lib/features/group_discussion/presentation/screens/gd_topic_screen.dart` | Added a `_LanguageSelector` AppBar dropdown (4 options, English default) on this pre-session screen only; selecting a value calls `ref.read(gdSessionControllerProvider.notifier).setLanguage(value)` immediately |
| `lib/features/jam/presentation/screens/jam_topics_screen.dart` | Converted from `ConsumerWidget` to `ConsumerStatefulWidget` (needed to hold the picker's local selected-value state, matching every other existing picker in this app); added the same `_LanguageSelector` pattern, wired to the same, already-shared (non-`.family`) `jamSessionControllerProvider` instance `JamRecordingScreen` reads from later |
| `test/features/group_discussion/gd_test_doubles.dart` | `FakeGdRealtimeService.sendStart`/`sendUserMessage` now actually record the `language` argument (previously discarded it) — a small, backward-compatible fix needed so screen-level tests could observe it; confirmed no existing test asserted on the old (language-less) shape |
| `test/features/group_discussion/presentation/controllers/gd_session_controller_test.dart` | Added one new test proving `setLanguage` changes the language sent with `start` — GD's controller had no such test before this phase (JAM's did) |
| `test/features/group_discussion/presentation/screens/gd_topic_screen_test.dart` | 3 new regression tests (detailed in §6) |
| `test/features/jam/presentation/screens/jam_topics_screen_test.dart` | 2 new regression tests (detailed in §6) |

No Django file was touched. No new API, no payload-shape change, no
controller logic changed (`setLanguage`/`_language`'s existing read
points in both controllers are untouched) — this phase is UI wiring only.

## 4. The actual UI-to-controller-to-request data flow

**GD**: `GdTopicScreen`'s AppBar dropdown → `setState` (local display) +
`ref.read(gdSessionControllerProvider.notifier).setLanguage(value)`
(immediate) → user picks/types a topic → `startDiscussion(topic)` →
`createSession` (HTTP) → WebSocket connects → `sendStart(language: _language)`
— the controller's own pre-existing, unchanged code path, now finally
reached with a real user-chosen value instead of always the hardcoded
default.

**JAM**: `JamTopicsScreen`'s AppBar dropdown → `setState` (local display) +
`ref.read(jamSessionControllerProvider.notifier).setLanguage(value)`
(immediate, **before** any navigation) → tapping a topic or "Random Topic"
pushes `JamRecordingScreen` (a **different screen**, but the **same**
`jamSessionControllerProvider` instance, since it is a plain non-`.family`
provider) → user records and stops → `_uploadAndAdvance` →
`saveAudio(..., language: _language)` — again, the controller's own
pre-existing, unchanged code path.

## 5. Before-and-after behavior

| Scenario | Before | After |
|---|---|---|
| GD: start a discussion in Vietnamese | Always started (and reported) in English — the dropdown didn't exist | Dropdown on the topic screen; selecting Vietnamese and starting sends `language: 'vietnam'` with `start`, confirmed by a new controller-level test |
| GD: change language after a discussion is already live | N/A (no dropdown existed) | **Deliberately not exposed on the live discussion screen** — per the verified server behavior in §2, it would have no effect on that session; exposing it there would have been the "decorative selector" this phase was told to avoid |
| JAM: record topics in different languages within one visit | Always uploaded as English | Each upload reflects whichever language was selected on the topics screen most recently before that recording — matching the real `save_audio` view's own per-upload read, confirmed by the pre-existing JAM controller test (unchanged) plus this phase's new screen-level wiring test |
| GD/JAM state isolation | N/A | Confirmed architecturally: `gdSessionControllerProvider` and `jamSessionControllerProvider` are separate, non-`.family` providers — selecting a language in one feature cannot affect the other |

## 6. Regression tests added — actual results

**`test/features/group_discussion/presentation/controllers/gd_session_controller_test.dart`**
(+1 test, 14 total in file, all passing): `setLanguage` before
`startDiscussion` changes the language actually sent with `start` — GD's
controller previously had no test for this at all (unlike JAM's).

**`test/features/group_discussion/presentation/screens/gd_topic_screen_test.dart`**
(+3 tests, 8 total in file, all passing):
1. The selector exposes exactly `['english', 'vietnam', 'arabic', 'russian']`, defaulting to `'english'`.
2. Selecting "Vietnamese" updates the displayed value **and** reaches the real `start` request sent through `FakeGdRealtimeService` (`language: 'vietnam'`) once a topic is tapped.
3. After selecting "Russian" and starting one session, the dropdown still reads `'russian'` for a subsequent attempt in the same visit — no stale reset to the default between sessions.

**`test/features/jam/presentation/screens/jam_topics_screen_test.dart`**
(+2 tests, 11 total in file, all passing):
1. The selector exposes the same 4 options, defaulting to `'english'`.
2. Selecting "Arabic" updates the displayed value and calls through to the real, shared `JamSessionController.setLanguage('arabic')` — verified with a `_SpyJamSessionController` that records the call while still behaving exactly like the real controller otherwise, rather than driving the full recording/upload flow end-to-end (that end-to-end wiring — `setLanguage` → the actual `saveAudio` payload — is already independently covered, unchanged, by `jam_session_controller_test.dart`'s pre-existing "setLanguage changes the language sent on the next upload" test).

**Existing tests run, not weakened**:
`flutter test test/features/group_discussion/presentation/screens/gd_topic_screen_test.dart`
(8/8 passing), the full `test/features/group_discussion/` directory
(confirmed passing alongside the above), and the full `test/features/jam/`
directory — **205/205 passing** across both feature directories combined,
including the pre-existing narrow-width (360px) responsive-overflow test
for JAM's topics screen, confirming the new 3rd AppBar action does not
cause layout overflow even at that width.

**Requirement #6 ("loading, error, and empty-option states")**: not
applicable here — the 4-option list is a static constant (matching the
real template, which is also static), not loaded from any API, so there
is no loading/error/empty state for the *options themselves* to test;
this was not fabricated as a test to satisfy a checklist item that does
not apply to this implementation.

## 7. `flutter analyze` and full-suite results

```
flutter analyze
```
→ **No issues found!** (run after every edit this phase, consistently clean)

```
flutter test test/features/group_discussion/ test/features/jam/
```
→ **205/205 passing**, 0 failing.

```
flutter test
```
(full suite) → **1910/1910 passing**, 0 skipped, 0 failing — **6 more than
the Phase 6 baseline of 1904**, the exact count of new regression tests
added (1 GD controller + 3 GD screen + 2 JAM screen). No existing test was
weakened, skipped, or removed to reach this result.

## 8. Remaining uncertainties, blockers, and manual-verification requirements

- **No live-backend or device testing was performed or is claimed.** Every
  finding and every fix in this phase is source-read-and-fake-adapter
  verified, consistent with this engagement's standing blocker (no usable
  test account).
- **Scope boundary, stated plainly, not silently omitted**: the real web
  also shows this same dropdown on the *live* pages (`GD_app/room.html`,
  `jam/session.html`), not just the pre-session ones. This phase
  deliberately did **not** add the picker to `GdDiscussionScreen` (would be
  a no-op for an already-started GD session, confirmed in §2) or to
  `JamRecordingScreen` (would have been technically functional for JAM,
  given its per-upload read, but was left out to keep GD and JAM's
  implementations symmetric and the change minimal, rather than because of
  any technical blocker). If a future phase wants mid-session language
  switching inside an active JAM recording screen specifically, nothing
  found this phase blocks that — it is a scope choice, not a limitation of
  the backend contract.
- **No persistence of the selected language across app restarts or
  navigation away and back to a freshly-created screen instance** — the
  real web persists the choice via `localStorage`
  (`window.LinguaVoice.restoreLanguagePreference`, confirmed present in
  `gd.js`). This phase's Flutter implementation resets to English on a
  fresh widget instance, matching the same (lack of) cross-session
  persistence already present in every other existing picker in this app
  (Roleplay, the 4 AI modules) — not a new gap introduced by this phase,
  and left unaddressed here since it was outside the audited gap's scope
  and would affect 6 screens at once, not just GD/JAM.

## 9. Confirmations

- **Django source**: unchanged. `git status --short` in `Career_Buddy_LMS/`
  shows the identical 3-modified/3-untracked state present since Phase 1,
  before and after this phase.
- **Pre-existing uncommitted/untracked work**: fully preserved — this
  phase added exactly 2 modified source files and 4 modified test files;
  every file Phase 6 left behind in Mobile_app remains exactly as it was.
- **No secrets, keystores, or signing material** were read, printed, or
  modified.
- **Authentication, password-reset, profile flows, subscription/payment
  logic, employer workflows, proctoring, and Demo Mode**: none touched —
  confirmed by the git diff above showing only GD/JAM screen and test
  files changed.
- **No APK/AAB was built, nothing was deployed, uploaded, or prepared for
  release.**

## Parity matrix update

The "GD/JAM — language selection" row in
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` was updated from `Partial` to
**Fully equivalent** (source-verified; not yet live-device-confirmed),
documenting the genuine GD-vs-JAM behavioral difference discovered this
phase and citing the new wiring and tests. No other row was changed.

## Completion

The gap was confirmed still present, the real (and non-uniform) web
behavior was established from source before any UI change, the language
selector is now connected to the real, pre-existing GD/JAM controller
methods, both features' existing session/exercise flows were re-verified
intact via their full test suites, and regression tests were added and
pass. Stopping here, as instructed — no further remediation phase started
without explicit approval.
