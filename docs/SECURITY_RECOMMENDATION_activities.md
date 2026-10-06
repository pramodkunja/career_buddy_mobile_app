# Security recommendation: Activities exercise-submission gaps

**Status: documented only. Nothing in this document has been implemented.**
No grading behavior, access checks, or database constraints have been
changed. This is a standalone write-up for review/approval, deliberately
kept separate from the read-only browsing APIs built in this phase (which
touch none of the code below).

Found during backend inspection (`activities/views.py`) while planning the
mobile Learning Activities module. All five items were discovered by
reading the actual current code, not inferred.

---

## 1. `submit_exercise()` — no `_can_access_activity()` check

**File:** `activities/views.py`, `submit_exercise(request, exercise_pk)`

**Current behavior:** Decorated with `@login_required` and `@require_POST`
only. Every other view that touches an `Exercise` (`exercise_detail`,
`analyze_speaking`/`writing`/`listening`/`reading` via
`_module_access_denied`) calls `_can_access_activity(request.user, activity)`
before proceeding. `submit_exercise` does not — it loads the `Exercise` via
`get_object_or_404` and goes straight to processing the submission.

**Security impact:** A logged-in Free-plan user can `POST` directly to
`/activities/exercise/<pk>/submit/` for an exercise belonging to a locked,
paid activity and have it accepted — the paywall enforced on every GET page
is not enforced on the one endpoint that actually writes data. For the
`writing`/`timer` exercise types this also means a Free user can trigger a
paid Sarvam AI call (via the same view) without the plan check that its
sibling `analyze_*` endpoints already perform.

**Minimal safe correction:** Add the same check already used elsewhere:
```python
exercise = get_object_or_404(Exercise, pk=exercise_pk)
activity = exercise.sub_activity.activity
if not _can_access_activity(request.user, activity):
    return JsonResponse({'success': False, 'data': {}, 'error': 'This activity requires an upgrade to access.'}, status=403)
```
placed right after the existing `get_object_or_404`, mirroring
`_module_access_denied`'s exact response shape for consistency with the
endpoints that already do this correctly.

**Required regression tests:** a Free-plan user submitting to a locked
activity's exercise gets 403 and no `UserExerciseResult` row is created; a
Free-plan user submitting to their one accessible (claimed) activity still
succeeds unchanged; a Normal/Pro user's submissions are unaffected.

**Compatibility impact:** None expected for legitimate use — every
currently-working submission flow already passes through a page that
performed this same check to get there. The only behavior that changes is
a direct, out-of-band POST to a locked exercise's submit URL, which was
never a supported path.

---

## 2. `mark_sub_complete()` — no `_can_access_activity()` check

**File:** `activities/views.py`, `mark_sub_complete(request, sub_pk)`

**Current behavior:** `@login_required` + `@require_POST` only:
```python
sub = get_object_or_404(SubActivity, pk=sub_pk)
progress, _ = UserProgress.objects.get_or_create(user=request.user, sub_activity=sub)
progress.mark_completed()
```
No ownership/plan check at all.

**Security impact:** Any logged-in user can mark any sub-activity —
including one under a locked, paid activity, or one belonging to an
activity they've never opened — as completed, with no exercises attempted.
This inflates the completion counts shown on the dashboard/activity list
for content the user never actually engaged with, and bypasses the paywall
in the same way as #1.

**Minimal safe correction:**
```python
sub = get_object_or_404(SubActivity, pk=sub_pk)
if not _can_access_activity(request.user, sub.activity):
    return JsonResponse({'success': False, 'data': {}, 'error': 'This activity requires an upgrade to access.'}, status=403)
```
(This view's only caller is a real `<form>` POST from `sub_activity.html`,
so the response on denial should redirect with a Django `messages` error for
the HTML path — the JSON shape above is only illustrative of the check
itself, not the response format, since this view currently renders HTML on
success too.)

**Required regression tests:** Free-plan user cannot mark a locked
sub-activity complete (check is enforced, `UserProgress.status` stays
unchanged); existing "mark complete" flow for an accessible sub-activity
is unaffected.

**Compatibility impact:** None for the documented UI flow (the "Mark
Complete" button only ever appears on a sub-activity page the user could
already open, which already implies access). Only closes an out-of-band gap.

---

## 3. `submit_exercise()` trusts client-submitted `score`/`max_score`

**File:** `activities/views.py`, `submit_exercise(request, exercise_pk)`

**Current behavior:**
```python
score = data.get('score', 0)
max_score = data.get('max_score', 0)
```
used as-is for `mcq`, `fill_blank`, `matching`, `ordering`, `bingo`, and for
`writing`/`timer` whenever `settings.SARVAM_API_KEY` is unset — no
server-side recomputation from `Question.correct_answer` for any of these.
This is consistent with the page design (the correct answer is shipped to
the client in `exercise_detail`'s rendered HTML before submission), not an
isolated oversight — grading is intentionally client-side for these types.

**Security impact:** Any authenticated user can submit an arbitrary score
(e.g. `{"score": 999999, "max_score": 1}`) for any accessible exercise, with
no bound. This inflates their own progress/dashboard totals; combined with
#1 above, it can also apply to activities they shouldn't have access to at
all.

**Minimal safe correction:** This is the one item that is **not** a small,
isolated patch — genuinely fixing it means either (a) recomputing
score/max_score server-side from `exercise.questions` and the submitted
`answers` for each of the 5 affected types (real new grading logic per
type, non-trivial), or (b) at minimum clamping `max_score` to a
server-known value (e.g. `exercise.questions.count()`) and `score` to
`[0, max_score]` as a partial mitigation that doesn't fully re-grade but
removes the "arbitrary large number" class of abuse. Recommend treating
this as its own scoped decision — it changes grading behavior, which is
explicitly out of this phase and needs its own sign-off, not a bundled fix.

**Required regression tests (once a direction is chosen):** submitting a
score/max_score outside a valid range is rejected or clamped; a correctly
client-graded submission for each of the 5 types still records the same
score as today (no behavior change for legitimate use); existing
`UserExerciseResult` rows and dashboard totals for already-submitted
attempts are unaffected (this is a forward-only fix, not a data migration).

**Compatibility impact:** Potentially larger than #1/#2 — any fix here
changes what value ends up in `UserExerciseResult.score` for real users
going forward, so it needs careful review of exactly which mitigation
(recompute vs. clamp) before implementation, and is intentionally **not**
proposed as a concrete diff here.

---

## 4. `UserExerciseResult` has no limit on duplicate attempts

**File:** `activities/models.py` (`UserExerciseResult`, no `unique_together`
or constraint on `(user, exercise)`), `activities/views.py`
(`submit_exercise` always does `.objects.create(...)`, never an update).

**Current behavior:** Every submission — regardless of how many already
exist — creates a new row. `_build_dashboard_context`'s `total_score`
(views.py) sums **every** row a user has ever created, not deduplicated per
exercise and not limited to a best/latest attempt.

**Security impact:** Combined with #3, a user can repeatedly POST to
inflate their dashboard `total_score` without bound, simply by resubmitting
the same exercise. Even independent of #3 (i.e. even with legitimately
server-graded scores), repeated resubmission still double/triple-counts a
score that was already earned once.

**Minimal safe correction:** Two independent, non-mutually-exclusive
options: (a) at the submission view, reject a resubmission within some
cool-down, or cap total attempts per exercise (there is currently no
concept of an attempt limit anywhere in this app — would be a new rule, not
a bug fix, and should be confirmed against intended product behavior
first — "retry to improve your score" is explicit product copy in
`sub_activity.html`'s Learning Tips, so *some* resubmission is clearly
intended); (b) at the dashboard/aggregation layer, sum only the
**latest** (or **best**) `UserExerciseResult` per `(user, exercise)` rather
than every row ever created — this is the safer, more surgical fix since it
doesn't touch the submission flow's intended "retry" behavior at all, only
how totals are aggregated. Recommend (b) as the smaller, lower-risk
correction, kept separate from any decision about (a).

**Required regression tests:** a user with 3 resubmissions of the same
exercise shows a dashboard total reflecting only the latest/best attempt,
not the sum of all 3; a user with attempts across multiple different
exercises still gets each one counted once.

**Compatibility impact:** Changes the displayed `total_score` for any
existing user who has ever resubmitted an exercise (likely a downward
correction for some users) — worth flagging to product/support before
shipping, since it's a visible number changing, not just an internal fix.

---

## 5. Completion-rate logic is implemented three separate times

**Files:** `Activity.get_completion_rate()` (models.py),
`_build_dashboard_context()` (views.py, dashboard), `activity_list()`
(views.py, inline in the per-activity loop) — and now, as of this phase, a
4th call site exists via the new read-only APIs, but those explicitly
**reuse** the existing implementations (see §5/§6 of
`BACKEND_CONTRACT_activities.md`) rather than adding a new one, per this
phase's instructions.

**Current behavior:** Three independently-maintained implementations of
"is this sub-activity/activity done", which happen to currently agree, but
have already drifted once in spirit — `activity_list`'s inline version is
workshop-aware (uses `ScoreRecord`-based scores for GD/JAM/Roleplay
activities); `Activity.get_completion_rate()` (used by `activity_detail`)
is **not** workshop-aware and returns 0% for a workshop activity regardless
of the user's actual score. This is not a security issue, but it is an
existing, live inconsistency between what the activity list page and the
activity detail page show for the same workshop activity today.

**Security impact:** None directly — this is a correctness/consistency
concern, included here because it was found during the same investigation
and is relevant to anyone touching this code next.

**Minimal safe correction:** Not proposed here — deciding which of the two
behaviors ("detail page's workshop rate should also reflect
`ScoreRecord`" vs "list page should stop being workshop-aware for
consistency") is a product decision, not a security fix, and is out of
scope for this document. Flagging only so it isn't mistaken for something
this phase silently resolved.

**Required regression tests:** N/A until a direction is chosen.

**Compatibility impact:** N/A until a direction is chosen.
