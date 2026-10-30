# Phase 57 — Employer Job Posting: Contract Duration Parity

## 1. Files changed and reason for each change

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added `bool get _isContract => _jobType == 'contract' || _employmentType == 'contract';` — the effective "is this a Contract posting" check, mirroring `job_form.html`'s own `isContract()` (`const sel = isNonItSheet() ? employmentSelect : jobTypeSelect;`). This is the single source of truth every other change below reads from.
  - The "Project Duration (months)" / "Project / Contract Duration (months)" `AppTextField` is now wrapped in `if (_isContract) ...[...]` instead of always rendering — this is the core conditional-visibility fix.
  - The "Job Type" dropdown's `onChanged` now clears `_contractDurationMonths` whenever the newly-selected value isn't `'contract'`.
  - The "Employment Type" dropdown's `onChanged` does the same (both Non-IT sheets share this one field, per Phase 56's confirmed source reading).
  - `_onCategoryChanged` now unconditionally clears `_contractDurationMonths` at the end of its `setState` block — a category switch always blanks whichever of `_jobType`/`_employmentType` could have held `'contract'` for the old category, so `_isContract` is always `false` immediately afterward.
  - `_localRequiredErrors()` gained a new `_isContract`-gated block validating the duration: empty → "Enter the project duration in months."; non-numeric → "Enter the project duration as a whole number of months."; negative → "Project duration cannot be negative."; `>12` → "Project duration cannot exceed 12 months."; `<1` (i.e. `0`) → "Project duration must be at least 1 month." — checked in that exact order, mirroring the server's own field-level-then-form-level validation sequence.
  - `_submit()`'s `JobPostingSubmission` construction now sends `_isContract ? _contractDurationMonths.text.trim() : ''` instead of the value unconditionally — a submit-time backstop reproducing the server's own unconditional discard (`cleaned['contract_duration_months'] = None` whenever `job_type != 'contract'`), on top of the controller already being cleared by the handlers above.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`** — added the new `Phase 57: Contract Duration conditional visibility and validation` group (17 tests, §4).
- **No other file was changed.** `job_posting_submission.dart`, `job_posting_catalog.dart`, and `job_posting_remote_datasource.dart`/its test file carry only their pre-existing Phase 52-55 diffs, confirmed unmodified by this phase (`contractDurationMonths` was already a plain `String` field sent as-is — no domain-model or serialization change was needed, since the existing contract already represented "no duration" as an empty string correctly).

## 2. Confirmed web behavior and how Flutter now matches it

Re-confirmed directly against the current source at the cited line ranges (re-read this phase, not assumed from Phase 56's report):

- **`forms.py:355-358`**: the widget's own comment — "Shown only when job_type == 'contract'; whole months, 2 digits, max 12."
- **`forms.py:468-473`** (`clean_contract_duration_months`, `CONTRACT_DURATION_MAX = 12`): `value > 12` → "Project duration cannot exceed 12 months."
- **`forms.py:566-569`**: field-level `error_messages` override — `'invalid'` → "Enter the project duration as a whole number of months.", `'min_value'` → "Project duration cannot be negative."
- **`forms.py:898-907`** (form-level `clean()`): `job_type == 'contract'` gates the block; `duration is None` → "Enter the project duration in months."; `duration < 1` → "Project duration must be at least 1 month."; otherwise (`job_type != 'contract'`) `cleaned['contract_duration_months'] = None`.
- **`job_form.html:935-967`**: `isContract()` reads `employmentSelect` for any Non-IT sheet, `jobTypeSelect` for IT; `toggleDuration()` shows/hides the wrapper, clears the input the instant it's hidden (`durationInput.value = ''`), and clears the error (`setDurationError('')`); `validateDuration()` mirrors the same 5 messages in the same order.

Flutter's `_isContract` getter, the `if (_isContract)` visibility gate, the 2 dropdown `onChanged` clears, the `_onCategoryChanged` clear, and the 5-branch `_localRequiredErrors()` check together reproduce all of the above: the field is now genuinely hidden outside Contract postings (for IT *and* both Non-IT sheets, not just IT), a stale value can never survive a switch away from Contract, and all 5 server messages are reproduced verbatim in the same precedence order.

## 3. Validation and conditional visibility behavior implemented

- **Visibility**: `_isContract` (`_jobType == 'contract' || _employmentType == 'contract'`) gates the field for all 3 category/classification combinations.
- **Clearing**: 3 independent paths all converge on the same outcome — changing Job Type away from Contract, changing Employment Type away from Contract, or switching Job Category entirely (which always blanks whichever field could have held `'contract'`) — each clears `_contractDurationMonths` immediately. Switching *back* to Contract shows an empty field (never a previously-typed stale value), confirmed by test (§4, item 4).
- **Validation order**: required → non-numeric → negative → over-12 → under-1, matching the server's own field-level/method-level/form-level layering.
- **Submission**: `contractDurationMonths` is sent as the validated string when `_isContract`, else always `''` — both via the UI-level clearing and a submit-time backstop, so no path can leak a stale or irrelevant value into the payload. The field name and payload shape (`contract_duration_months`, a plain string) are unchanged — `JobPostingRemoteDataSource` needed no edit.
- **Edit mode**: unaffected in its loading mechanism (`_contractDurationMonths.text = data.contractDurationMonths;` was already correct and untouched); the field's *visibility* now correctly follows the loaded `jobType`/`employmentType`, verified by a dedicated edit-mode test (§4, item 17).

## 4. Tests run, with actual pass/fail counts

New group `PostNewJobScreen — Phase 57: Contract Duration conditional visibility and validation` (17 tests, all passing):

1. Project Duration is hidden for IT when no Job Type, or a non-Contract Job Type, is selected.
2. Project Duration is visible for IT once Job Type is Contract.
3. Project Duration is visible for Non-IT × Technical once Employment Type is Contract.
4. Project Duration is visible for Non-IT × Non-Technical once Employment Type is Contract.
5. Switching Job Type away from Contract hides Project Duration, clears its value and any validation error.
6. Switching back to Contract after typing a duration shows an empty field, not the stale value.
7. A missing duration is rejected for a Contract IT posting with the real server error.
8. Valid durations of 1 and 12 months are both accepted (2 separate tests).
9. A duration of 0 is rejected with "Project duration must be at least 1 month."
10. A negative duration is rejected with "Project duration cannot be negative."
11. A decimal duration is rejected with "Enter the project duration as a whole number of months."
12. Non-numeric duration text is rejected with the same "whole number" message.
13. A duration over 12 months is rejected with "Project duration cannot exceed 12 months."
14. A stale duration typed while Contract was selected is not submitted after switching away.
15. A Non-IT × Technical Contract posting submits its duration correctly (via Employment Type, not Job Type).
16. Edit mode: a Contract posting loads with Project Duration visible and populated, and resubmits the loaded value unchanged.

Command and result:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 65 passing, 0 failing (48 pre-existing + 17 new)
```
```
flutter test test/features/employer
→ 178 passing, 0 failing (161 pre-existing + 17 new)
```
```
flutter test
→ 2,540 passing, 0 failing (2,523 pre-existing + 17 new; exact match against the Phase 55 baseline plus these additions — no regressions)
```
No existing test was weakened, removed, or modified. The pre-existing "Edit mode fetches and displays the existing job's values" test (which uses a `full_time`, non-Contract fixture) was re-run and continues to pass — confirming the new conditional visibility doesn't disturb a non-Contract edit flow.

## 5. Analysis results and any existing warnings

```
flutter analyze
→ 8 issues found (identical file/line/message to the Phase 55 baseline)
```
All 8 are the same pre-existing `unused_element_parameter` warnings in unrelated resume-controller test files (`create_resume_pdf_controller_test.dart`, `manual_resume_builder_controller_test.dart` ×2, `manual_resume_page_preview_controller_test.dart`, `manual_resume_pdf_controller_test.dart`, `manual_resume_preview_controller_test.dart`, `manual_resume_builder_screen_test.dart`) — untouched by this phase, unchanged in count or content. `flutter analyze lib/features/employer/` on its own returns "No issues found."

## 6. Device verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results reported in §4-5.

## 7. Remaining limitations or unverified behavior

- The real web page's Project Duration input carries HTML attributes (`inputmode="numeric"`, a 2-digit `maxlength`) that are not reproduced 1:1 in Flutter — Flutter relies on `keyboardType: TextInputType.number` (a soft keyboard hint, not an input filter) plus submit-time validation, consistent with this project's established convention for every other numeric field on this form (`experience_years`, `experience_years_max`, `openings`), not a gap specific to this phase.
- No live round-trip against the real server was performed to confirm the server still returns these exact 5 messages unchanged; the messages were taken from direct, re-confirmed source reading (`forms.py`) rather than a live POST.
- This phase did not address any other Phase 56 audit finding (application-contact validation, age-limit validation, general text-field validation) — explicitly out of scope per the directive.

## 8. Confirmation

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout this phase — only `grep`/`Read` were used against `jobs_app/forms.py` and `templates/employer/job_form.html`; no file in either tree was created, edited, deleted, or renamed. No backend API, request format, database model, migration, or production data was changed. `git status --short` in `Mobile_app` shows exactly the same 5 files already modified by Phases 52-55 (carrying this phase's additional diff) plus the 5 pre-existing untracked Phase 52-56 reports — no unrelated file was created, reset, stashed, or overwritten; the pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. No signing material, credential, token, or keystore was inspected. No build was published and no signing configuration was changed.

---

**This phase is complete.** Not starting another phase without explicit approval.
