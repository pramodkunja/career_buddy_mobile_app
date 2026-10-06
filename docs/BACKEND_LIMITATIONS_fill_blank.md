# W007 — Fill in the Blank: web behavior and why it can't be built in Flutter yet

This documents the actual web implementation (read from source, not assumed)
and explains precisely why the Fill in the Blank exercise cannot be
implemented as a real interactive Flutter screen without a backend change —
which this task's instructions explicitly forbid making. No Django/web file
was modified to produce this document.

## The genuine gap: no JSON API exposes question content

Every `*_api` view in `activities/views.py` was read directly:
`dashboard_api`, `activity_list_api`, `activity_detail_api`,
`sub_activity_detail_api`, `mcq_exercise_api`, `submit_mcq_exercise_api`.

Only the last two expose per-question content (question text, correct
answer, explanation) — and `_mcq_exercise_or_error` (`activities/views.py`)
explicitly rejects any exercise whose `exercise_type != 'mcq'` with a 400
("This exercise type isn't supported yet."). `sub_activity_detail_api`'s
per-exercise JSON is only `{id, title, exercise_type, exercise_type_display,
order, last_attempt}` — no question list.

The **only** place Fill in the Blank question content exists in a
machine-readable form is the `questions_json` context variable
`exercise_detail()` builds and embeds as a `<script type="application/json">`
tag inside the server-rendered `exercise.html` page
(`activities/views.py:1389-1403`) — not a callable API, HTML markup a
browser parses after receiving the full page.

Per this task's explicit instruction ("Do NOT create a new backend API just
because the existing web action is inconvenient... If Flutter cannot use the
existing action: document why; do not modify Django"), no new endpoint was
added. This is why W007 could not become a real question-answering screen
this phase.

## What the web actually does (for a future implementation)

Source: `templates/activities/exercise.html` (the `fill_blank` branch,
lines 184-212) and `static/js/exercises.js` (`initFillBlank`,
`submitScore`, `showResultPanel`).

### Structure
- **All questions on one page** — not one-at-a-time like MCQ. Each question
  is its own `.fill-question-card`: a number (`Question {{ forloop.counter }}`),
  the question text, one text `<input>`, and a per-question "Check" button.
- **No progress bar and no question counter** for this exercise type — the
  `#q-progress-bar`/`#current-q`/`#score-display` elements `updateProgress()`
  updates only exist in the MCQ branch's markup; fill_blank's DOM has none
  of them. A Flutter screen should not invent a progress bar the web itself
  doesn't have here.
- **No `exercise.instructions` shown anywhere** on this page, for any
  exercise type — confirmed by grep; not a fill_blank-specific omission.

### Answer interaction and validation
- One text input per question, `autocomplete="off"`, placeholder "Type your
  answer here...".
- Clicking **Check** (per-question, not a single global submit for grading):
  - Empty (after `.trim()`) → inline error "Please enter an answer first.",
    input stays enabled, does not count toward "checked".
  - Non-empty → **the input and the Check button are both disabled** (locked
    after checking — cannot be edited or re-checked).
  - Grading rule: `given.trim().toLowerCase() === correct.trim().toLowerCase()`
    — exact match after trim + lowercase. No partial credit, no multiple
    accepted answers, no punctuation normalization.
  - Correct → green "Correct!". Incorrect → red "Incorrect. Correct answer:
    **{correct}**" — **the correct answer is revealed inline on a wrong
    answer**, and the question's `explanation` (if any) is also revealed at
    that point (`fill-hint-N`, shown regardless of correct/incorrect).
  - The correct answer is already present in the page's DOM before checking
    (`data-correct` attribute + `QUESTIONS_DATA`) — a pre-existing
    characteristic of the web's own implementation, not something this
    document is flagging as new.
- **Submit All Answers** (bottom of page, `#submit-fill`) is disabled until
  every question has been checked (`checkedCount === inputs.length`) — not
  until every answer is *correct*, just until every one has been checked.

### Submission (the mechanism, for reference — not called by Flutter this phase)
- `POST` to `{% url 'submit_exercise' exercise.pk %}` (already-existing,
  generic, JSON-in/JSON-out endpoint — not MCQ-specific).
- Headers: `Content-Type: application/json`, `X-CSRFToken: {{ csrf_token }}`.
- Body: `{"score": <client-computed int>, "max_score": <total questions>,
  "answers": {"1": {"given": "...", "correct": "...", "result":
  "correct"|"wrong"}, "2": {...}, ...}}` — keys are 1-based question
  *position* strings, matching the page's own numbering, not a database id.
- **`submit_exercise` (`activities/views.py:1413-1526`) trusts the
  client-submitted `score`/`max_score` verbatim for `fill_blank`** (it only
  re-derives the score server-side for `writing`/`timer` types, via an AI
  call) — confirmed by reading the view; this is a pre-existing
  characteristic of the web app, already documented separately in
  `docs/SECURITY_RECOMMENDATION_activities.md` from an earlier phase, not
  something introduced by this task.
- Response: `{"status": "ok", "score", "max_score", "percentage",
  "attempt", "customSummaryHtml"}`. The client prefers the server's echoed
  score/max_score if present, but they're always identical to what was sent
  for this exercise type.
- Side effect: creates a `UserExerciseResult` row (`attempt_number` =
  count-so-far + 1) and, if this was the sub-activity's last remaining
  exercise, marks the `UserProgress` row `completed`; otherwise
  `in_progress`.

### Result state
- Shared `showResultPanel()` (used by every exercise type, not
  fill_blank-specific): a **6-tier qualitative message** by percentage —
  100 → "Perfect Score!" 🏆, ≥90 → "Excellent!" 🌟, ≥80 → "Very Good!" ✨,
  ≥60 → "Good Job!" 👍, ≥40 → "Average" 💪, else → "Keep Practising" 📚 —
  plus `"You scored {score} out of {max_score} ({pct}%)"`.
- **Try Again**: `onclick="location.reload()"` — a full page reload, not a
  dedicated reset action. Every input/checked-state/score resets because
  the page is rebuilt from scratch.
- **Back to Sub-Activity**: link to `sub_activity_detail`.
- **Previous Score sidebar**: shows only the single most recent attempt's
  `score`/`max_score` (`all_attempts.0`, ordered `-completed_at`) — "No
  attempts yet." if none. No percentage shown here, no full attempt
  history list, despite `all_attempts` (the full list) being available in
  the view's own context.

## What Flutter does instead this phase

`ExerciseTile` is tappable for every exercise type. For `mcq`, it navigates
to the existing, real MCQ flow. For every other type (fill_blank included),
tapping opens the existing `ComingSoonScreen` (already used for
Registration/Password Reset/Employer Login/Job Detail/Pro placeholders)
with a message naming the real exercise type
(`exercise.exerciseTypeDisplay`, already-available data — not invented):
*"Fill in the Blank exercises aren't available in the app yet. Please
practice this exercise on the Career Buddy website for now."*

This is honest (never claims to grade a real question), uses zero invented
data, and reuses existing shared UI — it does not fabricate a fill-blank
exercise screen with fake or hardcoded content, which the task's
instructions explicitly forbid.

The exercise's **last-attempt score/percentage** (from
`sub_activity_detail_api`'s existing `last_attempt` field, already wired
since W005) continues to display correctly for fill_blank exercises too —
that part of the data pipeline is exercise-type-agnostic and was already
functional.
