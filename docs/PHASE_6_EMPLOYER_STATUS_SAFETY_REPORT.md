# Phase 6 — Prevent Employer Application Status Downgrade

Scope: fix the P1-1 risk from `docs/PHASE_5_REMAINING_PARITY_REVIEW.md` —
a latent data-integrity defect where an unrecognized/missing application
status could be silently defaulted to `'applied'` and re-submitted on a
notes-only save. Read first: `docs/PHASE_5_REMAINING_PARITY_REVIEW.md`,
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`,
`docs/PHASE_2_PARITY_AUDIT_REPORT.md`, `docs/PHASE_3_CRITICAL_FIXES_REPORT.md`,
`docs/PHASE_4_JOB_DETAIL_WIRING_REPORT.md`. Git status confirmed unchanged
from Phase 5's end state in both repositories before any edit.

## 1. Confirmed root cause — from actual source, not assumed

**Flutter side**, re-read fresh:
- `employer_application_detail_html_parser.dart:42` (before this phase):
  `status: statusMatch?.group(1) ?? 'applied'`, with `_selectedStatusPattern`
  matching `<option value="([a-z_]+)"[^>]*\bselected\b` **anywhere in the
  whole page** (`.firstMatch` against the full HTML, not scoped to the
  status `<select>` specifically).
- `employer_application_detail_screen.dart` (before this phase):
  `_status` seeded directly from this value in `initState`/
  `didUpdateWidget`, bound as the dropdown's `initialValue`, and always
  included in the save payload (`_submit()` → `updateStatus(status: _status, ...)`)
  regardless of whether the user touched the dropdown.

**Django side, read directly (not assumed identical to a prior phase's
notes)**:
- `jobs_app/models.py:243-247`: `JobApplication.STATUS_CHOICES` — exactly
  6 values (`applied`, `reviewing`, `shortlisted`, `interview`, `offered`,
  `rejected`) — confirmed verbatim-matching `kApplicationStatusOptions`.
- `jobs_app/models.py:280`: `status = models.CharField(..., choices=STATUS_CHOICES, default='applied')`
  — no `blank=True`.
- `jobs_app/forms.py:225-232`: `ApplicationStatusForm(forms.ModelForm)`,
  `fields = ['status', 'employer_notes']` — because the model field isn't
  `blank=True`, Django's `ModelForm` makes this form field **required**.
  **Confirmed: `status` cannot simply be omitted from a save request** —
  doing so would fail `form.is_valid()`, not silently succeed. This
  directly answers the task's required check ("verify from the real view
  and payload contract that omission is safe before implementing it") —
  **it is not safe**, so the fix does not take that path.
- `jobs_app/views.py:684-709` (`application_detail`), read in full:
  ```python
  previous_status = app.status
  form = ApplicationStatusForm(request.POST, instance=app)
  if form.is_valid():
      app = form.save()
      if app.status != previous_status:
          notify_candidate_status_change(request, app)
          messages.success(request, '... The candidate has been notified by email.')
  ```
  This confirms the exact mechanism and consequence: if the submitted
  `status` differs from whatever was *actually* stored before the save
  (not whatever the client believed it to be), the server treats it as a
  real, intentional status change and emails the candidate. A client that
  submits a fabricated `'applied'` when the real stored status is, say,
  `'shortlisted'`, would trigger exactly this — an incorrect, unintended
  candidate notification, with no indication to the employer that
  anything unusual happened.

**Root cause confirmed exactly as described in Phase 5, with the added,
now-verified specificity that `status` is a mandatorily required field on
every save.**

## 2. The fix

Minimal, Flutter-only, no backend contract change:

- **`lib/features/employer/domain/entities/employer_application_detail.dart`**:
  `status` changed from `String` to `String?`. Doc comment explains why a
  fabricated fallback is unsafe, citing the exact Django source above.
- **`lib/features/employer/data/employer_application_detail_html_parser.dart`**:
  replaced the single loose, whole-page regex with a two-step, scoped
  parse (`_parseSelectedStatus`): first locate the specific
  `<select name="status">...</select>` block (matching
  `{{ form.status }}`'s real rendering, `application_detail.html:210`),
  then find its `selected` option within that block only, then validate
  the extracted value against `kApplicationStatusOptions`' known 6 values.
  Returns `null` — never a guessed value — if any step fails. This both
  fixes the original missing-match defect and closes an additional,
  previously-unflagged scoping risk (the old regex could theoretically
  have matched an unrelated `selected` option anywhere else on the page).
- **`lib/features/employer/presentation/screens/employer_application_detail_screen.dart`**:
  - `_status` is now `String?`.
  - `_submit()` guards at the top: if `_status == null`, sets a clear
    error message and returns **without calling the controller/repository
    at all** — defense in depth, since the build-time UI below already
    makes this unreachable in practice.
  - `build()`: when `_status == null`, the "Recruitment Decision" card
    shows a new `_UnknownStatusNotice` widget (a clear, red-accented
    explanation: *"Couldn't read this application's current status... To
    avoid accidentally changing it, status updates and notes can't be
    saved from here right now"* + a Reload button) **instead of** the
    dropdown, notes field, and Save button — all three are hidden
    together, since none of them can be safely used without a real status
    to pair with.
  - When `_status` is non-null (the successfully-parsed case), **the
    entire pre-existing workflow is untouched**: same dropdown, same
    notes field, same save button, same payload shape.

No Django file was touched. No new endpoint, no payload-shape change, no
unrelated refactor (the resume/interview/cover-letter sections of the
screen, and the datasource's CSRF/redirect/validation handling, are
byte-for-byte unchanged).

## 3. Before-and-after behavior

| Scenario | Before | After |
|---|---|---|
| Status successfully parsed, employer changes only notes | Submits the real, correctly-parsed status unchanged (this specific path was never broken) | **Unchanged** — same real status submitted |
| Status successfully parsed, employer deliberately changes status | Submits the newly selected status | **Unchanged** — same behavior |
| Status select missing or has no `selected` option | Silently defaults to `'applied'` and can be submitted on any save, including a notes-only one | **`status` is `null`; no dropdown, notes field, or save button is shown at all** — nothing can be submitted until the page is reloaded and a real status is obtained |
| Selected value present but outside the known 6 choices | Was trusted as-is (any `[a-z_]+` string) | **Treated identically to a missing match — `null`, same safe-notice behavior** |
| An unrelated `<select>` elsewhere on the page has its own `selected` option | Could have been mistaken for the real status (whole-page `.firstMatch`) | **Impossible — the parse is scoped to the specific `<select name="status">` block** |

## 4. Regression tests added

All in existing test files; no existing test was weakened, modified in a
way that reduces coverage, or removed.

**`test/features/employer/data/employer_application_detail_html_parser_test.dart`**
(2 existing tests unchanged + 3 new):
- A status select with no `selected` option → `status` is `null` (never
  `'applied'`); every other real field still parses.
- A `selected` value outside the known 6 `STATUS_CHOICES` (`'archived'`)
  → `status` is `null`.
- An unrelated `<select>` elsewhere on the page with its own `selected`
  option → the real status (`'applied'`) is still correctly found,
  proving the scoped match works, not just the validation fallback.

**`test/features/employer/presentation/screens/employer_application_detail_screen_test.dart`**
(3 existing tests unchanged + 3 new, each inspecting the actual captured
repository call, not merely that the screen renders — `_FakeRepository`
was extended to record `updateStatusCallCount`/`lastSubmittedStatus`/
`lastSubmittedNotes`):
- An unknown (`null`) status shows the notice, hides the dropdown/Save
  button, and the repository is **never called** (`updateStatusCallCount == 0`).
- Editing only notes, with a successfully-parsed real status, submits
  that **same real status** (`'applied'` in the fixture) and the edited
  notes — proving a notes-only edit cannot submit anything else.
- A deliberate dropdown change to "Shortlisted" submits `'shortlisted'`
  correctly — proving the legitimate status-change path still works
  exactly as before.

## 5. Validation — exact commands and actual results

```
flutter analyze
```
→ **No issues found!**

```
flutter test test/features/employer/data/employer_application_detail_html_parser_test.dart \
             test/features/employer/presentation/screens/employer_application_detail_screen_test.dart
```
→ **All passed** (5 + 6 = 11 tests across the two directly affected files).

```
flutter test test/features/employer/
```
→ **All passed** (118 tests across the whole employer feature directory —
confirms nothing else in the employer module regressed, including the
profile/dashboard/job-posting screens Phases 3-4 already touched).

```
flutter test
```
(full suite) → **1904/1904 passing**, 0 skipped, 0 failing — **6 more
than the Phase 5 baseline of 1898**, the exact count of new regression
tests added (3 parser + 3 screen). No existing test was weakened or
removed to reach this result.

## 6. Remaining limitations

- **No live-backend testing was performed or is claimed.** Per the task's
  own framing, this defect is reproducible entirely from a crafted HTML
  fixture, and that is exactly how it was fixed and tested — no device,
  account, or production/dev-server access was used or needed.
- **The fix trades availability for safety in one specific, narrow case**:
  if the real status genuinely cannot be determined (a markup change, a
  transient render issue), the employer can no longer save *anything* —
  not even notes — from this screen until the page is reloaded and a real
  status is obtained. This is a direct, unavoidable consequence of the
  verified fact that Django's own form requires `status` on every save;
  there is no safer alternative available within a Flutter-only fix.
- **The `_UnknownStatusNotice`'s "Reload" button** re-invalidates and
  re-fetches via the existing `retry()` method — it was not given its own
  dedicated test in this phase (the three new screen tests focus on the
  save-payload safety property the task specifically asked for); this is
  a minor test-coverage gap, not a known defect.

## 7. Confirmations

- **Django source**: unchanged. `git status --short` in `Career_Buddy_LMS/`
  shows the identical 3-modified/3-untracked state present since Phase 1,
  before and after this phase.
- **Pre-existing uncommitted/untracked work**: fully preserved in both
  repositories — this phase added exactly 3 modified source files (the
  entity, the parser, the screen) and 2 modified test files; every file
  Phase 5 left behind remains exactly as it was.
- **No secrets, keystores, or signing material** were read, printed, or
  modified.
- **Demo Mode, authentication, password-reset, profile flows (job-seeker
  or employer-profile), subscription logic, and proctoring**: none
  touched this phase — confirmed by the git diff above showing only the
  employer-application-detail files changed.
- **No APK/AAB was built, nothing was deployed or uploaded** to any
  store.
- **No live-device or production verification is claimed** anywhere in
  this report.

## Parity matrix update

The "Employer application detail — status update" row in
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` was updated to reflect exactly
what was implemented and verified this phase (Partial/fragile →
**Fully equivalent**, source-verified, not yet live-device-confirmed),
citing the new `_parseSelectedStatus`/`_UnknownStatusNotice` mechanisms and
the 6 new regression tests. No other row was changed.

## Status

**Fixed**, per the evidence above — not partially fixed, not blocked.
Stopping here, as instructed. No further remediation phase started
without explicit approval.
