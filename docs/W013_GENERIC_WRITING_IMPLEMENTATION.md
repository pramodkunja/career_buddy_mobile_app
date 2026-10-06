# W013 — Generic Writing Implementation

## 1. Implementation Summary

Implemented the Generic Writing exercise type (`Exercise.exercise_type ==
'writing'`, under an ordinary, non-module Activity) end to end in Flutter:
data extraction from the server-rendered exercise page, an exact port of
the web's client-side word-count/validation/scoring heuristic, submission
through the existing generic `submit_exercise` endpoint, and a result
screen that renders the server's AI feedback (when present) or just the
score (when not). This is **not** the AI Writing module (`ai_writing`
feature, reached via `isWritingModuleActivity`) — that screen and its
routing are untouched.

## 2. Actual Web Behavior Discovered

Traced end to end from `templates/activities/exercise.html`'s `writing`
branch (lines 295-320) through `static/js/exercises.js`'s `initWriting()`
(lines 654-1108) to `activities/views.py`'s `submit_exercise` (lines
1411-1526):

- **Layout**: every prompt rendered simultaneously (no question-by-question
  navigation), each with an optional "Guide" box (`question.explanation`),
  a `<textarea>`, a live word counter, and a min/max hint. A single
  "Submit Writing" button at the bottom, disabled until every prompt
  satisfies its own word-count range.
- **Word counting**: `text.trim() ? text.trim().split(/\s+/).filter(Boolean).length : 0`
  — whitespace-run splitting, punctuation never stripped.
- **Word limits (`getWritingLimits()`)**, checked in order: (1) the
  exercise's own title is exactly "Proposal Section Writing" (or the
  prompt text contains "proposal section") → hardcoded 150-200; (2) the
  Guide text contains an explicit "X-Y words" / "X–Y words" / "X to Y
  words" range → that range; (3) the Guide text contains a single "N
  words" → N as the minimum, no maximum; (4) otherwise: 50-word minimum,
  no maximum.
- **Client scoring**: a genuinely complex heuristic per prompt — base tier
  from word-count-vs-target (100/80/50/20/0), then a chain of independent
  multiplicative penalties: copying the question text back (×0.3, only
  when the question is >20 chars), an under-met "N recommendations/
  examples" requirement (proportional), low relevance to figures/numbers
  mentioned in the prompt (×0.4 or ×0.8), duplicated sentences (-20/dup,
  floored at 0), and an unmet "structure" checklist (purpose/findings/
  recommendation) when the Guide mentions "structure" (proportional). The
  per-prompt scores are averaged, then the whole submission is further cut
  to ×0.4 if two+ substantial (>50-char) responses are identical.
- **Submission payload**: `POST /activities/exercise/<id>/submit/` with
  `{score, max_score: 100, answers: {"<position>": "<trimmed text>"}}` —
  the exact same generic, non-enveloped contract Matching/Bingo/Fill in
  the Blank already use. `answers` keys are the prompt's 1-based position
  in the rendered order (`data-q="{{ forloop.counter }}"`), **not** the
  database `Question.id`.
- **Server-side behavior — the actual surprise**: `writing` is **not**
  fully client-authoritative like Matching/Bingo/Fill in the Blank.
  `submit_exercise`'s `if exercise.exercise_type in ('writing', 'timer')
  and settings.SARVAM_API_KEY:` branch (`views.py:1422-1495`) **discards
  the client score entirely** and recomputes it via Sarvam AI
  (`analyze_text_with_sarvam_chat`, `ai_mode="writing"`), with repetition-
  ratio and reference-similarity caps layered on top, when that setting is
  configured. When a single prompt's AI call throws, that prompt's
  contribution falls back to `score / len(questions)` — an even split of
  the *client's own* total score, which is the one place the client score
  still matters even with the key configured. When `SARVAM_API_KEY` is
  unset entirely, the branch is skipped and the client score is trusted
  verbatim, exactly like every other exercise type.
- **`customSummaryHtml`**: built only inside the AI branch, one of three
  fixed HTML shapes per prompt (issues list / "No major issues found." /
  "Answer too short to evaluate."), optionally followed by an "Improved
  Version" block. Empty string when the AI branch didn't run.
- **Completion/retry/navigation**: identical to every other generic
  exercise type — `submit_exercise` marks the sub-activity in-progress/
  completed via the same `UserProgress` call; "Try Again" is a full page
  reload (`location.reload()`); the sidebar shows only the single most
  recent attempt's score.

## 3. Flutter Architecture Used

New feature `lib/features/generic_writing/`, mirroring `fill_blank/`'s
layering exactly (domain/data/presentation, Riverpod `Notifier.family`,
existing `ApiClient`/`Result`/`Failure` types, existing router/theme/
shared widgets). No new state-management system, API client, or backend
endpoint. Reused the existing HTML-embedded-JSON extraction pattern
(`extractEmbeddedJsonList`, a local per-feature copy, consistent with
Matching/Bingo/Fill in the Blank) since this exercise type has no JSON
API either.

## 4. Files Created

**Domain**
- `lib/features/generic_writing/domain/entities/writing_prompt.dart`
- `lib/features/generic_writing/domain/entities/generic_writing_exercise.dart`
- `lib/features/generic_writing/domain/entities/generic_writing_submission_result.dart`
- `lib/features/generic_writing/domain/entities/writing_task_feedback.dart`
- `lib/features/generic_writing/domain/services/writing_word_count.dart`
- `lib/features/generic_writing/domain/services/writing_limits.dart`
- `lib/features/generic_writing/domain/services/writing_client_scorer.dart`
- `lib/features/generic_writing/domain/services/writing_summary_parser.dart`
- `lib/features/generic_writing/domain/repositories/generic_writing_repository.dart`

**Data**
- `lib/features/generic_writing/data/models/generic_writing_exercise_model.dart`
- `lib/features/generic_writing/data/models/generic_writing_submission_result_model.dart`
- `lib/features/generic_writing/data/datasources/generic_writing_remote_datasource.dart`
- `lib/features/generic_writing/data/repositories/generic_writing_repository_impl.dart`

**Presentation**
- `lib/features/generic_writing/presentation/generic_writing_route_args.dart`
- `lib/features/generic_writing/presentation/providers/generic_writing_providers.dart`
- `lib/features/generic_writing/presentation/controllers/generic_writing_controller.dart`
- `lib/features/generic_writing/presentation/screens/generic_writing_screen.dart`
- `lib/features/generic_writing/presentation/widgets/generic_writing_in_progress_body.dart`
- `lib/features/generic_writing/presentation/widgets/generic_writing_prompt_card.dart`
- `lib/features/generic_writing/presentation/widgets/generic_writing_result_view.dart`

**Demo Mode**
- `lib/core/demo/demo_generic_writing_repository.dart` — a 2-prompt fixture
  copied verbatim from the real seed exercise "Negotiation Outcome
  Reflection" (`populate_activities.py:135-142`, under "Business
  Negotiation Simulation" → "Live Negotiation and Debrief"), not invented.
  Added because every other genuinely-working exercise-producing feature
  already has one, and Demo Mode swaps *every* repository — omitting it
  would have made this screen crash under Demo Mode specifically.

**Tests** (17 new files, ~85 new test cases)
- `test/features/generic_writing/domain/services/writing_word_count_test.dart`
- `test/features/generic_writing/domain/services/writing_limits_test.dart`
- `test/features/generic_writing/domain/services/writing_client_scorer_test.dart`
- `test/features/generic_writing/domain/services/writing_summary_parser_test.dart`
- `test/features/generic_writing/data/generic_writing_exercise_model_test.dart`
- `test/features/generic_writing/data/generic_writing_submission_result_model_test.dart`
- `test/features/generic_writing/data/generic_writing_repository_test.dart`
- `test/features/generic_writing/presentation/controllers/generic_writing_controller_test.dart`
- `test/features/generic_writing/presentation/widgets/generic_writing_prompt_card_test.dart`
- `test/features/generic_writing/presentation/screens/generic_writing_screen_test.dart`
- `test/core/demo/demo_generic_writing_repository_test.dart`

## 5. Files Modified

- `lib/app/router/route_paths.dart` — added `genericWritingExercisePattern`/`genericWritingExercise(id)`.
- `lib/app/router/app_router.dart` — registered the new route.
- `lib/core/demo/demo_activities_data.dart` — added the "Business
  Negotiation Simulation" demo activity fixture (id 9012/9112/9209).
- `lib/features/activities/presentation/widgets/exercise_tile.dart` —
  added `exercise.exerciseType == 'writing'` to `_hasWorkingScreen`
  (independent of `isWritingModule`), with a doc comment explaining the
  distinction from the AI Writing module.
- `lib/features/activities/presentation/screens/sub_activity_detail_screen.dart` —
  added the routing branch for `exercise.exerciseType == 'writing'`,
  placed **after** all four AI-module title checks, deliberately
  reproducing `get_module_template()`'s real precedence (module template
  wins over the generic exercise-type switch) — see §14 for why this
  ordering matters.
- `test/features/activities/presentation/widgets/exercise_tile_test.dart` —
  the pre-existing "isWritingModule false → Not available" test used
  `type: 'writing'`, which is no longer accurate now that this type always
  has a working screen; changed that test to `type: 'timer'` (still
  genuinely unimplemented) and added a new test asserting `writing` always
  shows "Start" regardless of `isWritingModule`.
- `test/features/activities/presentation/screens/sub_activity_detail_screen_test.dart` —
  registered the new route in the test router; added a routing test for a
  `writing` exercise under an ordinary Activity.
- `test/core/demo/demo_activities_repository_test.dart`,
  `test/core/demo/demo_navigation_test.dart` — updated the demo activity
  count (11→12) and titles list; added a full navigation test for the new
  fixture.

## 6. API Contract

- **GET** `/activities/exercise/<id>/` (`ApiEndpoints.exerciseDetailPage`)
  — same HTML page every exercise type reads; the `questions-data`
  `<script type="application/json">` tag is extracted and parsed. Auth:
  session cookie, `@login_required`. No new endpoint.
- **POST** `/activities/exercise/<id>/submit/` (`ApiEndpoints.submitExercise`)
  — same generic endpoint every other exercise type uses. CSRF via the
  `csrftoken` cookie (already set at login) sent as `X-CSRFToken`.
  - Request: `{"score": <client-computed 0-100>, "max_score": 100,
    "answers": {"<position>": "<trimmed text>", ...}}`
  - Response: `{"status": "ok", "score", "max_score", "percentage",
    "attempt", "customSummaryHtml"}` — `score`/`max_score` may differ from
    what was sent (server AI override); `customSummaryHtml` may be `""`.
  - Errors: 401 → `UnauthorizedFailure` (triggers logout), 403 →
    `ForbiddenFailure` (locked activity), 404 → `NotFoundFailure`, other →
    mapped via the existing `ExceptionMapper`, same as every other
    exercise type.

## 7. Scoring Behavior

Client score computed by `computeGenericWritingClientScore` — a
line-for-line Dart port of `initWriting()`'s heuristic (see §2), always
submitted as the request's `score`. The **server is the actual authority**
whenever `SARVAM_API_KEY` is configured: it recomputes via AI and returns
its own `score`/`max_score`/`percentage`, which is what
`GenericWritingResultView` displays — the app never shows the client's own
guess as if it were final. This was the central, non-obvious finding of
this task (see §2's "actual surprise").

## 8. Word Count / Validation Rules

Implemented in `writing_word_count.dart` (counting) and `writing_limits.dart`
(per-prompt min/max range), both pure functions, both fully unit-tested
against the exact JS behavior (whitespace splitting, punctuation-agnostic,
the "Proposal Section Writing" special case, range/single-count Guide-text
parsing, the 50-word/no-max default). The Submit button is gated on
`GenericWritingInProgress.allValid` — every prompt within its own range —
mirroring `refreshWritingState()`'s `requirementsMet` exactly, including
that an exercise with zero prompts is never submittable.

## 9. UI Parity

Every prompt visible and independently editable at once (no per-prompt
Check button, no navigation, no progress bar, no timer — none of those
exist in the real `writing` branch). Guide box colors
(`#fffbeb`/`#fde68a`/`#92400e`) and word-count colors
(`#64748b`/`#198754`/`#dc3545`) taken directly from
`static/css/exercises.css`/`refreshWritingState()`. Submit button is
`.btn-success` green/white, matching MCQ/Matching/Bingo/Fill in the
Blank's own submit buttons. The result screen reuses the same score-tier
card (gradient/emoji/message by percentage) already established by
`McqResultView`/`MatchingResultView`/`BingoResultView`/`FillBlankResultView`.

## 10. Completion Behavior

Unchanged — `submit_exercise` itself marks the parent sub-activity
in-progress or completed via the existing `UserProgress` mechanism, reused
as-is. No new completion endpoint or logic.

## 11. Retry Behavior

"Try Again" mirrors the web's `location.reload()`: `GenericWritingController.tryAgain()`
re-fetches the exercise from scratch and resets every draft to empty,
rather than merely clearing local state — same reasoning already
established for Fill in the Blank/Matching/Bingo.

## 12. Known Limitations

- **`customSummaryHtml` is parsed, not rendered as raw HTML** — no
  HTML-rendering dependency exists in this project, and the three block
  shapes the server emits are entirely deterministic
  (`activities/views.py:1465-1495`), so `parseWritingSummaryHtml` extracts
  the user-visible content (issue phrase/message/suggestion, "no issues"
  state, improved-passage text) into a typed structure instead. If the
  AI's own generated text ever contained literal `<`/`&` characters, they
  would appear unescaped in the parsed output — an edge case in the
  server's own f-string construction (it doesn't HTML-escape AI output
  either), not something this parser introduces.
- **AI feedback UI is genuinely untestable against the real backend from
  this environment** — the dev database has zero `Activity`/`SubActivity`/
  `Exercise` rows (by design, per the task's own constraint), so no real
  `submit_exercise` call with `SARVAM_API_KEY` configured could be
  exercised end-to-end. Verified instead via unit tests against the exact
  HTML shapes read directly from `activities/views.py`'s source, and via
  Demo Mode (which never produces AI feedback, matching the
  `SARVAM_API_KEY`-unset fallback path faithfully).
- **The client-side scoring heuristic's many interacting penalty rules**
  were tested individually and for the tier boundaries, the averaging,
  and the cross-prompt duplication check, but not exhaustively for every
  possible combination of simultaneous penalties (e.g., a prompt that
  triggers the copy-penalty, the relevance-penalty, *and* the
  repetition-penalty at once) — the arithmetic order matches the JS
  source exactly, but combinatorial coverage of that scale was judged out
  of proportion for a client-side heuristic the server is free to
  override entirely.

## 13. Tests Added

17 new test files, ~85 new test cases across word-count/limits/scorer/
summary-parser unit tests, model parsing (valid/missing-optional/
malformed), repository tests (success/401/403/404 via the existing fake
HTTP adapter), controller tests (load/draft/validate/submit-gating/submit/
failure/no-double-submit/retry), widget tests (prompt card states,
full-screen flow, responsive at 320/375/430/tablet), and a demo-repository
test. Also updated 4 existing test files (§5) to reflect the now-accurate
"writing has a working screen" behavior — a correction, not a weakening,
per this task's own standing instruction for genuine corrections.

## 14. flutter analyze Result

```
Analyzing Mobile_app...
No issues found! (ran in 1.6s)
```

## 15. flutter test Result

```
00:22 +1008: All tests passed!
```
Full suite (previously ~920 tests, now 1008), zero failures, zero skips.

## 16. Web Safety Verification

- No file under `Career_Buddy_LMS/` was read via `Edit`/`Write` — only
  `Read`/`grep` (read-only) were used against the web project this entire
  task.
- `git status --short` in `Career_Buddy_LMS/` shows the same pre-existing,
  unrelated uncommitted diff (`activities/urls.py`, `activities/views.py`,
  `business_english_lms/urls.py`, plus 3 untracked test files) that
  predates this session — confirmed unrelated to Generic Writing (it
  covers `urls.py` routing and unrelated API test files).
- No backend endpoint added, no Django settings changed, no migration
  created, no database write of any kind performed.
- Database state (`Activity`/`SubActivity`/`Exercise` = 0) was not
  touched — this task never queried or wrote to the dev database.

---

# W013 STATUS: COMPLETE

Web modified: NO
Backend modified: NO
Database modified: NO

Generic Writing: COMPLETE

Files changed: 17 new feature files + 1 demo repository + 6 modified
files (router ×2, demo data, exercise tile, sub-activity routing) + 17 new
test files + 4 modified test files. Full list in §4/§5.

API used: `GET /activities/exercise/<id>/` (HTML extraction) +
`POST /activities/exercise/<id>/submit/` (existing generic endpoint) —
identical contract to Matching/Bingo/Fill in the Blank.

Tests: `00:22 +1008: All tests passed!` (full suite, 0 failures)

Analyze: `No issues found! (ran in 1.6s)`

Report: `Mobile_app/docs/W013_GENERIC_WRITING_IMPLEMENTATION.md`

Known limitations: (1) `customSummaryHtml` is parsed into structured data
rather than rendered as raw HTML (no HTML-rendering dependency in this
project; the source shape is fully deterministic). (2) The AI-feedback
path can't be exercised against a real backend response in this
environment (empty dev database) — verified via unit tests against the
exact server-generated HTML shapes and via Demo Mode's
`SARVAM_API_KEY`-unset-equivalent fallback. (3) The client scoring
heuristic's penalty rules are tested individually/at tier boundaries, not
combinatorially for every simultaneous-penalty interaction.
