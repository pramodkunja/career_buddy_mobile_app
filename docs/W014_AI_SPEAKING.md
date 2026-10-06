# W014 — AI Speaking: Web → Flutter

## 1. Web files inspected

- `templates/activities/modules/speaking.html` — the full template (read in full)
- `static/activities/js/speaking.js` — the full 979-line script (read in full)
- `activities/views.py:27-46` — `get_module_template()` / `is_module_activity()` (title-keyword routing to `'activities/modules/speaking.html'`)
- `activities/views.py:1629-1685` — `analyze_speaking(request, exercise_pk)`, the endpoint reused
- `activities/agents/base.py` — `BaseAgent.safe_run` (always HTTP 200, `{success, data, error, meta}`)
- `activities/agents/speaking.py:20-41` — `SpeakingAgent.run()` (server-side Sarvam STT, `choose_best_transcript`, `_normalised_module_score`, `_save_module_result`)
- `activities/agents/utils.py` — `derive_revision_issues` / `derive_languagetool_issues` (issue shape: `{phrase, type, message, suggestion}`)
- `activities/views.py:1075-1152` — `sub_activity_detail_api` (`last_attempt`, already consumed by this app since W005)
- `templates/includes/language_dropdown.html` — the 4 language values (`english`, `vietnam`, `arabic`, `russian`)
- `activities/urls.py:28` — the `analyze_speaking` URL entry

## 2. Actual web flow

A single page, `speaking.html` + `speaking.js`, with in-place client-side state transitions and one server round-trip:

**Topic** (idle) → **Recording** → **Recorded** (ready to submit) → **Submitting** → **Result**.

- The template hardcodes one initial topic ("Describe your best experience at the workplace."), confirmed **not** a member of the 20-topic array `speaking.js` cycles through via "New Topic" (`getNextUniqueTopic()`/`refillTopicPool()`) — once tapped even once, the initial prompt can never reappear.
- Recording uses the browser's `MediaRecorder` (preferring `audio/webm;codecs=opus`) plus, in parallel, the Web Speech API for a **live, best-effort client-side transcript preview** — this preview is never sent as the primary transcription source.
- Hard caps: `MAX_RECORD_SECONDS = 90` (with an unreproduced 60-second special case, `isElevatorPitchTimed`, for one specific activity/sub-activity/exercise combination) and auto-terminate once `pauseCount > 5`.
- A client-side `MIN_MEANINGFUL_WORDS = 25` gate blocks submission if the live transcript looks too short — enforced only via the browser's own live transcript.
- On submit, the recorded audio (plus `client_transcript`, `duration_seconds`, `pause_count`, `language`, `reference_text`) is posted to `analyze_speaking`. The server does its **own** Sarvam speech-to-text transcription from the uploaded audio; `client_transcript` is used only as a *fallback* if server-side STT fails (`choose_best_transcript([stt_text, client_transcript], reference_text)` prefers `stt_text`).
- **The response's own `data.quick_tip` field is fetched but never displayed.** The JS instead computes and shows a client-side heuristic tip via `getDynamicQuickTip()` — confirmed by reading every call site; this is the web's actual, shipped behavior, not an oversight.
- On a server-call failure, the web's `catch` block falls back to a **locally-computed, unauthorised score** (`estimateLocalScores`/`computeSpeakingScore`) — this app deliberately does not reproduce that (see §8).
- `renderTextWithIssues()` inline-highlights each issue span in the transcript with a hover tooltip (desktop-only interaction pattern).

## 3. API/data sources

**Reused, existing, server-authoritative endpoint** (Case A — no new backend surface):

- **Method**: `POST`
- **Endpoint**: `/activities/exercise/<exercise_pk>/analyze/speaking/` (`ApiEndpoints.analyzeSpeaking(exerciseId)`)
- **Authentication**: session cookie, `@login_required`. **Not** `@csrf_exempt` (unlike the mock-quiz family) — every request sends `X-CSRFToken` from the `csrftoken` cookie.
- **Request** (multipart form data): `audio` (the recorded file), `duration_seconds`, `pause_count`, `client_transcript` (always sent as an empty string — see §6), `language`, `reference_text` (the topic prompt).
- **Response**: **always HTTP 200**, body `{success, data, error, meta}` (`BaseAgent.safe_run`'s own contract — even a rejected submission is a 200). `success` in the body, not the HTTP status, is authoritative. On `success: true`, `data` is `{transcript (falls back to text), issues[], improved_passage, feedback, scores{}, score_25, duration_seconds, pause_count}` (`quick_tip` present but deliberately unparsed — see §2). On `success: false`, `error` is a human-readable string surfaced as-is.
- **Purpose**: server-graded speech analysis — transcription, issue detection, an improved-passage rewrite, and a 0-25 module score (`score_25`, the only score the web itself displays).

`sub_activity_detail_api` (already built in W005) additionally supplies `last_attempt` (`score`, `max_score`, `percentage`, `completed_at`) — reused for the "Previous Score" sidebar card.

## 4. Audio/speech implementation

- `package:record` (`^7.1.1`) wraps the platform microphone. `AudioRecorderService` is a thin injectable interface (`hasPermission`, `start`, `pause`, `resume`, `stop`, `cancel`) over `package:record`'s `AudioRecorder`, mirroring the existing `ApiClient`-injection pattern — lets the controller be tested without a real microphone/plugin.
- Encoding: the package's default, AAC-LC (`.m4a`) — there is no small, well-maintained WebM/Opus recorder for mobile equivalent to the web's `MediaRecorder`; the server's Sarvam transcription call is not format-specific, so this is a safe substitution, not a functional loss.
- Recordings are written to a fresh temporary file per take (`path_provider`'s `getTemporaryDirectory()`); an unsent/cancelled recording is discarded via `cancel()`, not left to accumulate on device storage.
- Android: `RECORD_AUDIO` permission added to `AndroidManifest.xml`. iOS: `NSMicrophoneUsageDescription` added to `Info.plist`. `AudioRecorder.hasPermission(request: true)` drives the actual OS permission prompt.
- No live, client-side speech-to-text preview is implemented (see §6) — recording/timer/pause/submit are otherwise unchanged from the web.

## 5. Flutter files changed

New feature tree, `lib/features/ai_speaking/`:
- `domain/entities/speaking_topic.dart`, `speaking_issue.dart`, `speaking_analysis_result.dart`
- `domain/repositories/ai_speaking_repository.dart`
- `domain/services/audio_recorder_service.dart`, `speaking_quick_tip.dart`, `speaking_module_detection.dart`
- `data/models/speaking_analysis_result_model.dart`
- `data/datasources/ai_speaking_remote_datasource.dart`
- `data/repositories/ai_speaking_repository_impl.dart`
- `data/services/audio_recorder_service_impl.dart`
- `presentation/controllers/ai_speaking_controller.dart`
- `presentation/providers/ai_speaking_providers.dart`
- `presentation/ai_speaking_route_args.dart`
- `presentation/screens/ai_speaking_screen.dart`
- `presentation/widgets/speaking_topic_card.dart`, `speaking_recorder_card.dart`, `speaking_result_card.dart`

Modified:
- `pubspec.yaml` — added `record: ^7.1.1`
- `android/app/src/main/AndroidManifest.xml` — `RECORD_AUDIO` permission
- `ios/Runner/Info.plist` — `NSMicrophoneUsageDescription`
- `lib/core/network/api_endpoints.dart` — `analyzeSpeaking(exerciseId)`
- `lib/app/router/route_paths.dart` — `aiSpeakingPattern` / `aiSpeaking(exerciseId)`
- `lib/app/router/app_router.dart` — new route entry
- `lib/features/activities/presentation/widgets/exercise_tile.dart` — new `isSpeakingModule` param
- `lib/features/activities/presentation/screens/sub_activity_detail_screen.dart` — routes a Speaking-module exercise to `AiSpeakingScreen` instead of the generic "not available" fallback

New tests, `test/features/ai_speaking/` (domain, data, presentation) plus additions to `test/features/activities/presentation/widgets/exercise_tile_test.dart`, `test/features/activities/presentation/screens/sub_activity_detail_screen_test.dart`, and a new `test/app/router/ai_speaking_route_test.dart` — see §10.

## 6. Functionality implemented

- Real topic display/cycling (initial prompt + 20-topic pool, exact "never repeat before pool exhaustion" behavior), language selection (English/Vietnamese/Arabic/Russian — a real, functional field sent to the server), recording with a 90-second cap and pause tracking (auto-stop past 5 pauses), stop/re-record, submit for analysis, retry-on-failure (resending the exact same recording), "Try Again" (same topic, discards the result).
- Server-authoritative results only: transcript, issues, improved passage, feedback, and the 0-25 score, exactly as the server computed them — nothing recomputed or estimated client-side.
- The same client-side quick-tip heuristic the web actually displays (`computeSpeakingQuickTip`, a verbatim, English-only port of `getDynamicQuickTip()`), not the server's own unused `quick_tip` field.
- "Mark Sub-Activity Complete" (unconditional, matching the web's ungated form on this page) and the "Previous Score" sidebar card (from `sub_activity_detail_api`'s `last_attempt`).
- A confirm dialog guarding accidental back-navigation mid-recording ("Leave without saving?").

## 7. Mobile adaptations

- The web's inline-highlighted, hover-tooltip "Mistakes Review" transcript becomes a plain transcript followed by a simple issue list (phrase → message/suggestion) — the same information, adapted for touch instead of hover.
- A circular mic button (tap to start/stop) replaces the web's button + waveform UI; pause/resume are separate explicit actions instead of the same toggle button relabeling itself.
- The `isElevatorPitchTimed` 60-second special case is not reproduced — every exercise uses the standard 90-second cap, a deliberate, minor simplification, not a data error.

## 8. Known limitations

- **No live word count or live transcript preview during recording** — the web's Web Speech API has no Flutter/mobile equivalent without adding a dedicated speech-to-text package, which was deliberately not introduced for this feature. Consequently `client_transcript` is always sent as an empty string; since the server's own Sarvam STT is the *primary* transcription source in the normal case, this only removes a fallback path (server STT itself failing), not the authoritative result.
- **The client-side `MIN_MEANINGFUL_WORDS = 25` pre-submission gate is not reproduced** — it depends on the same live transcript this app doesn't have. A short/silent recording is still submitted; the server's own analysis (via `SpeakingAgent`) is the sole judge of whether it was meaningful.
- **No client-side fallback score on a failed server call** — the web's `estimateLocalScores`/`computeSpeakingScore` fallback is explicitly not reproduced, since it would mean the app inventing a score the server never authorised. A failed submission instead surfaces a retryable error, preserving the recording — the same resilience pattern already used by `AmcatController`/`MockTestController`.
- **The 4-language cosmetic UI-label overlay is not reproduced** — `language` remains a real, functional field (it changes the AI's actual feedback text server-side), only the decorative client-side re-labelling of buttons/headers for non-English languages is skipped.
- **The full-feedback-card restore-on-reload behavior is not reproduced.** The web's `previousResultData`/`previous-result-data` JS-only mechanism restores the entire evaluation card (score, improved passage, issues, feedback) from a full stored `result_data` blob on page reload. No existing JSON API exposes that blob for a single exercise — `sub_activity_detail_api`'s `last_attempt` only exposes `score`/`max_score`/`percentage`/`completed_at`, which is what backs this app's simpler "Previous Score" sidebar card instead (a genuine, confirmed backend limitation, not routed around).

## 9. W013 routing — confirmed unaffected

The new route (`/activities/exercise/:id/speaking`) has two path segments after `/activities/exercise/`, one more than the existing `mcqExercisePattern` (`/activities/exercise/:id`) — structurally, it cannot be matched by the wrong route regardless of declaration order, unlike the genuine W013 `/activities/workshop` collision. No change to W013's route order was made or required; `test/app/router/ai_speaking_route_test.dart` confirms both routes resolve independently.

## 10. Tests

```
flutter analyze: PASS
flutter test: 414/414 PASS
```

New tests (76), none replacing or weakening an existing test:
- `test/features/ai_speaking/domain/` — `speaking_module_detection_test.dart`, `speaking_topic_test.dart`, `speaking_quick_tip_test.dart` (pool integrity, keyword-routing matches/misses, every quick-tip branch)
- `test/features/ai_speaking/data/` — `speaking_analysis_result_model_test.dart` (full/partial/malformed parsing), `ai_speaking_remote_datasource_test.dart` (multipart field/CSRF-header construction, `success: true`/`success: false` handling, non-JSON body, server error mapping), `ai_speaking_repository_test.dart` (Success/Failed mapping end to end through the real datasource)
- `test/features/ai_speaking/presentation/` — `ai_speaking_controller_test.dart` (idle/recording/pause/resume/90s auto-stop/5-pause auto-stop/submit success/submit failure+retry/tryAgain/pickNewTopic, using `fake_async` for timer-driven behavior, matching `AmcatController`/`MockTestController`'s test conventions), `ai_speaking_screen_test.dart` (every sealed state's rendering, previous-score card, an end-to-end real-controller flow, denied-microphone-permission handling, 320/375/430px responsive)
- Additions to existing files: `exercise_tile_test.dart` (`isSpeakingModule` true/false), `sub_activity_detail_screen_test.dart` (navigation to `AiSpeakingScreen` for a Speaking-module Activity's non-mcq exercise), `test/app/router/ai_speaking_route_test.dart` (new — confirms no route collision with `mcqExercisePattern`)

## 11. Regression

```
W001–W007: PASS
W013: PASS
W020–W023: PASS
W014: PASS
```

Baseline before W014: 338/338. After W014: 414/414 — no existing test was modified, weakened, or removed.

## 12. Web integrity

```
Web project modified: NO
```

`git status --short` / `git diff --stat` against the Django project show only the same pre-existing, unrelated working-tree changes confirmed at the end of every prior phase (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, plus the three untracked `tests_*.py` files) — nothing touched by this task.
