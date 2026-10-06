# W017 — AI Reading: Web → Flutter

## 1. Web files inspected

- `templates/activities/modules/reading.html` — the full 275-line template (read in full)
- `activities/static/activities/js/reading.js` — the full 1174-line script (read in full)
- `activities/views.py:27-42` — `get_module_template()` (reading branch, `activities/views.py:37`: `"reading" in title.lower() and "professional" in title.lower()` — **both** required, matching Speaking/Writing's pattern, unlike Listening's single-keyword rule)
- `activities/views.py:1915-1969` — `analyze_reading(request, exercise_pk)`, `@login_required @require_POST` (no `@csrf_exempt`)
- `activities/agents/reading.py` — `ReadingAgent.run()` (full 148 lines read)
- `activities/agents/utils.py` — `transcribe_with_sarvam`, `choose_best_transcript`, `compute_reference_similarity`, `has_meaningful_speech`
- `activities/agents/base.py` — `BaseAgent.safe_run` (shared always-200-unless-explicitly-overridden `{success,data,error,meta}` contract)
- `activities/urls.py:31` — the `analyze_reading` URL entry (no token-minting view is involved for this module at all)
- `activities/management/commands/setup_professional_modules.py` — confirms the real seed title/category for parity purposes only (not executed)

## 2. Actual web flow

```
Page load (reading.html + reading.js, no server call needed to start)
    → a level (1/2/3) and a passage are picked from a client-side pool
      (5 hardcoded passages per level, 15 total)
User taps the mic button
    → getUserMedia + MediaRecorder starts a REAL audio recording
    → in parallel, the browser's optional SpeechRecognition API runs live
      (a client-side transcript hint, not authoritative)
User may Pause/Resume; each Pause increments a counter
    → exceeding 5 pauses in one recording FULLY DISCARDS the attempt
      (resetReading() — the same full reset used by "New passage"/level
      switch, NOT the same behavior as W014 Speaking's pauseLimitExceeded
      flag, which keeps the partial recording)
User taps Stop, then "Submit for Analysis"
    → POST /activities/exercise/<id>/analyze/reading/ (multipart: audio,
      text, client_transcript, reference_text, duration_seconds,
      pause_count, language) — NO attempt_token field exists
Django runs ReadingAgent: transcribes the uploaded audio via Sarvam STT,
picks the best available transcript (server STT > client transcript >
typed text), scores it against reference_text
    → server-derived score_25 written to BOTH result['score_25'] (top
      level) AND data['score_25'] (nested) — confirmed by reading the two
      assignments directly (activities/views.py:1966-1967)
Client renders feedback/quick_tip TEXT VERBATIM AS RETURNED BY THE SERVER
    (no client-side banding/recomputation, unlike Listening)
    → the form is then PERMANENTLY LOCKED (attemptEvaluated = true) until
      "Try Again" (a real reset, matching Listening/Writing's lock
      behavior, not Speaking's never-locks behavior)
```

Reading shares its recording mechanism with Speaking (real `MediaRecorder`
capture + optional live `SpeechRecognition` hint) but diverges from every
other module in at least one respect each: it has **no anti-replay token at
all** (unlike Listening), a **full-discard pause limit** (unlike Speaking's
partial-keep), **server-verbatim feedback/quick_tip text** (unlike
Listening's client-computed banding), and **permanent lock-after-success**
(unlike Speaking, which never locks). None of these were assumed from
precedent — each was independently confirmed by reading the actual
`reading.js`/`analyze_reading`/`ReadingAgent` source, per the task's explicit
instruction not to assume similarity to W014/W016.

## 3. Reading mechanism

- **No attempt token.** Grepped `reading.js` for `attempt_token`/`attemptToken` — zero matches. `analyze_reading` (`activities/views.py:1915-1930`) never reads or validates any such field. This is a genuine, confirmed absence, not an oversight in web inspection — Reading simply has no anti-replay mechanism to reproduce, faithfully implement, or work around.
- **Real audio, not TTS/text-only.** `reading.js` calls `navigator.mediaDevices.getUserMedia` + `MediaRecorder`, uploaded as the `audio` multipart field. `ReadingAgent.run()` (`activities/agents/reading.py:29-35`) transcribes it server-side via `transcribe_with_sarvam(audio_file, api_key, prompt=reference_text)` when both an audio file and API key are present, then merges with the client's live `SpeechRecognition` transcript and the raw `text` field via `choose_best_transcript()` — a 3-way fallback identical in structure to W014 Speaking's, confirmed independently here rather than assumed.
- **Passage pool**: `reading.js` defines `passages[1]`, `passages[2]`, `passages[3]`, each a 5-entry array with a `title` and a `displayLines` array (joined with `" "` at render time — `currentPassageText = (passage.displayLines || []).join(" ")`, `reading.js:722`). `getNextPassageIndex()`/`refillPassagePool()` implement a shuffle-pool-with-exclusion (never repeat the current passage until the level's pool is exhausted, then refill) — ported verbatim into `kReadingPassagesByLevel` and `AiReadingController._pickPassage()`.
- **Pause limit — full discard, not partial keep**: `reading.js:962-970` — on the 6th pause (`pauses > 5`), it calls `resetReading()` (the SAME function used by "New passage"/level-switch — a hard reset back to idle on the current passage) then `showPauseLimitMessage()`. This is a materially different behavior from W014 Speaking, which keeps the partially-recorded audio and sets a `pauseLimitExceeded` flag instead of discarding it — confirmed by direct comparison of the two scripts' pause handlers, not assumed.
- **Lock after success**: `attemptEvaluated` (`reading.js:361`) starts `false`, is reset to `false` on every fresh attempt (`reading.js:761`, inside `resetReading()`), and is set to `true` only on a successful analysis (`reading.js:1114`). While `true`, the Submit button stays disabled (`reading.js:571`, `!attemptEvaluated` guard) — the same permanent-lock pattern already confirmed for Listening/Writing, here independently re-verified for Reading rather than assumed from precedent.

## 4. API contract

**Single endpoint — no token-acquisition step:**
- Method: `POST`
- URL: `/activities/exercise/<exercise_pk>/analyze/reading/`
- Auth: session cookie, `@login_required`, **not** `@csrf_exempt` (`X-CSRFToken` required, confirmed by decorator absence — same as every other analyze endpoint)
- Request (multipart): `audio` (the recorded file), `text` (empty — Flutter has no live speech-recognition transcript to send, honestly sent as `''`), `client_transcript` (same, `''`), `reference_text` (the passage text), `duration_seconds`, `pause_count`, `language`
- Response: `{success, data, error, meta}`. On success, `data` contains `{text, issues, improved_passage, feedback, quick_tip, scores, score_25}` where `text` is the **reference passage** (not a transcript — confirmed by reading `ReadingAgent`'s return shape; `user_transcript`, if present, is never read by the web's own rendering code, so it is deliberately not parsed in the Flutter model either). **`score_25` appears at BOTH `result['score_25']` (top-level) and `data['score_25']` (nested)** — `activities/views.py:1966-1967` — matching Speaking's dual placement, confirmed independently rather than assumed from either Speaking or Writing/Listening's single-placement patterns.
- Errors: 200 with `success:false` for a rejected/too-short submission (`has_meaningful_speech` via `BaseAgent.safe_run`'s standard retry contract); 403 for a locked activity (`_module_access_denied`); non-2xx statuses (401/404/5xx) handled by the existing shared `ApiExceptionsInterceptor`, the same established pattern as every other module.

## 5. Validation

`ReadingAgent.run()` requires meaningful recognized speech (via `has_meaningful_speech`, the same helper used by Listening/Writing) before scoring; a too-short/silent submission is rejected with `success:false` and a message, not a hard error — the Flutter controller surfaces this as a `ReadingSubmitFailed` state, retryable without discarding the recording (distinct from the pause-limit's full discard, which is a client-side, pre-submission reset, not a server validation rejection).

## 6. Scoring

Server-authoritative only — `score_25` is computed entirely by `analyze_reading`/`ReadingAgent` from the transcribed audio against `reference_text` (`_normalised_module_score(scores, 'overall', 'accuracy', 'pronunciation')`, capped at 10 if `relevance < 50`, `activities/views.py:1946-1957`). Flutter never computes, estimates, or locally overrides any score — it only displays the value the server returns, identical to the no-local-scoring rule already upheld in W014/W015/W016.

## 7. Flutter implementation

New feature tree, `lib/features/ai_reading/`:
- `domain/entities/reading_passage.dart` (`kReadingPassagesByLevel`, `kReadingDefaultLevel`), `reading_issue.dart`, `reading_analysis_result.dart`
- `domain/repositories/ai_reading_repository.dart` (`analyze`)
- `domain/services/reading_module_detection.dart` (`isReadingModuleActivity`)
- `data/models/reading_analysis_result_model.dart`
- `data/datasources/ai_reading_remote_datasource.dart`
- `data/repositories/ai_reading_repository_impl.dart`
- `presentation/controllers/ai_reading_controller.dart` (sealed `ReadingState`: `ReadingIdle`/`ReadingRecording`/`ReadingRecorded`/`ReadingSubmitting`/`ReadingSubmitFailed`/`ReadingResult`)
- `presentation/providers/ai_reading_providers.dart` (datasource + repository providers only — `audioRecorderServiceProvider` is deliberately reused, not redefined; see below)
- `presentation/ai_reading_route_args.dart`
- `presentation/screens/ai_reading_screen.dart`
- `presentation/widgets/reading_passage_card.dart`, `reading_recorder_card.dart`, `reading_result_card.dart`

Modified:
- `lib/core/network/api_endpoints.dart` — `analyzeReading(exerciseId)`
- `lib/app/router/route_paths.dart` — `aiReadingPattern` / `aiReading(exerciseId)`
- `lib/app/router/app_router.dart` — new route entry
- `lib/features/activities/presentation/widgets/exercise_tile.dart` — new `isReadingModule` param
- `lib/features/activities/presentation/screens/sub_activity_detail_screen.dart` — routes a Reading-module exercise to `AiReadingScreen`
- `lib/features/activities/presentation/screens/activity_detail_screen.dart` — the AI-module "not available" banner now also excludes Reading-module activities
- `lib/features/activities/domain/entities/activity_detail.dart` — updated `isWorkshop`'s doc comment

**Deliberate cross-feature reuse**: `AudioRecorderService` (and its `audioRecorderServiceProvider`) is imported directly from `lib/features/ai_speaking/` rather than duplicated, since it is a generic platform-capability wrapper (permission check, start/pause/resume/stop/cancel around the device microphone) with no Speaking-specific logic in it — distinct from the established precedent of NOT sharing plain data entities (`ReadingIssue` is its own type, structurally identical to `SpeakingIssue`/`WritingIssue`/`ListeningIssue` but independently defined, since those are feature-owned data shapes, not shared infrastructure).

**State management**: `AiReadingController` (`Notifier<ReadingState>`), reusing the same Riverpod/`Result`/`Failure`/`ExceptionMapper` architecture as W014-W016. `pauseRecording()` implements the full-discard-on-exceeding-5-pauses rule directly (`await _recorder.cancel()`, then a fresh `ReadingIdle` with a `micErrorMessage`) rather than a flag, matching the web's `resetReading()` call — a deliberate, confirmed divergence from `AiSpeakingController`'s partial-keep behavior. `ReadingResult` is terminal; `submitForAnalysis()` is a no-op once in that state, and `tryAgain()` is the only path back to `ReadingIdle` (on the same passage) — mirroring `attemptEvaluated`.

## 8. UI/functional parity

Preserved: level chips (1/2/3, independently pooled), "New" passage button, passage title + text always visible (no reveal-gate — unlike Listening's hidden-until-played story text, confirmed different by inspecting `reading.html`'s markup directly), mic/Pause/Resume/Stop controls, pause-count chip, Submit for Analysis / Retry Analysis / Record Again, Mistakes Review (issue list), Improved Version, Overall Feedback and Quick Tip (both rendered **verbatim** from the server response, not locally banded), score/25, Try Again, Previous Score.

## 9. Feasibility

**FULLY IMPLEMENTABLE.**

No anti-replay or other blocking server mechanism exists for this module at all — confirmed by direct inspection of both `reading.js` and `analyze_reading`. The recording mechanism reuses the exact same real-microphone infrastructure already built and proven for W014 Speaking (`AudioRecorderService`), reused rather than duplicated. The API contract (multipart fields, dual `score_25` placement, verbatim feedback/quick_tip, no token) was independently verified field-by-field against the actual Django view and `ReadingAgent`, not assumed from any prior module's precedent — including the two behaviors that most differ from precedent (full-discard pause limit, permanent lock-after-success alongside verbatim-not-banded feedback text).

## 10. Database constraint

The current development database contains **zero** `Activity`, `SubActivity`, and `Exercise` records:
```
Activities: 0
SubActivities: 0
Exercises: 0
```
confirmed via a read-only `manage.py shell` query both before and after this task. No seed command, fixture, migration, or manual database write was performed at any point. W017 was validated entirely through mocked/provider-overridden repository and audio-recorder-service data plus automated controller/widget/route tests, using representative in-memory `Activity`/`SubActivity`/`Exercise`-equivalent test fixtures (never inserted into Django/MySQL) — never against real seeded content.

Because of this, the full navigation chain (Activities → Activity Detail → Sub-Activity Detail → Interactive Exercises → AI Reading) cannot currently be exercised manually against a real running app/session in this environment — this is a data-availability gap in the environment, not an implementation defect. The routing/detection wiring is verified at the code level instead, via `test/app/router/ai_reading_route_test.dart` and the `sub_activity_detail_screen_test.dart`/`activity_detail_screen_test.dart` navigation additions.

## 11. Testing

```
flutter analyze: PASS
flutter test: 648/648 PASS
```

Baseline before W017: 586/586. 62 new tests, none replacing an existing test's assertions (one pre-existing test in `activity_detail_screen_test.dart` was retitled/reframed, see below), none weakening coverage:
- `test/features/ai_reading/domain/` — `reading_module_detection_test.dart` (5 tests, including the both-keywords-required confirmation matching Speaking/Writing's asymmetry vs. Listening), `reading_passage_test.dart` (4 tests, pool contents/shape)
- `test/features/ai_reading/data/` — `reading_analysis_result_model_test.dart` (7 tests, confirming `score_25` read correctly and `user_transcript` deliberately not parsed), `ai_reading_remote_datasource_test.dart` (7 tests, multipart field construction incl. empty `text`/`client_transcript`, CSRF header, using a real temp `.m4a` file), `ai_reading_repository_test.dart` (4 tests)
- `test/features/ai_reading/presentation/` — `ai_reading_controller_test.dart` (16 tests, via `fake_async` with a fake `AudioRecorderService` and fake repository: idle→recording→recorded→submitting→result, the exceeding-5-pauses FULL DISCARD rule — `recorder.cancelCount >= 1` and a return to `ReadingIdle` with a `micErrorMessage` — explicitly asserted as different from Speaking's partial-keep, the permanent lock after success, `tryAgain()` unlocking, level/passage-pool cycling), `ai_reading_screen_test.dart` (11 tests: idle rendering, New/level-chip switching, full end-to-end flow, a `Completer`-backed submitting-state assertion via `CircularProgressIndicator`, denied-microphone-permission handling, Try Again reset, failed-submission retry, Previous Score card presence/absence, 320/375/430px responsive)
- Additions to existing files: `exercise_tile_test.dart` (`isReadingModule` true/false pair), `sub_activity_detail_screen_test.dart` (navigation to `AiReadingScreen` for a Reading-module title), `activity_detail_screen_test.dart` (a new W017-specific test confirming the "not available" banner is suppressed for `'Professional Reading'`; the pre-existing "non-Speaking AI module still shows banner" test was retitled to a synthetic, non-matching title — `'Professional Vocabulary Drills'` — and reframed as a defensive test for an unrecognized future module type, since its original premise, "Reading is not yet implemented," was invalidated by this task), `test/app/router/ai_reading_route_test.dart` (new — 5 tests confirming no collision across `mcqExercisePattern`/`aiSpeakingPattern`/`aiWritingPattern`/`aiListeningPattern`/`aiReadingPattern`; required a `_FakeAiListeningRepository` override in this file's `ProviderScope` since `AiListeningScreen` — used only for the sibling-route-collision assertion — otherwise triggers a real, platform-channel-dependent `ApiClient` call on build)

## 12. Limitations

- The web's live client-side `SpeechRecognition` transcript hint is not reproduced — Flutter sends `text`/`client_transcript` as empty strings and relies entirely on the server-side Sarvam STT transcription of the uploaded audio, the same honestly-documented simplification already applied to `client_transcript` in W014 Speaking.
- The full-feedback-restore-on-reload behavior (the web's session-based "resume where you left off" JS mechanism) is not reproduced — the same confirmed, pre-existing limitation already documented for W014/W015/W016 (no existing API exposes the full stored `result_data` blob for a single exercise).
- The 3-language cosmetic UI-label overlay (Vietnamese/Russian/Arabic button text) is not reproduced; `language` itself remains a real, functional field sent to the server.

## 13. Web integrity

```
Web project modified: NO
Database mutated: NO
```

`git status --short` / `git diff --stat` against the Django project show only the same pre-existing, unrelated changes confirmed at the end of every prior phase (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py` modified + 3 untracked `tests_*.py` files) — nothing touched by this task. `Activity`/`SubActivity`/`Exercise` counts remain `0`/`0`/`0`, confirmed via a read-only query both before and after implementation; no seed command, fixture, or migration was run; no server-side validation was bypassed, weakened, or modified.
