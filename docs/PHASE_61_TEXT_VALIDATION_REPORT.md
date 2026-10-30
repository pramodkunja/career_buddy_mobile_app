# Phase 61 — Employer Job Posting: Field-Specific Text Validation Parity

## 1. Summary

Implemented the 5 remaining `TEXT_FIELD_RULES` character-validation rules that Phases 52-60 had deliberately left out of scope: `industry_sector`, `industry_experience`, `department_function`, `functional_skills`, and `keywords`. Each field now enforces its own allowed-character class, minimum-letter count, and (where configured) standalone-long-digit-run restriction, using the server's exact message, running only when the field is non-empty (empty values continue to show Phase 60's "is required." message, never the character-rule message). No requiredness, visibility, payload field name, or domain-model change was made — only the 5 fields' value-level validation and their normalised-text submission.

## 2. Verified Django source locations

Re-read directly this phase (not assumed from Phase 56):

- **`jobs_app/forms.py:104-124`** (`TEXT_FIELD_RULES`): the 5 relevant entries, confirmed byte-for-byte identical to the Phase 56 audit's reading.
- **`jobs_app/forms.py:132-144`** (`text_field_error`):
  ```python
  def text_field_error(value, rule):
      text = re.sub(r'\s+', ' ', value or '').strip()
      if not text:
          return ''
      if not re.match('^[' + rule['chars'] + ']+$', text):
          return rule['message']
      if len(re.findall(r'[A-Za-z]', text)) < rule['min_letters']:
          return rule['message']
      if rule['no_long_digits'] and re.search(r'\d{3,}', text):
          return rule['message']
      return ''
  ```
- **`jobs_app/forms.py:597-602`** (`_clean_text_field`):
  ```python
  def _clean_text_field(self, name):
      value = self.cleaned_data.get(name) or ''
      problem = text_field_error(value, TEXT_FIELD_RULES[name])
      if problem:
          raise forms.ValidationError(problem)
      return re.sub(r'\s+', ' ', value).strip()
  ```
- **`jobs_app/forms.py:941-948`**: `clean_department_function`, `clean_industry_sector`, `clean_industry_experience`, `clean_functional_skills`, `clean_keywords` — each a one-line `return self._clean_text_field('<name>')`, confirming no field-specific override beyond its own `TEXT_FIELD_RULES` entry.
- **`jobs_app/forms.py:590-595`** (`text_rules_js`): confirms the client-side JS (`templates/employer/job_form.html:1681-1701`, `textFieldError()`) is a byte-for-byte mirror of the same regex/rules — corroborating, not a separate source of truth.
- **Execution order**: Django's `_clean_fields()` always runs each field's own `clean_<name>` (raising on a non-empty-but-invalid value) *before* `clean()`'s sheet-required loop (Phase 60) runs. If `clean_<name>` already raised, `cleaned_data` has no entry for that field, so the sheet loop's `(cleaned.get(name) or '').strip()` evaluates to `''`, but its `name not in self.errors` guard is already `False` — so the "is required." message never also fires alongside a format error. This confirms the exact same mutually-exclusive precedence already used for `application_contact` (Phase 58) and `age_limit` (Phase 59), reproduced identically here.

## 3. Field-by-field parity matrix

| Field | Allowed chars | Min letters | Long-digit restriction | Exact message | Category scope | Flutter before | Flutter after |
|---|---|---|---|---|---|---|---|
| `industry_sector` | `A-Za-z0-9 .,&/()'\-` | 2 | **Yes** (no run of 3+ digits) | "Industry / Sector should contain a valid industry name and should not contain only numbers or special characters." | Both Non-IT sheets | Missing | **Implemented** |
| `industry_experience` | `A-Za-z0-9 .,&/()'\-+` (allows `+`) | 2 | No | "Industry Experience should describe the relevant experience and should not contain only numbers or special characters." | Both Non-IT sheets (format rule applies even though only required on Technical) | Missing | **Implemented** |
| `department_function` | `A-Za-z0-9 .,&/()'\-` | 2 | **Yes** | "Department / Function should contain a valid name and should not contain only numbers or special characters." | Non-Technical only (no widget exists for Technical) | Missing | **Implemented** |
| `functional_skills` | `A-Za-z0-9 .,&/()'\-+#` (allows `+#`) | 2 | No | "Functional Skills should contain valid skill names and should not contain only numbers or special characters." | Non-Technical only | Missing | **Implemented** |
| `keywords` | `A-Za-z0-9 .,&/()'\-+#` (allows `+#`) | 2 | No | "Key Skills / Keywords should contain valid keywords and should not contain only numbers or special characters." | Both Non-IT sheets | Missing | **Implemented** |

Whitespace: all 5 fields use the identical `re.sub(r'\s+', ' ', value or '').strip()` normalisation, both for the rule check itself and for the value ultimately stored/submitted — reproduced identically in Flutter's `_normaliseFreeText`.

**Deliberately not touched** (confirmed to have no `TEXT_FIELD_RULES` entry, re-verified this phase): `responsibilities`, `working_hours`. Also confirmed untouched and out of this phase's scope: `title`, `location`, `certifications`, `software_skills`, `language_requirements` (all 5 remain in `TEXT_FIELD_RULES` but were not part of this phase's named 5-field list) — their requiredness/optionality from Phases 52-60 is unaffected.

## 4. Exact rules and messages implemented

Ported via 2 shared helpers in `post_new_job_screen.dart`:
- `_normaliseFreeText(text)` — `text.replaceAll(RegExp(r'\s+'), ' ').trim()`.
- `_textFieldError(normalisedText, {allowedChars, minLetters, noLongDigits, message})` — checks (in order) the allowed-character regex, the minimum-letter count (`RegExp(r'[A-Za-z]').allMatches(...).length`), and, when `noLongDigits` is true, a standalone run of 3+ digits (`RegExp(r'\d{3,}')`) — all 3 failure modes return the same single `message`, matching `text_field_error`'s own single-message-per-field design (unlike `age_limit`/`contract_duration_months`, which have multiple distinct messages).

Each of the 5 fields gets its own `RegExp` constant and message constant (`_industrySectorCharsRe`/`_industrySectorMessage`, etc.), called from `_localRequiredErrors()` only when the field's normalised text is non-empty — an empty value continues to produce only the Phase 60 "is required." message (for the 4 fields that are ever required) or no error at all (for `industry_experience` on Non-Technical, where it's optional).

## 5. Files changed and reason for each change

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added `_normaliseFreeText` and `_textFieldError`, plus 5 pairs of `RegExp`/message constants (one pair per field).
  - Rewrote the 5 fields' existing Phase 60 required-only checks in `_localRequiredErrors()` into `if (empty) { required-message } else { character-rule-check }` branches, each still gated by the same category/classification condition Phase 60 already established (`_isNonIt` for `industry_sector`/`keywords`/`industry_experience`'s visibility, `_isNonItTech` for `industry_experience`'s own requiredness, `_isNonItNonTech` for `department_function`/`functional_skills`).
  - Updated `_submit()`'s construction of these 5 fields to send `_normaliseFreeText(...)` instead of a bare `.trim()`, so a value like `"Retail   Trade"` is submitted as `"Retail Trade"`, matching `_clean_text_field`'s own return value. `responsibilities`/`working_hours` were left as plain `.trim()` (no `TEXT_FIELD_RULES` entry exists for either, so no normalisation change applies).
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`** — added the new `Phase 61: field-specific text validation parity` group (34 tests, §6). No existing fixture needed further updating beyond what Phase 60 had already done — the values Phase 60 chose for `industry_sector`/`industry_experience`/`department_function`/`functional_skills`/`keywords` (e.g. `'Construction'`, `'3 years in civil construction'`, `'Human Resources'`) already happen to satisfy these new character rules, confirmed by the full regression run showing zero fixture-related failures.

No other file was changed by this phase's own work. `job_posting_catalog.dart`, `job_posting_submission.dart`, and `job_posting_remote_datasource_test.dart` carry only their pre-existing Phase 52-60 diffs. The 6 `test/features/resume/...` files carry only the pre-existing Phase 59 syntax fix, untouched further here.

## 6. Tests added, commands executed, and actual pass/fail counts

New group `PostNewJobScreen — Phase 61: field-specific text validation parity` (34 tests, all passing):

- A parameterised loop over all 5 fields (4 tests each = 20 tests): accepts a valid value; rejects a disallowed character (`!`) with the exact message; rejects a value with fewer than 2 letters; leaving the field blank still shows the Phase 60 "is required." message, never this field's own format message.
- 2 tests confirming `no_long_digits: true` rejects a 3+ digit run for `industry_sector` and `department_function`.
- 3 tests confirming `no_long_digits: false` **accepts** a 3+ digit run for `industry_experience`, `functional_skills`, and `keywords`.
- 2 tests confirming `industry_experience` accepts `+` while `industry_sector` rejects it (the one chars-class difference between those two).
- 2 tests confirming `keywords` accepts `#` while `industry_sector` rejects it.
- 1 test confirming repeated internal whitespace in `industry_sector` is collapsed to a single space before submission.
- 1 test confirming `industry_experience`'s format rule still applies on Non-IT × Non-Technical even though the field is optional there (an invalid value is rejected with the format message, not silently accepted just because it isn't required).
- 1 test confirming correcting an invalid `industry_sector` value clears the error and allows submission.
- 1 test confirming `department_function`/`functional_skills` have no widget at all for Non-IT × Technical (their rules can never run there).
- 1 test confirming a valid IT submission never shows any of these 5 fields' messages.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 160 passing, 0 failing (126 pre-existing + 34 new)
```
```
flutter test test/features/employer
→ 273 passing, 0 failing (239 pre-existing + 34 new)
```
```
flutter test
→ 2,635 passing, 0 failing (2,601 pre-existing + 34 new — exact match against the Phase 60 baseline plus these additions; no regressions)
```
No existing assertion was weakened, removed, or modified to make a new test pass.

## 7. Flutter analysis results and warnings

```
flutter analyze
→ No issues found! (0 issues)
```
Matches the Phase 60 baseline of 0 issues exactly — unchanged by this phase's own code. `flutter analyze lib/features/employer/` also reports "No issues found."

## 8. Device/live-server verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results reported in §6-7.

## 9. Remaining mismatches or limitations

- The real web page refuses certain keystrokes live as the user types for these fields' siblings (e.g. `age_limit`'s `keydown` filter); no equivalent live keystroke filtering exists for these 5 `TEXT_FIELD_RULES` fields either on the web page or in Flutter — both validate on blur/submit instead, so there is no new gap introduced here.
- No live round-trip against the real server was performed to confirm it still returns these exact 5 messages unchanged; all were taken from direct, re-confirmed source reading (`forms.py`) rather than a live POST.
- `title` and `location`'s own `TEXT_FIELD_RULES` entries (and `certifications`/`software_skills`/`language_requirements`'s) remain unimplemented in Flutter — explicitly out of this phase's named 5-field scope, not touched.

## 10. Confirmation: Django reference directories, backend APIs, production data, and signing configuration unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout this phase — only `grep`/`sed -n` were used against `jobs_app/forms.py` and `templates/employer/job_form.html`; no file in either tree was created, edited, deleted, or renamed. No backend API, request format, database model, migration, or production data was changed. No payload field name, serialization logic, or domain-model type was altered. No credential, token, password, keystore, or signing material was inspected, printed, or modified. No build was published and no signing configuration was changed.

## 11. Confirmation: unrelated working-tree changes preserved

`git status --short` before this phase showed the same 5 employer files already modified by Phases 52-60, plus the 6 resume test files carrying the Phase 59 syntax fix, plus 9 pre-existing untracked Phase 52-60 reports. After this phase: the same 5 employer files (now carrying this phase's additional diff), the 6 resume test files (unchanged by this phase), and the 10 pre-existing untracked reports (including this one). No unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found.

## 12. Confirmation: Phase 60 requiredness and earlier Phase 52-59 behavior remain intact

All Phase 60 required-field checks for these same 5 fields (and the other 2, `responsibilities`/`working_hours`, untouched by this phase) were re-verified still passing, with the precedence rule explicitly tested (§6: "leaving the field blank still shows the Phase 60 'is required.' message, not this field's own format message"). The Phase 52 (conditional required fields, work-mode options), Phase 53 (education requiredness), Phase 54 (education option lists, custom qualification validation), Phase 55 (experience range fields), Phase 57 (Contract Duration), Phase 58 (Application Contact), and Phase 59 (Age Limit) test groups all re-ran and passed unchanged in the same test executions reported in §6 — none were reverted, weakened, or altered by this phase.

---

**This phase is complete.** Not starting Phase 62 without explicit approval.
