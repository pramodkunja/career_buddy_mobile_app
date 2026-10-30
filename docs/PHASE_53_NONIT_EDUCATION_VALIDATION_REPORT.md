# Phase 53 — Fix Non-IT Education Required-Field Validation

## 1. Source behavior confirmed

Reference tree (read-only, never modified): `royalStaffing_CB01/jobs_app/`.

**`education` field declaration** — `models.py:200`:
```python
education = models.CharField(max_length=20, choices=EDUCATION_CHOICES, blank=True)
```
`blank=True` makes the Django `ModelForm` field `required=False` by default. `forms.py`'s `__init__` (the block at lines ~480-539 that explicitly overrides requiredness for `department`, `designation`, `gender_preference`, `interview_mode`, `job_type`, `work_environment`, `notice_period`) contains **no override for `education`** (confirmed: `grep -n "fields\['education'\]"` returns nothing). So `education`'s only requiredness is whatever `clean()` adds on top.

**`clean()`'s requiredness rule** — `forms.py:836-838`:
```python
# Qualification is mandatory on both NON-IT sheets.
if non_it and not cleaned.get('education') and 'education' not in self.errors:
    self.add_error('education', 'Qualification is required.')
```
`non_it` is derived at `forms.py:819` as `sheet is not None`, where `sheet = self.NON_IT_FIELDS.get(classification)` only when `category == 'non_it'` (`forms.py:816-818`). `NON_IT_FIELDS` has entries for both `'technical'` and `'non_technical'`, so **`non_it` is true for both Non-IT sheets** and false for IT (and for Non-IT with no classification chosen yet).

## 2. Categories requiring education, with evidence

| Category | Required? | Evidence |
|---|---|---|
| IT | **No** — never required, at any layer | `models.py:200` (`blank=True`), no `__init__` override, and `forms.py:836` gates the only requiredness check behind `non_it`, which is `False` for IT |
| Non-IT × Technical | **Yes** | `forms.py:836-838`, `non_it` is `True` |
| Non-IT × Non-Technical | **Yes** | `forms.py:836-838`, `non_it` is `True` (same check, same variable) |

Confirmed directly from the model and form source, not inferred from the old audit report or from `job_form.html`.

## 3. Root cause of the Flutter gap

`post_new_job_screen.dart`'s `_localRequiredErrors()` — the client-side pre-check that mirrors `clean()`'s category-specific requiredness so an incomplete submission doesn't need a round trip — had no entry for `'education'` at all, for any category. The widget itself (`_dropdown(..., errorKey: 'education', ...)`) was already wired to display an error for that key if one were present in the map; the map simply never populated it. A Non-IT employer who left Qualification blank would pass local validation and only discover the problem after a live POST round-trip (or, per Phase 52's established risk pattern, with a lower-quality generic error if the server-rendered message wasn't surfaced correctly).

## 4. Fix applied

**File:** `lib/features/employer/presentation/screens/post_new_job_screen.dart`

Added one check to `_localRequiredErrors()`, following the exact pattern/wording convention established in Phase 52:
```dart
if (_isNonIt && _educationPreset.isEmpty) {
  errors['education'] = 'Qualification is required.';
}
```
`_isNonIt` is the existing getter for `_jobCategory == 'non_it'`, matching the server's `non_it` semantics for this check (both Non-IT classifications are covered; IT is excluded). The exact server error wording (`'Qualification is required.'`) is reused verbatim, consistent with every other check in this method.

The class's existing doc comment above `_localRequiredErrors()` (which documents each category-specific rule with its `forms.py` line numbers) was extended with a matching bullet for `education`, including a note on why the accepted-value constraints described below were deliberately not mirrored.

No other file needed a code change. `kEducationPresets` (`job_posting_catalog.dart`) and `JobPostingSubmission.educationPreset`/`educationOther` (`job_posting_submission.dart`) already existed from before this phase and needed no change to support this fix.

## 5. Tests added

**File:** `test/features/employer/presentation/screens/post_new_job_screen_test.dart`, new group `PostNewJobScreen — Phase 53: Non-IT education/qualification required-field parity` (4 new tests):

1. `a Non-IT × Technical submission missing its Qualification is blocked with the real server error` — fills every other required field, leaves Qualification unset, confirms `repo.callCount == 0` and `'Qualification is required.'` is shown.
2. `a Non-IT × Non-Technical submission missing its Qualification is blocked with the real server error` — same shape for the other Non-IT sheet.
3. `selecting a Qualification value clears the "Qualification is required." error for Non-IT` — submits once while blocked, then selects "ITI", resubmits, confirms the error clears, `repo.callCount == 1`, and `repo.submitted?.educationPreset == 'iti'`.
4. `Qualification is not required for IT (a valid IT submission with no Qualification choice still succeeds)` — uses the existing `_fillMinimalValidItJob` fixture unmodified (it never set an education value), confirms the submission still succeeds with `educationPreset == ''`, proving IT's behavior is unchanged.

**Existing fixtures updated** (required, not optional, once `education` became a real requirement for Non-IT): `_fillMinimalValidNonItTechnicalJob` and `_fillMinimalValidNonItNonTechnicalJob` now additionally select Qualification "ITI" — chosen deliberately because it is accepted under the server's own value-constraint rules for *either* Non-IT sheet (see §7), so the fixtures stay realistic even though Flutter doesn't yet enforce those constraints client-side. The two pre-existing Phase 52 "valid submission" assertions in this file were extended with `expect(repo.submitted?.educationPreset, 'iti')` for stronger regression coverage.

All 4 new tests pass; no existing test assertions were weakened.

## 6. Test results

- Focused file (`post_new_job_screen_test.dart`): **22 passing, 0 failing** (18 pre-existing + 4 new).
- Employer feature suite (`test/features/employer`): **133 passing, 0 failing**.
- Full suite (`flutter test`): **2,495 passing, 0 failing** — exactly Phase 52's baseline of 2,491 plus these 4 new tests; no regressions.

## 7. Analyzer comparison

`flutter analyze`: **8 issues**, identical in count, file, line, and message to Phase 52's baseline — all pre-existing `unused_element_parameter` warnings in unrelated resume-controller test files, untouched by this phase.

## 8. Device/emulator verification

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com` or any backend. Verification in this phase is limited to static analysis and the Flutter widget-test suite described above.

## 9. Confirmation of safety boundaries

- Both Django reference trees (`royalStaffing_CB01/`, `Career_Buddy_LMS/`) were read-only for this phase: only `grep`, `sed -n` (print), and `Read` were used against `jobs_app/forms.py` and `jobs_app/models.py`. No file in either tree was created, edited, deleted, or renamed.
- `git status` on `Career_Buddy_LMS` shows pre-existing modified/untracked files (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, two new test files under `activities/`) that predate this phase and were never touched during this session — left exactly as found.
- No backend endpoint, migration, database change, seed, or production-data mutation was made.
- No authentication, OTP, role, subscription, or access-control behavior was touched.
- No production account was used; no fabricated test account was invented or claimed.
- `git status --short` in `Mobile_app` shows exactly the same 4 modified files from Phase 52 (`job_posting_catalog.dart`, `job_posting_submission.dart`, `post_new_job_screen.dart`, `post_new_job_screen_test.dart`) plus `docs/PHASE_52_NONIT_JOB_POSTING_FIX_REPORT.md` (untracked) — this phase's changes are additive diffs on top of those same 4 files (only `post_new_job_screen.dart` and the test file were actually edited in Phase 53; `job_posting_catalog.dart` and `job_posting_submission.dart` carry only their pre-existing Phase 52 diff, unmodified here). No unrelated file was created, reset, stashed, or overwritten.
- No release build, signing config, or Play Store deployment step was touched or attempted.
- No signing file, keystore, credential, token, API key, or OTP/auth-bypass mechanism was inspected, printed, or modified.
- This phase implemented only the named education requiredness gap — no other outstanding Item 5 gap (experience ranges, text-field character rules, age-limit validation, contact validation, contract-duration rules) was touched, and the employer form was not refactored or redesigned.

## 10. Remaining Non-IT education/job-posting gaps deliberately left outside this phase

- **Accepted-value constraints** (`forms.py:884-894`): Non-IT × Technical must pick from `TECH_EDUCATION_KEYS` (`degree`/`diploma`/`iti`/`certification`) or `'custom'`; IT and Non-IT × Non-Technical must *not* pick `TECH_ONLY_EDUCATION_KEYS` (`degree`/`certification`), a stale-value guard against switching sheets. Flutter's `kEducationPresets` (`job_posting_catalog.dart:102-113`) is a single flat list of all 10 presets shown identically regardless of category/classification, so an employer could pick a value the server will reject (e.g. "12th / HSC / PUC" on Non-IT × Technical, or "Degree" on IT) and only find out after a round trip. This is the same *class* of gap as the `work_mode` options-list fix already made in Phase 52, but it is a distinct, "accepted value set" concern — not the requiredness gap this phase was scoped to — and the directive's own forbidden list names this same class of issue ("experience ranges") as out of scope. Left for a future phase.
- **`education_other` required-when-`'custom'`** (`forms.py:910-918`): when `education == 'custom'`, the server requires non-empty `education_other` text and runs it through `normalise_education_text`/`education_text_error` character-rule validation. Flutter's `_localRequiredErrors()` does not check this either. This falls squarely under the directive's explicitly excluded "text-field character rules" category and was left untouched.
- All five gaps explicitly named as out-of-scope in the Phase 53 directive (experience ranges, text-field character rules, age-limit validation, contact validation, contract-duration rules) remain unaddressed, as instructed.
