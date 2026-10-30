# Phase 62 — Employer Job Posting: Complete Validation Parity Audit

## 1. Executive summary

Phases 52-61 closed every category-specific requiredness gap, the education/experience/contract-duration/application-contact/age-limit rules, and 5 of the 10 `TEXT_FIELD_RULES` fields. Re-inspecting the current source (not assuming prior reports still hold) found:

- **Phase 61's own 5 remaining `TEXT_FIELD_RULES` fields** (`title`, `location`, `certifications`, `software_skills`, `language_requirements`) are **all still unimplemented** in Flutter — confirmed by direct source reading, not by absence of a helper name.
- **A new, higher-priority confirmed gap**: Salary (`salary_min`/`salary_max`) has **zero format validation** in Flutter — no decimal rejection, no format-specific min/max bounds, no min-greater-than-max cross-check — despite the server enforcing all three. This was not named in any Phase 56-61 directive and had not previously been audited.
- **A second new confirmed gap**: `openings` accepts `0` and negative integers locally; the server rejects anything below `1`.
- **One suspected gap, now ruled out by direct verification**: `interview_mode_other`/`notice_period_other` have no server-side "required when `others` is selected" rule at all — confirmed by reading `clean()` in full; this is correctly *not* implemented in Flutter and should not be treated as a gap.
- No regression was found in Phases 52-61's own work; every re-checked rule and its test coverage remains intact.

## 2. Scope and source files inspected

- **Flutter**: `lib/features/employer/presentation/screens/post_new_job_screen.dart` (read in full via targeted greps across every field reference, `_localRequiredErrors()`, `_submit()`, and every widget block), `lib/features/employer/domain/entities/job_posting_submission.dart`, `lib/features/employer/data/job_posting_catalog.dart`, `test/features/employer/presentation/screens/post_new_job_screen_test.dart`, `test/features/employer/data/job_posting_remote_datasource_test.dart`.
- **Django (read-only)**: `royalStaffing_CB01/jobs_app/forms.py` in full (re-read `TEXT_FIELD_RULES`, `text_field_error`, `_clean_text_field`, every `clean_<field>` method, `SALARY_RULES`, `_clean_salary_range`, `clean_openings`, `clean()`'s sheet-required loop and cross-field checks, `NON_IT_FIELDS`/`NON_IT_ALL_FIELDS`), `royalStaffing_CB01/templates/employer/job_form.html` (client-side mirrors).
- **Prior reports read**: `PHASE_56_EMPLOYER_JOB_POSTING_VALIDATION_AUDIT.md`, `PHASE_60_NON_IT_REQUIRED_FIELDS_REPORT.md`, `PHASE_61_TEXT_VALIDATION_REPORT.md` (and, by extension, the earlier Phase 52-55/57-59 reports these reference). `PHASE_51_FINAL_PARITY_MATRIX.md`/`PHASE_51_FINAL_AUDIT_REPORT.md`/`PHASE_51_FINAL_IMPLEMENTATION_ROADMAP.md` were not re-read in full this phase — the directive's Step 4 scopes the Phase 51 findings (landing-page popup, category-specific job browsing, protected Build Resume navigation) out unless directly relevant to employer-form validation, and none of those three topics touch job-posting field validation, so they are recorded in §9 as out of scope rather than re-audited.
- **`~/Downloads/CB_changes.docx`**: not re-read this phase — Phase 56 already confirmed its only relevant line is the generic "Changed Job Fields inside Employer portal," with no field-level detail; nothing suggests this has changed.
- **Verification performed this phase**: `flutter analyze` (full project) and `flutter test test/features/employer` + the focused screen test file were actually executed (see §8) to confirm the current working tree matches Phase 61's reported baseline before auditing further. The complete `flutter test` run was **not** re-executed this phase (Phase 61's own run, 2,635 passing, is cited as the last-confirmed full-suite figure, not re-verified here — see §8's explicit distinction).
- **Git working tree**: `git status --short` confirmed identical to Phase 61's end state (5 employer files + 6 unrelated pre-existing resume-test files modified, 10 untracked Phase 52-61 reports) before this audit began, and remains identical after it (only this new report added).

## 3. Complete field inventory and parity matrix

| Field | Shown (category) | Required | Format/range rule | Flutter status | Evidence |
|---|---|---|---|---|---|
| `job_category` | All | Yes | — | Complete | `_localRequiredErrors()` |
| `job_classification` | Non-IT | Yes (widget-level) | — | Complete | Dropdown's own required validator |
| `department` | Non-IT×Technical | Yes | Must match classification | Complete | Phase 52 |
| `department_function` | Non-IT×Non-Technical | Yes | `TEXT_FIELD_RULES` | Complete | Phase 60 (required) + Phase 61 (format) |
| `designation` | Non-IT | No | Must match classification's allowed list | Complete (pre-existing) | `kDesignationOptions` filtered by classification |
| `industry_sector` | Non-IT (both) | Yes | `TEXT_FIELD_RULES` | Complete | Phase 60 + 61 |
| `title` | All | Yes (presence) | `TEXT_FIELD_RULES` **not implemented** | **Partial** | §4 |
| `job_type` | IT | Yes | Options list | Complete | Phase 52 |
| `contract_duration_months` | Conditional (`job_type`/`employment_type` == `contract`) | Conditional | 1-12, whole number, 5 distinct messages | Complete | Phase 57 |
| `employment_type` | Non-IT (both) | Yes | Options list | Complete | Phase 52 |
| `experience` / `experience_years` / `experience_plus` / `experience_years_max` | All | Yes (preset or custom) | 0-99, mutual exclusivity | Complete | Phase 55 |
| `location` | All | Yes (presence) | `TEXT_FIELD_RULES` **not implemented** | **Partial** | §4 |
| `education` / `education_other` | All (optional for IT) | Non-IT: yes | Category-specific option lists + custom-text rules | Complete | Phase 53/54 |
| `functional_skills` | Non-IT×Non-Technical | Yes | `TEXT_FIELD_RULES` | Complete | Phase 60 + 61 |
| `industry_experience` | Non-IT (both) | Technical only | `TEXT_FIELD_RULES` (applies on both sheets regardless of requiredness) | Complete | Phase 60 + 61 |
| `working_hours` | Non-IT (both) | Yes | None in source | Complete | Phase 60 (no format rule exists to implement) |
| `salary_format` | All | Yes | Options list | Complete | Pre-existing |
| `salary_min` / `salary_max` | All | Yes (presence only) | **Format-specific min/max, integer-only, min≤max — none implemented** | **Missing** | §5.A |
| `openings` | All | Yes | **Must be ≥ 1 — only non-numeric rejected, 0/negative accepted** | **Partial** | §5.B |
| `perks` | All | No | — | Complete (optional, no rule) | — |
| `description` | All | Yes (presence) | None in source | Complete | — |
| `requirements` | IT | No | None in source | Complete (optional) | — |
| `responsibilities` | Non-IT (both) | Yes | None in source (no `TEXT_FIELD_RULES` entry) | Complete | Phase 60 |
| `certifications` | Non-IT (both) | No | `TEXT_FIELD_RULES` **not implemented** | **Partial** | §4 |
| `software_skills` | Non-IT×Non-Technical | No | `TEXT_FIELD_RULES` **not implemented** | **Partial** | §4 |
| `language_requirements` | Non-IT×Non-Technical | No | `TEXT_FIELD_RULES` **not implemented** (letters-only, no digits at all) | **Partial** | §4 |
| `keywords` | Non-IT (both) | Yes | `TEXT_FIELD_RULES` | Complete | Phase 60 + 61 |
| `application_contact` | Non-IT (both) | Yes | 3-way email/phone/name, multi-separator | Complete | Phase 58 |
| `skills` / `mandatory_skills` | IT (optional) / Non-IT×Technical (required, department-scoped) | Varies | 3-4 mandatory count, department-scoped list, custom-skill character rule | Complete (pre-existing) | `kMandatorySkillsMin`/`Max`, line ~457's count check — see §5.C for one sub-rule not independently re-verified |
| `deadline` | IT | No | Date format | Complete (optional) | — |
| `status` | IT | Yes | Options list | Complete | — |
| `work_environment` | IT | Yes | Options list | Complete | Phase 52 |
| `interview_mode` / `interview_mode_other` | IT | Yes / **never required** | — | Complete | §5.D (confirms "other" text is correctly *not* required, matching source) |
| `work_mode` | Non-IT (both) | Yes | Classification-specific option list | Complete | Phase 52 |
| `joining_requirement` | Non-IT×Non-Technical | Yes | Options list | Complete | Phase 52 |
| `notice_period` / `notice_period_other` | IT + Non-IT×Technical | Yes / **never required** | — | Complete | §5.D |
| `gender_preference` | IT (required) / Non-IT (optional, "if applicable") | Varies | Options list | Complete | Phase 52 |
| `age_limit` | Non-IT (both) | No | `N`/`N+`/`N-M`/`N-M+`, 1-99 | Complete | Phase 59 |

## 4. Detailed findings for the five remaining text-validation fields

Re-verified directly in `jobs_app/forms.py` this phase (lines cited are current, re-read line numbers):

| Field | `TEXT_FIELD_RULES` entry? | Allowed chars | Min letters | Long-digit rule | Exact message | Flutter |
|---|---|---|---|---|---|---|
| `title` | Yes (`forms.py:106-107`) | `A-Za-z0-9 .,&/()'\-+#` | 2 | **Yes** | "Job Title should contain a valid job title and should not contain only numbers or special characters." | **Missing** — `_localRequiredErrors()` has no character check; `title`'s validator (`Validators.required(v) ?? _fieldErrors['title']`) *would* display a message if one were added to `_fieldErrors['title']`, so the error-display plumbing already exists and needs no new work, only the check itself. |
| `location` | Yes (`forms.py:124-125`) | `A-Za-z0-9 .,&/()'\-` | 2 | No | "Location should contain a valid place name (e.g. Hyderabad, Telangana) and should not contain only numbers or special characters." | **Missing** — identical situation to `title`: the validator already folds `_fieldErrors['location']` in, just never populated. |
| `certifications` | Yes (`forms.py:114-115`) | `A-Za-z0-9 .,&/()'\-+` | 2 | No | "Required Certifications should contain valid certification names and should not contain only numbers or special characters." | **Missing**, and **no `_fieldError('certifications')` slot exists at all** — unlike `title`/`location`, a format error here currently has nowhere to render even generically. |
| `software_skills` | Yes (`forms.py:118-119`) | `A-Za-z0-9 .,&/()'\-+#` | 2 | No | "Software / MS Office Skills should contain valid software names and should not contain only numbers or special characters." | **Missing**, same no-error-slot situation as `certifications`. |
| `language_requirements` | Yes (`forms.py:120-121`) | `A-Za-z .,&/()'\-` (**no digits at all** — the only field among all 10 `TEXT_FIELD_RULES` entries that excludes `0-9`) | 2 | No (irrelevant — digits are already fully disallowed) | "Language Requirements should contain language names only." | **Missing**, same no-error-slot situation. |

All 5 use `_clean_text_field` with no field-specific override (`forms.py:940-949`), confirmed identical execution order and whitespace normalisation (`re.sub(r'\s+', ' ', value).strip()`) to the 5 fields Phase 61 already implemented. None of these 5 is required to be reproduced with any different mechanism than Phase 61's own `_textFieldError`/`_normaliseFreeText` helpers — the same pattern applies directly, just with each field's own chars/message.

No test exists for any of these 5 fields' character rules (`grep` for each exact message string in the test file returned zero matches).

## 5. Additional confirmed validation gaps (outside the named 5-field scope)

### A. Salary (`salary_min`/`salary_max`) — confirmed, high priority

`forms.py:412-422` (`SALARY_RULES`) + `forms.py:645-663` (`_clean_salary_range`):
```python
SALARY_RULES = {
    'monthly': {'label': 'Salary', 'min': 1000, 'max': 999999, 'integer': True, ...
                'ceiling_message': 'Salary must not exceed ₹9,99,999 per month (6 digits).'},
    'lpa': {'label': 'LPA', 'min': 1, 'max': 99, 'integer': True, ...
            'ceiling_message': 'LPA must not exceed 99 LPA (2 digits).'},
}

def _clean_salary_range(self, field_name, bound):
    ...
    if rules['integer'] and value != value.to_integral_value():
        raise forms.ValidationError(f'{label} must be a whole number (no decimals).')
    if value < rules['min']:
        raise forms.ValidationError(f'{label} must be at least {rules["fmt"](rules["min"])}.')
    if value > rules['max']:
        raise forms.ValidationError(rules['ceiling_message'] or ...)
```
Plus `forms.py:726-731` (`clean()`): `if s_min > s_max: add_error('salary_min', f'Minimum {label} must not be greater than Maximum {label}.')`.

**Current Flutter** (`post_new_job_screen.dart`): `_localRequiredErrors()` only has `if (_salaryMin.text.trim().isEmpty) errors['salary_min'] = 'Minimum Salary is required.';` (and the max equivalent) — no decimal check, no format-specific min/max bound, no cross-field comparison. A value like `500` (monthly, below the ₹1,000 floor), `50.5` (a decimal), `9999999` (above the ceiling), or `salary_min=50000 > salary_max=30000` all currently pass Flutter's local validation and would only be caught on a server round trip. This field is required and shown for **every** posting regardless of category — the single highest-traffic unvalidated field found in this audit. No test covers any of these cases.

### B. `openings` lower bound — confirmed, medium priority

`forms.py:951-958` (`clean_openings`): `if value is not None and value < 1: raise forms.ValidationError('Openings must be 1 or greater.')` — the widget's own `min="1"` HTML attribute is explicitly a client-side-only hint (the form carries `novalidate`), so this server check is the sole enforcement on the real page too.

**Current Flutter**: `if (int.tryParse(_openings.text.trim()) == null) errors['openings'] = 'Please enter a valid numeric value.';` — `int.tryParse('0')` and `int.tryParse('-5')` both return non-null, so `0` and negative values currently pass local validation. No test covers this boundary (the existing Phase 11 regression test covers a *different* scenario — a `null` scraped value showing blank rather than a guessed `1` — not the `0`/negative case).

### C. Mandatory-skills / custom-skill sub-rules — not independently re-verified, low priority, needs further verification

`forms.py:762-769` applies `custom_skill_error()` (its own character/length rule, distinct from `TEXT_FIELD_RULES`) to employer-typed custom IT skills, and a combined-length cap on `skills_required`. Flutter's skill-picker UI (`_toggleSkill`, the mandatory-count check at line ~457) was confirmed to exist and enforce the 3-4 mandatory count, but this audit did not trace whether Flutter also reproduces `custom_skill_error`'s own character rule for employer-typed custom skills, since that is a separate, older subsystem (apparently pre-dating Phase 52) not named in any Phase 52-61 directive. **Confidence: needs further verification** — flagged for a future, narrowly-scoped audit of the custom-skill-typing path specifically, not claimed as a confirmed gap here.

### D. `interview_mode_other` / `notice_period_other` — verified NOT a gap

Grepped and read every reference to both fields in `forms.py`'s `clean()` (lines 840-871): both are only ever *cleared* (`cleaned['interview_mode_other'] = ''`) when their parent field is hidden/inapplicable for the posting's category. **No `clean_interview_mode_other`/`clean_notice_period_other` method exists, and no "required when parent == 'others'" check exists anywhere in the source.** Flutter correctly has no local requiredness check for either — this was worth explicitly re-verifying (an earlier internal note from this engagement's own history had flagged it as a suspected gap) but direct source reading rules it out. Recorded here per the directive's instruction not to claim a mismatch from the absence of a helper name without tracing the actual execution path.

## 6. Regression review of Phases 52-61

Re-read the current `_localRequiredErrors()`/`_submit()`/widget code for every rule each phase introduced, and re-ran the focused and employer-scoped test suites (§8) to confirm continued passing, rather than assuming the prior reports' narrative still holds:

| Phase | Area | Re-verified in source | Re-verified by test run | Regression found |
|---|---|---|---|---|
| 52 | Category-specific required fields, work-mode options | Yes | Yes (160/160 focused, 273/273 employer) | None |
| 53 | Education requiredness | Yes | Yes | None |
| 54 | Education options, custom qualification validation | Yes | Yes | None |
| 55 | Experience range, "10+"/max mutual exclusivity | Yes | Yes | None |
| 57 | Conditional Contract Duration | Yes | Yes | None |
| 58 | Application Contact validation | Yes | Yes | None |
| 59 | Age Limit validation | Yes | Yes | None |
| 60 | Non-IT required-field parity | Yes | Yes | None |
| 61 | Field-specific text validation (5 fields) | Yes | Yes | None |

No apparent regression or newly-exposed boundary case was found in any of these 9 phases' own work. The gaps recorded in §4-5 are all **additions** to scope that these phases' own directives explicitly excluded (Phase 61's own report named `title`/`location`/`certifications`/`software_skills`/`language_requirements` as reserved for a future phase; salary/openings were never named in any Phase 52-61 directive at all).

## 7. Prioritized implementation recommendations

| # | Field/behavior | Django source | Flutter source | Current behavior | Expected behavior | Example | Test coverage | Recommended action | Priority | Confidence |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `salary_min`/`salary_max` format/range/cross-check | `forms.py:412-422,645-663,726-731` | `post_new_job_screen.dart` `_localRequiredErrors()` (no format check) | Only presence is checked | Reject decimals, format-specific min/max, reject min > max | `salary_min=500` (monthly) passes locally, server rejects (`< 1000`) | None | Implement a Phase-61-style helper mirroring `_clean_salary_range` + the cross-check | **High** | Confirmed |
| 2 | `openings` lower bound | `forms.py:951-958` | `_localRequiredErrors()`'s `int.tryParse(...) == null` check | `0`/negative accepted | Reject `< 1` with `'Openings must be 1 or greater.'` | `openings=0` passes locally, server rejects | None | Add a `< 1` check alongside the existing parse check | **Medium** | Confirmed |
| 3 | `title` character rule | `forms.py:106-107` | No character check (validator slot already exists) | Any character accepted once non-empty | `TEXT_FIELD_RULES` chars/min-letters/no-long-digits | `title="12345"` passes locally, server rejects | None | Apply Phase 61's `_textFieldError` pattern to `title`, feeding `_fieldErrors['title']` | **Medium** | Confirmed |
| 4 | `location` character rule | `forms.py:124-125` | No character check (validator slot already exists) | Same as above | Same pattern | `location="###"` passes locally, server rejects | None | Same pattern as `title` | **Medium** | Confirmed |
| 5 | `certifications`/`software_skills`/`language_requirements` character rules + missing error slots | `forms.py:114-121` | No character check, no `_fieldError(...)` slot for any of the 3 | Any character accepted; a hypothetical server rejection has nowhere to render inline either | `TEXT_FIELD_RULES` chars/min-letters; add the missing `_fieldError` slots | `language_requirements="123"` passes locally (digits aren't even excluded client-side) | None | Implement the 3 character rules and add their 3 missing `_fieldError` slots in the same pass | **Low-Medium** (all 3 are optional fields, lower traffic than title/location/salary) | Confirmed |
| 6 | Custom IT skill character rule (`custom_skill_error`) | `forms.py:762-769` | Unverified this phase | Unknown | Match `custom_skill_error`'s own rule | Not demonstrated | Unknown | Scope a dedicated audit of the custom-skill-typing path before implementing | **Low** | Needs further verification |

Recommended next phase: **salary format/range validation (item 1)**, on its own grounds that it's the single highest-traffic field with zero format enforcement, followed by `openings` (item 2, small and mechanically simple), then the 5-field text-validation follow-up (items 3-5, directly extending Phase 61's own established pattern).

## 8. Existing test coverage and verification limitations

- **Newly executed this phase**: `flutter analyze` (full project) → 0 issues, matching Phase 61's reported baseline exactly. `flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart` → 160 passing, 0 failing, matching Phase 61 exactly. `flutter test test/features/employer` → 273 passing, 0 failing, matching Phase 61 exactly. These 3 runs confirm the working tree has not drifted from Phase 61's end state.
- **Not re-executed this phase**: the complete `flutter test` run (2,635 passing per Phase 61's own report) — not re-run here, since the audit made no code change and the employer-scoped run already confirms no drift in the area this audit concerns; citing 2,635 as a historical, not newly-verified, figure.
- **No device or live-server verification** was performed or claimed, consistent with this phase's audit-only scope.
- **No test exists** for any of the gaps recorded in §4-5 (confirmed by grepping the test file for each field's exact message string — zero matches in every case).

## 9. Explicit items outside the scope of this audit

- Phase 51's landing-page popup, category-specific job browsing, and protected Build Resume navigation findings — none relate to employer job-posting field validation or submission, per direct inspection of what those topics cover; not re-audited here.
- Any area of the application outside the employer job-posting form (student/candidate flows, resume parsing, AI interview, subscription gating, etc.).
- `CB_changes.docx`'s other 14 checklist items — unrelated to job-posting field validation, not re-read this phase (Phase 56 already established this).
- Actually implementing any of the gaps recorded in §5 and §7 — this phase is audit-only, per its own explicit completion boundary.

## 10. Confirmation: no source code, tests, backend files, or existing reports were changed

No file under `lib/`, `test/`, or any Django directory was created, edited, or deleted during this audit. No existing report (`docs/PHASE_51_*.md` through `docs/PHASE_61_*.md`) was modified. The only file created this phase is this report, `docs/PHASE_62_EMPLOYER_VALIDATION_PARITY_AUDIT.md`.

## 11. Confirmation: both Django reference directories remained untouched

Both `royalStaffing_CB01` and `Career_Buddy_LMS` were read-only throughout — only `grep`/`sed -n` were used against `jobs_app/forms.py` and `templates/employer/job_form.html`; no file in either tree was created, edited, deleted, or renamed.

## 12. Confirmation: unrelated working-tree changes were preserved

`git status --short` before and after this audit is identical except for the addition of this one new report file: the same 5 employer files already modified by Phases 52-61, the same 6 pre-existing `test/features/resume/...` files carrying the Phase 59 syntax fix, and the same 10 pre-existing untracked Phase 52-61 reports. Nothing was reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found; no credential, token, keystore, or signing material was inspected, printed, or modified; no build was published and no signing configuration was touched.

---

**This phase is complete. Awaiting explicit approval before implementing any recommendation above or starting Phase 63.**
