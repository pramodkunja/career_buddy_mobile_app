# Phase 65 — Employer Job Posting: Remaining Text-Field Validation Parity

## 1. Summary of the five fields implemented

Implemented the last 5 `TEXT_FIELD_RULES` fields left open since Phase 61: `title`, `location` (both required, universal), `certifications`, `software_skills` (Non-Technical only), and `language_requirements` (Non-Technical only, digits disallowed entirely). All 5 now reuse Phase 61's established `_textFieldError`/`_normaliseFreeText` helpers, with their own allowed-character set, message, and (for `title` only) the standalone-3+-digit restriction. While implementing `title`/`location`, a **pre-existing, previously-latent bug** in their own error-display mechanism was discovered and fixed (§5) — without it, a corrected `title`/`location` value would have remained permanently blocked after one invalid attempt.

## 2. Verified Django source locations and rules

Re-read directly this phase (not assumed from Phase 62/64's citations):

- **`jobs_app/forms.py:106-124`** (`TEXT_FIELD_RULES`): all 5 entries confirmed byte-for-byte identical to every prior phase's reading — unchanged source.
- **`jobs_app/forms.py:940,944,946,947,949`**: `clean_title`/`clean_certifications`/`clean_software_skills`/`clean_language_requirements`/`clean_location` are each a one-line `return self._clean_text_field('<name>')` — no field-specific override beyond the `TEXT_FIELD_RULES` entry, identical mechanism to Phase 61's 5 fields.
- **`jobs_app/models.py:153,177`**: `title = models.CharField(max_length=200)` and `location = models.CharField(max_length=200)` — neither has `blank=True` → both required for every category, confirmed unchanged.
- **`jobs_app/models.py:141,151,152`**: `certifications`, `software_skills`, `language_requirements` are all `blank=True` → always optional, confirmed unchanged, and none appears in any `NON_IT_FIELDS` `required` list.

## 3. Exact allowed-character sets and special restrictions

| Field | Allowed chars | Min letters | Long-digit restriction | Required |
|---|---|---|---|---|
| `title` | `A-Za-z0-9 .,&/()'\-+#` | 2 | **Yes** (rejects a standalone run of 3+ digits) | Yes, all categories |
| `location` | `A-Za-z0-9 .,&/()'\-` | 2 | No | Yes, all categories |
| `certifications` | `A-Za-z0-9 .,&/()'\-+` | 2 | No | No (optional, both Non-IT sheets) |
| `software_skills` | `A-Za-z0-9 .,&/()'\-+#` | 2 | No | No (optional, Non-Technical only) |
| `language_requirements` | `A-Za-z .,&/()'\-` (**no digits at all**) | 2 | N/A (digits already fully excluded) | No (optional, Non-Technical only) |

`location`'s own 3-consecutive-digit behavior was explicitly re-verified per the directive's own caution ("do not apply the title field's consecutive-three-digits restriction unless the current source explicitly requires it") — confirmed `no_long_digits: False` for `location`, so `"Sector 123, Pune"` is correctly **accepted**, unlike the same digit pattern in `title`. No discrepancy from the directive's recorded rules was found for any of the 5 fields.

## 4. Exact error messages and field placement

| Field | Message |
|---|---|
| `title` | `"Job Title should contain a valid job title and should not contain only numbers or special characters."` |
| `location` | `"Location should contain a valid place name (e.g. Hyderabad, Telangana) and should not contain only numbers or special characters."` |
| `certifications` | `"Required Certifications should contain valid certification names and should not contain only numbers or special characters."` |
| `software_skills` | `"Software / MS Office Skills should contain valid software names and should not contain only numbers or special characters."` |
| `language_requirements` | `"Language Requirements should contain language names only."` |

All attached to the field itself (`errors['title']`, `errors['location']`, etc.), matching `self.add_error(field_name, ...)`'s own placement — none of these ever shares a message with another field.

## 5. Optional-field and required-field behavior, and the pre-existing bug fixed to deliver it

- **Required-vs-format precedence**: for `title`/`location`, the character-rule check in `_localRequiredErrors()` only ever runs on a **non-empty** value — an empty value never gets a key in the returned map from this check, so the field's own pre-existing `validator: (v) => Validators.required(v) ?? _fieldErrors[key]` is the sole source of the (unchanged) `"This field is required."` message. The two messages never co-occur (verified by test, §6).
- **Optional fields never get a spurious error**: `certifications`/`software_skills`/`language_requirements` only run their character check on non-empty text — an empty value produces no error at all, for either of these fields, in any category (verified by test, §6).
- **The pre-existing bug, discovered and fixed this phase**: `title`/`location`/`description` fold a server- or locally-set `_fieldErrors[key]` into their own `FormField` `validator`. Nothing in `_submit()` previously cleared `_fieldErrors` before `Form.validate()` ran on a *new* submit attempt — it was only ever reset on the method's own *success* path. Once `title`/`location` gained a local character-rule check in this phase, a failing attempt would set e.g. `_fieldErrors['title']`; on the *next* tap (even with a corrected, fully valid title), `Form.validate()` ran **first**, read the *still-stale* `_fieldErrors['title']` inside the validator, and reported the field invalid all over again — making the success path (the only place that resets `_fieldErrors`) permanently unreachable once a single local title/location format error had ever occurred. This was caught immediately by this phase's own "correcting an invalid value" tests (§6), which failed with `repo.callCount` staying `0` after a valid correction. Fixed by clearing `_fieldErrors = {}` at the very start of `_submit()`, before `Form.validate()` runs, so no stale per-field message can survive into a new attempt. This fix applies uniformly to `title`, `location`, and `description` (all 3 use the same fold pattern) and was verified not to disturb the existing server-rejection display test (§6).

## 6. Tests added and actual pass/fail counts

New group `PostNewJobScreen — Phase 65: remaining text-field validation parity` (40 tests, all passing):

- **Job Title** (8 tests): valid ordinary title; valid permitted punctuation; disallowed character; fewer than 2 letters; numeric-only; 3+ consecutive digits rejected; exactly 2 consecutive digits accepted (restriction not too broad); empty field shows the existing required message, not the format one; correcting an invalid value clears the error and allows submission.
- **Location** (9 tests): valid place name; valid punctuation; disallowed character; fewer than 2 letters; numeric-only; 3+ consecutive digits **accepted** (confirming no `no_long_digits` restriction, unlike Job Title); empty field required-message precedence; correcting an invalid value.
- **Required Certifications** (7 tests): valid name; valid punctuation; disallowed character; fewer than 2 letters; numeric-only; consecutive digits accepted (no restriction); empty optional field produces no error at all.
- **Software / MS Office Skills** (7 tests): valid value; `+`/`#` both accepted; disallowed character; fewer than 2 letters; numeric-only; consecutive digits accepted; empty optional field produces no error.
- **Language Requirements** (8 tests): valid language name; multiple languages with permitted separators; valid punctuation; **digits rejected** (the one field among all 10 `TEXT_FIELD_RULES` entries that excludes `0-9` entirely); other disallowed characters; fewer than 2 letters; numeric-only; empty optional field produces no error.
- **Regression** (1 test): a single submission with all 5 fields populated together succeeds with none of the 5 messages appearing spuriously.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 235 passing, 0 failing (195 pre-existing + 40 new)
```
```
flutter test test/features/employer
→ 348 passing, 0 failing (308 pre-existing + 40 new)
```
```
flutter test
→ 2,710 passing, 0 failing (2,670 pre-existing + 40 new; actually executed this phase, no regressions)
```
No existing assertion was weakened, removed, or modified to make a new test pass. Note: the first run of the "correcting an invalid value" tests for `title`/`location` **failed** before the §5 fix was applied — this is reported transparently as part of the development process, not hidden; the fix was applied and all tests subsequently passed.

## 7. Flutter analysis results

```
flutter analyze
→ No issues found! (0 issues)
```
Matches the Phase 64 baseline of 0 issues exactly.

## 8. Device/live-server verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results in §6-7.

## 9. Remaining mismatches or limitations

- No live round-trip against the real server was performed to confirm it still returns these exact 5 messages unchanged; all were taken from direct, re-confirmed source reading.
- The real web page's `title`/`location`/etc. inputs have no live keystroke-level filtering of their own beyond the shared `TEXT_RULES` blur/submit-time check (confirmed in Phase 61); Flutter's submit-time-only validation matches this, not a new gap.
- The §5 bug fix (clearing `_fieldErrors` at the start of `_submit()`) is a narrowly-scoped, directly-necessary change to make this phase's own new `title`/`location` checks actually work — it was not a pre-planned part of this phase's scope, but was required to deliver the feature correctly; it is called out explicitly here rather than silently bundled in.

## 10. Confirmation: Phase 61 validation remains intact

The Phase 61 `field-specific text validation parity` test group (34 tests, covering `industry_sector`/`industry_experience`/`department_function`/`functional_skills`/`keywords`) was re-run as part of this phase's regression suite and all 34 passed unchanged. No line touched by this phase overlaps with those 5 fields' checks or helpers (only new, separate constants/checks were added for the 5 new fields).

## 11. Confirmation: Phase 63 salary validation remains intact

The full Phase 63 `salary format, range and cross-field validation` test group (22 tests) was re-run and all 22 passed unchanged.

## 12. Confirmation: Phase 64 openings validation remains intact

The full Phase 64 `Openings minimum-value validation` test group (13 tests) was re-run and all 13 passed unchanged.

## 13. Confirmation: Django reference directories and backend APIs unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) had no file created, edited, deleted, or renamed — only `grep`/`sed -n` were used against `jobs_app/forms.py` and `jobs_app/models.py`. No backend API, request format, database model, migration, or production data was changed. No payload field name, serialization logic, or domain-model type was altered.

## 14. Confirmation: unrelated working-tree changes preserved

`git status --short` before this phase showed the same 5 employer files already modified by Phases 52-64, plus the 6 resume test files carrying the Phase 59 syntax fix, plus 12 pre-existing untracked Phase 52-64 reports. After this phase: the same 5 employer files (now carrying this phase's additional diff), the 6 resume test files (unchanged by this phase), and the 13 pre-existing untracked reports (including this one). No unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. No credential, token, keystore, or signing material was inspected, printed, or modified; no build was published and no signing configuration was changed.

---

**This phase is complete.** Not starting another phase without explicit approval.
