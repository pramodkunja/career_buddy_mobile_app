# W015 — AI Writing: Web → Flutter

## 1. Web files inspected

- `templates/activities/modules/writing.html` — the full template (read in full)
- `static/activities/js/writing.js` — the full 447-line script (read in full)
- `activities/views.py:27-42` — `get_module_template()` (writing branch: `"writing" in title.lower() and "professional" in title.lower()`)
- `activities/views.py:1690-1767` — `analyze_writing(request, exercise_pk)`, the endpoint reused
- `activities/agents/writing.py` — `WritingAgent.run()` (the 500/900-char server-side validation, repetition/copy-detection safety nets, `previous_improved_passage` anti-copy-paste check)
- `activities/agents/utils.py:929-985` — `fallback_text_module_analysis()` (confirms `feedback`/`quick_tip` are always populated)
- `activities/agents/base.py` — `BaseAgent.safe_run` / `AgentInputError` (same always-200, `{success,data,error,meta}` contract as Speaking)
- `static/activities/js/linguavoice-common.js` — `formatImprovedText()`, `computeWritingScore()` (confirmed dead in practice), `unwrapApiData()`
- `activities/views.py:1075-1152` — `sub_activity_detail_api` (`last_attempt`, reused for "Previous Score")
- `activities/urls.py:29` — the `analyze_writing` URL entry
- `activities/management/commands/setup_professional_modules.py` — confirms the real seed data (`Activity.title = 'Professional Speaking'`/`'Professional Passage Writing'`/etc., and that the seeded `Exercise.exercise_type` is hardcoded `'writing'` — a placeholder value — for **all four** professional modules, including Speaking)

## 2. Actual web flow

A **single, continuous page** — genuinely different from AI Speaking's exclusive state-machine screens. The writing textarea and topic stay visible and editable at all times; the evaluation cards simply appear below once a successful analysis exists, and the user can keep editing and resubmitting indefinitely — there is no explicit "Try Again" action, unlike Speaking.

- **Topic selection**: a `typeSelect` dropdown (General / Story / Opinion), each with its own 10-topic pool (`topicsByType`). The hardcoded initial topic ("Write about one person who inspires you.") **is** the first entry of the "general" pool — the opposite of Speaking, where the initial topic is confirmed *not* a pool member. Verified independently rather than assumed identical.
- **Validation**: `updateWordGuard()` enforces 500–900 **non-whitespace characters** (`text.replace(/\s+/g,'').length`), disabling "Submit for Analysis" outside that range. This is genuinely **server-enforced too** (`WritingAgent.run()` raises `AgentInputError` for the same 500/900 range) — unlike Speaking's client-only 25-word gate, this one is doubly authoritative, confirmed by reading both sides.
- **Submit**: `POST`s `text`, `language`, `reference_text` (the topic), and — only when a prior successful analysis in the same page session produced one — `previous_improved_passage` (`window.lastImprovedPassage`), an anti-copy-paste signal the server uses to detect a resubmission that's just a copy of its own last suggestion.
- **Result display**: unlike Speaking, the server's own `quick_tip` field **is** what the web displays (`quickTipText.textContent = result.quick_tip || '...'`) — the opposite of Speaking, where the server's `quick_tip` is fetched but never shown. Verified independently by reading `writing.js` line by line.
- **Score**: `raw.score_25 !== undefined ? raw.score_25 : lv.computeWritingScore(renderResult.count)` — a client-side fallback score exists in the JS, but is confirmed **dead in practice**: `analyze_writing` always sets `result['score_25']` for every successful, authenticated request (`activities/views.py:1745`), and this view is reachable only when authenticated.
- **A one-exercise-only server-side special case**: "Proposal Section Writing" (under the "Proposal and Bid Writing" activity) enforces a distinct 150–200 *word* rule server-side (`activities/views.py:1707-1716`, HTTP 400), completely separate from the generic 500–900 *character* rule — the same category of narrow, title-matched special case as Speaking's `isElevatorPitchTimed`.
- **Mark complete**: a plain HTML form POST to the existing `mark_sub_complete` endpoint — same as Speaking, no new backend behavior.
- **Previous score**: a server-rendered sidebar card from `previous_result` (score, completed date) — updated live client-side after a fresh successful analysis using the *client's* current date, not re-fetched from the server.

## 3. API/data sources

**Reused, existing, server-authoritative endpoint** (Case A — no new backend surface):

- **Method**: `POST`
- **Endpoint**: `/activities/exercise/<exercise_pk>/analyze/writing/` (`ApiEndpoints.analyzeWriting(exerciseId)`)
- **Authentication**: session cookie, `@login_required`. **Not** `@csrf_exempt` — every request sends `X-CSRFToken` from the `csrftoken` cookie, same as `analyze_speaking`.
- **Request** (multipart form data): `text`, `language`, `reference_text` (the topic prompt), and `previous_improved_passage` (sent only when non-empty). The web's `formData.append("module", "writing")` is **not** sent — confirmed by reading the view line by line that it never calls `request.POST.get('module', ...)` at all; a vestigial, unused field.
- **Response**: HTTP 200 in the normal case (body's `success` field authoritative, same `AgentInputError` → `success:false` contract as Speaking); **HTTP 403** for a locked activity (`_module_access_denied`) and **HTTP 400** for the one "Proposal Section Writing" word-count violation — both genuine non-2xx statuses this app's shared `ApiExceptionsInterceptor` already handles uniformly (mapped to `ForbiddenFailure`/`UnexpectedFailure` with a generic message, not the server's exact string — the same pre-existing behavior every other endpoint in this app already has for a non-2xx status, not a W015-specific gap).
- **A confirmed, load-bearing contract difference from `analyzeSpeaking`**: **`score_25` is a top-level field of the response body, a sibling of `data`, not nested inside it** — verified directly against the view (`result['score_25'] = score_25`, with no matching write into `result['data']`). Blindly reusing Speaking's parsing (which reads `score_25` from inside `data`, since that endpoint genuinely duplicates it there) would have silently produced a wrong/missing score for Writing; this was caught by re-reading the source rather than assumed.

## 4. Flutter implementation

New feature tree, `lib/features/ai_writing/`:
- `domain/entities/writing_topic.dart`, `writing_issue.dart`, `writing_analysis_result.dart`
- `domain/repositories/ai_writing_repository.dart`
- `domain/services/writing_module_detection.dart`, `writing_validation.dart`, `writing_text_formatting.dart`
- `data/models/writing_analysis_result_model.dart`
- `data/datasources/ai_writing_remote_datasource.dart`
- `data/repositories/ai_writing_repository_impl.dart`
- `presentation/controllers/ai_writing_controller.dart`
- `presentation/providers/ai_writing_providers.dart`
- `presentation/ai_writing_route_args.dart`
- `presentation/screens/ai_writing_screen.dart`
- `presentation/widgets/writing_topic_card.dart`, `writing_input_card.dart`, `writing_result_card.dart`

Modified:
- `lib/core/network/api_endpoints.dart` — `analyzeWriting(exerciseId)`
- `lib/app/router/route_paths.dart` — `aiWritingPattern` / `aiWriting(exerciseId)`
- `lib/app/router/app_router.dart` — new route entry
- `lib/features/activities/presentation/widgets/exercise_tile.dart` — new `isWritingModule` param
- `lib/features/activities/presentation/screens/sub_activity_detail_screen.dart` — routes a Writing-module exercise to `AiWritingScreen`
- `lib/features/activities/presentation/screens/activity_detail_screen.dart` — the pre-W014 "guided AI module... isn't available" banner now also excludes Writing-module activities (it already excluded Speaking as of W014)
- `lib/features/activities/domain/entities/activity_detail.dart` — updated `isWorkshop`'s doc comment to reflect Speaking *and* Writing now having real screens

**State management**: `AiWritingController` (`Notifier<WritingState>`), reusing the exact same architecture (Riverpod `NotifierProvider.family`, the shared `ApiClient`/`Result`/`Failure` types, `ExceptionMapper`) as `AiSpeakingController`. Deliberately **not** structured as a state machine of mutually-exclusive full-screen states — `WritingIdle` / `WritingSubmitting` / `WritingResult` / `WritingSubmitFailed` all carry `topic`/`writingType`, and the screen renders the input card unconditionally regardless of which state is active, appending the result/error below it — mirroring the web's own continuous-page structure rather than forcing Speaking's swapped-screen pattern onto a fundamentally different flow. The raw draft text itself lives in the screen's own `TextEditingController`, not in controller state — matching how the web keeps it in the DOM textarea rather than re-deriving it from JS state on every keystroke.

## 5. Routing

`RoutePaths.aiWritingPattern = '/activities/exercise/:id/writing'` — two path segments after `/activities/exercise/`, one more than `mcqExercisePattern` (`/activities/exercise/:id`), so it cannot structurally collide with it regardless of declaration order (same reasoning as `aiSpeakingPattern`). `SubActivityDetailScreen`'s exercise tap handler routes to `AiWritingScreen` whenever the parent **Activity's** title matches `isWritingModuleActivity` — the same title-based rule `get_module_template()` uses, checked independently against the writing branch's own keywords (`"writing"` + `"professional"`) rather than assumed to match Speaking's. `test/app/router/ai_writing_route_test.dart` confirms `mcqExercisePattern`/`aiSpeakingPattern`/`aiWritingPattern` all resolve independently with no collision.

## 6. Validation

Client-side: 500–900 non-whitespace characters (`countNonSpaceChars`/`isWritingLengthValid`, ported verbatim from `updateWordGuard()`), disabling Submit and showing the same two warning messages the web shows ("Please write at least 500 characters." / "Please keep your answer within 900 characters."). This is also genuinely server-enforced (`WritingAgent.run()`), so the client-side gate is a real UX convenience backed by authoritative server validation, not an invented rule. The one-exercise-only 150–200 *word* special case ("Proposal Section Writing") is **not** reproduced client-side — no client-visible signal distinguishes that exercise from any other before submission — but the server still enforces it; a violating submission surfaces as a normal, retryable failure (generic message, per §3's non-2xx handling note).

## 7. Result handling

Server-authoritative only: `transcript`(`text`)/`issues`/`improved_passage`/`feedback`/`quick_tip`/`score_25` are rendered exactly as returned — nothing recomputed client-side. The confirmed-dead `computeWritingScore` client-side fallback (§2) is **not** reproduced, consistent with this app's standing rule against fabricating scores.

## 8. Completion behavior

Identical, reused mechanism to every other exercise type in this app: `MarkSubCompleteController`/`markSubCompleteControllerProvider` (unconditional "Mark Sub-Activity Complete" button, matching the web's ungated form on this page) — no new completion API, no client-side completion guessing; the screen only reflects completion once the server's own next fetch confirms it (existing invalidation pattern).

## 9. Previous-attempt behavior

Reuses `sub_activity_detail_api`'s existing `last_attempt` (`score`/`max_score`/`percentage`/`completed_at`), the same source `AiSpeakingScreen`'s "Previous Score" card already uses — passed in by `SubActivityDetailScreen`, not re-fetched. The web's separate JS-only full-feedback-card-restore-on-reload behavior (driven by the full stored `result_data` blob) is **not** reproduced — the same genuine, confirmed backend limitation already documented for W014 (no existing API exposes that blob for a single exercise).

## 10. Known limitations

- The 150–200 *word* special case for "Proposal Section Writing" is not reproduced client-side (§6) — the server still enforces it correctly.
- No live word-count preview beyond the character counter — matches the web exactly (the web itself has no separate word counter for this module, only the character counter).
- The full-feedback-restore-on-reload behavior is not reproduced (§9) — same confirmed limitation as AI Speaking.
- The 3-language cosmetic UI-label overlay (Vietnamese/Russian text translations of static headings/buttons — `writing.js` has no Arabic translation branch at all, only Vietnamese and Russian) is not reproduced; `language` itself remains a real, functional field sent to the server.

## 11. Zero-Activity database constraint

The current development database contains **zero** `Activity`, `SubActivity`, and `Exercise` records. No seed command or database mutation was performed at any point during this task — confirmed via a read-only `manage.py shell` query before and after implementation:

```
Activities: 0
SubActivities: 0
Exercises: 0
```

W015 was validated entirely through mocked/provider-overridden repository data and automated controller/widget/route tests rather than by inserting activity content into the database. `setup_professional_modules.py` (the real seed command that *would* create a `'Professional Passage Writing'` Activity) was read to confirm its title/category/exercise-type values for parity purposes, but was never executed.

## 12. Manual end-to-end testing limitation

Because the database has no Activity content, the full navigation chain (Activities → Activity Detail → Sub-Activity Detail → Interactive Exercises → AI Writing) cannot currently be exercised manually against a real running app/session in this environment. The route, controller, and every UI state are verified by automated tests (§13) using representative in-memory data and provider overrides instead; `test/app/router/ai_writing_route_test.dart` and the `sub_activity_detail_screen_test.dart` navigation test specifically confirm the wiring from `SubActivityDetailScreen` through to `AiWritingScreen` is correct at the code level. Manual verification remains available once real Activity content exists in the environment — this is a data-availability gap in the current environment, not an implementation defect.

## 13. Testing

```
flutter analyze: PASS
flutter test: 492/492 PASS
```

Baseline before W015: 417/417. 75 new tests, none replacing or weakening an existing test:
- `test/features/ai_writing/domain/` — `writing_module_detection_test.dart`, `writing_topic_test.dart`, `writing_validation_test.dart`, `writing_text_formatting_test.dart`
- `test/features/ai_writing/data/` — `writing_analysis_result_model_test.dart` (including the top-level-vs-nested `score_25` regression case), `ai_writing_remote_datasource_test.dart` (multipart fields, CSRF header, `previous_improved_passage` inclusion rules, `success:true`/`false`, 403/500 mapping), `ai_writing_repository_test.dart`
- `test/features/ai_writing/presentation/` — `ai_writing_controller_test.dart` (topic/type pools, submit validation gate, `previous_improved_passage` chaining across submissions, resubmission-not-blocked, retry-after-failure), `ai_writing_screen_test.dart` (every state's rendering, character-counter/validation UI, submission flow via a controllable `Completer`-backed fake repository, previous-score card, 320/375/430px responsive)
- Additions to existing files: `exercise_tile_test.dart` (`isWritingModule` true/false), `sub_activity_detail_screen_test.dart` (navigation to `AiWritingScreen`), `activity_detail_screen_test.dart` (the AI-module banner correctly excludes Writing too), `test/app/router/ai_writing_route_test.dart` (new — confirms no collision between `mcqExercisePattern`/`aiSpeakingPattern`/`aiWritingPattern`)

Two genuine bugs were found and fixed during responsive/widget testing, not pre-existing regressions:
- A `RenderFlex` overflow at 320px in `WritingInputCard`'s header row (title + character counter on one line) — fixed by moving the counter to its own right-aligned line below the title.
- A `RenderFlex` overflow at 320px in `WritingResultCard`'s score row ("Overall Score" label + a large `headlineSmall` score value) — fixed by wrapping the label in `Expanded`.

## 14. Regression

```
Login/Dashboard/Activities/Activity Detail/Sub-Activity Detail/MCQ/Workshop Dashboard/AI Speaking/
OOP Mock Test/Subject Quizzes/AMCAT/CoCubes: PASS
```
No existing test was modified, weakened, or removed. `AiSpeakingController`/`AiSpeakingScreen` and the W013 route-order fix are unaffected — confirmed by `ai_writing_route_test.dart`'s explicit `/speaking still resolves to AiSpeakingScreen, not AiWritingScreen` case.

## 15. Web integrity

```
Web project modified: NO
Database mutated: NO
```

`git status --short` / `git diff --stat` against the Django project show only the same pre-existing, unrelated changes confirmed at the end of every prior phase (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, plus the three untracked `tests_*.py` files) — nothing touched by this task. Database `Activity`/`SubActivity`/`Exercise` counts remain `0`/`0`/`0`, confirmed via a read-only query both before and after implementation; no seed command, fixture, or migration was run.
