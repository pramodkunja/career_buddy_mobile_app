# Phase 59 — Employer Job Posting: Age Limit Validation Parity

## 0. Pre-existing blocker found and fixed (outside this phase's scope, but required for verification)

Before starting Phase 59, `git status --short` showed 6 files under `test/features/resume/` already modified in the working tree (not by this session — they predate this phase and were not part of Phases 52-58's changes). These were an external, in-progress fix for the `unused_element_parameter` analyzer warnings that had been part of every prior phase's "8 pre-existing issues" baseline (removing an unused named constructor parameter and null-initializing the field via an initializer list instead). 4 of the 6 files were valid; 2 files (`test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart` and `test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart`) had a syntax error — a constructor initializer list using `:` twice instead of a comma (`: levelCommonResult = null : previewResult = null;`), which does not compile and broke `flutter analyze`/`flutter test` project-wide.

Per explicit user confirmation (asked before touching anything, since this is unrelated to Age Limit), I corrected only the malformed punctuation in both files — `:` → `,` between the two initializers — restoring valid Dart syntax with no behavioral change. This is reflected in §1 as a change outside Phase 59's own scope, made only to unblock verification. **This also means the Phase 58-reported baseline of "8 pre-existing analyzer issues" is stale**: those 8 warnings had already been resolved (just left in a broken state) before this phase began — see §7 for the corrected comparison.

## 1. Files changed and reasons

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added a `_fieldError('age_limit')` call beneath the existing "Age Limit (optional)" `AppTextField` — this was the specific gap Phase 56 flagged: every other field on this screen already had an inline error slot, `age_limit` did not.
  - Added 3 new static helpers: `_ageLimitRe`/`_ageLimitMessage` (mirrors `AGE_LIMIT_RE`/`AGE_LIMIT_MESSAGE` exactly), `_ageLimitError` (mirrors `clean_age_limit`'s validation logic), and `_normaliseAgeLimit` (mirrors `clean_age_limit`'s own `.strip()` + dash-whitespace normalisation).
  - `_localRequiredErrors()` gained a new `_isNonIt`-gated block: a blank value is always acceptable (no "required" branch exists for this field at all, unlike `application_contact`); a non-empty, malformed value gets `_ageLimitError`'s message.
  - `_submit()`'s `JobPostingSubmission` construction now sends `_normaliseAgeLimit(_ageLimit.text)` instead of a bare `.trim()`, so a value like `"25 - 35"` is submitted as `"25-35"`, matching what the server itself stores.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`** — added the new `Phase 59: Age Limit validation parity` group (19 tests, §6). No existing fixture needed updating (unlike Phases 54/58), since Age Limit was never, and remains, optional.
- **`test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart`** and **`test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart`** — the pre-existing syntax-error fix described in §0, made only to unblock verification, with explicit user approval before touching either file.

No other file was changed. `job_posting_submission.dart`'s `ageLimit` field was already correctly typed/documented (`'age_limit' — free text, Non-IT only`); no domain-model edit was needed. `job_posting_catalog.dart` and `job_posting_remote_datasource.dart` (and its test file) carry only their pre-existing Phase 52-58 diffs, confirmed unmodified by this phase.

## 2. Verified Django source locations and rules

Re-read directly this phase (not assumed from the Phase 56 audit, per the directive's instruction):

- **`jobs_app/forms.py:127-128`**:
  ```python
  AGE_LIMIT_RE = re.compile(r'^(\d{1,2})(?:\s*-\s*(\d{1,2}))?\+?$')
  AGE_LIMIT_MESSAGE = 'Please enter a valid numeric age limit, e.g. 25 or 25-35.'
  ```
- **`jobs_app/forms.py:604-614`** (`clean_age_limit`):
  ```python
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
- **`jobs_app/forms.py:276-316`** (`NON_IT_FIELDS`/`NON_IT_ALL_FIELDS`): `('age_limit', 'Age Limit')` is in the `optional` list for **both** `'technical'` and `'non_technical'` sheets (never in either `required` list), and in `NON_IT_ALL_FIELDS` (blanked for IT) — confirmed unchanged from Phase 56.
- **`templates/employer/job_form.html:630-633`**: the field carries the `nonit-only` class (`hidden` by default, shown only for Non-IT) and has its own `err_age_limit` display div — confirming the real web page already has a dedicated inline error slot that Flutter was missing.
- **`templates/employer/job_form.html:1716-1726`**: the client-side JS mirror reproduces the exact same regex and low/high checks (`low < 1 || (high !== null && (high < 1 || high < low))`) and routes every failure to the same single `AGE_LIMIT_MESSAGE` — confirming there is genuinely only one message for this field (unlike `contract_duration_months`'s 5 distinct messages), and that the real page restricts keystrokes to `[\d\-+ ]` (a live-input filter Flutter does not reproduce, consistent with this project's established "validate on submit, not on keystroke" convention for every other field — see §9).

## 3. Requiredness and visibility by category

| Category/classification | Shown? | Required? |
|---|---|---|
| IT | No | n/a |
| Non-IT × Technical | Yes | No (always optional) |
| Non-IT × Non-Technical | Yes | No (always optional) |

Unlike `application_contact` (Phase 58), there is no "is required" message for this field at all — a blank value is unconditionally acceptable on both Non-IT sheets, confirmed by `clean_age_limit`'s own `if not value: return ''` with no corresponding entry in either sheet's `required` list.

## 4. Accepted and rejected formats

| Input | Accepted? | Why |
|---|---|---|
| `25` | Yes | plain 1-2 digit number |
| `25+` | Yes | number + trailing `+` |
| `25-35` | Yes | range, both ends 1-2 digits |
| `25-35+` | Yes | range + trailing `+` (structurally always allowed, with or without a range) |
| `1`, `99` | Yes | the regex's own 1-2 digit structure naturally caps the range at 1-99 |
| `0`, `25-0` | No | low (or high) `< 1` |
| `100` | No | 3 digits — the regex can only capture 2, so the string fails to match at all |
| `25.5` | No | no `.` in the pattern — falls straight to the generic message |
| `abc` | No | non-numeric |
| `35-25` | No | high `<` low |
| `25-` | No | an incomplete range fails the regex entirely |
| `25++` | No | a second `+` fails the regex entirely |

All reproduced via `_ageLimitRe` (identical regex) and `_ageLimitError` (identical low/high comparison), in the same order the server applies them (regex match first, then the low/high business rule).

## 5. Whitespace normalization and payload behavior

`clean_age_limit` only normalises whitespace immediately around a hyphen (`re.sub(r'\s*-\s*', '-', value)`) — narrower than `application_contact`'s/`education`'s general `\s+` → single-space collapse, because `AGE_LIMIT_RE` structurally cannot match a value with whitespace anywhere else (digits don't allow embedded spaces, and the value is already outer-trimmed first). `_normaliseAgeLimit` reproduces exactly this: `text.trim().replaceAll(RegExp(r'\s*-\s*'), '-')`. This same normalised value is both what gets validated and what is sent as `age_limit` in the submission payload — e.g. `"25 - 35"` submits as `"25-35"` (tested in §6, item 14). The payload field name (`age_limit`) and its string type are unchanged.

## 6. Tests added and actual pass/fail counts

New group `PostNewJobScreen — Phase 59: Age Limit validation parity` (19 tests, all passing):

1. Age Limit is not shown for IT.
2. Age Limit remains optional for Non-IT × Technical — a valid submission with none still succeeds.
3. Age Limit remains optional for Non-IT × Non-Technical — a valid submission with none still succeeds.
4. A plain integer (`25`) is accepted.
5. A "plus" value (`25+`) is accepted.
6. A range (`25-35`) is accepted.
7. A range-plus (`25-35+`) is accepted.
8. The lower (`1`) and upper (`99`) boundaries are both accepted (as `1-99`).
9. `0` is rejected.
10. A 3-digit value (`100`) is rejected.
11. A decimal (`25.5`) is rejected.
12. A non-numeric value (`abc`) is rejected.
13. An upper age below the lower age (`35-25`) is rejected.
14. An incomplete range (`25-`) is rejected.
15. A malformed double `+` (`25++`) is rejected.
16. A zero upper end (`25-0`) is rejected.
17. Whitespace around the hyphen (`25 - 35`) is normalized to `25-35` before submission.
18. Correcting an invalid value clears the error and allows submission.
19. Edit mode: an existing Non-IT posting with an Age Limit (`25-35`) loads and preserves it unchanged on resubmission.

Every rejection test asserts the exact message `'Please enter a valid numeric age limit, e.g. 25 or 25-35.'` is shown and `repo.callCount == 0`; every acceptance test asserts `repo.callCount == 1` and the exact submitted `ageLimit` value.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 108 passing, 0 failing (89 pre-existing + 19 new)
```
```
flutter test test/features/employer
→ 221 passing, 0 failing (202 pre-existing + 19 new)
```
```
flutter test
→ 2,583 passing, 0 failing (2,564 pre-existing + 19 new — exact match against the Phase 58 baseline plus these additions; no regressions)
```
No existing test was weakened, removed, or modified to make a new test pass.

## 7. Analysis results and warnings

```
flutter analyze
→ No issues found! (0 issues)
```
This is **not** identical to the Phase 58 baseline of "8 pre-existing issues" — see §0: those 8 warnings were already resolved by an external, in-progress edit found at the start of this phase (2 files of which had a syntax error, fixed with explicit approval). After that fix, the analyzer reports 0 issues, both before and after this phase's own Age Limit changes — confirming Phase 59's own code changes introduced no new analyzer issues. `flutter analyze lib/features/employer/` also reports "No issues found," matching the directive's stated Phase 58 employer-only baseline.

## 8. Device/live-server verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results reported in §6-7. Automated widget tests are not reported as emulator or live-server verification.

## 9. Remaining limitations or unverified behavior

- The real web page restricts keystrokes on this field to `[\d\-+ ]` as the user types (§2); Flutter validates on submit instead, consistent with this project's established convention for every other field on this form (none of them reproduce live keystroke filtering).
- No live round-trip against the real server was performed to confirm it still returns this exact message unchanged; it was taken from direct, re-confirmed source reading (`forms.py`) rather than a live POST.
- This phase did not address any other Phase 56 audit finding (general text-field validation, or anything beyond Age Limit) — explicitly out of scope per the directive.

## 10. Confirmation: Django reference directories and backend APIs unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout this phase — only `grep`/`sed -n` were used against `jobs_app/forms.py` and `templates/employer/job_form.html`; no file in either tree was created, edited, deleted, or renamed. No backend API, request format, database model, migration, or production data was changed. The payload field name (`age_limit`) and the datasource's serialization were inspected and confirmed to need no change — neither was edited.

## 11. Confirmation: unrelated working-tree changes preserved

`git status --short` before this phase showed 5 employer files already modified by Phases 52-58 (unchanged in scope by this phase's addition) plus 6 resume test files with the pre-existing, partially-broken external fix described in §0. After this phase: the same 5 employer files (now carrying this phase's additional diff), the 6 resume test files (now syntactically valid, per explicit user approval, with no other change), and the 7 pre-existing untracked Phase 52-58 reports. No unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. The Phase 52-58 fixes (conditional required fields, education/work-mode option lists, experience range fields, Contract Duration conditional visibility, Application Contact requiredness/format) were all re-verified still passing in the same test runs (§6) — none were reverted, weakened, or altered by this phase.

---

**This phase is complete.** Not starting another phase without explicit approval.
