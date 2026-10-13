# Phase 16 — MCQ & Matching Submission Compatibility Report

**Scope:** targeted compatibility fix only, bringing the Flutter MCQ and
Matching exercise submission payloads in line with the server-side
re-grading introduced in the updated Django source
(`royalStaffing_CB01/`). No other exercise type, auth/OTP/subscription/role
logic, backend code, or build/deploy step was touched.

## 1. Verified grading contract (updated Django source, read directly — not assumed)

A new module, `activities/grading.py`, re-derives and clamps the score for
every exercise type except `writing`/`timer` — `submit_exercise` no longer
trusts whatever `score` the client sends for MCQ or Matching. Its own
docstring: *"Progress is now driven by scores, so the score stored must be
one the server can stand behind, not whatever number the browser sends."*

Both MCQ and Matching grading key the submitted `answers` dict by
`str(i)`, where `i` comes from `enumerate(questions, start=1)` over
`list(exercise.questions.all())` — i.e. the question's **1-based rank in
`Question.Meta.ordering = ['order']` order** (`activities/models.py:138-139`),
confirmed **not** interchangeable with the database primary key. Since
`activities/views.py:870`'s `questions = exercise.questions.all()` is an
unmodified queryset, this is the same order Flutter already receives via
`questions_json` — but `questions_json`'s own `'id': q.id`
(`activities/views.py:892-905`) is the database id, which `McqQuestion.id`
is built from. Position and id are two different numbers.

**MCQ** (`grading.py`): compares
`_norm(_answer(answers, i).get('chosen'))` against `q.correct_answer` (a
letter 'a'-'d'). Confirmed against `templates/activities/exercise.html`
(`data-option="a"`, `data-correct="{{ question.correct_answer }}"`) and
`static/js/exercises.js:134-156` (`chosen = this.dataset.option`).

**Matching** (`grading.py`): compares
`_answer(answers, i).get('paired')` against `str(i)`. Confirmed against
`templates/activities/exercise.html:220,231` — both `.left-item` and
`.right-item` render `data-id="{{ forloop.counter }}"` — and
`static/js/exercises.js:396-410`'s `tryMatch`/submit handler, which sends
`paired` in **both** the correct (`{result:'correct', paired}`) and wrong
(`{result:'wrong', paired}`) cases.

**Silent-failure shape**: `_answer()` treats any non-dict entry as `{}`
(`entry if isinstance(entry, dict) else {}`), so a wrongly-shaped
submission doesn't error — `.get('chosen')`/`.get('paired')` return
`None`, which never matches a real answer, so it silently scores 0.

## 2. Flutter files changed and why

**MCQ** (wire-shape building lives in the datasource):
- `lib/features/activities/data/datasources/mcq_exercise_remote_datasource.dart`
  — `submitMcqExercise` now takes a `questionOrder: List<int>` (the
  exercise's own question ids, in server order) and builds
  `{"<position>": {"chosen": "<letter>"}}` by mapping each answered id to
  its 1-based index in `questionOrder`, instead of keying by raw question
  id with a flat string value.
- `lib/features/activities/domain/repositories/mcq_exercise_repository.dart`
  — added `questionOrder` to the abstract method signature; corrected the
  `McqSubmitEcho` doc comment, which previously (incorrectly) claimed the
  server never grades MCQ.
- `lib/features/activities/data/repositories/mcq_exercise_repository_impl.dart`
  — threads `questionOrder` through to the datasource (pass-through, no
  logic).
- `lib/core/demo/demo_mcq_exercise_repository.dart` — added `questionOrder`
  to the override signature (parameter unused — this demo fake grades and
  echoes locally, no wire format to build).
- `lib/features/activities/presentation/controllers/mcq_exercise_controller.dart`
  — `submit()` now passes `questionOrder: [for (final q in exercise.questions) q.id]`.

**Matching** (wire-shape building already lives in the repository, so only
one file needed changing):
- `lib/features/matching/data/repositories/matching_exercise_repository_impl.dart`
  — the per-pair `answers` map now always includes the real `paired` value
  (`matches[position]!.toString()`). Previously, a correct pair sent only
  `{'result': 'correct'}`, omitting `paired` — on a stale assumption that
  only the wrong-pair case needed it. Since `grading.py` reads `paired`
  unconditionally for every position, a correct pair with no `paired` key
  was being scored as wrong by the (new) server-side re-grading.

No change was needed to `MatchingPair` (its `position` field was already
correctly modeled as the 1-based position, not a database id — confirmed by
its own pre-existing, accurate doc comment) or to the Matching
datasource/controller (both are pure pass-throughs for data already built
correctly upstream).

## 3. Before / after payload examples (from the actual implementation)

**MCQ** — exercise with questions at database ids `740, 12, 305` (server
order), answers `{740: 'b', 12: 'a', 305: 'd'}`:

Before:
```json
{"answers": {"740": "b", "12": "a", "305": "d"}}
```

After:
```json
{"answers": {"1": {"chosen": "b"}, "2": {"chosen": "a"}, "3": {"chosen": "d"}}}
```

An unanswered question is omitted entirely from the map (never sent as a
null/empty guess).

**Matching** — `matches: {1: 1, 2: 2, 3: 1}` (1 and 2 correct, 3 wrongly
paired with 1):

Before:
```json
{"answers": {"1": {"result": "correct"}, "2": {"result": "correct"}, "3": {"result": "wrong", "paired": "1"}}}
```

After:
```json
{"answers": {"1": {"result": "correct", "paired": "1"}, "2": {"result": "correct", "paired": "2"}, "3": {"result": "wrong", "paired": "1"}}}
```

## 4. Tests added

- `test/features/activities/mcq/mcq_exercise_repository_test.dart` — new
  `REGRESSION (Phase 16)` group: (a) asserts the exact outgoing `answers`
  map for 3 questions with non-sequential database ids (`740, 12, 305`),
  keyed `"1"/"2"/"3"` each `{"chosen": letter}`; (b) asserts an unanswered
  question is omitted, not sent as null.
- `test/features/matching/data/matching_exercise_repository_test.dart` —
  new `REGRESSION (Phase 16)` group: (a) a correct pair sends `paired` too;
  (b) an incorrect pair sends the real paired position; (c) a 3-pair mix
  (2 correct, 1 wrong) asserts the full exact structure.
- Existing call sites updated to the new `questionOrder` parameter (no
  behavior change intended): `test/core/demo/demo_mcq_exercise_repository_test.dart`,
  `test/features/activities/mcq/mcq_exercise_controller_test.dart` (plus
  one new assertion, `expect(repo.lastSubmittedQuestionOrder, [100, 101])`,
  added to an existing test), `test/features/activities/presentation/screens/mcq_exercise_screen_test.dart`,
  and four router tests discovered only once `flutter analyze` was run
  project-wide: `test/app/router/ai_listening_route_test.dart`,
  `ai_reading_route_test.dart`, `ai_speaking_route_test.dart`,
  `ai_writing_route_test.dart` (each has its own unrelated
  `_FakeMcqExerciseRepository` that needed the signature updated to match).

All new assertions capture the real outgoing `RequestOptions.data` via a
`FakeHttpClientAdapter(onRequest: ...)`, per this codebase's established
convention — not a mocked repository layer.

**Commands and results:**

```
flutter test test/features/activities/ test/core/demo/   → 287 passed
flutter test test/features/matching/                      → 47 passed
flutter test                                               → 1943 passed, 0 failed
```

## 5. `flutter analyze` results

First whole-project run surfaced 4 pre-existing `invalid_override` errors
in the four router test files above (their local fakes hadn't been updated
for the new `questionOrder` parameter). Fixed by adding the parameter to
each fake's signature (unused, same as the demo repository). Final run:

```
flutter analyze
No issues found! (ran in 2.8s)
```

## 6. Remaining uncertainties / blockers

None for the scope of this phase. One adjacent, explicitly out-of-scope
finding carried over from Phase 15 and **not** touched here: Mock
Interview's hardcoded `/3` violation-count text is stale against the
updated backend's 2/3 thresholds — a candidate for a future phase, not
Phase 16.

## 7. Verified vs. assumed

**Verified by direct source read** (not inferred from the Phase 15 docs
alone, per this phase's explicit instruction): the `order`-based 1-based
position scheme, the id/position non-equivalence, the MCQ `{"chosen":
letter}` shape and letter semantics, the Matching `paired` requirement in
both correct and incorrect cases, and the `_answer()` silent-failure
behavior — all read directly from `activities/grading.py`,
`activities/models.py`, `activities/views.py`,
`templates/activities/exercise.html`, and `static/js/exercises.js` in
`royalStaffing_CB01/`.

**Not independently verified**: live submission against a running instance
of the updated backend (no such environment was available in this session;
verification is limited to static source reading plus Flutter-side
regression tests asserting the exact outgoing payload matches the
contract derived from that reading).

## Git status check

Confirmed via `git status --short` in `Mobile_app/` that only the files
listed above (plus pre-existing Phase 13/14/15 uncommitted work, preserved
untouched) show as modified/untracked. Both Django trees
(`Career_Buddy_LMS/` and `royalStaffing_CB01/`) were confirmed untouched —
file modification timestamps on every Django file read this phase predate
2026-10-13, and `Career_Buddy_LMS/`'s own pre-existing uncommitted changes
(unrelated to this phase) were left exactly as found.

---

Phase 16 is complete. Stopping here per instruction — awaiting explicit
approval before beginning Phase 17 or any other phase.
