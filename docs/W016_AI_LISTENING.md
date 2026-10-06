# W016 — AI Listening: Web → Flutter

## 1. Web files inspected

- `templates/activities/modules/listening.html` — the full template (read in full)
- `static/activities/js/listening.js` — the full 673-line script (read in full)
- `activities/views.py:27-42` — `get_module_template()` (listening branch: `"listen" in title.lower()` — **no** `"professional"` requirement)
- `activities/views.py:1327-1364` — `exercise_detail()`, the plain HTML view that mints `attempt_token`
- `activities/views.py:1770-1908` — `analyze_listening(request, exercise_pk)`, the endpoint reused
- `activities/agents/listening.py` — `ListeningAgent.run()` (`has_meaningful_speech`, a `ValueError` — not `AgentInputError` — for too-short text)
- `activities/agents/utils.py` — `has_meaningful_speech`, `compute_listening_score_25`, `fallback_text_module_analysis`
- `activities/agents/base.py` — `BaseAgent.safe_run` (the shared always-200-unless-explicitly-overridden, `{success,data,error,meta}` contract, and its `AgentInputError`-vs-generic-`Exception` retry behavior)
- `static/activities/js/linguavoice-common.js` — `readConfig()`, `hasMeaningfulText()`, `computeListeningAssessment()`, `unwrapApiData()`
- `activities/urls.py:22,29` — the `exercise_detail`/`analyze_listening` URL entries
- `activities/management/commands/setup_professional_modules.py` — confirms the real seed title (`'Listen & Write'`, category `'listening'`, order 22)

## 2. Actual web flow

```
GET /activities/exercise/<id>/  (exercise_detail, HTML view)
    → mints a fresh attempt_token (secrets.token_hex(16))
    → embeds it in <script type="application/json" id="listening-config">
JavaScript init (listening.js)
    → reads attemptToken/analyzeEndpoint out of that script tag
    → picks a random story from the client-side "stories" pool (no server call)
User taps Play
    → window.speechSynthesis reads the story text aloud (on-device TTS, no audio file)
    → a wall-clock timer estimates progress against an estimated duration
User types a comprehension summary, taps "Submit for Analysis"
    → POST /activities/exercise/<id>/analyze/listening/ with the attempt_token
Django validates the token against a session-stored used-token list, then runs ListeningAgent
    → server-derived score_25 + content_match_percent, both nested inside data
Client renders the result — feedback/quick-tip text is itself computed CLIENT-SIDE
    from the server's content_match_percent (see §"result contract" below)
    → the form is then PERMANENTLY LOCKED (attemptEvaluated) until the page is reloaded
```

A hybrid of Speaking's and Writing's flows: playback is a discrete state machine (Ready → Playing → Paused/Completed → Terminated) like Speaking's recorder, but the answer box stays visible the whole time like Writing's textarea. Unique to this module: a **single evaluation per page load** — once submitted successfully, the form locks permanently; retrying requires an actual restart (a fresh `attempt_token`), not just a tap.

## 3. Anti-replay token — full investigation

- **Token source**: server-side only, minted in `exercise_detail()` (`activities/views.py:1353`, `secrets.token_hex(16)`) — a cryptographically random 32-hex-character string.
- **Generation trigger**: every single render of the `exercise_detail` HTML page for a module-type activity — i.e. once per "page load" (or reload/restart), not per exercise and not per submission.
- **Storage (server)**: not stored anywhere until first used — the token itself is stateless; what *is* stored server-side is a session-scoped **list of already-used tokens**, keyed per exercise (`request.session['listening_used_tokens_<exercise_pk>']`, capped at the last 20).
- **Storage (client)**: embedded directly in the rendered HTML, inside `<script type="application/json" id="listening-config">{"attemptToken": "...", ...}</script>` — read once by `listening.js` into a local JS variable (`lv.readConfig("listening-config")`).
- **Transmission**: sent back as a plain `multipart/form-data` field, `attempt_token`, on the `analyze_listening` POST.
- **Validation** (`activities/views.py:1799-1816`): missing token → **HTTP 409** `{success:false, error:"Could not verify this attempt..."}`; token present in the session's used-list for this exercise → **HTTP 409** `{success:false, error:"This attempt has already been evaluated..."}`. Both are genuine non-2xx statuses — a real difference from Speaking/Writing's always-200 contract, confirmed by reading the view directly rather than assumed.
- **Single-use / expiry**: the token is marked used **only after a successful evaluation** (`used_tokens.append(attempt_token)` runs inside the `if result['success'] and request.user.is_authenticated:` block) — a request that fails validation, errors, or is rejected by the agent never consumes it, so the same token can be retried after a genuine failure. There is no separate time-based expiry — its only "expiry" is being spent on a success, or the session ending.
- **Signing/hashing**: none — it's an opaque random token; the server never re-derives or verifies its structure, only whether it's present and whether it's already in the session's used-list.
- **Flutter accessibility — the critical question**: **YES, legitimately obtainable.** `exercise_detail` is a standard `@login_required` Django view, authenticated by the same session cookie this app's `ApiClient` already persists via its cookie jar (the identical mechanism every other authenticated request in this app already relies on). Issuing `GET /activities/exercise/<id>/` from Flutter is **the exact same request a browser makes when opening this exercise** — not a bypass, not a different code path, not a special/undocumented endpoint. The server has no way to distinguish this request from a real browser's and applies identical validation either way. `AiListeningRemoteDataSource.fetchAttemptToken` does exactly this, then reads `attemptToken` out of the same well-defined `<script type="application/json" id="listening-config">` blob the web's own `lv.readConfig()` reads — a stable, deliberately-embedded JSON document (not fragile arbitrary-HTML scraping), via `extractEmbeddedJsonConfig()`. **The anti-replay mechanism itself is fully respected**: each Flutter "attempt" fetches its own fresh token (equivalent to a page load/restart) and can be used for exactly one successful evaluation, identically to the web.
- **Known fragility (honestly documented, not a security concern)**: this approach is coupled to the template continuing to render that exact `<script id="listening-config">` tag. If that markup changes, token extraction fails cleanly (`fetchAttemptToken` throws a `ValidationException` with a clear message, surfaced as a retryable error) — it does not silently break, hang, or bypass anything.

## 4. Audio flow

**There is no audio file, streamed audio, or server-provided audio asset anywhere in this feature — on the web or in Flutter.** The "story" is a **hardcoded, client-side text pool** (`stories.beginner`/`stories.intermediate`, 6 entries each, `listening.js:10-87`) read aloud entirely on-device via the **Web Speech API** (`window.speechSynthesis`/`SpeechSynthesisUtterance`). There is no recording, no upload, and no playback of a real audio file to inspect or reproduce. Flutter's equivalent is `package:flutter_tts` (`ListeningTtsService`/`ListeningTtsServiceImpl`), which drives the platform's native TTS engine (iOS `AVSpeechSynthesizer` / Android `TextToSpeech`) to read the same fixed story text aloud — a faithful, same-category reproduction, not an invented mechanism.

- **Playback controls**: Play, Pause/Resume (toggle), New Story, level (Beginner/Intermediate — two independently-pooled story sets), speed (0.8×/1.0×/1.2×).
- **Pause limit**: exceeding 5 pauses in one playback session **auto-terminates** the attempt (`showPauseLimitMessage()`) — the same 5-pause rule already established for AI Speaking (W014), confirmed independently here from `listening.js:492-525`.
- **Progress**: a wall-clock timer against `estimateDuration()` (words ÷ speed-adjusted words-per-second, floored at 8 seconds) — not derived from any real audio duration, since none exists; ported verbatim as `estimateListeningDuration`.
- **Pause/resume simplification (documented, honest)**: platform TTS pause/resume support is not reliably available at every Android API level, unlike every modern browser's `speechSynthesis.resume()`. `AiListeningController.resumeNarration()` restarts narration from the beginning of the story rather than claiming an exact resume-from-position, while still preserving the accumulated pause count and the 5-pause limit exactly. This is a deliberate, minor UX simplification — never silently invented as identical to the web's behavior.
- **Story text reveal**: hidden until Play is first tapped (matches the web template's inline patch script toggling `storyTextBox`'s `d-none` class).

## 5. API contract

**Endpoint 1 — token acquisition (reused HTML view, Case A-adjacent: an existing endpoint used for its existing, real purpose):**
- Method: `GET`
- URL: `/activities/exercise/<exercise_pk>/`
- Auth: session cookie, `@login_required`
- Request: none (no body/params beyond the path)
- Response: full HTML page; the `attemptToken` is read out of the embedded `<script type="application/json" id="listening-config">` JSON blob
- Errors: a locked activity redirects to `/activities/?locked=1` (no such script tag on that page — `fetchAttemptToken` throws a clear `ValidationException`); non-2xx statuses (401/403/404/5xx) are mapped by the existing shared `ApiExceptionsInterceptor`

**Endpoint 2 — analysis:**
- Method: `POST`
- URL: `/activities/exercise/<exercise_pk>/analyze/listening/`
- Auth: session cookie, `@login_required`, **not** `@csrf_exempt` (`X-CSRFToken` required)
- Request (multipart): `text`, `reference_text` (the story), `duration_seconds`, `pause_count`, `attempt_token`, `language`
- Response: `{success, data, error, meta}`. On success, `data` contains `{text, issues, improved_passage, scores, feedback, quick_tip, score_25, content_match_percent}` — **`score_25`/`content_match_percent` are nested inside `data`** (confirmed by reading the view: it mutates the same dict `result['data']` already references, the same placement as `analyzeSpeaking`, **not** `analyzeWriting`'s top-level placement — verified independently, not assumed from either).
- Errors: 200 with `success:false` for a rejected/too-short submission (though note: `ListeningAgent.run()` raises a plain `ValueError`, not `AgentInputError`, for `has_meaningful_speech` failures — `BaseAgent.safe_run` retries a generic `Exception` up to 3 times with incremental backoff before giving up, meaning this specific failure path is noticeably *slower* than Speaking/Writing's equivalent immediate-reject validation errors, a genuine confirmed backend quirk, not something "fixed" here); **HTTP 409** for a missing/reused `attempt_token` (`{success:false, error}`); 403 for a locked activity (`_module_access_denied`). Non-2xx statuses are handled by the existing shared interceptor uniformly, the same established pattern as Writing's 400/403 cases.

## 6. Flutter implementation

New feature tree, `lib/features/ai_listening/`:
- `domain/entities/listening_story.dart`, `listening_issue.dart`, `listening_analysis_result.dart`
- `domain/repositories/ai_listening_repository.dart` (`fetchAttemptToken` + `analyze`)
- `domain/services/listening_module_detection.dart`, `listening_validation.dart`, `listening_duration.dart`, `listening_feedback.dart`, `listening_tts_service.dart`
- `data/models/listening_analysis_result_model.dart`, `listening_page_config.dart` (the embedded-JSON-blob extractor)
- `data/datasources/ai_listening_remote_datasource.dart`
- `data/repositories/ai_listening_repository_impl.dart`
- `data/services/listening_tts_service_impl.dart` (wraps `package:flutter_tts`)
- `presentation/controllers/ai_listening_controller.dart`
- `presentation/providers/ai_listening_providers.dart`
- `presentation/ai_listening_route_args.dart`
- `presentation/screens/ai_listening_screen.dart`
- `presentation/widgets/listening_story_card.dart`, `listening_answer_card.dart`, `listening_result_card.dart`

Modified:
- `pubspec.yaml` — added `flutter_tts: ^4.2.5` (no native manifest/Info.plist changes required — on-device TTS output needs no special platform permission on either platform)
- `lib/core/network/api_endpoints.dart` — `analyzeListening(exerciseId)`, `exerciseDetailPage(exerciseId)`
- `lib/app/router/route_paths.dart` — `aiListeningPattern` / `aiListening(exerciseId)`
- `lib/app/router/app_router.dart` — new route entry
- `lib/features/activities/presentation/widgets/exercise_tile.dart` — new `isListeningModule` param
- `lib/features/activities/presentation/screens/sub_activity_detail_screen.dart` — routes a Listening-module exercise to `AiListeningScreen`
- `lib/features/activities/presentation/screens/activity_detail_screen.dart` — the AI-module "not available" banner now also excludes Listening-module activities
- `lib/features/activities/domain/entities/activity_detail.dart` — updated `isWorkshop`'s doc comment

**State management**: `AiListeningController` (`Notifier<ListeningState>`), reusing the same Riverpod/`Result`/`Failure`/`ExceptionMapper` architecture as W014/W015. Genuinely new compared to both: a `ListeningLoading`/`ListeningLoadFailed` pair precedes the active state, since token acquisition is an async network call neither Speaking nor Writing needs before becoming interactive — `build()` schedules `Future.microtask(_load)` and starts in `ListeningLoading`. Once loaded, `ListeningActive` carries the playback state machine (`PlaybackStatus`) *and* a nested `SubmissionPhase` (`Idle`/`InFlight`/`Succeeded`/`Failed`) — `Succeeded` is terminal and permanently blocks further `submit()` calls, mirroring `attemptEvaluated`.

## 7. UI/functional parity

Preserved: story title/meta, level/speed selectors, New Story, Play/Pause, progress bar, status/pause-count chips, the hidden-until-played story text, the always-enabled (validated-on-tap, not live-disabled) answer box and Submit button, Mistakes Review (issue list, touch-adapted from the web's hover-highlight), Evaluation (Total Score, Content Match %, Improved Version, Overall Feedback — computed via the same client-side banding the web uses, driven by the server's `content_match_percent`), Quick Tip, Mark Complete, Previous Score.

## 8. Feasibility

**FULLY IMPLEMENTABLE.**

The anti-replay token is legitimately obtainable through the existing `exercise_detail` HTML endpoint using the app's already-authenticated session — no backend modification, no bypass, no fake/hardcoded token. The audio mechanism (on-device TTS from fixed text) is fully reproducible with `flutter_tts`, with one honestly-documented, minor simplification (pause/resume restarts narration from the beginning rather than an exact mid-utterance resume, due to platform TTS limitations — §4). The API contract (both the HTML token page and the JSON analysis endpoint) was independently verified field-by-field, including two contract details that genuinely differ from Speaking/Writing (`score_25` placement, the 409 status for token errors, and the slower `ValueError`-vs-`AgentInputError` failure path for too-short text) — none of which required any backend change to work with.

## 9. Database constraint

The current development database contains **zero** `Activity`, `SubActivity`, and `Exercise` records:
```
Activities: 0
SubActivities: 0
Exercises: 0
```
confirmed via a read-only `manage.py shell` query both before and after this task. No seed command, fixture, migration, or manual database write was performed at any point. W016 was validated entirely through mocked/provider-overridden repository and TTS-service data plus automated controller/widget/route tests, using representative in-memory `Activity`/`SubActivity`/`Exercise`-equivalent test fixtures (never inserted into Django/MySQL) — never against real seeded content. `setup_professional_modules.py` (the real seed command that *would* create a `'Listen & Write'` Activity) was read only to confirm its title/category values for parity purposes; it was never executed.

Because of this, the full navigation chain (Activities → Activity Detail → Sub-Activity Detail → Interactive Exercises → AI Listening) cannot currently be exercised manually against a real running app/session in this environment — this is a data-availability gap in the environment, not an implementation defect. The routing/detection wiring is verified at the code level instead, via `test/app/router/ai_listening_route_test.dart` and the `sub_activity_detail_screen_test.dart`/`activity_detail_screen_test.dart` navigation additions.

## 10. Testing

```
flutter analyze: PASS
flutter test: 585/585 PASS
```

Baseline before W016: 492/492. 93 new tests, none replacing or weakening an existing test:
- `test/features/ai_listening/domain/` — `listening_module_detection_test.dart` (including the no-"professional"-required confirmation), `listening_story_test.dart`, `listening_validation_test.dart`, `listening_duration_test.dart`, `listening_feedback_test.dart` (every banding branch of both `buildListeningFeedback`/`buildListeningQuickTip`)
- `test/features/ai_listening/data/` — `listening_page_config_test.dart` (the embedded-JSON extractor, including the "redirected to a different page" and "id collision" cases), `listening_analysis_result_model_test.dart` (confirming `score_25`/`content_match_percent` are read from inside `data`), `ai_listening_remote_datasource_test.dart` (token-page fetch + parse, the 409 token-error path, multipart field construction, CSRF header), `ai_listening_repository_test.dart`
- `test/features/ai_listening/presentation/` — `ai_listening_controller_test.dart` (loading → active/load-failed, play/pause/resume, the 5-pause termination rule, the permanent-lock-on-success rule, retry-after-genuine-failure, New Story vs. speed-change reset differences, all via `fake_async` with a fake TTS service and fake repository), `ai_listening_screen_test.dart` (loading/error/retry, story reveal, submission success/failure/local-validation, previous score, 320/375/430px responsive)
- Additions to existing files: `exercise_tile_test.dart` (`isListeningModule` true/false), `sub_activity_detail_screen_test.dart` (navigation to `AiListeningScreen`, using a non-"professional" title to also prove the detection-rule difference), `activity_detail_screen_test.dart` (the AI-module banner correctly excludes Listening too), `test/app/router/ai_listening_route_test.dart` (new — confirms no collision across all three of `mcqExercisePattern`/`aiSpeakingPattern`/`aiWritingPattern`/`aiListeningPattern`)

One genuine `RenderFlex` overflow at 320px was found and fixed in `ListeningResultCard`'s "Content Match" row (label + percentage), the same class of fix already applied in W015's result card.

## 11. Limitations

- Pause/resume restarts narration from the beginning of the story rather than an exact mid-utterance resume (§4) — a documented, honest simplification due to platform TTS constraints, not silently claimed equivalent to the web.
- Token extraction depends on the `exercise_detail` template continuing to render its `<script id="listening-config">` blob — a known, honestly-documented coupling (§3), not a security concern, since a template change would fail extraction cleanly rather than silently misbehave.
- The full-feedback-restore-on-reload behavior (the web's `previous_result_json` JS-only mechanism) is not reproduced — the same confirmed, pre-existing limitation already documented for W014/W015 (no existing API exposes the full stored `result_data` blob for a single exercise).
- The 3-language cosmetic UI-label overlay (Vietnamese/Russian) is not reproduced; `language` itself remains a real, functional field sent to the server.

## 12. Web integrity

```
Web project modified: NO
Database mutated: NO
```

`git status --short` / `git diff --stat` against the Django project show only the same pre-existing, unrelated changes confirmed at the end of every prior phase — nothing touched by this task. `Activity`/`SubActivity`/`Exercise` counts remain `0`/`0`/`0`, confirmed via a read-only query both before and after implementation; no seed command, fixture, or migration was run; no anti-replay validation was bypassed, weakened, or modified.
