# Phase 63 — Employer Job Posting: Salary Format, Range and Cross-Field Validation

## 1. Summary of implemented salary rules

Implemented the salary validation gap identified in Phase 62: `salary_min`/`salary_max` previously only checked presence. They now reproduce the Django server's full rule set — format-specific minimum/maximum bounds (Monthly: ₹1,000–999,999; LPA: 1–99 LPA), whole-number-only enforcement (decimal rejection), the exact format-dependent "is required"/"invalid"/"floor"/"ceiling" messages, and the minimum-greater-than-maximum cross-field check (attached to `salary_min`, only evaluated once both values individually pass). Switching the Salary Format dropdown now also clears both fields, matching the real web page's own confirmed behavior of never mixing monthly-rupee and LPA figures.

## 2. Verified Django source locations

Re-read directly this phase (not assumed from Phase 62):

- **`jobs_app/forms.py:412-422`** (`SALARY_RULES`): `monthly` → `min: 1000, max: 999999, integer: True`, ceiling message `'Salary must not exceed ₹9,99,999 per month (6 digits).'`; `lpa` → `min: 1, max: 99, integer: True`, ceiling message `'LPA must not exceed 99 LPA (2 digits).'`.
- **`jobs_app/forms.py:565-585`** (field setup in `__init__`): for each of `salary_min`/`salary_max`, `label = f'{bound} {rules["label"]}'` (`bound` = `'Minimum'`/`'Maximum'`, `rules['label']` = `'Salary'`/`'LPA'` depending on the *currently selected* format), then:
  ```python
  field.error_messages.update({
      'required': f'{label} is required.',
      'invalid': f'Enter a valid numeric value for {label}.',
      'max_digits': too_large,          # = ceiling_message
      'max_decimal_places': invalid,     # reuses the 'invalid' message
      'max_whole_digits': too_large,
  })
  ```
- **`jobs_app/forms.py:633-637`** (`_salary_format`): reads the *raw submitted* `salary_format` from `self.data` when the form is bound, defaulting to `'monthly'` — confirming the format-dependent labels above are resolved per-submission, not fixed at page-load time.
- **`jobs_app/forms.py:639-663`** (`clean_salary_min`/`clean_salary_max`/`_clean_salary_range`):
  ```python
  def _clean_salary_range(self, field_name, bound):
      value = self.cleaned_data.get(field_name)
      if value is None:
          return value
      rules = self.SALARY_RULES[self._salary_format()]
      label = f'{bound} {rules["label"]}'
      if rules['integer'] and value != value.to_integral_value():
          raise forms.ValidationError(f'{label} must be a whole number (no decimals).')
      if value < rules['min']:
          raise forms.ValidationError(f'{label} must be at least {rules["fmt"](rules["min"])}.')
      if value > rules['max']:
          raise forms.ValidationError(rules['ceiling_message'] or ...)
      return value
  ```
- **`jobs_app/forms.py:726-731`** (`clean()`'s cross-check): `if s_min is not None and s_max is not None and s_min > s_max: self.add_error('salary_min', f'Minimum {label} must not be greater than Maximum {label}.')`, where `label = SALARY_RULES[self._salary_format()]['label']` (the bare `'Salary'`/`'LPA'`, not bound-prefixed). The `s_min is not None and s_max is not None` guard confirms the cross-check only evaluates `cleaned_data` entries that survived their own field-level clean — a field whose `clean_salary_*` raised is absent from `cleaned_data`, so the comparison is skipped entirely, never producing a misleading cross-field message alongside an individual-field one.
- **`jobs_app/models.py:167-168,455-466`**: `salary_min`/`salary_max` are `DecimalField(max_digits=10, decimal_places=2)`; `_fmt_monthly` formats with Indian digit grouping (`1000` → `"1,000"`), confirming the floor message's exact text `'Minimum Salary must be at least ₹1,000 per month.'` (and `'Minimum LPA must be at least 1 LPA.'` for LPA, where `fmt(v) = f'{v} LPA'`).
- **`templates/employer/job_form.html:1385-1537`**: the client-side `SALARY_FORMATS`/`salaryFieldError`/`validateSalaryField` JS is a byte-for-byte mirror of the above (`label.min`/`label.max` = `"Minimum Salary"`/`"Maximum Salary"` or the LPA equivalents; the cross-check message literally concatenates `cfg.label.min + ' must not be greater than ' + cfg.label.max + '.'`). Critically, this file's own comment states: *"Switching format clears any entered values so monthly and LPA figures are never mixed"* — confirmed by `salaryFormatEl.addEventListener('change', function () { applySalaryFormat(true); })`, where `applySalaryFormat(true)` sets `input.value = ''` for both fields. This directly informed §3's implementation choice over the directive's own worded requirement ("revalidates both values using the newly selected bounds") — see §9 for the explicit discrepancy note.

## 3. Monthly and LPA boundary-validation matrix

| Format | Min | Max | Integer-only | Floor message | Ceiling message |
|---|---|---|---|---|---|
| Monthly | 1000 | 999999 | Yes | `"Minimum Salary must be at least ₹1,000 per month."` / `"Maximum Salary must be at least ₹1,000 per month."` | `"Salary must not exceed ₹9,99,999 per month (6 digits)."` (same text regardless of which field) |
| LPA | 1 | 99 | Yes | `"Minimum LPA must be at least 1 LPA."` / `"Maximum LPA must be at least 1 LPA."` | `"LPA must not exceed 99 LPA (2 digits)."` (same text regardless of which field) |

Boundary values `1000`/`999999` (Monthly) and `1`/`99` (LPA) are all accepted (inclusive bounds); `999`/`1000000` and `0`/`100` are the adjacent rejected values, confirmed by test (§6).

## 4. Exact error messages and field placement

| Condition | Message | Attached to |
|---|---|---|
| Empty | `"{Minimum\|Maximum} {Salary\|LPA} is required."` | The field itself (`salary_min`/`salary_max`) |
| Non-numeric / malformed / >2 decimal places | `"Enter a valid numeric value for {Minimum\|Maximum} {Salary\|LPA}."` | The field itself |
| Has a non-zero fractional part | `"{Minimum\|Maximum} {Salary\|LPA} must be a whole number (no decimals)."` | The field itself |
| Below the format's minimum | `"{Minimum\|Maximum} {Salary\|LPA} must be at least {fmt(min)}."` | The field itself |
| Above the format's maximum | The fixed ceiling message (no "Minimum"/"Maximum" prefix) | The field itself |
| `salary_min > salary_max` (both individually valid) | `"Minimum {Salary\|LPA} must not be greater than Maximum {Salary\|LPA}."` | **Always `salary_min`**, never `salary_max` |

All messages are verbatim from `forms.py`, re-confirmed this phase, not paraphrased.

## 5. Cross-field comparison behavior

Implemented exactly as `clean()` does: the comparison only runs when **both** `salary_min` and `salary_max` text parse successfully and individually pass every other check (format, decimal, floor, ceiling) for the current format — mirrored in Flutter by only setting `parsedMin`/`parsedMax` when `_salaryFieldError` returns `null` for that field, and gating the cross-check on both being non-null. Equality (`min == max`) is explicitly allowed — the comparison uses strict `>`, matching `s_min > s_max` exactly (verified by test §6). When `salary_min` is individually invalid (e.g. below the floor) but numerically less than a valid `salary_max`, only the individual-field message appears — the cross-field message never also fires, matching the server's `cleaned.get()`-absence guard (verified by test §6).

## 6. Files changed and reason for each change

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added `_salaryFieldError(trimmedText, {boundLabel, isLpa})` — mirrors `_clean_salary_range` exactly (numeric-shape check via regex, including the >2-decimal-places "invalid" case; whole-number check; floor; ceiling), and `_wholeSalaryValue(trimmedText)` — extracts the parsed integer for use in the cross-field comparison.
  - Rewrote the `_localRequiredErrors()` salary block: the required messages are now format-dependent (`$minLabel is required.`, where `minLabel` is `'Minimum LPA'`/`'Minimum Salary'` depending on `_salaryFormat`), each field is validated via `_salaryFieldError` when non-empty, and the cross-field check is added using the parsed values, exactly as described in §5.
  - The Salary Format dropdown's `onChanged` now also clears `_salaryMin`/`_salaryMax`, matching `job_form.html`'s own `applySalaryFormat(true)` behavior (§2, §9).
  - No change was made to `_submit()`'s construction of `salaryMin`/`salaryMax` (`_salaryMin.text.trim()`/`_salaryMax.text.trim()`) — the server parses the raw numeric string itself; no client-side normalisation beyond trimming is needed or performed by the server either.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`** — added the new `Phase 63: salary format, range and cross-field validation` group (22 tests, §7). No existing fixture needed updating: every pre-existing test's salary values (`30000`/`50000`, `25000`/`35000`, etc.) already fall within the Monthly bounds and were never compared across a format switch, confirmed by the full regression run showing zero fixture-related failures.

No other file was changed. `job_posting_catalog.dart`, `job_posting_submission.dart`, and `job_posting_remote_datasource_test.dart` carry only their pre-existing Phase 52-62 diffs. The 6 `test/features/resume/...` files carry only the pre-existing Phase 59 syntax fix, untouched further here.

## 7. Tests added and actual pass/fail counts

New group `PostNewJobScreen — Phase 63: salary format, range and cross-field validation` (22 tests, all passing):

1-4. Requiredness: empty Minimum, empty Maximum, whitespace-only Minimum (counts as empty, not "invalid"), and the required message becomes `"Minimum LPA is required."` once LPA is selected.
5-10. Monthly: lower boundary (1000) accepted, upper boundary (999999) accepted, below minimum (999) rejected, above maximum (1000000) rejected, a decimal (1500.50) rejected, non-numeric rejected.
11-16. LPA: lower boundary (1) accepted, upper boundary (99) accepted, below minimum (0) rejected, above maximum (100) rejected, a decimal (5.5) rejected, non-numeric rejected.
17-20. Cross-field: min > max rejected (attached to Minimum Salary), min == max accepted, no cross-field error when Minimum is individually invalid even though numerically below Maximum.
21-22. Format switching: Monthly → LPA clears both fields; LPA → Monthly clears both fields.
23. Correcting an invalid Minimum Salary clears the error and allows submission.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 182 passing, 0 failing (160 pre-existing + 22 new)
```
```
flutter test test/features/employer
→ 295 passing, 0 failing (273 pre-existing + 22 new)
```
```
flutter test
→ 2,657 passing, 0 failing (2,635 pre-existing + 22 new — this full-suite figure was actually re-executed this phase, unlike Phase 62's citation of it as historical; no regressions)
```
No existing assertion was weakened, removed, or modified to make a new test pass.

## 8. Flutter analysis results and warnings

```
flutter analyze
→ No issues found! (0 issues)
```
Matches the Phase 62 baseline of 0 issues exactly — unchanged by this phase's own code. `flutter analyze lib/features/employer/` also reports "No issues found."

## 9. Device/live-server verification status, and remaining mismatches

**Device/live-server verification: not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results in §7-8.

**Documented discrepancy (per the directive's own instruction to follow the source over the brief's wording)**: Step 3, requirement #11 of this phase's directive asked to "ensure changing from Monthly to LPA, or vice versa, revalidates both values using the newly selected bounds." Direct source reading of `job_form.html` (§2) shows the real page does not revalidate stale values under new bounds — it **clears both fields outright** on a format switch, with its own comment explicitly stating this is "so monthly and LPA figures are never mixed." Implementing a revalidate-in-place behavior instead would have diverged from the real, confirmed server/web behavior. This phase implements the clearing behavior, matching the source exactly; the directive's own safety rules instruct following the source where it differs from the brief.

**Other limitations**:
- The real web page's salary inputs restrict certain keystrokes live (`inputmode="numeric"`/`"decimal"` plus a native `maxLength`); Flutter validates on submit instead, consistent with this project's established convention for every other numeric field (`experience_years`, `contract_duration_months`, `openings`).
- No live round-trip against the real server was performed to confirm it still returns these exact messages unchanged; all were taken from direct, re-confirmed source reading.

## 10. Confirmation: Openings and text-field validation gaps were not changed

Per this phase's explicit scope boundary, the `openings` lower-bound gap (accepting `0`/negative values) and the remaining `TEXT_FIELD_RULES` fields (`title`, `location`, `certifications`, `software_skills`, `language_requirements`) identified in Phase 62 were **not** touched in this phase — confirmed by `git diff` showing changes scoped entirely to the salary block in `_localRequiredErrors()`, the 2 new salary helper methods, and the Salary Format dropdown's `onChanged`. The `openings` check (`int.tryParse(_openings.text.trim()) == null`) remains exactly as it was before this phase.

## 11. Confirmation: Django reference directories and backend APIs unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout this phase — only `grep`/`sed -n` were used against `jobs_app/forms.py`, `jobs_app/models.py`, and `templates/employer/job_form.html`; no file in either tree was created, edited, deleted, or renamed. No backend API, request format, database model, migration, or production data was changed. No payload field name, serialization logic, or domain-model type was altered.

## 12. Confirmation: unrelated working-tree changes preserved

`git status --short` before this phase showed the same 5 employer files already modified by Phases 52-62, plus the 6 resume test files carrying the Phase 59 syntax fix, plus 10 pre-existing untracked Phase 52-62 reports. After this phase: the same 5 employer files (now carrying this phase's additional diff), the 6 resume test files (unchanged by this phase), and the 11 pre-existing untracked reports (including this one). No unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. No credential, token, keystore, or signing material was inspected, printed, or modified; no build was published and no signing configuration was changed.

---

**This phase is complete.** Not starting Phase 64 without explicit approval.
