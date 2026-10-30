# Phase 52 — Non-IT Employer Job-Posting Validation and Dropdown Parity Fix

## 1. Reported defects and reproduction status

All three defects Phase 51 reported were **reproduced by direct code
tracing** (not device-tested — no employer test account is available to
this or any prior phase) and cross-checked against the current, updated
`royalStaffing_CB01/jobs_app/forms.py`/`models.py`, which was re-read in
full this phase as the authoritative source, per this task's instruction.

| Reported defect | Reproduced? | Evidence |
|---|---|---|
| `_localRequiredErrors()` unconditionally requires `work_environment`, `interview_mode`, `notice_period` even when hidden for Non-IT | **Confirmed** | `post_new_job_screen.dart` (pre-fix) checked `_workEnvironment.isEmpty`/`_interviewMode.isEmpty`/`_noticePeriod.isEmpty` with no category/classification gate at all, while their own widgets were correctly gated (`!_isIt`/`_isIt`/`!_isNonItNonTech`) |
| Duplicate/incorrectly-populated `job_type` dropdown shown for Non-IT | **Confirmed** | The dropdown bound to `_jobType`/`kJobTypeOptions` (IT's own option list) rendered unconditionally with a relabeled title ("Employment Type (job nature)") directly above the real, separate `employmentType`/`kEmploymentTypeOptions` dropdown, which already renders correctly for Non-IT |
| Category switching leaves stale/contradictory values | **Confirmed, and a 2nd case found by this phase's own trace**: `_onCategoryChanged`/`_onClassificationChanged` cleared only skills/department state, never the work_environment/interview_mode/job_type trio or the work_mode/employment_type/joining_requirement trio, nor `notice_period` when moving between Non-IT classifications |
| `gender_preference` over-strict for Non-IT | **Confirmed** | `jobs_app/forms.py:840-841`: "If Applicable" (never required) on both Non-IT sheets; Flutter required it unconditionally |

**One additional, previously-unreported defect found by this phase's own
direct trace of `forms.py`'s `clean()` method** (in scope under Part B/D,
since it's the identical root-cause class — option-list/requiredness
parity — the task already asked to verify): `work_mode`'s allowed value
set is **not one shared list** — the server validates against a different
set per Job Classification (`WORK_MODE_OPTIONS['technical']` vs.
`['non_technical']`, `forms.py:867-869`), and the two lists are not
identical (Technical has "Plant", not "Hybrid"; Non-Technical has
"Hybrid", not "Plant"). Flutter's single flat `kWorkModeOptions` let an
employer pick a choice the server would then reject with "Select a work
mode from the list." This was fixed as part of the same validation-parity
work, not treated as a separate, out-of-scope item, since it's the same
mechanism (server-authoritative per-category option sets) this phase was
already auditing field-by-field.

**Not investigated further / left as-is, per this phase's explicit scope
boundary**: `department`'s own requiredness/visibility, `education`'s
requiredness (the source confirms `education` is also required for
Non-IT, `forms.py:837-838`, but Phase 51 never flagged it and this phase's
brief did not name it — fixing it would have meant going beyond "fix a
field only when the updated web source confirms a mismatch" into
"implement every outstanding field from Item 5", which this phase was
explicitly told not to do; recorded here as an observed-but-deliberately-
unfixed gap, not an oversight).

## 2. Root cause

`jobs_app/forms.py`'s `__init__` (lines 494-509) sets `gender_preference`/
`interview_mode`/`job_type`/`work_environment`/`notice_period` all to
`required=False` at the Django field level — the *actual* requiredness
logic lives entirely in `clean()` (lines 820-884), which branches on
`job_category`/`job_classification` to decide, per field, whether to
error. `post_new_job_screen.dart`'s `_localRequiredErrors()` was written
as a flat, unconditional checklist that never branched the same way its
own sibling widget-visibility conditions already did — the widgets were
built correctly (Phase 43-era work already hid the right fields for the
right categories), but the validation method checking them was never
updated to match. The duplicate `job_type` dropdown had the identical root
cause in miniature: its widget was missing the `_isIt` gate every sibling
IT-only field already had.

## 3. Files changed

- **`lib/features/employer/data/job_posting_catalog.dart`** — replaced the
  single flat `kWorkModeOptions` with `kTechWorkModeOptions`/
  `kNonTechWorkModeOptions`, matching `JobPosting.TECH_WORK_MODE_CHOICES`/
  `NONTECH_WORK_MODE_CHOICES` exactly; updated 2 stale doc-comment
  cross-references.
- **`lib/features/employer/domain/entities/job_posting_submission.dart`**
  — updated `workMode`'s doc comment to point at the new, correctly-split
  constants (no field/type change — the entity's shape was already
  correct).
- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**
  — the actual fix:
  - `_localRequiredErrors()`: gated `work_environment`/`interview_mode`/
    `gender_preference` behind `_isIt`; gated `notice_period` behind
    `_isIt || _isNonItTech`; added new checks for `work_mode`/
    `employment_type` (required whenever `_isNonIt`) and
    `joining_requirement` (required when `_isNonItNonTech`) — mirroring
    `forms.py`'s `clean()` exactly, with the same error wording the server
    itself returns for each.
  - The IT-only "Job Type" dropdown is now wrapped in `if (_isIt) ...`,
    removing the duplicate/mislabeled Non-IT rendering entirely — Non-IT
    now shows exactly the one real "Employment Type" dropdown the web
    shows.
  - `_buildWorkModeSection()` now calls a new `_workModeOptionsFor(
    classification)` helper to show the correct option list per
    classification.
  - `_onCategoryChanged`/`_onClassificationChanged` now clear the
    now-inapplicable side's fields on every switch (IT trio vs. Non-IT
    trio; `notice_period` vs. `joining_requirement`; `work_mode` cleared
    only if its current value isn't in the new classification's own list,
    to avoid a `DropdownButtonFormField` value/items mismatch).
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`**
  — see §5.

No other file was changed. No backend, Django, routing, or unrelated
Flutter feature file was touched.

## 4. How category-specific behavior was matched to the updated web source

Every requiredness/visibility/option-list rule above was taken directly
from a fresh read of `royalStaffing_CB01/jobs_app/forms.py` this phase
(`__init__` lines 480-539, `clean()` lines 820-914) and
`jobs_app/models.py`'s choice-list constants (lines 29-73) — not inferred
from the Flutter audit's own description of the bug, and not assumed from
the client-side JS in `job_form.html` alone (that JS's `nonit-hide`/
`nonit-only`/`data-nonit-required` classes were used only to corroborate,
never as the sole source, consistent with this project's own standing
practice of treating the real POST/`clean()` behavior as final authority
over client-side hints).

## 5. Tests added and their results

All 10 new tests below were added to the existing `PostNewJobScreen`
group structure in `post_new_job_screen_test.dart`, under a new `Phase
52: Non-IT required-field parity` group:

1. The IT-only "Job Type" dropdown is absent for Non-IT; only the real
   "Employment Type" dropdown appears.
2. A valid Non-IT × Technical submission reaches the repository (was
   previously blocked) and submits the correct category-specific field
   values (`employmentType`, `workMode`, `noticePeriod` set; `jobType`/
   `workEnvironment`/`interviewMode` sent empty).
3. A valid Non-IT × Non-Technical submission reaches the repository and
   submits the correct values (`joiningRequirement` set; `noticePeriod`
   sent empty, since Technical/IT's own field doesn't apply here).
4. A Non-IT submission missing `work_mode`/`employment_type` is still
   correctly blocked, with the real "Select a work mode."/"Select an
   employment type." errors (visible-field validation preserved, not
   disabled wholesale).
5. A Non-IT × Non-Technical submission missing `joining_requirement` is
   blocked with the real error.
6. Gender is confirmed optional for Non-IT — a valid submission with no
   gender chip tapped still succeeds, submitting an empty
   `genderPreference`.
7. Switching IT → Non-IT removes the Work Environment/Interview Mode
   sections entirely (so their stale values can no longer even be shown,
   let alone submitted).
8. Switching Non-IT classification Technical → Non-Technical clears the
   Notice Period pills' selection and swaps in Joining Requirement.
9. Non-IT × Technical's Work Mode dropdown offers "Plant" and not
   "Hybrid"; Non-IT × Non-Technical offers "Hybrid" and not "Plant".

All pre-existing tests in this file (the IT-only submission test, the
Non-IT visibility test, the server-side-error test, and all 5 Edit-mode
tests) were re-run unchanged and still pass — none were weakened, deleted,
or had their expected values altered.

**Focused results**: `flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart`
→ **18 passing, 0 failing** (9 pre-existing + 9 new).
`flutter test test/features/employer` (whole directory) → **129 passing, 0
failing** (was 120 before this phase).

## 6. Full-suite and analyzer comparison with Phase 51

| Metric | Phase 51 baseline | This phase |
|---|---|---|
| Full test suite | 2,482 passing, 0 failing | **2,491 passing, 0 failing** (+9, matching the 9 new tests exactly) |
| `flutter analyze` | 8 issues | **8 issues** — identical, pre-existing `unused_element_parameter` warnings in unrelated resume-controller test files; 0 new issues |

Both were re-run fresh this phase, not assumed from the Phase 51 report.

## 7. Emulator/device verification

**Not performed.** `emulator-5556` (Android 14/API 34) was not running at
the start of this phase (only `emulator-5554`, Android 17/API 37, was
available) — checked via `flutter devices`/`adb devices`, no emulator was
wiped, reset, or recreated. More fundamentally, even with `emulator-5556`
booted, this phase's fix lives entirely inside `PostNewJobScreen`, a
screen reached only by an authenticated employer — no legitimate employer
test account exists in this environment (consistent with every prior
phase's own finding), and this task explicitly prohibits fabricating one
or bypassing authentication. A guest-only app launch would never reach the
changed code at all, so it was judged to add no real verification value
for this specific fix and was not attempted. All verification for this
phase is therefore automated-test-based only, as explicitly permitted by
the task's own instructions for this situation.

## 8. What remains unverified

- **A real, live Non-IT job submission against the actual production or
  staging backend** — the single most direct way to close this out, but
  requires a legitimate employer account this phase does not have. The
  fix's correctness rests on (a) a direct, line-cited re-read of the
  server's own `clean()` logic and (b) 9 new widget tests exercising the
  exact same branches, but no live POST was made.
- **`education`'s own requiredness gap** (Non-IT requires it per
  `forms.py:837-838`; Flutter's `_localRequiredErrors()` has never
  checked it, before or after this phase) — observed during this phase's
  source trace, deliberately left unfixed as out of this phase's named
  scope (see §1's "not investigated further" note).
- Every other Item 5 field-level gap already catalogued in
  `PHASE_51_FINAL_PARITY_MATRIX.md`/`PHASE_51_FINAL_IMPLEMENTATION_ROADMAP.md`
  (the 8 `TEXT_FIELD_RULES`-governed fields' unmirrored char-set rules,
  `experience_plus`/`experience_years_max`'s missing UI, the 12-month
  contract-duration ceiling, etc.) — none of these were in this phase's
  named scope (Part A-D only) and none were touched.

## 9. Confirmation: Django trees untouched; uncommitted work preserved

Neither `royalStaffing_CB01/` nor `Career_Buddy_LMS/` was written to —
both were read-only throughout this phase (`jobs_app/forms.py`,
`jobs_app/models.py`, `templates/employer/job_form.html`). `git status`
before this phase showed a clean working tree (the Phase 40-51 commit was
already in place); after this phase, only the 4 files listed in §3 are
modified — confirmed via `git diff --stat`, no other file was touched,
reset, stashed, or overwritten.

## 10. Remaining Item 5 gaps deliberately left outside this phase

Per the task's explicit scope boundary, this phase did not touch any of
the following, all still open per the Phase 51 roadmap:

- The 8 `TEXT_FIELD_RULES`-governed fields' (industry_sector, industry_
  experience, certifications, keywords, department_function,
  functional_skills, software_skills, language_requirements) and `title`'s
  unmirrored char-set/length validation.
- `age_limit`'s and `application_contact`'s unmirrored regex validation.
- `contract_duration_months`'s unmirrored 12-month ceiling and its
  always-visible-rather-than-conditional rendering.
- `experience_plus` ("10+" years) and `experience_years_max` (a typed
  range) — both still structurally impossible to express in the current
  UI (hardcoded `false`/`''` in the submission).
- `education`'s Non-IT requiredness (see §8).
- The 4 stale documentation files (`WEB_SCREEN_INVENTORY.md`, etc.) that
  still describe this screen as unbuilt.

None of these were implemented, and no attempt was made to broaden this
phase into a general Item 5 cleanup.
