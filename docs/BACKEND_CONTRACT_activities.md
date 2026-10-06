# Backend contract: Learning Activities

**Status: implemented.** Sections A-C (browsing) and D (MCQ exercise) all
exist and are covered by tests — see each section for the exact test file.
Sections A-C reuse the exact same queries/business logic as their HTML
counterparts (`activity_list()`, `activity_detail()`, `sub_activity_detail()`)
via shared helper functions (`_activity_list_data`, `_subs_with_status`,
`_sub_activity_exercise_data`) — no completion-rate or access logic was
recomputed a fourth time. Section D is genuinely new server-side MCQ
grading logic — see `PHASE_3_EXERCISE_ARCHITECTURE.md` for why it's a
separate implementation from the existing (client-trusted)
`submit_exercise`.

Sections A-C are read-only browsing; section D is the first (and, this
phase, only) exercise type with real submission — fill_blank, matching,
bingo, ordering, writing, timer, AI modules, roleplay, and quiz-bank remain
out of scope. See `SECURITY_RECOMMENDATION_activities.md` for the
still-unresolved write-path concerns on the *existing* `submit_exercise`/
`mark_sub_complete` endpoints, which this phase does not touch.

## Response envelope

All three endpoints use:
```json
{"success": true, "data": {...}, "meta": {...}}
```
on success, and on failure:
```json
{"success": false, "data": {}, "error": "<message>"}
```
This is a **new convention for this phase** — `dashboard_api()` (built
earlier) predates it and returns a flat object; it was not retrofitted,
since that would break the already-shipped Flutter dashboard. The error
shape (`{"success": false, "data": {}, "error": ...}`) matches the one
already used by `_module_access_denied()` elsewhere in `activities/views.py`.

## Common responses across all three endpoints

- **Unauthorized** (not logged in): `401`, `{"success": false, "data": {}, "error": "Not authenticated"}`. Checked explicitly (not via `@login_required`) so a JSON client never sees a login-page redirect mistaken for success — same reasoning as `dashboard_api()`.
- **Permission denied** (employer session): `403`, `{"success": false, "data": {}, "error": "Not permitted"}`.
- **Not found**: `404`, `{"success": false, "data": {}, "error": "Not found"}`.
- **Locked** (plan doesn't allow this activity): `403`, `{"success": false, "data": {}, "error": "This activity requires an upgrade to access."}` — same message `_module_access_denied()` already uses.
- Auth: Django session cookie, exactly as every other endpoint (no JWT, nothing new).
- CSRF: not required — all three are `GET` only (`@require_GET`).
- Pagination: none. None of the source views paginate either (an activity's own sub-activity/exercise counts are small; the full activity catalogue is returned in one response, matching `activity_list()`).

---

## A. `GET /activities/api/`

**Purpose:** Activity list — mirrors `activity_list()` (`activities/views.py`), category filter included.
**Auth:** required (see above).
**Method:** `GET`. **URL:** `/activities/api/` (trailing slash required, matches Django's `APPEND_SLASH` convention used everywhere else in this project).
**Query parameters:** `category` (optional, string) — one of `Activity.CATEGORY_CHOICES`' values (`speaking`, `writing`, `vocabulary`, `negotiation`, `communication`, `analysis`, `workshop`). Ignored for Free-plan users, who only ever see the fixed Free-plan catalogue regardless of this parameter (same as the web).
**Source view/query:** `_activity_list_data()`, extracted from and used by both `activity_list()` and this endpoint — identical queryset, filtering, and per-activity completion-rate rule (including the workshop-score-aware branch for GD/JAM/Roleplay activities).

### Response (`200`)
```json
{
  "success": true,
  "data": {
    "activities": [
      {
        "id": 12,
        "title": "Business Vocabulary Building Games",
        "description": "Learn and practice essential business vocabulary...",
        "category": "vocabulary",
        "category_display": "Vocabulary & Idioms",
        "level": "Intermediate",
        "duration": "30 min",
        "is_locked": false,
        "completion_rate": 60,
        "is_completed": false
      }
    ],
    "categories": [
      {"value": "speaking", "label": "Speaking & Presentation"}
    ],
    "selected_category": "",
    "is_free_preview": false,
    "total_activities": 20
  },
  "meta": {"count": 20}
}
```

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `data.activities[].id` | int | no | `Activity.id` |
| `.title` | string | no | `Activity.title` |
| `.description` | string | no | `Activity.objective` — the web card's description text is `objective`, not a separate `description` field; named `description` here for a clearer wire contract, sourced from `objective` |
| `.category` | string | no | raw `Activity.category` value |
| `.category_display` | string | no | `Activity.get_category_display()` |
| `.level` | string | no | `Activity.level` |
| `.duration` | string | no | `Activity.duration` |
| `.is_locked` | bool | no | `not _can_access_activity(user, activity)` |
| `.completion_rate` | int (0-100) | no | same rule as the web list page (workshop-aware) |
| `.is_completed` | bool | no | `completion_rate == 100` |
| `data.categories[]` | array of `{value, label}` | no | `Activity.CATEGORY_CHOICES`, for building filter UI |
| `data.selected_category` | string | no | echoes the `category` query param (`""` if none) |
| `data.is_free_preview` | bool | no | true when the requesting user is on the Free plan |
| `data.total_activities` | int | no | count of all active activities (unaffected by the category filter — matches the web header's live count) |
| `meta.count` | int | no | length of `data.activities` (i.e. the *filtered* count) |

**Empty state:** a `category` with no matching activities (or, in principle, zero active activities at all) returns `200` with `"activities": []` — not an error. Verified by test.

**Not implemented / intentionally omitted:** text/keyword search (the web has none — do not add it without separately confirmed scope); `direct_url` (a Django-`reverse()`'d path, meaningless to a mobile router).

---

## B. `GET /activities/api/<id>/`

**Purpose:** Activity detail + its sub-activities — mirrors `activity_detail()`.
**Auth:** required.
**Method:** `GET`. **URL:** `/activities/api/<int:id>/`.
**Query parameters:** none.
**Source view/query:** `_subs_with_status()`, extracted from and used by both `activity_detail()` and this endpoint, plus `Activity.get_completion_rate(user)` (the **non**-workshop-aware method — see note below).
**Side effect (parity with the web page):** a successful `GET` calls `_claim_free_activity()`, exactly as opening the web page does — for a Free-plan user, viewing an activity in their catalogue for the first time spends their one free slot.

### Response (`200`)
```json
{
  "success": true,
  "data": {
    "id": 12,
    "title": "Business Vocabulary Building Games",
    "description": "Learn and practice essential business vocabulary...",
    "category": "vocabulary",
    "category_display": "Vocabulary & Idioms",
    "level": "Intermediate",
    "duration": "30 min",
    "is_workshop": false,
    "is_module": false,
    "completion_rate": 50,
    "sub_activities": [
      {
        "id": 34,
        "title": "Common Business Terms",
        "description": "...",
        "order": 1,
        "status": "in_progress",
        "exercise_count": 2,
        "started_at": "2026-09-01T10:00:00Z",
        "completed_at": null
      }
    ]
  },
  "meta": {"sub_activity_count": 3}
}
```

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `data.id`/`.title`/`.category`/`.category_display`/`.level`/`.duration` | — | no | same as list |
| `.description` | string | no | `Activity.objective` |
| `.is_workshop` | bool | no | `is_workshop_activity(activity)` — the web page **redirects** to a dedicated GD/JAM/Roleplay app for these instead of showing sub-activities; this endpoint still returns real data, flagged with this boolean, since exercise-taking (including workshops) is out of scope this phase either way |
| `.is_module` | bool | no | `is_module_activity(activity)` — the web page skips straight to `exercise_detail` for these; same reasoning as above |
| `.completion_rate` | int (0-100) | no | `Activity.get_completion_rate(user)` — **note:** this is a *different* calculation than the list endpoint's for workshop activities (it has no `ScoreRecord` awareness and returns 0% for GD/JAM/Roleplay regardless of actual score). This is an existing inconsistency between the web's own list and detail pages, faithfully preserved here rather than silently "fixed" — see `SECURITY_RECOMMENDATION_activities.md` §5. |
| `data.sub_activities[].status` | string | no | one of `not_started` / `in_progress` / `completed` |
| `.exercise_count` | int | no | `len(sub.exercises.all())` |
| `.started_at`/`.completed_at` | ISO-8601 string | yes | from the user's `UserProgress` row for that sub-activity, `null` if none yet |

**Empty state:** an activity with zero sub-activities returns `"sub_activities": []` (the web template has no explicit empty-state message for this case either — preserved as-is, not invented).
**Not found:** `id` not matching any active `Activity` → `404`.
**Locked:** → `403` (see common responses).

**Not implemented / intentionally omitted:** `Question`/`BingoCard` content, `correct_answer`, any grading data — exercise content is entirely out of scope for this phase (see endpoint C for exactly what a mobile client gets about exercises: summaries + last score only).

---

## C. `GET /activities/api/sub/<id>/`

**Purpose:** Sub-activity detail + its exercises' summaries and last scores — mirrors `sub_activity_detail()`.
**Auth:** required.
**Method:** `GET`. **URL:** `/activities/api/sub/<int:id>/` — note this takes only the sub-activity's own id, unlike the web's nested `<activity_pk>/sub/<sub_pk>/` path; the parent activity is derived from `sub.activity` (a mobile client reaching this screen already has the id from endpoint B's response and doesn't need to also pass a redundant activity id).
**Query parameters:** none.
**Source view/query:** `_sub_activity_exercise_data()`, extracted from and used by both `sub_activity_detail()` and this endpoint.
**Side effects (parity with the web page):** a successful `GET` calls `_claim_free_activity()` **and** `UserProgress.mark_started()` unconditionally — exactly as opening the web page does. **This means `status` in the response is never `"not_started"` once you've called this endpoint even once** — the first GET itself flips it to at least `in_progress`, same as visiting the web page does. (Verified by test; documented so it isn't mistaken for a bug.)

### Response (`200`)
```json
{
  "success": true,
  "data": {
    "id": 34,
    "title": "Common Business Terms",
    "description": "...",
    "instructions": "...",
    "order": 1,
    "activity": {"id": 12, "title": "Business Vocabulary Building Games"},
    "status": "in_progress",
    "started_at": "2026-09-01T10:00:00Z",
    "completed_at": null,
    "all_exercises_done": false,
    "exercises": [
      {
        "id": 56,
        "title": "Vocabulary Quiz",
        "exercise_type": "mcq",
        "exercise_type_display": "Multiple Choice",
        "order": 1,
        "last_attempt": {
          "score": 8,
          "max_score": 10,
          "percentage": 80,
          "attempt_number": 1,
          "completed_at": "2026-09-05T09:00:00Z"
        }
      },
      {
        "id": 57,
        "title": "Fill in the Blanks",
        "exercise_type": "fill_blank",
        "exercise_type_display": "Fill in the Blank",
        "order": 2,
        "last_attempt": null
      }
    ]
  },
  "meta": {"exercise_count": 2}
}
```

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `data.id`/`.title`/`.order` | — | no | `SubActivity` fields |
| `.description` | string | no | `SubActivity.description` |
| `.instructions` | string | no | `SubActivity.instructions` |
| `.activity` | object `{id, title}` | no | parent activity reference only — not the full activity payload (fetch endpoint B for that) |
| `.status` | string | no | `not_started` / `in_progress` / `completed` — see side-effect note above |
| `.started_at`/`.completed_at` | ISO-8601 string | yes | from `UserProgress` |
| `.all_exercises_done` | bool | no | every exercise in this sub-activity has at least one `UserExerciseResult` |
| `data.exercises[].id`/`.title`/`.order` | — | no | `Exercise` fields |
| `.exercise_type` | string | no | raw value, one of `mcq`/`fill_blank`/`matching`/`ordering`/`bingo`/`writing`/`timer` |
| `.exercise_type_display` | string | no | `Exercise.get_exercise_type_display()` |
| `.last_attempt` | object or `null` | yes | `null` if the user has never submitted this exercise |
| `.last_attempt.score`/`.max_score`/`.attempt_number` | int | no | from the most recent `UserExerciseResult` (`-completed_at`) |
| `.last_attempt.percentage` | int (0-100) | no | `UserExerciseResult.percentage` property |
| `.last_attempt.completed_at` | ISO-8601 string | no | — |

**Cross-user isolation:** `last_attempt` is always scoped to `UserExerciseResult.objects.filter(user=request.user, ...)` — verified by test that a different user's attempts never appear.
**Empty state:** a sub-activity with zero exercises returns `"exercises": []`.
**Not found:** `id` not matching any `SubActivity` → `404`.
**Locked:** if the parent activity isn't accessible → `403`.

**Not implemented / intentionally omitted (deliberately, per this phase's scope):** `Question` rows, `BingoCard` rows, `correct_answer`, `explanation`, `answers_json`, `result_data` — none of this is returned. Getting an exercise's actual question content is out of scope until the exercise-taking phase, whose API design depends on the still-open decision in `SECURITY_RECOMMENDATION_activities.md` (client-graded parity vs. server-side grading).

---

## D. MCQ exercise (server-authoritative grading) — Phase 3

Full architecture rationale in `PHASE_3_EXERCISE_ARCHITECTURE.md`. Two
endpoints, MCQ (`exercise_type == 'mcq'`) only — any other type gets `400`.
Tests: `activities/tests_mcq_exercise_api.py` (20 tests).

### D1. `GET /activities/api/exercise/<int:id>/`

**Purpose:** exercise + questions for the mobile exercise-taking screen,
**without** the answer key.
**Auth:** required. Same `_can_access_activity()` check as sections B/C —
locked → `403`.
**Method:** `GET`. **Query parameters:** none.
**Source:** `mcq_exercise_api()` / `_mcq_exercise_or_error()`
(`activities/views.py`) — a **new** view, since `exercise_detail()` (the
HTML page) embeds `correct_answer`/`explanation` directly in its response
(verified in `PHASE_3_EXERCISE_ARCHITECTURE.md` §1) and can't be reused
as-is for a pre-submission JSON contract.

```json
{
  "success": true,
  "data": {
    "exercise": {"id": 56, "title": "Vocabulary Quiz", "exercise_type": "mcq", "instructions": "Pick the best answer.", "order": 1},
    "sub_activity": {"id": 34, "title": "Common Business Terms"},
    "activity": {"id": 12, "title": "Business Vocabulary Building Games"},
    "questions": [
      {"id": 123, "question_text": "What is the synonym of 'concise'?", "options": {"a": "Brief", "b": "Long", "c": "Vague", "d": "Complex"}, "order": 1}
    ]
  },
  "meta": {"question_count": 1}
}
```

| Field | Type | Notes |
|---|---|---|
| `data.exercise.*` | — | `Exercise` fields, same shape as section C's exercise summary plus `instructions` |
| `data.sub_activity`/`data.activity` | `{id, title}` | parent references only |
| `data.questions[].id`/`.question_text`/`.order` | — | `Question` fields |
| `data.questions[].options` | object | only the option keys (`a`-`d`) whose `Question.option_*` field is non-empty — **no `correct_answer`, no `explanation`** (verified by test: response body never contains those keys or their values) |

**Non-MCQ exercise:** `400`, `{"success": false, "data": {}, "error": "This exercise type isn't supported yet."}`.
**Not found / locked / unauthenticated:** same as sections A-C.

### D2. `POST /activities/api/exercise/<int:id>/submit/`

**Purpose:** server-authoritative MCQ grading + persistence.
**Auth:** required, same access check as D1.
**Method:** `POST`, JSON body. CSRF: standard Django session CSRF applies
(no `@csrf_exempt`) — same pattern already used for `/users/login/`.
**Source:** `submit_mcq_exercise_api()` / `_grade_mcq_answers()`
(`activities/views.py`) — reuses `submit_exercise`'s exact persistence
pattern (`UserExerciseResult.objects.create`, attempt numbering via
`.count() + 1`, `UserProgress`/`all_exercises_done()` side effect) but
computes `score`/`max_score` itself instead of trusting the request body.

**Request:**
```json
{"answers": {"123": "a", "124": "d"}}
```
Keys are `str(Question.id)`; values are a lowercase option letter
(`a`/`b`/`c`/`d`) — the same representation `Question.correct_answer`
itself stores and the same one the web's own JS compares
(`PHASE_3_EXERCISE_ARCHITECTURE.md` §1). **No `score`, `max_score`,
`correct`, or `percentage` field is read from the request body even if
present** — verified by test (`test_client_supplied_fake_score_is_ignored`,
`test_persisted_result_contains_server_calculated_values`).

**Response (`200`):**
```json
{
  "success": true,
  "data": {
    "exercise_id": 56,
    "score": 1,
    "max_score": 2,
    "percentage": 50,
    "attempt_number": 2,
    "questions": [
      {"question_id": 123, "selected": "a", "correct": "a", "is_correct": true, "explanation": "..."},
      {"question_id": 124, "selected": "b", "correct": "d", "is_correct": false, "explanation": "..."}
    ]
  },
  "meta": {}
}
```

| Field | Type | Notes |
|---|---|---|
| `data.score`/`.max_score` | int | server-computed via `_grade_mcq_answers` — `max_score` is always `len(questions)`, never client-supplied |
| `.percentage` | int (0-100) | `UserExerciseResult.percentage` property |
| `.attempt_number` | int | same `.count() + 1` numbering as `submit_exercise` — see `PHASE_3_EXERCISE_ARCHITECTURE.md` §1 for its known non-monotonic-after-deletion caveat, unchanged here |
| `data.questions[].correct`/`.explanation` | — | **only ever returned here, post-submission** — never in D1 |
| `.selected` | string or `null` | the submitted letter, normalised (lowercased/trimmed); `null` if that question wasn't answered |

**Malformed body (invalid JSON, or `answers` not an object):** handled
safely — treated as `{}` (every question graded as unanswered/incorrect),
never a `500`. Verified by test.
**Not found / locked / unauthenticated / wrong exercise type:** same as D1.

**Side effect (unchanged behavior, reused not reimplemented):** on
success, `UserProgress` for the exercise's sub-activity is created/updated
and marked `completed` if `SubActivity.all_exercises_done(user)` is now
true, else `in_progress` — identical rule to `submit_exercise`.
