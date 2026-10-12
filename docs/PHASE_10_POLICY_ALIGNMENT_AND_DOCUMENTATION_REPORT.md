# Phase 10 — Mock Interview Policy Alignment & Documentation Cleanup

Flutter-only documentation/comment phase, implementing the 5 decisions
approved from `docs/PHASE_9_MOCK_INTERVIEW_PROCTORING_DECISION_AUDIT.md`.
No Django/web file was read or modified this phase (none was needed — every
change is Flutter-only documentation plus one regression test). No feature
behavior was changed.

## 1. Inspection performed (Task 1)

Re-inspected `MockInterviewQuestionView`
(`lib/features/mock_interview/presentation/widgets/mock_interview_question_view.dart`),
`MockInterviewController`
(`lib/features/mock_interview/presentation/controllers/mock_interview_controller.dart`),
and the existing test coverage
(`test/features/mock_interview/presentation/screens/mock_interview_screen_test.dart`,
`test/features/mock_interview/presentation/mock_interview_controller_test.dart`)
against the approved decisions. **No regression found** — current behavior
already matches what was approved:

- The `TextField` (key `answer-text-field`) is rendered unconditionally for
  every question in `MockInterviewQuestionView.build` — theory and coding
  alike (only the hint text differs by `question.isCoding`). **Confirmed
  unchanged.**
- The on-device `speech_to_text` mic button is still shown whenever
  `stt.SpeechToText().initialize()` succeeds (`_initSpeech`), and still
  writes results into the same `TextField` rather than a separate path.
  **Confirmed unchanged.**
- Coding-question behavior (same `TextField`, different hint text, same
  `submitAnswer()` call) is untouched — no separate code path exists for it
  to regress. **Confirmed unchanged.**
- `MockInterviewController.submitAnswer()`/`_autoSubmit()` send
  `current.answerText.trim()` as-is, with no length check anywhere in
  either method, and `resume_submit_answer` (the real server endpoint, per
  Phase 9) has none either. **Confirmed unchanged — no new minimum-word
  rule was introduced, and none existed before.**

Since no regression was found, **no functional code was changed** in this
phase — exactly as instructed ("Make no functional changes unless the
inspection discovers an accidental regression").

One narrow regression test was added (not a functional change) to make this
verified invariant explicit and protect it going forward — see §4.

## 2. Face-detection limitation documented (Task 2)

Updated the most relevant existing in-repo documentation: the top-of-file
scope-note doc comment on `MockInterviewState` in
`lib/features/mock_interview/presentation/controllers/mock_interview_controller.dart`
(this is the controller every Mock Interview screen/widget is built around,
and it already carried the prior version of this exact scope note — the
natural, single place to keep it accurate rather than introducing a new
doc file that would duplicate Phase 9's report).

The updated comment now states, concisely and only in terms of **currently
verified** behavior (no planned/future behavior described as implemented):

- What mobile *does* implement for real: the mandatory camera gate,
  continuous video recording + upload (kept server-side only on a pass),
  and app-lifecycle-based tab-switch/backgrounding detection reported to the
  real `resume_record_violation` endpoint.
- What mobile does *not* implement: the web's periodic (~1.5s) face-presence
  / multiple-face detection (`face-api.js`, `templates/resume_interview.html:1768-1826`).
- An explicit warning that `ViolationType.faceNotDetected`/`.multipleFaces`
  being modeled in the enum (because the server already accepts those event
  types) **must never be read as proof this client detects or reports
  either condition** — neither is ever actively triggered.
- That this is a **deferred product/engineering decision**, not an
  oversight, pointing to `docs/PHASE_9_MOCK_INTERVIEW_PROCTORING_DECISION_AUDIT.md`
  for the full analysis (on-device processing, dependency/platform
  compatibility, real-device validation, privacy, and disclosure — listed,
  not re-derived here, to avoid duplicating that report).

No dependency, detector, permission, violation trigger, camera-frame
processor, or disclosure UI was added — this task is a comment-only change.

## 3. Stale `cameraInterrupted` comment corrected (Task 3)

**Inspection first, per the task's own instruction**: re-grepped
`cameraInterrupted` across `lib/` and `test/` before touching anything.
Result: identical to Phase 9's finding — the symbol exists only in
`malpractice.dart` itself (the enum value, its `apiValue` mapping, and its
own doc comment). **No call site anywhere reports it.** No discrepancy from
Phase 9 was found, so no broader change was needed or made.

Corrected `lib/features/mock_interview/domain/entities/malpractice.dart`'s
doc comment on the `ViolationType` enum, which previously claimed this
client reports `cameraInterrupted` "if the live camera preview drops
mid-interview" (implying an ongoing monitor that does not exist). It now
states plainly that:
- `cameraInterrupted` is modeled (the server already accepts it) but **no
  call site in this codebase currently reports it**.
- Unlike the web (which continuously re-verifies the live camera track for
  the whole interview via `templates/resume_interview.html:817-842` and
  reports a drop as this violation), this client only checks camera
  liveness **once**, at the camera gate (`InterviewCameraService.start`) —
  there is no ongoing mid-interview camera-liveness monitor today.

No call site, listener, camera monitor, or violation submission was added —
this is a documentation-only correction, matching the task's instruction
exactly.

## 4. Regression test added

`test/features/mock_interview/presentation/mock_interview_controller_test.dart`
— one new test in the existing `MockInterviewController` group:

> `'REGRESSION (Phase 10): a manual submit() with a short typed answer
> succeeds — no client-side minimum-word restriction exists (approved
> Phase 9/10 decision: do not introduce one)'`

It drives the real controller through `start()` → `confirmCameraLive()` →
`updateAnswerText('Yes.')` → `submitAnswer()` using the existing
`_FakeMockInterviewRepository` test double (no new test infrastructure
added), and asserts the 2-word answer is submitted verbatim and the
interview proceeds to results — i.e., nothing rejects or alters a short
typed answer. This complements the existing (already-passing, unmodified)
`'updateAnswerText is submitted verbatim (trimmed) when the timer expires'`
test, which only covered the **auto-submit** path; this new test covers the
**manual** `submitAnswer()` path, which is where a minimum-length rule
would most naturally have been added had one existed.

## 5. Files changed this phase

- `lib/features/mock_interview/presentation/controllers/mock_interview_controller.dart`
  — doc comment only (Task 2). No code statement changed.
- `lib/features/mock_interview/domain/entities/malpractice.dart` — doc
  comment only (Task 3). No code statement changed.
- `test/features/mock_interview/presentation/mock_interview_controller_test.dart`
  — one new test added (Task 1/§4). No existing test modified.
- `docs/PHASE_10_POLICY_ALIGNMENT_AND_DOCUMENTATION_REPORT.md` — this report
  (new).

No other file in this repository, and no file in the Django/web repository,
was read, created, edited, or deleted this phase.

**A note on scope control during this phase**: an initial `dart format` run
over the three touched files was reverted after it was discovered to
reformat large, unrelated, pre-existing portions of
`mock_interview_controller.dart` and the test file (confirmed, by running
the same check against an untouched baseline file
(`recommended_jobs_section.dart`), that this codebase's existing style is
not plain `dart format`'s default 80-column width — so a blind format run
is repo-wide noise, not a fix). Both files were restored via `git checkout`
and the two intended edits were re-applied by hand, byte-for-byte identical
in substance to the first attempt but without any incidental reformatting
of surrounding code. The diffs reported in §4/§2/§3 above are the final,
minimal result.

## 6. Verification (Task 4)

**1. Formatting check** (changed files only, check-only — not applied, see
§5's note):
```
dart format --output=none --show=changed \
  lib/features/mock_interview/presentation/controllers/mock_interview_controller.dart \
  lib/features/mock_interview/domain/entities/malpractice.dart \
  test/features/mock_interview/presentation/mock_interview_controller_test.dart
→ Changed: mock_interview_controller.dart, mock_interview_controller_test.dart
```
Both are flagged because this codebase's pre-existing style uses a wider
column width than `dart format`'s 80-column default — confirmed repo-wide,
not introduced by this phase, by running the identical check against
`recommended_jobs_section.dart` (untouched this phase, last touched in
Phase 4) which is **also** flagged. Applying the default-width formatter
would rewrite large stretches of pre-existing, unrelated code — out of this
phase's explicitly minimal scope — so it was deliberately not applied.

**2. Static analysis**:
```
flutter analyze lib/features/mock_interview/ test/features/mock_interview/
→ No issues found!

flutter analyze (whole project)
→ No issues found!
```

**3. Focused tests** — Mock Interview answer input and violation-type
behavior:
```
flutter test test/features/mock_interview/
→ 60 passed, 0 failed (includes the new Phase 10 regression test)

flutter test test/features/mock_interview/presentation/mock_interview_controller_test.dart \
  --plain-name "REGRESSION (Phase 10)"
→ 1 passed, 0 failed
```

**4. Full suite**:
```
flutter test
→ 1922 passed, 0 failed
```
Baseline immediately before this phase (end of Phase 8) was **1921**
passing. **+1**, matching exactly the one new regression test added —
zero regressions anywhere else in the suite.

No live device, emulator, browser, or production backend was used for any
of the above — every result is from the local Flutter toolchain against
the existing fake/mock test doubles.

## 7. Explicit confirmations (per the task's required list)

- **Typed theory answers remain supported** — unchanged, confirmed by
  inspection (§1) and by the existing, unmodified
  `'typing an answer updates the controller state'` /
  `'renders the current question, the countdown timer, and a submit
  action'` tests, both still passing.
- **No new minimum answer-length restriction was introduced** — confirmed
  by inspection (§1) and by the new regression test (§4), which explicitly
  exercises and protects this.
- **Face detection remains unimplemented and deferred** — no detector,
  dependency, permission, or runtime behavior was added; only the existing
  scope-note documentation was clarified (§2).
- **The stale `cameraInterrupted` comment was corrected without adding any
  runtime behavior** — verified via a fresh grep before editing (§3); the
  change is comment-only.
- **The Django/web repository was not modified** — it was not even read
  this phase; every fact restated here was already verified in Phase 9 and
  is cited back to that report rather than re-derived.
- **No dependencies, build settings, signing assets, or production data
  were changed** — `pubspec.yaml`, platform configuration, and signing
  material were not touched; no package was added or upgraded.
- **Outstanding verification**: none specific to this phase's own changes —
  both edits are documentation-only and their only testable claim (the
  minimum-length behavior) is now covered by an automated test. The broader
  outstanding items remain exactly what Phase 9 already identified as
  product decisions (face-detection build/skip, disclosure copy if it is
  ever built) — unchanged by this phase, which implemented only the
  decisions already approved.

## Status

Phase 10 complete: documentation now accurately describes current mobile
behavior, the stale comment is corrected, the approved typed-answer policy
is preserved and additionally regression-tested, and all verification
results above are reported as actually run — no device, production, or
end-to-end interview verification was performed or is claimed.
