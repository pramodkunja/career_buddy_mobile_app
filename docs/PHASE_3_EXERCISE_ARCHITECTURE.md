# Phase 3 — Secure MCQ Exercise Architecture

**Status: implemented for MCQ only.** fill_blank/matching/bingo/ordering/
writing/timer/AI modules/roleplay/quiz-bank are explicitly out of scope —
see `SECURITY_RECOMMENDATION_activities.md` and
`BACKEND_CONTRACT_activities.md` for the prior phases this builds on.

## 1. Existing behavior (verified by reading the actual code, not assumed)

### `exercise_detail` (`activities/views.py:1157-1236`), GET, `@login_required`

Gates access via `_can_access_activity()` (line 1161, redirects on failure —
see `SECURITY_RECOMMENDATION_activities.md` §1 for why this pattern needs
to be a clean 403 for a JSON API instead). For the default (non-AI-module)
flow, it builds `questions_json` (lines 1217-1231):
```python
'options': {'a': q.option_a, 'b': q.option_b, 'c': q.option_c, 'd': q.option_d},
'correct': q.correct_answer,
'explanation': q.explanation,
```
**The correct answer and explanation are shipped to the browser before the
user answers** — confirmed both here and in the rendered template
(`templates/activities/exercise.html:139-165`, each option button carries
`data-correct="{{ question.correct_answer }}"` and
`data-explanation="{{ question.explanation }}"`).

### MCQ answer format (verified against the actual comparison code)

`templates/activities/exercise.html:139-165`: each option button has
`data-option="a"` (or b/c/d) and `data-correct="{{ question.correct_answer }}"`.
`static/js/exercises.js:130-144`:
```js
const chosen = this.dataset.option;   // 'a' | 'b' | 'c' | 'd'
const correct = this.dataset.correct; // Question.correct_answer, verbatim
...
if (chosen === correct) { ... }
```
This strict-equality comparison only works if `Question.correct_answer` is
stored as a **lowercase single letter** (`'a'`/`'b'`/`'c'`/`'d'`) matching
the template's `data-option` values — confirmed by this being the only way
the comparison could ever succeed, since `data-option` is a template
literal, never user data. (No MCQ `Question` rows exist in this dev
database to sample directly — confirmed via `Activity.objects.count() == 0`,
`Question.objects.count() == 0` — so this is derived from reading the
comparison logic itself, not from live data. Documented as such rather than
asserted as directly observed.)

`Question.correct_answer` (`activities/models.py:131-152`) is a generic
`CharField` reused across exercise types with different meaning per type —
for `fill_blank` it holds free text (compared case-insensitively,
`exercises.js:211`), for `matching`/`ordering` something else entirely. This
architecture only interprets it for `exercise_type == 'mcq'`.

### `submit_exercise` (`activities/views.py:1241-1354`), POST, `@login_required @require_POST`

```python
score = data.get('score', 0)
max_score = data.get('max_score', 0)
```
Used verbatim for `mcq` (and 4 other types) — this is the client-trust gap
`SECURITY_RECOMMENDATION_activities.md` §3 documents. **Left completely
untouched by this phase** (see §2 below for why).

Persistence pattern (lines 1325-1345), replicated exactly by the new
endpoint:
```python
attempt = UserExerciseResult.objects.filter(user=request.user, exercise=exercise).count() + 1
result = UserExerciseResult.objects.create(
    user=request.user, exercise=exercise, score=score, max_score=max_score,
    answers_json=answers, attempt_number=attempt,
)
if exercise.sub_activity:
    progress, _ = UserProgress.objects.get_or_create(user=request.user, sub_activity=exercise.sub_activity)
    if exercise.sub_activity.all_exercises_done(request.user):
        progress.mark_completed()
    else:
        progress.mark_started()
```
Response: `{status, score, max_score, percentage, attempt, customSummaryHtml}`.

### Attempts (verified, unchanged by this phase)

- **Numbering:** `count() + 1` at write time — not a stored running counter.
  If an attempt were ever deleted (via `delete_attempt`), a later submission
  could reuse a number a still-existing row already has. This is existing
  behavior, not something introduced or fixed here.
- **Latest result selection:** `.order_by('-completed_at').first()`
  wherever "the current/previous attempt" is needed (`exercise_detail`,
  `_sub_activity_exercise_data`).
- **What's persisted:** every attempt is a new `UserExerciseResult` row —
  no cap, no update-in-place. Previous attempts remain queryable and
  visible (`all_attempts` in `exercise_detail`'s context).
- **Not changed in this phase:** no uniqueness constraint, no attempt cap,
  no destructive migration — per explicit instruction.

### Sub-activity completion (verified, unchanged by this phase)

`SubActivity.all_exercises_done(user)` (`activities/models.py:95-110`) —
true once the user has at least one `UserExerciseResult` for every exercise
in the sub-activity, regardless of score. The new endpoint calls this exact
method (imported, not reimplemented) to decide `mark_completed()` vs
`mark_started()`, identical to `submit_exercise`'s own logic. `mark_sub_complete`
(the explicit "Mark Complete" button flow) is untouched — this phase adds no
new way to mark a sub-activity complete beyond what already existed.

## 2. Security decision: new endpoint, not an upgraded `submit_exercise`

**Chosen: Option A — a new, mobile-only endpoint pair**, not a rewrite of
`submit_exercise`.

Why: `submit_exercise` is a single shared function serving **7 exercise
types** for the web, including live, working `writing`/`timer` AI-scoring
paths. `exercise.html`'s MCQ JS *already* computes and displays per-question
correct/incorrect feedback client-side, immediately, before the score is
ever POSTed — if `submit_exercise` were changed to recompute MCQ server-side
and that computation ever disagreed with what the JS already showed the
user (even from a subtle normalization difference), the web user would see
a score that contradicts the feedback they just watched happen. Changing
shared code to fix a mobile-only requirement risks that regression for a
system this phase was explicitly told to leave alone ("preserve existing
web behavior", "do not modify unrelated backend modules"). A separate
endpoint carries zero risk to the web flow — verified by running the full
existing test suite unchanged (see §10).

**Is this "duplicate grading logic"?** No — checked directly:
`submit_exercise` (and everything upstream of it) performs **zero**
server-side comparison against `Question.correct_answer` for MCQ today; it
only ever trusts the client's number. The new endpoint's grading helper
(`_grade_mcq_answers`, `activities/views.py`) is therefore the **first**
server-side MCQ grading logic in this codebase, not a second copy of an
existing one. It is small, single-purpose, and is the one and only place
MCQ scores are computed for this new flow.

## 3. New endpoints

- **`GET /activities/api/exercise/<int:pk>/`** — exercise + questions,
  **without** `correct_answer`/`explanation`. MCQ only this phase: any
  other `exercise_type` returns `400` (`"error": "This exercise type isn't
  supported yet."`) rather than a half-correct or empty response — building
  a generic multi-type contract now would be exactly the kind of
  unrequested placeholder work §18 rules out.
- **`POST /activities/api/exercise/<int:pk>/submit/`** — body is `{"answers":
  {"<question_id>": "<a|b|c|d>"}}` only. No `score`/`max_score`/`correct`/
  `percentage` field is ever read from the request body — grading is 100%
  server-computed from `Question.correct_answer`. Full contract in
  `BACKEND_CONTRACT_activities.md`, "Exercise submission (MCQ)" section.

Both reuse `_can_access_activity()` (imported, same function
`submit_exercise` should but doesn't yet use — see
`SECURITY_RECOMMENDATION_activities.md` §1, still unresolved and
**deliberately not fixed by this phase** for the *existing* endpoint, but
correctly enforced from the start on these *new* ones) and both return a
clean `401`/`403`/`404` JSON error rather than an HTML redirect, matching
the `dashboard_api`/`activity_list_api` precedent already established in
this codebase.

## 4. What Flutter never sends

Verified by construction: the request-model/datasource code for the new
submission call has no field for score, max_score, correct, or percentage —
there is nothing to send even by mistake. The server also does not read
any such key from the request body if one were present (unlike
`submit_exercise`, which does `data.get('score', 0)`).
