# Phase 48 — Assessment Malpractice Controls: Web-to-Mobile Parity

## 1. Executive summary

Phase 40's old audit treated "assessment malpractice controls" as one topic.
Re-auditing the current `royalStaffing_CB01` source directly found **three
genuinely separate systems**, not one, each with its own scope:

1. **AI Mock Interview** (`career_app` — `ResumeInterviewSession`/
   `InterviewViolation`) — a server-tracked, 3-strike, escalating
   violation system (warn → flag → terminate). **Already fully implemented
   in Flutter** (an earlier phase's work, re-verified here, not re-built).
   One real gap found and fixed: the screen-level `WidgetsBindingObserver`
   wiring that drives it had no test exercising the actual lifecycle
   callback end to end — only the controller method it calls was
   unit-tested directly. Added 3 tests; no production code changed here.
2. **JAM ("Just A Minute")** — a simpler, one-shot (non-escalating) control:
   leaving the app mid-recording auto-stops it, exactly as the 60-second
   timer running out would. **This one was missing in Flutter** — found,
   implemented, and tested this phase.
3. **Skill Up's embedded lesson-quiz assessments** (585 static lesson pages
   under `TechCenter/`/`NonITCenter/`) — a real, purely **client-side**
   fullscreen + 3-strike-auto-submit engine embedded directly in those
   pages' own JS. This is the item the brief specifically flagged
   ("fullscreen detection inside the Skill-Up assessment WebView"). It is
   confirmed real, confirmed separate from both systems above, and
   confirmed to already run unmodified inside the existing
   `SkillUpLessonScreen` WebView (the same static HTML, unchanged) — see
   §3 and §10 for why no code change was made here and what remains
   unverified on-device.

No backend, Django template, authentication, or subscription code was
touched. Both reference trees were only read.

## 2. Exact updated web source files and functions inspected

- `career_app/models.py:26-182` — `ResumeInterviewSession` (malpractice
  fields) and `InterviewViolation` (the 8 `TYPE_CHOICES`).
- `career_app/views.py:1192-1313` — `resume_camera_verified`,
  `resume_violation_state`, `resume_record_violation`,
  `MALPRACTICE_FLAG_THRESHOLD`/`MALPRACTICE_TERMINATE_THRESHOLD` (2/3).
- `templates/resume_interview.html:1572-1880` — `interviewIsActive()`, the
  `visibilitychange`/`blur`/`contextmenu`/`keydown` (PrintScreen/Cmd+Shift+
  3-4-5) listeners, the continuous `faceapi` liveness loop, the messages
  map (`career_app/views.py`'s 8 types mirrored 1:1).
- `templates/jam/session.html:208-420,583-588` — `startSession`/
  `stopSession`/the 60s timer, and the `visibilitychange` listener that
  calls `stopSession()` + `alert(...)` the instant `document.hidden` while
  a recording is running.
- `jam_app/views.py:180-303` — confirmed `jam_session`/`jam_session_with_
  topic`/`assessment_session` all render the identical `jam/session.html`,
  so the Assessment flow is governed by the exact same control as an
  ordinary practice session.
- `core/skillup_access.py` — confirmed Skill Up's locked-content gating is
  unrelated to malpractice controls (a plan check, not an anti-cheat one);
  ruled out as in-scope for this phase.
- `static/js/exam_guard.js` — the shared, page-head-loaded incident
  de-duplicator (coalesces blur/visibilitychange/fullscreenchange into one
  "incident" per leave, so a page's own engine doesn't double-count).
- `static/js/skillup_protect.js`, `static/js/content-protection.js` —
  site-wide/Skill-Up-wide copy/paste/print/context-menu blocking,
  confirmed to have **no server component, no counter, no termination** —
  a content-theft deterrent, not an assessment malpractice control; ruled
  out as out of scope.
- A representative embedded lesson quiz engine, read in full:
  `static/001 Career Buddy/TechCenter/project-management-agile-delivery/
  agile-project-manager/agile_pm_core_skills_course.html:1075-1570` — the
  `requestFullscreen()`/`fullscreenchange`/`visibilitychange`/`blur`/
  keyboard-shortcut-block/3-warning-auto-submit engine, confirmed present
  via `grep -rl "onIncident("` across the whole Skill Up tree: **585
  files** (383 under `TechCenter/`, all 202 under `NonITCenter/` — i.e.
  every Phase 47 Non-IT lesson also has this).
- `skillup_assessment/templates/skillup_assessment/*.html` (the
  Certifications quiz hub) — confirmed **zero** matches for `CBExamGuard`,
  `fullscreen`, `warn`, `strike`, or `proctor`: this quiz flow has no
  malpractice engine of its own at all, only the generic copy/paste
  blocker.

## 3. Source-to-mobile parity table

| # | Control | Web enforcement | Flutter status | Evidence |
|---|---|---|---|---|
| 1 | Mock Interview: TAB_SWITCH (tab/app hidden) | Client reports to server; server is authoritative counter | **Implemented & now verified** | `MockInterviewScreen.didChangeAppLifecycleState` (`paused`/`hidden`) → `MockInterviewController.reportViolation` → `resume_record_violation`. New screen-level test added (§6). |
| 2 | Mock Interview: WINDOW_BLUR (focus loss, not fully hidden) | Same | **Implemented & now verified** | `AppLifecycleState.inactive` mapping; new test added. |
| 3 | Mock Interview: 2/3-strike warn→flag→terminate | Server (`MALPRACTICE_FLAG_THRESHOLD`=2, `_TERMINATE_THRESHOLD`=3, read dynamically) | **Implemented & verified** (pre-existing, `mock_interview_controller_test.dart`'s Phase 17 regression group) | Re-confirmed thresholds unchanged in current source. |
| 4 | Mock Interview: FACE_NOT_DETECTED / MULTIPLE_FACES | Client-side `face-api.js`, continuous | **Missing — pre-existing, honestly documented gap, out of scope to build this phase** (no task directive to add live face detection; not a regression) | `malpractice.dart`'s own doc comment, re-confirmed accurate against current source |
| 5 | Mock Interview: CAMERA_INTERRUPTED (continuous re-verification) | Client-side, continuous | **Missing — pre-existing, honestly documented gap** (camera is only checked once, at the gate) | Same doc comment, re-confirmed accurate |
| 6 | Mock Interview: COPY_PASTE / SCREENSHOT_ATTEMPT | Client-side (`contextmenu`/copy events; PrintScreen/Cmd+Shift+3-4-5 keys) — **actively triggered on web**, not merely modeled | **Correctly not reproduced** — no native answer-field equivalent exists, and reliable screenshot-attempt detection has no public Flutter API; reporting a fake version would violate "never pretend to detect what can't be observed" | `resume_interview.html:1520,1759,1772-1776` (confirms these ARE live on web, a small correction to the existing code comment's wording — not a behavior change) |
| 7 | Mock Interview: FULLSCREEN_EXIT | **Modeled server-side; never actually triggered by the current web JS either** (no `fullscreenchange` listener anywhere in `resume_interview.html`) | **N/A — nothing to match**, since the web itself never fires this for the interview | Confirmed via direct grep: zero wiring in `resume_interview.html` |
| 8 | JAM: leaving the app mid-recording auto-stops it | Client-only, one-shot (not escalating); same control backs the graded Assessment | **Was missing — implemented this phase** | `jam/session.html:583-588`; see §4/§5 |
| 9 | JAM: no server-side violation counter | N/A (the web itself has none) | **Correctly not built** — would be inventing a requirement that doesn't exist | Confirmed: no `jam_app` model/view matches `violation`/`malpractice` |
| 10 | Skill Up embedded lesson-quiz: fullscreen requirement + 3-warning auto-submit + copy/paste/devtools-shortcut block | **100% client-side**, embedded directly in 585 lesson pages' own `<script>`, no server component | **Inherited unmodified** via the existing `SkillUpLessonScreen` WebView, which already loads these exact pages verbatim with JS unrestricted | See §10 for the one open, honestly-flagged platform-capability question |
| 11 | Skill Up Certifications quiz (`skillup_assessment`) | No malpractice engine at all (confirmed) | **N/A — nothing to implement**, correctly out of scope | `grep` across its 4 templates: zero matches |
| 12 | Skill Up site-wide copy/paste/print block | Client-side CSS/JS, Django-middleware-injected, no counter | **N/A for a native app** — a Flutter `TextField`'s own copy/paste is a normal, expected mobile affordance, not a malpractice vector the web's own control was ever meant to police on a native client | `core/middleware.ContentProtectionMiddleware` + `static/js/content-protection.js`, confirmed no server tie-in |

## 4. Root cause of the one confirmed, fixable gap (JAM)

`jam/session.html`'s `visibilitychange` listener (`document.hidden &&
timerInterval`) is the web's anti-pause-exploit control: switching away
mid-recording ends the recording immediately rather than letting a
candidate silently pause the 60-second clock, think, and resume. Flutter's
`JamRecordingScreen` had no `WidgetsBindingObserver` at all — backgrounding
the app during a JAM recording (practice **or** the graded Assessment,
since `assessment_session` renders the identical template) did nothing,
letting a user leave the app indefinitely with the recorder still "running"
server-side-equivalent (the local recorder keeps capturing) until they
manually returned and pressed Stop — a genuine parity gap, not merely an
unverified one.

A second, related issue was found and fixed while implementing this:
`JamSessionController.stopRecording()` had no re-entrancy guard. Once a
second caller of `stopRecording()` existed (the new app-lifecycle observer,
on top of the pre-existing manual Stop button and the 60s auto-timer), two
calls arriving before the first's `await _recorder.stop()` resolved would
both pass the `state is JamRecordingInProgress` check (state only changes
*after* that await), double-stopping the recorder and racing two uploads
for the same session. This was a latent risk even without the new observer
(e.g. the timer and a well-timed manual tap), closed with a `_stopping
Recording` guard.

## 5. Files created or modified and why

- `lib/features/jam/presentation/screens/jam_recording_screen.dart` —
  added `WidgetsBindingObserver`; `didChangeAppLifecycleState` calls the
  existing `JamSessionController.stopRecording()` (no new controller API)
  on `AppLifecycleState.paused`/`hidden` only (never `inactive` — the real
  page only ever listens for `visibilitychange`, never `blur`, so mapping
  `inactive` too would invent a stricter control than the source has), and
  shows a `SnackBar` with wording grounded in the real alert text, adapted
  for a mobile context ("left the app" instead of "switched tabs").
- `lib/features/jam/presentation/controllers/jam_session_controller.dart`
  — added the `_stoppingRecording` re-entrancy guard described in §4;
  updated class-level doc comments to record both changes and their
  sourcing.
- `lib/features/mock_interview/presentation/widgets/mock_interview_question_view.dart`
  — **no functional change**; a temporary debug print added while
  diagnosing the new test (§6) was fully reverted, confirmed via
  `flutter analyze` returning clean before finalizing.
- Tests — see §6.

No other production file was changed. `interview_analytics.dart`/
`mock_interview_results_view.dart`/`mock_interview_results_view_test.dart`
show as modified in `git status` but were **not** touched this phase —
confirmed pre-existing uncommitted work from before this session started.

## 6. Automated tests added

**`test/features/jam/presentation/controllers/jam_session_controller_test.dart`**
(+2): a 2nd `stopRecording()` call while the 1st is still awaiting the
recorder is a no-op (only 1 recorder-stop, 1 upload); the guard releases
correctly afterward so a later, non-racing `stopRecording()` still works
(proves it isn't a one-shot lockout).

**`test/features/jam/presentation/screens/jam_recording_screen_test.dart`**
(+4): backgrounding the app while `JamRecordingInProgress` calls
`stopRecording()` and shows the real warning copy; `AppLifecycleState
.hidden` does the same; backgrounding during a non-recording step
(Instructions) does nothing; `AppLifecycleState.inactive` does **not**
stop a recording (proves the deliberate non-mapping, matching the real
page's `visibilitychange`-only listener).

**`test/features/mock_interview/presentation/screens/mock_interview_screen_test.dart`**
(+3): backgrounding during an active question reports a real violation
through the real repository and — once the app is realistically
foregrounded again (`paused → hidden → inactive → resumed`, the only
transition sequence Flutter's own `AppLifecycleListener` assertion
allows) — the warning dialog actually renders; `AppLifecycleState.inactive`
alone reports as `windowBlur`; `AppLifecycleState.resumed` reports nothing.
(This closes the integration-level blind spot noted in §1: the controller
method was already unit-tested, but nothing previously exercised the
screen's own observer wiring end to end.)

No existing test was weakened, deleted, or had an assertion's expected
value changed.

## 7. Test results

- **Focused** (`test/features/jam` + `test/features/mock_interview`): 217
  passing, 0 failing.
- **Full suite**: **2,467 passing, 0 failing** (baseline 2,458; +9 new,
  exactly matching the 2+4+3 added above).

## 8. Static analysis

**8 issues** — identical to the pre-Phase-48 baseline, same pre-existing
unused-test-parameter warnings in unrelated resume-controller test files.
0 new issues.

## 9. Emulator verification

Device: `emulator-5556`, Android 14 (API 34), `flutter run -d
emulator-5556 --debug`. Storage checked first (host: 203Gi free; emulator
`/data`: 806MB free) — not wiped or reset.

- **Confirmed live**: clean build, clean launch, no `FlutterError`/crash in
  the run log at any point.
- **Confirmed live, as a guest**: this debug build resolves to the
  **production** backend by default (Phase 35's documented behavior); per
  this task's own safety rules (no production accounts, no fabricated test
  data), **no login was attempted**. The guest nav drawer shows only
  Home/Job Seeker Login/Employer Login — both JAM and Mock Interview are
  unreachable without authentication, which is existing, unmodified,
  correct behavior (neither route is public).
- **Not performed, honestly**: interactively triggering a JAM recording or
  a Mock Interview session and backgrounding the app mid-flow on-device —
  both require an authenticated session, and (confirmed by checking the
  two most recent prior phases' own reports) no legitimate test account
  has ever existed in this project's history; fabricating one was
  correctly out of scope. This is exactly the same, already-established
  limitation Phase 46/47 documented for their own authenticated-flow
  verification. The actual lifecycle-observer → controller → (fake)
  repository → UI chain is instead covered end-to-end by the widget tests
  in §6, which exercise the real screen code, the real controller code,
  and a real (fake-backed) repository call — only the genuine device/OS
  backgrounding signal and the real network call are substituted.
- Screenshots saved to
  `/private/tmp/claude-501/-Users-kunjapramodmahajan-Flutter-Projects-Career-Buddy-LMS/c536c444-170e-4e2d-b1fa-059604770772/scratchpad/phase48/`
  (`01_launch.png`, `02_drawer.png`) — session-scratch files, not part of
  the repository.

## 10. Remaining missing / partial / blocked / unverified

- **Skill Up embedded lesson-quiz fullscreen behavior inside the Flutter
  WebView — unverified, and deliberately not changed.** The quiz engine
  (§2, §3 row 10) is pure client-side JS embedded in the exact same static
  HTML `SkillUpLessonScreen` already loads unmodified with `JavaScript
  Mode.unrestricted`; there is no Flutter code to "implement" for it, since
  nothing here is reimplemented natively. The one open question is a
  platform-capability one, not a code gap: `webview_flutter` 4.x's default
  `WebViewController` (no custom `WebChromeClient.onShowCustomView`
  override exists in this codebase) is widely documented to not grant the
  HTML5 Fullscreen API its full native effect out of the box, so
  `document.documentElement.requestFullscreen()` likely resolves/rejects
  without `document.fullscreenElement` ever becoming non-null — meaning
  the page's own `fullscreenchange`-driven "fullscreen exited" warning
  specifically may never fire (its precondition, having *entered*
  fullscreen, is never met), while the independent `visibilitychange`/
  `blur`/keyboard-shortcut/3-warning-auto-submit logic (which doesn't
  depend on fullscreen state) is expected to keep working. This could not
  be verified on-device: every `NonITCenter/`/`TechCenter/` lesson with
  this engine is plan-gated (`core/skillup_access.py`, confirmed Phase 47),
  and no legitimate paid test account exists in this environment (§9). No
  native `WebChromeClient` change was made to "fix" this, since (a) it is
  unconfirmed whether the page's own graceful `.catch(()=>{})` handling
  already makes this a non-issue for the quiz's actual function (timer,
  auto-submit, and non-fullscreen violations still work either way), (b)
  it would be native-platform-channel work well beyond this project's
  established Dart-only pattern for every other phase, and (c) building it
  speculatively, un-verifiable without the exact session that's unavailable,
  would risk exactly the kind of invented-requirement work this phase was
  told to avoid. **Recommended next priority if product confirms this
  matters**: get a legitimate paid-plan test session, open one `TechCenter`
  or `NonITCenter` lesson's embedded assessment in the real
  `SkillUpLessonScreen`, and observe directly whether fullscreen visually
  engages; only then decide whether a custom `WebChromeClient`/
  `WKUIDelegate` fullscreen handler is actually warranted.
- Mock Interview's pre-existing, already-honestly-documented gaps (live
  face detection, continuous camera-liveness re-verification) are
  unchanged — re-confirmed accurate against the current source, not newly
  discovered, and no directive in this phase's brief asked for them to be
  built.

## 11. Confirmation: both Django reference trees untouched

Neither `Career_Buddy_LMS/` nor `royalStaffing_CB01/` was edited, created
in, or deleted from at any point — every file under both trees was only
read (`grep`/`Read`), confirmed by this phase having issued zero write
tool calls against either path.

## 12. Confirmation: no backend/production-data/auth/subscription/signing/publishing changes

- No Django view, model, migration, template, URL, or settings file was
  modified.
- No production account was used or created; no production network
  mutation was made (the one live emulator session only read the public
  landing page and nav drawer as a guest).
- No authentication, OTP, role, or subscription-gating logic was touched —
  the only access-adjacent file read this phase (`core/skillup_access.py`)
  was read-only, confirming existing behavior, never edited.
- No signing material (`key.properties`, keystores) was inspected or
  touched; no release build, APK/AAB upload, or Play Store action was
  taken.
