# Phase 17 — Mock Interview Threshold Compatibility Fix Report

**Scope:** targeted compatibility fix only. No backend code, API contract,
auth/OTP/subscription/role logic, resume builders, landing page, Skill-Up,
or other roadmap phase was touched. No build/release/signing step occurred.

## 1. Verified backend threshold behavior (updated Django source, read directly)

`career_app/views.py` (`royalStaffing_CB01/`):

- `PASSING_SCORE = 90` (line 1134); compared at `total_integer_score >=
  PASSING_SCORE` in both `resume_submit_answer`'s completion path (line
  1188) and `resume_analytics` (line 1834). Confirmed against the original
  repo's equivalent (`Career_Buddy_LMS/career_app/views.py:974`,
  `PASSING_SCORE = 70`) — the stale Flutter comment's "70" was accurate for
  the original backend, just not the updated one.
- `MALPRACTICE_FLAG_THRESHOLD = 2` (line 1212), `MALPRACTICE_TERMINATE_THRESHOLD
  = 3` (line 1213) — confirmed against the original repo's `= 3`/`= 5`.
- `resume_violation_state` (`@require_GET`, lines 1218-1235) returns
  `{"count", "status", "flag_threshold", "terminate_threshold"}` — both
  thresholds are already served dynamically by this endpoint.
- `resume_record_violation` (`@require_POST`, lines 1238-1313) returns
  `{"count", "status", "action", "type_occurrence_number"}` (main response
  at 1308-1313; a shorter already-terminated shape at 1265-1271 omitting
  `type_occurrence_number`) — **this endpoint does not include either
  threshold.** Only `resume_violation_state` does.
- The real web page (`templates/resume_interview.html`) itself still
  **hardcodes** `` `Warning ${malpracticeViolationCount}/3` `` in its own
  JS (lines 1685, 1691) — in both the original repo (where it numerically
  matched the old `flag_threshold=3`) and the updated repo (where it now
  only coincidentally matches the new `terminate_threshold=3`). The web
  never reads `flag_threshold`/`terminate_threshold` from either response
  for this text — confirmed by direct read, this is a long-standing,
  still-present stale hardcode on the web side too, not something Flutter
  was mirroring correctly before. Flutter's fix is a genuine improvement
  over current web behavior, not just a mirror of it.
- Chosen denominator semantics: **`terminate_threshold`**, not
  `flag_threshold`. Reasoning: the warning dialog is only ever shown for
  `action == warn` or `action == flagged` (a `terminated` action routes to
  a completely different state/screen, `MockInterviewTerminated`, never
  through this dialog) — so the denominator a candidate actually needs is
  "how many until this ends," which is `terminate_threshold`.
  `flag_threshold` plays no role in any Flutter-side decision (the server
  already tells the client `action` directly), so it was not added to
  Flutter's state at all, to avoid an unused field.

## 2. Flutter files changed

- `lib/features/mock_interview/presentation/controllers/mock_interview_controller.dart`
  — added `terminateThreshold` (nullable `int`) to `MockInterviewQuestionActive`
  and its `copyWith`; added a private `_terminateThreshold` field and
  `_ensureTerminateThreshold()` (calls the already-existing, already-tested
  `getViolationState()` repository method exactly once per interview,
  best-effort); called from `_loadNextQuestion()` before the first question
  loads. Also corrected a stale `career_app/views.py:1042` line citation in
  `MockInterviewTerminated`'s doc comment (now `:1213`, with the verified
  current value noted).
- `lib/features/mock_interview/presentation/widgets/mock_interview_question_view.dart`
  — the warning dialog now reads `widget.state.terminateThreshold`; shows
  `"Warning N/X"` when known, `"Warning N"` (no denominator) when not —
  never a hardcoded number either way.
- `lib/features/mock_interview/domain/entities/interview_analytics.dart` —
  corrected the stale `is_passed (total_integer_score >= 70)` doc comment to
  cite `PASSING_SCORE` and its verified current value (90), noting the 70
  was accurate historically; also corrected two stale line-number citations
  in the same doc comment block (`:1529-1555`/`resume_analytics.html:524`
  → `:1841`/`:529`) and the summary-numbers citation
  (`:1505-1601` → `:1775-1875`).
- `lib/features/mock_interview/domain/entities/malpractice.dart` — updated
  `ViolationAction`'s doc comment's stale `(3)`/`(5)` to the verified
  current `(2)`/`(3)`, and corrected its and `ViolationState`'s/
  `ViolationRecordResult`'s/`ViolationType`'s stale `career_app/views.py`
  line-number citations to match the updated source (verified individually,
  not guessed).

No change was made to `mock_interview_remote_datasource.dart`'s existing
`?? 3`/`?? 5` fallback defaults for missing `flag_threshold`/
`terminate_threshold` JSON fields — these are pre-existing, already
confirmed (Phase 15 gap analysis) to be unreachable in practice (the server
always includes both fields), so touching them was out of this phase's
scope; see §6.

## 3. How the threshold flows into the warning UI

1. `MockInterviewController._loadNextQuestion()` calls
   `_ensureTerminateThreshold()` once (guarded by `_terminateThreshold ==
   null`), which calls `_repository.getViolationState()` — a GET to
   `resume_violation_state`.
2. On success, `_terminateThreshold` is cached on the controller instance
   (a plain field, not reactive state — it never changes mid-interview) and
   passed into every subsequent `MockInterviewQuestionActive` construction
   as `terminateThreshold`.
3. On failure, `_terminateThreshold` stays `null` — best-effort, matching
   this feature's existing non-blocking patterns (`reportViolation`,
   `uploadRecordedVideo`); the interview is never blocked by this fetch.
4. `MockInterviewQuestionView._maybeShowViolationDialog` reads
   `widget.state.terminateThreshold` directly and builds `"Warning
   N/X"`/`"Warning N"` accordingly — never a literal `2` or `3`.

## 4. Regression tests added and exact results

`test/features/mock_interview/presentation/mock_interview_controller_test.dart`
— new `REGRESSION (Phase 17)` group (4 tests):
- the real server threshold (3) flows into `MockInterviewQuestionActive`;
- a different configured threshold (5) flows through identically, proving
  it isn't a baked-in number;
- `getViolationState` is fetched exactly once per interview, carried
  forward across subsequent questions (not re-fetched, not lost);
- a failed `getViolationState` leaves `terminateThreshold` null rather than
  guessing a number.

`test/features/mock_interview/presentation/widgets/mock_interview_question_view_test.dart`
(new file — no prior widget test exercised this dialog at all) — 4 tests:
- threshold 3 → dialog shows `"Warning 1/3"`;
- threshold 2 → dialog shows `"Warning 1/2"`, explicitly asserting the old
  `"Warning 1/3"` text is absent;
- threshold unknown (`null`) → dialog shows `"Warning 1"` with no `/`
  denominator at all;
- a `flagged` action still shows the "Flagged for Review" title and the
  dynamic count, confirming the fix didn't disturb that existing behavior.

Commands and results:
```
flutter test test/features/mock_interview/presentation/mock_interview_controller_test.dart
→ 20 passed (16 pre-existing + 4 new), 0 failed

flutter test test/features/mock_interview/presentation/widgets/mock_interview_question_view_test.dart
→ 4 passed, 0 failed

flutter test test/features/mock_interview/
→ 68 passed (60 pre-existing + 8 new), 0 failed

flutter test
→ 1951 passed, 0 failed (full project suite; 1943 prior + 8 new this phase)
```

## 5. `flutter analyze` results

```
flutter analyze
No issues found! (ran in 2.8s)
```
Run both scoped to `lib/features/mock_interview/` during development and
whole-project at the end — clean both times.

## 6. Blockers and unverified behavior

No blockers. One pre-existing, out-of-scope observation (not fixed, per
this phase's boundaries): `mock_interview_remote_datasource.dart`'s
`getViolationState()` still has hardcoded `?? 3`/`?? 5` fallback values for
a missing `flag_threshold`/`terminate_threshold` field in the JSON
response. These are confirmed unreachable in practice (the server always
includes both fields — Phase 15 gap analysis, re-confirmed by this phase's
own direct source read), so leaving them is not a functional risk, but they
are themselves slightly stale numbers. Fixing this would require either
accepting the same "default masks staleness" tradeoff this phase just
removed from the UI, or making the fields nullable — a design decision
beyond this phase's "targeted fix" scope. Flagging for a future phase's
consideration, not fixed here.

## 7. Verified vs. automated-tested vs. manual/live-tested

**Verified by direct source read** (this phase, not carried over from
Phase 15's report alone): `PASSING_SCORE=90`, `MALPRACTICE_FLAG_THRESHOLD=2`,
`MALPRACTICE_TERMINATE_THRESHOLD=3`, the exact JSON shapes of both
`resume_violation_state` and `resume_record_violation`, and the web
template/JS's own (still-hardcoded) warning-text behavior in both the
original and updated repos.

**Automated-tested**: all behavior described in §3 and §4 — the threshold
fetch-once-and-cache flow, the dynamic denominator rendering, the
null/unknown-threshold fallback, and the unaffected `flagged`-title
behavior — via the new controller and widget tests, plus the full existing
suite confirming zero regressions elsewhere.

**Not manually or live-tested**: no live device, emulator, or running
backend instance was used in this phase. No claim is made of manual UI
verification or a live `resume_violation_state`/`resume_record_violation`
round-trip against a real server — all verification is static source
reading plus Flutter-side automated tests.

---

Phase 17 is complete. Stopping here per instruction — awaiting explicit
approval before beginning Phase 18 or any other phase.
