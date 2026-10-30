# Phase 64 — Employer Job Posting: Openings Minimum Validation

## 1. Summary of the fix

Fixed the `openings` lower-bound gap identified in Phase 62: Flutter previously only rejected non-numeric input, accepting both `0` and negative integers that the server rejects. Direct, **empirically verified** investigation this phase (by actually running this project's own installed Django version, 5.2.18, against the field's real `IntegerField(min_value=0)` pipeline — not just reading the source) revealed the real behavior is a **3-way split**, not the single message the Phase 62 audit and this phase's own directive assumed:

1. Non-numeric / empty / whitespace-only → `"Please enter a valid numeric value."` (already correct in Flutter, unchanged this phase).
2. **Negative** values → Django's own **uncustomized** `MinValueValidator` message, `"Ensure this value is greater than or equal to 0."` — this project never overrides it.
3. Exactly **zero** → the project's custom `clean_openings()` message, `"Openings must be 1 or greater."`.

All three are now implemented in Flutter, in the server's own execution order.

## 2. Verified Django source location and exact error message

- **`jobs_app/models.py:180`**: `openings = models.PositiveIntegerField(default=1)`.
- **`jobs_app/forms.py:553-556`**: `self.fields['openings'].error_messages.update({'invalid': 'Please enter a valid numeric value.', 'required': 'Please enter a valid numeric value.'})` — confirmed this only overrides `'invalid'`/`'required'`, never `'min_value'`.
- **`jobs_app/forms.py:951-958`** (`clean_openings`, re-read in full, unchanged from Phase 62's citation):
  ```python
  def clean_openings(self):
      # openings is a PositiveIntegerField (allows 0 at the DB level), and
      # the widget's min="1" is a client-side hint only (this form's
      # <form> carries novalidate) — without this, a posting advertising
      # zero open positions was silently accepted.
      value = self.cleaned_data.get('openings')
      if value is not None and value < 1:
          raise forms.ValidationError('Openings must be 1 or greater.')
      return value
  ```
- **The critical discovery, confirmed by actually executing Django's own code** (this project's `requirements.txt` pins `Django>=5.2,<6.0`; the installed version is 5.2.18):
  ```python
  # django/db/models/fields/__init__.py
  class PositiveIntegerField(PositiveIntegerRelDbTypeMixin, IntegerField):
      def formfield(self, **kwargs):
          return super().formfield(**{'min_value': 0, **kwargs})
  ```
  This means the ModelForm's auto-generated `openings` field is a `forms.IntegerField(min_value=0, ...)`, which attaches a `MinValueValidator(0)` — a validator this project's own `error_messages.update()` never touches. Running the exact field configuration this form uses (`forms.IntegerField(min_value=0, required=True, error_messages={'invalid': ..., 'required': ...})`) against representative inputs produced:
  ```
  '-1'  -> ERROR: ['Ensure this value is greater than or equal to 0.']
  '0'   -> OK, cleaned=0
  '1'   -> OK, cleaned=1
  '1.5' -> ERROR: ['Please enter a valid numeric value.']
  '1.0' -> OK, cleaned=1   (Django strips a trailing ".0" before int())
  ''    -> ERROR: ['Please enter a valid numeric value.']
  '-5'  -> ERROR: ['Ensure this value is greater than or equal to 0.']
  ```
  This is **not** inferred or guessed — it is the literal output of running this project's own dependency-pinned Django version's real field-cleaning code in this session. It directly confirms the directive's own warning ("do not assume the same message applies to every invalid input without checking the source") was warranted: the Phase 62 audit's single-message assumption was incomplete for negative input.

## 3. Valid and invalid input cases covered

| Input | Result | Message |
|---|---|---|
| `1`, `5`, `100` | Accepted | — |
| `0` | Rejected | `"Openings must be 1 or greater."` |
| `-1`, `-5` (any negative integer) | Rejected | `"Ensure this value is greater than or equal to 0."` |
| Non-numeric (`abc`), malformed (`--1`) | Rejected | `"Please enter a valid numeric value."` (unchanged, pre-existing) |
| `1.5` (non-zero decimal) | Rejected | `"Please enter a valid numeric value."` (unchanged, pre-existing — `int.tryParse('1.5')` already returns `null`) |
| Empty / whitespace-only | Rejected | `"Please enter a valid numeric value."` (unchanged, pre-existing) |

**Known, deliberately unaddressed edge case** (see §8): `"1.0"` is accepted by Django (its `IntegerField.to_python` strips a trailing `.0` before calling `int()`) but is rejected by Flutter's existing `int.tryParse('1.0') == null` check. This is a pre-existing behavior the directive explicitly says to retain ("Nonnumeric and malformed values retain the correct existing or source-matching error behavior") and is outside this phase's named scope (the minimum-value rule, not general numeric parsing) — recorded as a known limitation, not fixed.

## 4. Files changed and why

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**: `_localRequiredErrors()`'s `openings` check was extended from a single `int.tryParse(...) == null` test into a 3-branch check (non-numeric → existing message, unchanged; negative → the new Django-default message; zero → the new custom message; `>= 1` → no error), in that exact order, matching the server's own field-level-then-`clean_openings` sequence.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`**: added the new `Phase 64: Openings minimum-value validation` group (13 tests, §5). No existing fixture needed updating — every pre-existing test already used Openings values of `1` or higher (or left the field at its default `'1'`), confirmed by the full regression run showing zero fixture-related failures.

No other file was changed. `job_posting_catalog.dart`, `job_posting_submission.dart`, and `job_posting_remote_datasource_test.dart` carry only their pre-existing Phase 52-63 diffs. The 6 `test/features/resume/...` files carry only the pre-existing Phase 59 syntax fix, untouched further here. `_submit()`'s construction of the `openings` payload value (`int.tryParse(_openings.text.trim()) ?? 1`) was left unchanged — by the time this line executes, local validation has already blocked any value below 1, so the `?? 1` fallback remains purely defensive and unreachable in practice, exactly as before.

## 5. Tests added and actual pass/fail counts

New group `PostNewJobScreen — Phase 64: Openings minimum-value validation` (13 tests, all passing):

1. `"1"` is accepted.
2. A typical positive value (`"5"`) is accepted.
3. A larger positive value (`"100"`) is accepted.
4. `"0"` is rejected with `"Openings must be 1 or greater."`.
5. `"-1"` is rejected with Django's own uncustomized `"Ensure this value is greater than or equal to 0."`, explicitly asserting the `"1 or greater"` message does *not* also appear.
6. `"-5"` is also rejected with the same min-value message.
7. Non-numeric (`"abc"`) retains the existing `"Please enter a valid numeric value."` message.
8. A decimal (`"1.5"`) is rejected with the same existing message.
9. Malformed input (`"--1"`) does not crash and is rejected with the same message.
10. An empty field retains the existing required/invalid message, with both new messages explicitly asserted absent.
11. A whitespace-only field behaves the same as empty.
12. Correcting `"0"` to `"1"` clears the error and allows submission.
13. Correcting a negative value to `"1"` clears the error and allows submission.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 195 passing, 0 failing (182 pre-existing + 13 new)
```
```
flutter test test/features/employer
→ 308 passing, 0 failing (295 pre-existing + 13 new)
```
```
flutter test
→ 2,670 passing, 0 failing (2,657 pre-existing + 13 new; actually executed this phase, no regressions)
```
No existing assertion was weakened, removed, or modified to make a new test pass.

## 6. Flutter analysis results

```
flutter analyze
→ No issues found! (0 issues)
```
Matches the Phase 63 baseline of 0 issues exactly — unchanged by this phase's own code.

## 7. Device/live-server verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. This phase's confirmation of the exact Django behavior came from executing the project's own installed Django library code directly (an isolated, in-process simulation of the field's `clean()` pipeline using the exact same version this project depends on), not from a live HTTP round trip to the production or reference server — this distinction is deliberate and stated explicitly, since the directive requires not claiming live-server verification that didn't happen.

## 8. Remaining mismatch or limitation

- **`"1.0"` acceptance**: Django's `IntegerField.to_python` strips a trailing `.0` before parsing, so the server accepts `"1.0"` as `1`; Flutter's existing `int.tryParse` does not accept any decimal point at all, rejecting `"1.0"` as "not a valid numeric value." This is a narrow, pre-existing discrepancy in the *general* numeric-parsing behavior (not the minimum-value rule this phase addresses), explicitly out of this phase's scope per its own directive ("do not change any other validation rules"), and left unaddressed.
- No live round-trip against the real server was performed to confirm the `"Ensure this value is greater than or equal to 0."` message is still rendered verbatim on a real negative-openings submission; this phase's confirmation comes from executing the exact same Django version/field configuration in isolation, which is the strongest verification available without a live or staging deployment.

## 9. Confirmation: Phase 63 salary validation remains intact

The full Phase 63 `salary format, range and cross-field validation` test group (22 tests) was re-run as part of this phase's regression suite (§5's `flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart` run) and all 22 passed unchanged. No line touched by this phase overlaps with the salary block in `_localRequiredErrors()` or the Salary Format dropdown's `onChanged`.

## 10. Confirmation: the remaining five text-validation gaps were not changed

`title`, `location`, `certifications`, `software_skills`, and `language_requirements` (identified in Phase 62, still open per Phase 61's own report) were not touched — confirmed by `git diff` showing changes scoped entirely to the `openings` block in `_localRequiredErrors()` and its corresponding test group.

## 11. Confirmation: Django reference directories and backend APIs unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) had no file created, edited, deleted, or renamed. Source inspection used `grep`/`sed -n`/`Read` only; the Django-behavior verification in §2 executed the project's own **already-installed** Django library code in an isolated Python process (reading, never writing, any project file) to observe real field-validation output — no application file, migration, or settings file in either tree was modified to do this. No backend API, request format, database model, migration, or production data was changed.

## 12. Confirmation: unrelated working-tree changes preserved

`git status --short` before this phase showed the same 5 employer files already modified by Phases 52-63, plus the 6 resume test files carrying the Phase 59 syntax fix, plus 11 pre-existing untracked Phase 52-63 reports. After this phase: the same 5 employer files (now carrying this phase's additional diff), the 6 resume test files (unchanged by this phase), and the 12 pre-existing untracked reports (including this one). No unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. No credential, token, keystore, or signing material was inspected, printed, or modified; no build was published and no signing configuration was changed.

---

**This phase is complete.** Not starting Phase 65 without explicit approval.
