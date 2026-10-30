# Phase 58 — Employer Job Posting: Application Contact Validation Parity

## 1. Files changed and reason for each change

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added 6 new static helpers: `_applicationContactMessage` (the exact `CONTACT_MESSAGE` string), `_emailLikeRe`, `_phonePartRe` (mirrors `PHONE_PART_RE`), `_contactNameRe` (mirrors `CONTACT_NAME_RE`), `_contactPartError` (mirrors `contact_part_error`), `_applicationContactError` (mirrors `clean_application_contact`'s split-and-check loop), and `_normaliseApplicationContact` (mirrors `clean_application_contact`'s own whitespace normalisation).
  - `_localRequiredErrors()` gained a new `_isNonIt`-gated block: empty → `'Application Contact is required.'`; non-empty but invalid → `_applicationContactError`'s result. IT is never checked (the field stays hidden there, unchanged).
  - `_submit()`'s `JobPostingSubmission` construction now sends `_normaliseApplicationContact(_applicationContact.text)` instead of a bare `.trim()`, so the submitted value matches what the server itself would store.
  - No widget/layout change was needed: the field was already `_isNonIt`-gated with an existing `_fieldError('application_contact')` display slot (confirmed by inspection in Step 1, per Phase 56's audit).
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`**:
  - Added 2 new top-level fixtures, `_fillNonItTechnicalExceptContact`/`_fillNonItNonTechnicalExceptContact` — every field the existing minimal-valid fixtures fill, minus Application Contact, so each new test can supply its own value in isolation.
  - Updated the existing `_fillMinimalValidNonItTechnicalJob`/`_fillMinimalValidNonItNonTechnicalJob` fixtures (and 2 other inline Non-IT test sequences — the Phase 53 "selecting a Qualification value clears..." test and the Phase 57 "Non-IT × Technical Contract posting" test) to additionally fill a valid Application Contact (`'hr@example.com'`), since it is now a genuine requirement these fixtures must satisfy to keep passing — the same kind of update Phase 54 made to these same fixtures when `education` became required.
  - Added the new `Phase 58: Application Contact requiredness and format validation` group (24 tests, §6).

No other file was changed. `job_posting_submission.dart`'s `applicationContact` field was already correctly typed and documented (`'application_contact' — free text, Non-IT only`); per this project's established "change the domain model only if it cannot represent the source-defined values correctly" principle, no edit was needed there. `job_posting_catalog.dart` and `job_posting_remote_datasource.dart` (and its test file) carry only their pre-existing Phase 52-57 diffs, confirmed unmodified by this phase.

## 2. Verified Django source rules and relevant source locations

Re-read directly this phase (not assumed from the Phase 56 audit, per the directive's explicit instruction to re-verify):

- **`jobs_app/forms.py:129-131`**:
  ```python
  PHONE_PART_RE = re.compile(r'^\+?[\d\s().\-]{7,20}$')
  CONTACT_NAME_RE = re.compile(r"^[A-Za-z .'\-]+$")
  CONTACT_MESSAGE = 'Application Contact should be a valid email address, phone number or contact name.'
  ```
- **`jobs_app/forms.py:148-163`** (`contact_part_error`):
  ```python
  def contact_part_error(part):
      part = part.strip()
      if not part:
          return ''
      if '@' in part:
          try:
              validate_email(part)
              return ''
          except forms.ValidationError:
              return CONTACT_MESSAGE
      digits = re.sub(r'\D', '', part)
      if digits and PHONE_PART_RE.match(part):
          return '' if 7 <= len(digits) <= 15 else CONTACT_MESSAGE
      if CONTACT_NAME_RE.match(part) and len(re.findall(r'[A-Za-z]', part)) >= 2:
          return ''
      return CONTACT_MESSAGE
  ```
- **`jobs_app/forms.py:616-623`** (`clean_application_contact`):
  ```python
  def clean_application_contact(self):
      value = re.sub(r'\s+', ' ', self.cleaned_data.get('application_contact') or '').strip()
      if not value:
          return ''
      parts = [p for p in re.split(r'[,/|;]', value) if p.strip()]
      if not parts or any(contact_part_error(p) for p in parts):
          raise forms.ValidationError(CONTACT_MESSAGE)
      return value
  ```
- **`jobs_app/forms.py:276-307`** (`NON_IT_FIELDS`): `('application_contact', 'Application Contact')` is in the `required` list for **both** `'technical'` and `'non_technical'` sheets — confirmed unchanged from Phase 56's reading.
- **`jobs_app/forms.py:815-829`** (the sheet-required loop in `clean()`): `self.add_error(name, f'{label} is required.')` — confirmed the missing-value message for `application_contact` is **`'Application Contact is required.'`**, not the generic `'This field is required.'` used by several other Phase 52 fields, and not `CONTACT_MESSAGE`. Because `clean_<field>` methods run before `clean()` in Django's pipeline, an empty value never reaches `clean_application_contact`'s format checks at all (it returns `''` immediately), so the 2 messages are mutually exclusive by construction — confirmed by tracing the actual control flow, not assumed.
- **`templates/employer/job_form.html`**: the field (`id_application_contact`) is a plain, always-rendered `TextInput` with no dedicated client-side JS validator of its own (unlike `education`/`experience`'s combo boxes) — its only client-side behavior is the shared `nonit-only` visibility class (hidden for IT) and the generic field-level `TEXT_RULES`-adjacent error display. No separate JS regex for contact format was found, confirming the field relies on the server round-trip for format validation on the real web page — Flutter now does strictly *better* than the live page here by catching the same rule locally first.

## 3. Requiredness behavior for IT and both Non-IT classifications

| Category/classification | Required? | Message when missing |
|---|---|---|
| IT | No — field is hidden, never validated | n/a |
| Non-IT × Technical | **Yes** | `'Application Contact is required.'` |
| Non-IT × Non-Technical | **Yes** | `'Application Contact is required.'` |

Implemented via a single `if (_isNonIt)`-gated block in `_localRequiredErrors()`, matching `NON_IT_FIELDS`'s identical treatment of this field on both sheets (no classification-specific branch was needed, unlike e.g. `joining_requirement` or `industry_experience`).

## 4. Supported contact formats, separator handling, and whitespace rules

- **Email**: any string containing `@`, checked against a standard email-shaped regex (`_emailLikeRe`) — the same level of fidelity as this codebase's existing `Validators.email`, standing in for Django's RFC-5322-ish `validate_email` (not reproduced bit-for-bit, consistent with this project's established approach to every other "validate against Django's exact validator" case).
- **Phone**: an optional leading `+`, then 7-20 characters of digits/spaces/`(`/`)`/`.`/`-` (`_phonePartRe`), **and** the digit count alone (ignoring punctuation) must be 7-15.
- **Name**: letters/spaces/`.`/`'`/`-` only (`_contactNameRe`), with at least 2 letters.
- **Precedence**: email check first (whenever `@` is present), then phone, then name — exactly `contact_part_error`'s own order.
- **Multiple contacts**: the whole value may be split on `,`, `/`, `|`, or `;`; every non-blank part must independently pass, or the whole field is rejected with one `CONTACT_MESSAGE`. All 4 separators are covered by individual tests (§6), not inferred from testing one.
- **Whitespace**: runs of whitespace are collapsed to a single space and the whole value trimmed (`_normaliseApplicationContact`) before either validation or submission — matching `clean_application_contact`'s own `re.sub(r'\s+', ' ', value).strip()` exactly. This is also the value actually sent in the payload (previously the screen only did a bare `.trim()`, leaving internal double-spaces unnormalised).

## 5. Exact error messages implemented

- Missing value (Non-IT only): `'Application Contact is required.'`
- Invalid format (any category, any non-empty value with a failing part): `'Application Contact should be a valid email address, phone number or contact name.'`

Both reproduced verbatim from the source re-read in §2, and verified as distinct, never co-occurring messages (§2's control-flow trace).

## 6. Tests added, commands run, and actual pass/fail counts

New group `PostNewJobScreen — Phase 58: Application Contact requiredness and format validation` (24 tests, all passing):

1. Required for Non-IT × Technical, with the real "is required" message.
2. Required for Non-IT × Non-Technical, with the real "is required" message.
3. Remains optional for IT — a valid IT submission with none still succeeds (also covers directive items 3 and 18 together).
4. A valid email address is accepted.
5. A valid phone number is accepted.
6. A valid contact name is accepted.
7-10. Each of the 4 separators (`,`, `/`, `|`, `;`) individually splits and accepts 2 valid parts — 4 separate tests, not inferred from one.
11. Multiple valid contacts across all 3 formats in one value are accepted.
12. Multiple contacts where one entry is invalid are rejected as a whole, with the real format error.
13. An invalid email-shaped value is rejected.
14. An invalid phone-shaped value (too few digits) is rejected.
15. An invalid name (digits mixed in) is rejected.
16. Phone digit-count boundaries below/above the floor and ceiling (6 and 16 digits) both fail, with the real format error.
17. A phone number with exactly 7 digits (the floor) is accepted.
18. A phone number with exactly 15 digits (the ceiling) is accepted.
19. A contact name with fewer than 2 letters is rejected.
20. Allowed name punctuation (hyphen, apostrophe, period) is accepted.
21. A disallowed character (underscore) in an otherwise name-shaped value is rejected.
22. Leading/trailing whitespace is trimmed and internal runs collapsed before submission.
23. Correcting an invalid value clears the error and allows submission.
24. Edit mode: an existing Non-IT posting with Application Contact loads and preserves it unchanged on resubmission.

**Note on test design**: the 7/15-digit boundary cases were originally written as 4 chained attempts (fail, pass, pass, fail) on one pumped screen; this failed because a *successful* submission navigates away from the screen (confirmed by the existing "navigates to Job Openings" test), so a later `enterText` on the now-disposed widget threw `StateError: No element`. Fixed by splitting into 3 tests: one chaining only the 2 *failing* boundaries (safe, since failed submissions stay on the form), and 2 separate dedicated tests for the 2 *passing* boundaries, each with its own pump — documented here per the directive's "if any proposed test case is inconsistent... follow the source and document the discrepancy," though this was a test-harness mechanics issue, not a Django-behavior discrepancy.

Existing fixtures/tests updated to keep passing (§1) — not new tests, but necessary corrections once Application Contact became a real requirement.

Commands and results:
```
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
→ 89 passing, 0 failing (65 pre-existing + 24 new)
```
```
flutter test test/features/employer
→ 202 passing, 0 failing (178 pre-existing + 24 new)
```
```
flutter test
→ 2,564 passing, 0 failing (2,540 pre-existing + 24 new — exact match against the Phase 57 baseline plus these additions; no regressions)
```
No existing assertion was weakened, removed, or modified to make a new test pass — the 4 fixture/test updates in §1 added a previously-missing valid field, they did not change any existing expectation.

## 7. Analysis results and existing warnings

```
flutter analyze
→ 8 issues found
```
Compared line-by-line against the Phase 57 baseline (also 8 issues): **identical file, line, and message for all 8** — the same pre-existing `unused_element_parameter` warnings in unrelated resume-controller test files. No issue changed, was introduced, or was resolved by this phase. `flutter analyze lib/features/employer/` on its own returns "No issues found."

## 8. Device/live-server verification status

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com`; no production data was touched. Verification in this phase is limited to the static analysis and widget-test results reported in §6-7. Automated widget tests are not reported as emulator or live-server verification.

## 9. Remaining limitations or unverified behavior

- The email check (`_emailLikeRe`) is a standard, reasonably strict pattern, not a bit-for-bit reproduction of Django's `validate_email` (which accepts some RFC 5322 edge cases, e.g. quoted local parts, that this regex does not) — this is the same, already-established level of fidelity used elsewhere in this codebase (`Validators.email`), not a new gap introduced by this phase.
- No live round-trip against the real server was performed to confirm it still returns these exact 2 messages unchanged; both were taken from direct, re-confirmed source reading (`forms.py`) rather than a live POST.
- The real web page's Application Contact `<input>` has no client-side JS validator of its own for format (§2) — Flutter's new local validation is strictly additive parity (catching the same server rule earlier), not a reproduction of an existing client-side behavior that didn't exist to begin with.
- This phase did not address any other Phase 56 audit finding (Age Limit validation, general text-field validation, or anything beyond Application Contact) — explicitly out of scope per the directive.

## 10. Confirmation: Django reference directories and backend APIs unchanged

Both Django reference directories (`royalStaffing_CB01`, `Career_Buddy_LMS`) were read-only throughout this phase — only `grep`/`sed -n`/`Read` were used against `jobs_app/forms.py`; no file in either tree was created, edited, deleted, or renamed. No backend API, request format, database model, migration, or production data was changed. The payload field name (`application_contact`) and the datasource's serialization (`JobPostingRemoteDataSource`) were inspected and confirmed to need no change — neither was edited.

## 11. Confirmation: unrelated working-tree changes preserved

`git status --short` before and after this phase shows the same 5 files already modified by Phases 52-57 (carrying this phase's additional diff), plus the 6 pre-existing untracked Phase 52-57 reports — no unrelated file was created, reset, stashed, or overwritten. The pre-existing unrelated changes in `Career_Buddy_LMS` (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) were left exactly as found. The Phase 52-57 fixes (conditional required fields, work-mode/education option lists, experience range fields, Contract Duration conditional visibility) were all re-verified still passing in the same test runs (§6) — none were reverted, weakened, or altered by this phase.

---

**This phase is complete.** Not starting Phase 59 or any subsequent phase without explicit approval.
