# Phase 56 — Employer Job Posting Validation Audit (Audit Only)

## 1. Audit scope and safety boundaries

Read-only audit of four remaining employer job-posting validation gaps in the Flutter mobile app, against the updated Django reference (`royalStaffing_CB01`): (A) general text-field validation, (B) age-limit validation, (C) application-contact validation, (D) contract duration and conditional visibility. **No application code, test, or Django source file was modified during this phase.** The only file created is this report. Both Django trees were read with `grep`/`sed -n`/`Read` only.

## 2. Baseline working-tree status

`git status --short` in `Mobile_app` at the start of this phase:
```
 M lib/features/employer/data/job_posting_catalog.dart
 M lib/features/employer/domain/entities/job_posting_submission.dart
 M lib/features/employer/presentation/screens/post_new_job_screen.dart
 M test/features/employer/data/job_posting_remote_datasource_test.dart
 M test/features/employer/presentation/screens/post_new_job_screen_test.dart
?? docs/PHASE_52_NONIT_JOB_POSTING_FIX_REPORT.md
?? docs/PHASE_53_NONIT_EDUCATION_VALIDATION_REPORT.md
?? docs/PHASE_54_EDUCATION_OPTIONS_CUSTOM_VALIDATION_REPORT.md
?? docs/PHASE_55_EXPERIENCE_RANGE_FIELDS_REPORT.md
```
This exactly matches the state left at the end of Phase 55 — the cumulative, uncommitted work of Phases 52-55. Nothing was reset, stashed, or overwritten. This report (`docs/PHASE_56_...md`) did not already exist; it is the sole new file this phase produces.

`CB_changes.docx` (`~/Downloads/CB_changes.docx`) was accessible and read (`textutil -convert txt -stdout`). It contains a 15-item, high-level feature checklist (landing page, IT/Non-IT browsing, resume parsing, AI interview, skill-up, malpractice controls, subscription gating). Item 5 is the only one touching this audit's scope: "Changed Job Fields inside Employer portal" — a one-line summary with no field-level detail, already fully superseded by the Phase 51 audit and Phases 52-55's own direct source reading. No new information relevant to text-field rules, age-limit, application-contact, or contract-duration was found in this document.

## 3. Source files and functions inspected

- **Django (read-only)**: `royalStaffing_CB01/jobs_app/forms.py` — `TEXT_FIELD_RULES`, `text_field_error`, `contact_part_error`, `AGE_LIMIT_RE`/`AGE_LIMIT_MESSAGE`, `PHONE_PART_RE`/`CONTACT_NAME_RE`/`CONTACT_MESSAGE`, `JobPostingForm.NON_IT_FIELDS`/`NON_IT_ALL_FIELDS`, `_clean_text_field`, `clean_title`/`clean_department_function`/`clean_industry_sector`/`clean_industry_experience`/`clean_certifications`/`clean_functional_skills`/`clean_software_skills`/`clean_language_requirements`/`clean_keywords`/`clean_location`, `clean_age_limit`, `clean_application_contact`, `clean_contract_duration_months`, `CONTRACT_DURATION_MAX`, the `__init__` error-message overrides for `experience_years`/`experience_years_max`/`contract_duration_months`, and the `clean()` method's sheet-field keep/required/blank logic and its `job_type == 'contract'` block.
- **Django (read-only)**: `royalStaffing_CB01/jobs_app/models.py` — `JobPosting.JOB_TYPE_CHOICES`, `TECH_EMPLOYMENT_TYPE_CHOICES`, and every relevant `CharField`'s `max_length`/`blank` (`location`, `industry_sector`, `industry_experience`, `certifications`, `working_hours`, `age_limit`, `keywords`, `application_contact`, `department_function`, `functional_skills`, `software_skills`, `language_requirements`, `title`, `description`, `requirements`).
- **Django (read-only)**: `royalStaffing_CB01/templates/employer/job_form.html` — the contract-duration markup/JS (`contract-duration-wrap`, `toggleDuration`, `isContract`, `validateDuration`, the IT-reset block's `clearFieldValue('contract_duration_months')`), and the `AGE_LIMIT_RE`/`CONTACT_MESSAGE` client-side mirrors noted in Phase 54's investigation (re-confirmed present, not re-read in full this phase since their content was already fully captured).
- **Flutter**: `lib/features/employer/presentation/screens/post_new_job_screen.dart` (`_localRequiredErrors()` in full; the `title`/`location`/`description` field validators; the `application_contact`/`age_limit`/`contract_duration_months` widget blocks; `_onCategoryChanged`/`_onClassificationChanged`), `lib/features/employer/domain/entities/job_posting_submission.dart`, `lib/features/employer/data/job_posting_catalog.dart` (`kEmploymentTypeOptions`, `kJobTypeOptions`), `lib/core/validators/validators.dart` (confirmed no job-posting text-field character-rule equivalent exists there), `lib/shared/widgets/app_text_field.dart` (confirmed it exposes no `maxLength` parameter at all).
- **Tests**: `test/features/employer/presentation/screens/post_new_job_screen_test.dart`, `test/features/employer/data/job_posting_remote_datasource_test.dart` — searched for any existing coverage of `age_limit`, `application_contact`, `contract_duration`/`Project Duration`, `title`/`location` character rules (none found — see §6).

## 4. Exact Django rules and references

### A. General text-field validation

`TEXT_FIELD_RULES` (`forms.py:104-118`) is applied via `text_field_error()` (`forms.py:133-145`) and each field's own `clean_<name>` → `_clean_text_field(name)` (`forms.py:597-602`). For a non-empty value: whitespace is collapsed/trimmed (`re.sub(r'\s+', ' ', value).strip()`) **before** character-class matching; must match `^[<chars>]+$` or the field's own message fires; must contain at least `min_letters` letters (numeric/symbol-only input refused); and, when `no_long_digits` is true, a standalone run of 3+ digits is refused even if otherwise valid (e.g. "Manager12345").

| Field | Label | Allowed chars (regex class) | min_letters | no_long_digits | Message |
|---|---|---|---|---|---|
| `title` | Job Title | `A-Za-z0-9 .,&/()'\-+#` | 2 | **yes** | "Job Title should contain a valid job title and should not contain only numbers or special characters." |
| `department_function` | Department / Function | `A-Za-z0-9 .,&/()'\-` | 2 | yes | "Department / Function should contain a valid name and should not contain only numbers or special characters." |
| `industry_sector` | Industry / Sector | `A-Za-z0-9 .,&/()'\-` | 2 | yes | "Industry / Sector should contain a valid industry name and should not contain only numbers or special characters." |
| `industry_experience` | Industry Experience | `A-Za-z0-9 .,&/()'\-+` | 2 | no | "Industry Experience should describe the relevant experience and should not contain only numbers or special characters." |
| `certifications` | Required Certifications | `A-Za-z0-9 .,&/()'\-+` | 2 | no | "Required Certifications should contain valid certification names and should not contain only numbers or special characters." |
| `functional_skills` | Functional Skills | `A-Za-z0-9 .,&/()'\-+#` | 2 | no | "Functional Skills should contain valid skill names and should not contain only numbers or special characters." |
| `software_skills` | Software / MS Office Skills | `A-Za-z0-9 .,&/()'\-+#` | 2 | no | "Software / MS Office Skills should contain valid software names and should not contain only numbers or special characters." |
| `language_requirements` | Language Requirements | `A-Za-z .,&/()'\-` (**letters only, no digits**) | 2 | no | "Language Requirements should contain language names only." |
| `keywords` | Key Skills / Keywords | `A-Za-z0-9 .,&/()'\-+#` | 2 | no | "Key Skills / Keywords should contain valid keywords and should not contain only numbers or special characters." |
| `location` | Job Location | `A-Za-z0-9 .,&/()'\-` | 2 | no | "Location should contain a valid place name (e.g. Hyderabad, Telangana) and should not contain only numbers or special characters." |

- `responsibilities` and `working_hours` have **no** `TEXT_FIELD_RULES` entry and no `clean_<name>` method (confirmed by grep — no match) — only the generic required/blank handling below applies to them; no character-class rule exists for either.
- **Required vs. optional** comes entirely from `NON_IT_FIELDS` (`forms.py:276-307`), not from the character rules above:

  | Classification | Required | Optional |
  |---|---|---|
  | Non-IT × Technical | `industry_sector`, `industry_experience`, `responsibilities`, `working_hours`, `keywords`, `application_contact` | `certifications`, `age_limit` |
  | Non-IT × Non-Technical | `department_function`, `functional_skills`, `industry_sector`, `responsibilities`, `working_hours`, `keywords`, `application_contact` | `industry_experience`, `certifications`, `software_skills`, `language_requirements`, `age_limit` |

  For IT, every field in `NON_IT_ALL_FIELDS` (`forms.py:313-316` — the same 12 fields) is blanked (`forms.py`'s `clean()`: "for name in self.NON_IT_ALL_FIELDS: if name not in keep: cleaned[name] = ''"). IT never shows or requires any of them.
- `title`: required at the model level (`models.py:153`, `CharField(max_length=200)`, no `blank=True`) — applies to every category. `location`: also required at the model level (`models.py:177`, same pattern, no `blank=True`) — applies to every category (confirmed distinct from the `NON_IT_FIELDS`-gated set, since `location` is never in `NON_IT_ALL_FIELDS`).
- **Length**: every field above has a model `max_length` (`title` 200, `department_function` 100, `industry_sector` 100, `industry_experience` 200, `certifications` 300, `functional_skills` 300, `software_skills` 300, `language_requirements` 200, `keywords` 300, `location` 200, `working_hours` 100, `age_limit` 50, `application_contact` 200) enforced by Django's automatic `ModelForm` `MaxLengthValidator`. **None of these widgets carry an HTML `maxlength` attribute in `job_form.html`** (confirmed — only the education/salary/openings/custom-skill/experience inputs do), so even the real web page does not cap these client-side; the length cap is a server-only backstop, not a UI rule to mirror pixel-for-pixel.

### B. Age-limit validation

`age_limit` (`models.py:143`, `max_length=50`, `blank=True` → optional) — `clean_age_limit` (`forms.py:604-613`):
```python
AGE_LIMIT_RE = re.compile(r'^(\d{1,2})(?:\s*-\s*(\d{1,2}))?\+?$')
AGE_LIMIT_MESSAGE = 'Please enter a valid numeric age limit, e.g. 25 or 25-35.'

def clean_age_limit(self):
    value = (self.cleaned_data.get('age_limit') or '').strip()
    if not value:
        return ''
    m = AGE_LIMIT_RE.match(value)
    if not m:
        raise forms.ValidationError(AGE_LIMIT_MESSAGE)
    low, high = int(m.group(1)), m.group(2)
    if low < 1 or (high is not None and (int(high) < 1 or int(high) < low)):
        raise forms.ValidationError(AGE_LIMIT_MESSAGE)
    return re.sub(r'\s*-\s*', '-', value)
```
- **Optional** — empty is always valid, every category.
- **Format**: a 1-2 digit number (`25`), optionally a range (`25-35`), and an optional trailing `+` on either form (`25+`, `25-35+` are both structurally accepted by the regex). No decimal point is accepted (the regex has no `.`, so e.g. `25.5` falls straight to the generic `AGE_LIMIT_MESSAGE`).
- **Range**: 1-99 (2-digit cap from the regex); `0` is explicitly rejected (`low < 1`); a range's high end must also be `>= 1` and `>= low`.
- **Normalisation**: whitespace around the `-` is collapsed to a bare `-` (`"25 - 35"` → `"25-35"`); the value is otherwise stored as typed (including a trailing `+`).
- **Category**: part of `NON_IT_FIELDS`'s **optional** list for *both* Non-IT sheets (§A table) — never shown or validated for IT.
- **Flutter**: shown for `_isNonIt` with no local format validation at all, and — distinct from every other free-text field on this screen — **no `_fieldError('age_limit')` call exists**, so even a server-side rejection of an invalid value has nowhere to render inline; only the generic top-of-form banner (`_generalError`) would appear.

### C. Application-contact validation

`application_contact` (`models.py:145`, `max_length=200`, `blank=True`) — `clean_application_contact` (`forms.py:616-623`) + `contact_part_error` (`forms.py:147-162`):
```python
PHONE_PART_RE = re.compile(r'^\+?[\d\s().\-]{7,20}$')
CONTACT_NAME_RE = re.compile(r"^[A-Za-z .'\-]+$")
CONTACT_MESSAGE = 'Application Contact should be a valid email address, phone number or contact name.'

def contact_part_error(part):
    part = part.strip()
    if not part: return ''
    if '@' in part:
        try: validate_email(part); return ''
        except forms.ValidationError: return CONTACT_MESSAGE
    digits = re.sub(r'\D', '', part)
    if digits and PHONE_PART_RE.match(part):
        return '' if 7 <= len(digits) <= 15 else CONTACT_MESSAGE
    if CONTACT_NAME_RE.match(part) and len(re.findall(r'[A-Za-z]', part)) >= 2:
        return ''
    return CONTACT_MESSAGE

def clean_application_contact(self):
    value = re.sub(r'\s+', ' ', self.cleaned_data.get('application_contact') or '').strip()
    if not value: return ''
    parts = [p for p in re.split(r'[,/|;]', value) if p.strip()]
    if not parts or any(contact_part_error(p) for p in parts):
        raise forms.ValidationError(CONTACT_MESSAGE)
    return value
```
- **Not phone-only or email-only** — confirmed by direct reading: a part is accepted if it's a valid email (Django's `validate_email`), **or** a phone-shaped string (`+`, digits, spaces, `()`, `.`, `-`, 7-20 raw characters) whose digit count is 7-15, **or** a plain name (letters/spaces/`.`/`'`/`-` only, at least 2 letters).
- **Multiple contacts**: the whole field may contain several entries separated by `,`, `/`, `|`, or `;`; **every** part must independently pass, or the whole field is rejected with one message (`CONTACT_MESSAGE`).
- **Required vs. optional**: empty is accepted (`if not value: return ''`) at the field-clean level, **but** `application_contact` is in `NON_IT_FIELDS`'s **required** list for *both* Non-IT sheets (§A table) — so the form-level `clean()` adds `'This field is required.'` (`forms.py`'s generic sheet-required loop) whenever it's blank on a Non-IT posting. It is effectively optional only for IT, where it is blanked/unused entirely.
- **Normalisation**: whitespace collapsed/trimmed before splitting; the stored value is the normalised whole string (not reformatted per-part).
- **Flutter**: shown for `_isNonIt`, has a `_fieldError('application_contact')` display slot already wired (so a *server* rejection would render inline correctly), but **no local required-ness check and no local format validation at all** — `_localRequiredErrors()` has never included `application_contact`, in any phase through 55.

### D. Contract duration and conditional visibility

`contract_duration_months` (an `IntegerField`, `forms.py:355-358`'s widget comment: "Shown only when job_type == 'contract'; whole months, 2 digits, max 12"):
- **Field-level** (`forms.py:566-569`): `error_messages` overridden to `'invalid'` → "Enter the project duration as a whole number of months.", `'min_value'` → "Project duration cannot be negative." (implies a `MinValueValidator(0)`).
- **Field-level clean** (`forms.py:468-473`, `CONTRACT_DURATION_MAX = 12`): if provided and `> 12` → "Project duration cannot exceed 12 months."
- **Form-level `clean()`** (`forms.py:898-907`):
  ```python
  if cleaned.get('job_type') == 'contract':
      duration = cleaned.get('contract_duration_months')
      if 'contract_duration_months' not in self.errors:
          if duration is None:
              self.add_error('contract_duration_months', 'Enter the project duration in months.')
          elif duration < 1:
              self.add_error('contract_duration_months', 'Project duration must be at least 1 month.')
  else:
      cleaned['contract_duration_months'] = None
  ```
- **Which job types/conditions show it**: the comment "Contract postings must state a project duration (IT and both NON-IT sheets)" plus `job_form.html`'s own `isContract()` (`job_form.html:935-938`):
  ```js
  function isContract() {
      const sel = isNonItSheet() ? employmentSelect : jobTypeSelect;
      return Boolean(sel && sel.value === 'contract');
  }
  ```
  confirms this is reachable from **all three** category/classification combinations, not IT-only: IT reads `job_type` (`JOB_TYPE_CHOICES` includes `'contract'`, `models.py:30-33`); **both** Non-IT sheets read the single shared `employment_type` field instead (`TECH_EMPLOYMENT_TYPE_CHOICES = [('permanent', ...), ('contract', ...), ('project', ...)]`, `models.py:36-38`, explicitly commented "'contract' is shared with the IT list so the duration logic is the same" — and this is the one, single `employment_type` field used by both Non-IT Technical and Non-IT Non-Technical, per `forms.py:223`, not a classification-split pair like `work_mode`).
- **Required when shown**: yes (`'Enter the project duration in months.'` if blank while contract is selected).
- **Numeric limits**: whole number, `>= 1`, `<= 12`.
- **Behavior when hidden**: `job_form.html`'s `toggleDuration()` (`job_form.html:958-967`) **actively clears the input** (`durationInput.value = ''`) the instant the field becomes irrelevant, in addition to the server discarding it unconditionally (`cleaned['contract_duration_months'] = None` when `job_type != 'contract'`). So: hidden ⇒ cleared client-side immediately, AND discarded server-side regardless of what (if anything) survived — a value is never silently carried through to a job type it doesn't apply to.
- **Submission field name**: `contract_duration_months`, unchanged from Flutter's existing `JobPostingSubmission.contractDurationMonths`/payload key.
- **Flutter**: the "Project Duration (months)" / "Project / Contract Duration (months)" `AppTextField` is rendered **unconditionally** for every job type/employment type (not gated on `'contract'` at all), has a `_fieldError('contract_duration_months')` display slot (so a server rejection renders inline), but has **zero local validation** (no required-when-contract check, no `1-12` range check, no non-numeric check) and **zero clearing logic** on job-type/employment-type change — a value typed while a non-contract type was selected is never cleared client-side (though the server would still discard it on submit, so this is a UI-confusion gap, not a data-integrity one).

## 5. Flutter-versus-Django parity matrix

| Field / rule | Django source behavior | Current Flutter behavior | Status | Evidence | Recommended next action |
|---|---|---|---|---|---|
| `title` required | Required, all categories (`models.py:153`) | `Validators.required(v) ?? _fieldErrors['title']` on the field's own validator | **Complete** | `post_new_job_screen.dart` title `TextFormField` validator | — |
| `title` character rule | `TEXT_FIELD_RULES['title']`, incl. `no_long_digits` (§4A) | No local check | **Missing** | No matching logic in `_localRequiredErrors()` or the title validator | Add a shared text-rule helper mirroring `text_field_error()`, applied to `title` first (highest-traffic field) |
| `description` required | Required, all categories (`models.py:154`, no `blank=True`) | `Validators.required(v) ?? _fieldErrors['description']` | **Complete** | Same pattern as `title` | — |
| `location` required | Required, all categories (`models.py:177`) | `Validators.required(v) ?? _fieldErrors['location']` | **Complete** | Existing validator | — |
| `location` character rule | `TEXT_FIELD_RULES['location']` (§4A) | No local check | **Missing** | No matching logic found | Group with other `TEXT_FIELD_RULES` fields (see §8) |
| `department_function` required (Non-Technical only) | Required for Non-IT × Non-Technical, blanked elsewhere | No `_localRequiredErrors()` entry | **Missing** | `_localRequiredErrors()` full read, no `department_function` key | Add classification-gated required check, same pattern as Phase 52's `joining_requirement` |
| `department_function` character rule | `TEXT_FIELD_RULES['department_function']` | No local check | **Missing** | No matching logic | Group with text-rule fields |
| `industry_sector` required (both Non-IT sheets) | Required | No `_localRequiredErrors()` entry | **Missing** | Same | Add `_isNonIt`-gated required check |
| `industry_sector` character rule | `TEXT_FIELD_RULES['industry_sector']` | No local check | **Missing** | Same | Group with text-rule fields |
| `industry_experience` required (Technical only; optional for Non-Technical) | Classification-specific requiredness | No `_localRequiredErrors()` entry | **Missing** | Same | Add `_isNonItTech`-gated required check |
| `industry_experience` character rule | `TEXT_FIELD_RULES['industry_experience']` | No local check | **Missing** | Same | Group with text-rule fields |
| `responsibilities` required (both Non-IT sheets) | Required, no character rule | No `_localRequiredErrors()` entry | **Missing** | Same | Add `_isNonIt`-gated required check only (no character rule applies) |
| `working_hours` required (both Non-IT sheets) | Required, no character rule | No `_localRequiredErrors()` entry | **Missing** | Same | Add `_isNonIt`-gated required check only |
| `keywords` required (both Non-IT sheets) | Required | No `_localRequiredErrors()` entry | **Missing** | Same | Add `_isNonIt`-gated required check |
| `keywords` character rule | `TEXT_FIELD_RULES['keywords']` | No local check | **Missing** | Same | Group with text-rule fields |
| `certifications` (optional, both sheets) | Optional; character rule still applies if non-empty | No local check | **Partial** (correctly optional; character rule missing) | `_fieldError('certifications')` exists, but no `_localRequiredErrors` entry needed (correct) and no value-rule check (gap) | Add value-only character check (no requiredness needed) |
| `software_skills` (optional, Non-Technical only) | Optional; character rule if non-empty | No local check | **Partial** | Same pattern | Add value-only character check |
| `language_requirements` (optional, Non-Technical only) | Optional; **letters-only** character rule (no digits at all) | No local check | **Partial** | Same pattern; note the stricter letters-only class vs. other fields | Add value-only character check, using the distinct `A-Za-z .,&/()'\-` class |
| `functional_skills` required (Non-Technical only) | Required | No `_localRequiredErrors()` entry | **Missing** | Same | Add `_isNonItNonTech`-gated required check |
| `functional_skills` character rule | `TEXT_FIELD_RULES['functional_skills']` | No local check | **Missing** | Same | Group with text-rule fields |
| Max length (all 12 `NON_IT_ALL_FIELDS` + `title`/`location`) | Model `max_length` (50-300, §4A), server-only backstop (no HTML `maxlength` even on the real page) | No client cap anywhere (`AppTextField` has no `maxLength` param) | **Unverified / low priority** | `app_text_field.dart` constructor read in full, no `maxLength` param exists | Lowest priority — the web itself doesn't enforce this client-side either; only worth adding if a future phase adds `AppTextField.maxLength` for other reasons |
| `age_limit` optional + format | Optional; `N`, `N+`, `N-M`, `N-M+`; 1-99; no decimals (§4B) | Shown for Non-IT, no local format validation, **no `_fieldError('age_limit')` slot at all** | **Missing** | `post_new_job_screen.dart` age-limit widget block; grep confirms no `_fieldError('age_limit')` anywhere | Smallest fix: add `AGE_LIMIT_RE`-equivalent local validator **and** wire an `_fieldError('age_limit')` display slot (2 gaps in 1 field) |
| `application_contact` required (both Non-IT sheets) | Required | No `_localRequiredErrors()` entry | **Missing** | `_localRequiredErrors()` full read | Add `_isNonIt`-gated required check, exact message `'This field is required.'` |
| `application_contact` format (email/phone/name, multi-part) | §4C's 3-way OR rule, `,`/`/`/`|`/`;`-separated | No local format validation | **Missing** | Same | Port `contact_part_error`-equivalent logic |
| `contract_duration_months` conditional visibility | Shown only when `job_type`(IT)/`employment_type`(Non-IT) `== 'contract'` | **Shown unconditionally**, for every job type/category | **Missing** | Widget code has no `if (...=='contract')` gate at all | Wrap the field in a `_isContract` getter-gated conditional, mirroring `_educationPreset == 'custom'`'s pattern |
| `contract_duration_months` required-when-contract | `'Enter the project duration in months.'` if blank while contract | No `_localRequiredErrors()` entry | **Missing** | Same | Add gated required check |
| `contract_duration_months` range (1-12) | `< 1` → "must be at least 1 month."; `> 12` → "cannot exceed 12 months." | No local check | **Missing** | Same | Add range check with the 2 exact messages |
| `contract_duration_months` stale-value clearing | Cleared client-side the instant the field is hidden (`toggleDuration`); always discarded server-side regardless | No clearing logic at all (field never hidden in the first place) | **Missing** | Same | Clear the controller when the gating value changes away from `'contract'`, same pattern as Phase 52's `_onClassificationChanged` clears |
| `contract_duration_months` applies to Non-IT too (not IT-only) | Confirmed — both Non-IT sheets share `employment_type`'s `'contract'` option (§4D) | The field is at least visually present for Non-IT already (unconditional rendering), so once gated correctly it will naturally cover Non-IT too | **Missing** (dependent on the gate above) | `kEmploymentTypeOptions` already includes `'contract'` (Phase 52-era, unchanged) | Implement the gate as `_jobType == 'contract' || _employmentType == 'contract'`, not an IT-only check |

Phases 52-55 fixes verified still intact during this audit (re-read, not modified): `_isNonIt`/`_isNonItTech`/`_isNonItNonTech`-gated `work_mode`/`employment_type`/`joining_requirement`/`gender_preference`/`interview_mode`/`notice_period`/`work_environment`/`job_type` required checks (Phase 52); `education` required-for-both-Non-IT-sheets check (Phase 53); `kGeneralEducationPresets`/`kTechEducationPresets` split and `education_other` custom-text validation (Phase 54); `experience_plus`/`experience_years_max` state, validation, and the `Material`-wrapped `CheckboxListTile` (Phase 55) — all present in the current `post_new_job_screen.dart`, none altered by this audit.

## 6. Test coverage and verification results

`grep` across `test/features/employer/presentation/screens/post_new_job_screen_test.dart` and `test/features/employer/data/job_posting_remote_datasource_test.dart` for `age_limit`/`Age Limit`, `application_contact`/`Application Contact`, and `contract_duration`/`Contract Duration`/`Project Duration` returned **zero matches** — none of the three dedicated audit areas (B, C, D) has any existing test, of any kind (visibility, validation, or serialization). No test exists for the general `TEXT_FIELD_RULES` character rules (area A) either — only `title`/`location`/`description`'s **requiredness** is covered, via the existing "tapping Save with nothing filled shows local required-field errors" test and the IT/Non-IT valid-submission tests, which exercise happy-path values only (never a character-rule violation).

Because this phase is audit-only, I did not run the test suite — per the directive, running is optional when a report can be produced from direct source/code reading, and no code change exists in this phase to verify. No test was weakened, removed, or modified. No test result is claimed here that was not actually observed; none were run, so none are reported as passing or failing.

No analyzer run was performed this phase for the same reason (nothing changed to analyze); Phase 55's last recorded baseline (8 pre-existing issues, same files) remains the most recent confirmed figure and is unaffected by this audit.

## 7. Confirmed complete / partial / missing / unverified / blocked items

- **Complete** (3): `title` required, `description` required, `location` required.
- **Partial** (3): `certifications`, `software_skills`, `language_requirements` — correctly optional, but missing their value-level character-rule check when non-empty.
- **Missing** (23 distinct rule-instances across 15 fields, per §5's matrix): every `NON_IT_FIELDS`-required text field's local requiredness (`department_function`, `industry_sector`, `industry_experience`, `responsibilities`, `working_hours`, `keywords`, `functional_skills`); every `TEXT_FIELD_RULES` field's character-rule validation (`title`, `department_function`, `industry_sector`, `industry_experience`, `functional_skills`, `keywords`, `location`, plus the 3 "Partial" fields' value-rule half); `age_limit`'s format validation and missing error-display slot; `application_contact`'s requiredness and format validation; and all four `contract_duration_months` rules (conditional visibility, required-when-contract, 1-12 range, stale-value clearing).
- **Unverified / low priority** (1): server-side `max_length` enforcement (50-300 chars per field) — a real but low-risk server-only backstop that the live web page itself does not mirror client-side either, so it is not a parity gap in the same sense as the others.
- **Blocked** (0): nothing in this audit's 4 areas required a resource that was unavailable — `CB_changes.docx` was accessible (§2), and both Django trees were fully readable.

## 8. Prioritized recommendation for the next implementation phase

Ranked by server-side rejection risk, user-visible impact, scope/coupling, and ease of verification:

1. **Highest priority — Contract Duration conditional visibility + validation (Area D).** This is the single most visibly broken item: the field is shown to *every* employer regardless of job type, with zero local validation, when the real page hides it entirely outside Contract postings. It is also the most self-contained: 4 rules, 1 field, 1 boolean gate (`_jobType == 'contract' || _employmentType == 'contract'`), reusing the exact clearing pattern already established in Phase 52 (`_onCategoryChanged`/`_onClassificationChanged`). High rejection risk (a Contract IT or Non-IT posting with a blank/out-of-range duration currently sails past local validation and needs a round trip), and it's easy to verify (visibility assertions + 3 validation-message tests + a stale-value-clearing test, directly mirroring Phase 55's own test structure for a conditionally-shown field).
2. **Second priority — `application_contact` requiredness + format (Area C).** A single required field, currently silently missing from `_localRequiredErrors()` for *every* Non-IT posting — meaning right now, every Non-IT submission with a blank Application Contact needs a server round trip to discover it's required at all. The format rule (email/phone/name, multi-part) is more involved than Contract Duration's numeric range, but is independently testable and doesn't touch any other field's state.
3. **Third priority — `age_limit` format validation + missing error slot (Area B).** Lower risk since the field is optional (most postings can simply leave it blank and never hit this path), but it is the only field on this screen with **no** `_fieldError` display slot at all, meaning a server rejection currently has literally nowhere to render — worth fixing both pieces together since they're one field, one widget block, and a 3-line regex-based validator.
4. **Lowest priority, broadest scope — the remaining `NON_IT_FIELDS` requiredness + `TEXT_FIELD_RULES` character rules (the rest of Area A).** This is real, confirmed scope (7 fields missing requiredness, 7 fields missing character rules, 3 fields missing their optional-but-validated character rule), but it is also the most repetitive and highest-count: a single phase implementing all of it would touch `_localRequiredErrors()` extensively and add a shared text-rule helper used by ~10 call sites. Given this project's established "smallest correct fix" precedent (Phases 52-55 each shipped one tightly-scoped field or field-pair at a time), I'd split this into 2 sub-phases rather than 1: first the 7 missing-requiredness checks (smaller, same pattern as Phase 52/53, no new helper needed), then a second phase adding the shared `TEXT_FIELD_RULES`-equivalent helper and wiring it to all 10 fields at once (since the helper itself is genuinely one coherent task — one function, ported once, applied everywhere it's needed — splitting the helper itself further would be artificial).

**My recommendation: start the next phase with Contract Duration (Area D) alone** — it is the smallest, most self-contained, most visibly incorrect (unconditional display of a field the real page hides), and the easiest to fully verify end-to-end (visibility, requiredness, range, and stale-value clearing are all testable in the same style as every prior phase in this engagement).

## 9. Explicitly excluded work

- No fix was implemented for any of the gaps identified above.
- No test was added, removed, or modified.
- No Django file was modified.
- Phases 52-55's own implementations were not touched, refactored, or "cleaned up" while reading them.
- The `max_length`/server-only backstop item (§7 "Unverified / low priority") was deliberately not escalated to "Missing," since the real web page itself provides no client-side equivalent to mirror.
- `CB_changes.docx`'s 14 non-job-posting feature items (landing page, AI interview, subscription gating, etc.) were read but are out of this phase's 4-area scope and are not reported on further here.

## 10. Confirmation

No application code, test file, or Django source file was modified during this phase. `git status --short` in `Mobile_app` remains identical to §2's baseline except for the addition of this one new report file. Both Django trees were read-only throughout (`grep`, `sed -n`, `Read` only — no `Edit`/`Write` call was made against either tree). No credential, token, keystore, or signing material was inspected. No build was published, no signing configuration changed, and no production data was touched.

---

**This phase is complete. Awaiting explicit approval before implementing any of the recommendations above.**
