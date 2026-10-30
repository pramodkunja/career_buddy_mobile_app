# Phase 60 — Employer Job Posting: Non-IT Required-Field Validation Parity

## 1. Requiredness parity matrix

Re-verified directly against the current `royalStaffing_CB01/jobs_app/forms.py` (not assumed from Phase 56), confirming the source is unchanged since that audit.

| Field | Shown for IT | Shown Non-IT×Technical | Shown Non-IT×Non-Technical | Required for | Missing-value message | Flutter before this phase | Flutter after this phase |
|---|---|---|---|---|---|---|---|
| `title` | Yes | Yes | Yes | All categories | `Validators.required`'s default | Complete | Unchanged — Complete |
| `location` | Yes | Yes | Yes | All categories | `Validators.required`'s default | Complete | Unchanged — Complete |
| `description` | Yes | Yes | Yes | All categories | `Validators.required`'s default | Complete | Unchanged — Complete |
| `industry_sector` | No | Yes | Yes | Both Non-IT sheets | `Industry / Sector is required.` | **Missing** | **Fixed** |
| `responsibilities` | No | Yes | Yes | Both Non-IT sheets | `Job Responsibilities is required.` | **Missing** | **Fixed** |
| `working_hours` | No | Yes | Yes | Both Non-IT sheets | `Working Hours / Shift is required.` | **Missing** | **Fixed** |
| `keywords` | No | Yes | Yes | Both Non-IT sheets | `Key Skills / Keywords is required.` | **Missing** | **Fixed** |
| `application_contact` | No | Yes | Yes | Both Non-IT sheets | `Application Contact is required.` | Complete (Phase 58) | Unchanged — Complete |
| `industry_experience` | No | Yes | Yes | **Technical only** (optional for Non-Technical) | `Industry Experience is required.` | **Missing** | **Fixed** |
| `department_function` | No | No | Yes | Non-Technical only | `Department / Function is required.` | **Missing** | **Fixed** |
| `functional_skills` | No | No | Yes | Non-Technical only | `Functional Skills is required.` | **Missing** | **Fixed** |
| `education` | Yes (optional) | Yes | Yes | Both Non-IT sheets | `Qualification is required.` | Complete (Phase 53) | Unchanged — Complete |
| `contract_duration_months` | Yes (conditional) | Yes (conditional) | Yes (conditional) | Only when effective job type is Contract | 5 distinct messages | Complete (Phase 57) | Unchanged — Complete |
| `age_limit` | No | Yes | Yes | Never (always optional) | n/a | Complete (Phase 59) | Unchanged — Complete |
| `certifications` | No | Yes | Yes | Never (always optional) | n/a | Correct (no check needed) | Verified, unchanged |
| `software_skills` | No | No | Yes | Never (always optional, Non-Technical only) | n/a | Correct (no check needed) | Verified, unchanged |
| `language_requirements` | No | No | Yes | Never (always optional, Non-Technical only) | n/a | Correct (no check needed) | Verified, unchanged |

The 7 rows marked **Missing → Fixed** are this phase's entire scope. No other row needed a change — every other field's requiredness (or lack of it) was already correctly implemented by Phases 52-59 and was re-verified, not re-implemented.

## 2. Django source locations used to confirm the rules

- **`jobs_app/forms.py:277-312`** (`NON_IT_FIELDS`): the `'technical'` and `'non_technical'` sheet dictionaries, each with a `'required'` and `'optional'` list of `(field_name, label)` tuples — re-read in full this phase, confirmed byte-for-byte identical to Phase 56's and Phase 58's prior readings.
- **`jobs_app/forms.py:313-316`** (`NON_IT_ALL_FIELDS`): the 12-field list discarded to `''` for IT and for any Non-IT sheet field not listed for the posting's own classification.
- **`jobs_app/forms.py:822-830`** (`clean()`'s sheet-required loop):
  ```python
  if sheet:
      for name, label in sheet['required']:
          keep.add(name)
          value = (cleaned.get(name) or '').strip()
          cleaned[name] = value
          if not value and name not in self.errors:
              self.add_error(name, f'{label} is required.')
      for name, _label in sheet['optional']:
          keep.add(name)
          cleaned[name] = (cleaned.get(name) or '').strip()
  for name in self.NON_IT_ALL_FIELDS:
      if name not in keep:
          cleaned[name] = ''
  ```
  This confirms: (a) the exact message format `f'{label} is required.'`; (b) whitespace-only values are stripped to `''` *before* the `if not value` check, so they count as missing, exactly like a genuinely empty value; (c) a field not in the active sheet's `required`/`optional` lists at all (e.g. `functional_skills` for Technical) is unconditionally discarded, never validated.

## 3. Missing or incorrect Flutter rules found

Exactly the 7 rows in §1 marked **Missing**: `industry_sector`, `responsibilities`, `working_hours`, `keywords` (required on both Non-IT sheets), `industry_experience` (required on Technical only), `department_function` and `functional_skills` (required on Non-Technical only). In every case the widget itself was already correctly visibility-gated (confirmed by inspection before editing — `_isNonIt`/`_isNonItNonTech` conditionals and existing `_fieldError(...)` slots were already in place for all 7), and `_submit()` already sent each via `.trim()`. The gap was purely in `_localRequiredErrors()`, which never checked any of these 7 fields in any phase through 59.

## 4. Files changed and reason for each change

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**: `_localRequiredErrors()` gained 7 new checks (one `if` per field, each `.trim().isEmpty`-gated by the correct category/classification boolean), using the exact `f'{label} is required.'` wording for each field's own label. No widget, state, or `_submit()` change was needed — both were already correct.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`**:
  - Updated `_fillMinimalValidNonItTechnicalJob`/`_fillNonItTechnicalExceptContact` to additionally fill Industry / Sector, Industry Experience, Job Responsibilities, Working Hours / Shift, and Key Skills / Keywords — these fixtures now satisfy every field Phase 60 made genuinely required, the same kind of update Phases 54/58 made to these same fixtures when `education`/`application_contact` became required.
  - Updated `_fillMinimalValidNonItNonTechnicalJob`/`_fillNonItNonTechnicalExceptContact` to additionally fill Department / Function, Functional Skills, Industry / Sector, Job Responsibilities, Working Hours / Shift, and Key Skills / Keywords.
  - Updated 2 other inline Non-IT test sequences (the Phase 53 "selecting a Qualification value clears..." test and the Phase 57 "Non-IT × Technical Contract posting" test) with the same additions.
  - Added the new `Phase 60: Non-IT required-field validation parity` group (18 tests, §6).

No other file was changed by this phase's own work. `job_posting_catalog.dart`, `job_posting_submission.dart`, and `job_posting_remote_datasource_test.dart` carry only their pre-existing Phase 52-59 diffs. The 6 `test/features/resume/...` files carry only the pre-existing Phase 59 syntax fix (unrelated to this phase, untouched further here).

## 5. Exact error messages implemented

- `Industry / Sector is required.`
- `Industry Experience is required.`
- `Job Responsibilities is required.`
- `Working Hours / Shift is required.`
- `Key Skills / Keywords is required.`
- `Department / Function is required.`
- `Functional Skills is required.`

All taken verbatim from `NON_IT_FIELDS`'s own labels via `f'{label} is required.'`, not invented or paraphrased.

## 6. Tests added and actual pass/fail counts

New group `PostNewJobScreen — Phase 60: Non-IT required-field validation parity` (18 tests, all passing):

1-5. Each of Industry / Sector, Industry Experience, Job Responsibilities, Working Hours / Shift, and Key Skills / Keywords is required for Non-IT × Technical (parameterized loop, 5 tests).
6-11. Each of Department / Function, Functional Skills, Industry / Sector, Job Responsibilities, Working Hours / Shift, and Key Skills / Keywords is required for Non-IT × Non-Technical (parameterized loop, 6 tests).
12. Industry Experience is optional for Non-IT × Non-Technical even though it is required for Technical (the one field whose requiredness genuinely differs by classification).
13. Certifications and Age Limit remain optional for Non-IT × Technical (a valid submission with neither still succeeds).
14. Certifications, Software Skills, Language Requirements, and Age Limit remain optional for Non-IT × Non-Technical.
15. A whitespace-only value (`'   '`) counts as empty, exactly like the server's own `.strip()` check.
16. IT postings are never subjected to any of the 7 Non-IT-only required fields — none of their widgets even render, and a valid IT submission shows no `"is required."` text at all.
17. Switching from Non-IT to IT clears a stale `"is required."` error from a Non-IT-only field, so it cannot block a subsequent IT submission.
18. Filling in a missing required field clears its error and allows submission.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 126 passing, 0 failing (108 pre-existing + 18 new)
```
```
flutter test test/features/employer
→ 239 passing, 0 failing (221 pre-existing + 18 new)
```
```
flutter test
→ 2,601 passing, 0 failing (2,583 pre-existing + 18 new — exact match against the Phase 59 baseline plus these additions; no regressions)
```
No existing assertion was weakened, removed, or modified to make a new test pass — the fixture updates in §4 added previously-missing valid field values, they did not change any existing expectation.

## 7. Analysis results and any warnings

```
flutter analyze
→ No issues found! (0 issues)
```
Matches the Phase 59 baseline of 0 issues (itself a correction of the earlier, stale "8 pre-existing issues" figure, as documented in Phase 59's own report) — unchanged by this phase's own code. `flutter analyze lib/features/employer/` also reports "No issues found."

## 8. Device/live-server verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results reported in §6-7.

## 9. Remaining gaps intentionally reserved for Phase 61

Per this phase's explicit scope boundary, the following were deliberately **not** touched, even though they affect some of the same 7 fields:

- **General allowed-character rules** (`TEXT_FIELD_RULES`'s regex character classes) for `industry_sector`, `keywords`, `functional_skills`, `department_function`, and `industry_experience` — all 5 are in `TEXT_FIELD_RULES` and have their own `clean_<field>` character/min-letter/no-long-digits checks that this phase did not implement.
- **Minimum-letter rules** (`min_letters: 2`) for the same 5 fields.
- **Standalone digit-pattern restrictions** (`no_long_digits`) for `industry_sector`, `functional_skills`, and `department_function`.
- `responsibilities` and `working_hours` have no `TEXT_FIELD_RULES` entry at all (confirmed in Phase 56's audit and re-confirmed this phase) — no character-rule work will ever be needed for these two specifically, only the requiredness check this phase added.
- Age Limit and Application Contact format rules, Contract Duration, and any other Phase 56 audit finding beyond required-field validation — untouched, per the explicit scope boundary.

## 10. Confirmation: both Django reference directories and backend APIs remained unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout this phase — only `grep`/`sed -n` were used against `jobs_app/forms.py`; no file in either tree was created, edited, deleted, or renamed. No backend API, request format, database model, migration, or production data was changed. No payload field name, serialization logic, or domain-model type was altered.

## 11. Confirmation: unrelated working-tree changes preserved

`git status --short` before this phase showed the same 5 employer files already modified by Phases 52-59, plus the 6 resume test files carrying the Phase 59 syntax fix, plus 8 pre-existing untracked Phase 52-59 reports. After this phase: the same 5 employer files (now carrying this phase's additional diff), the 6 resume test files (unchanged by this phase), and the 9 pre-existing untracked reports (including this one). No unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. The Phase 52-59 fixes (conditional required fields, education/work-mode option lists, experience range fields, Contract Duration conditional visibility, Application Contact and Age Limit validation) were all re-verified still passing in the same test runs (§6) — none were reverted, weakened, or altered by this phase.

---

**This phase is complete.** Not starting Phase 61 without explicit approval.
