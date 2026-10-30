# Phase 55 — Employer Job Posting: Experience Range Fields

## 1. Exact source rules and file/function references

Reference tree (read-only, never modified): `royalStaffing_CB01/jobs_app/forms.py`, `jobs_app/models.py`, `templates/employer/job_form.html`.

- **Field declarations** — `forms.py:359-368`: `experience` is a `forms.Select`; `experience_years` a visible/typed field (whole years, 2 digits max); `experience_plus` and `experience_years_max` are both `forms.HiddenInput` — i.e. the real page never shows raw inputs for these two, only JavaScript-driven UI writes to them.
- **Field-level error messages** — `forms.py:557-564`:
  ```python
  years = self.fields['experience_years']
  years.error_messages.update({
      'invalid': 'Enter a whole number of years (0-99).',
      'min_value': 'Experience years cannot be negative.',
  })
  self.fields['experience_years_max'].error_messages.update({
      'invalid': 'Enter the maximum experience as a whole number of years (0-99).',
      'min_value': 'Experience years cannot be negative.',
  })
  ```
- **Method-level range cap** — `forms.py:708-721` (`EXPERIENCE_YEARS_MAX = 99`):
  ```python
  def clean_experience_years_max(self):
      value = self.cleaned_data.get('experience_years_max')
      if value is not None and value > self.EXPERIENCE_YEARS_MAX:
          raise forms.ValidationError(f'Experience years must not exceed {self.EXPERIENCE_YEARS_MAX} (2 digits).')
      return value

  def clean_experience_years(self):
      value = self.cleaned_data.get('experience_years')
      if value is not None and value > self.EXPERIENCE_YEARS_MAX:
          raise forms.ValidationError(f'Experience years must not exceed {self.EXPERIENCE_YEARS_MAX} (2 digits).')
      return value
  ```
- **The custom-experience `clean()` block** — `forms.py:922-937`:
  ```python
  if cleaned.get('experience') == 'custom':
      years_min = cleaned.get('experience_years')
      years_max = cleaned.get('experience_years_max')
      if years_min is None and 'experience_years' not in self.errors:
          self.add_error('experience_years', 'Enter the required years of experience.')
      elif years_max is not None:
          if years_min is not None and years_min > years_max:
              self.add_error('experience_years', 'Minimum experience cannot be greater than maximum experience.')
          cleaned['experience_plus'] = False
  else:
      cleaned['experience_years'] = None
      cleaned['experience_years_max'] = None
      cleaned['experience_plus'] = False
  ```
- **The web page's experience combo box** — `templates/employer/job_form.html:694-849` (`expParseTyped`, `expApplyTyped`, `validateExperience`, the `keydown` handler). The regex `^(\d{0,2})(?:(-)(\d{0,2})|(\+)?)` and the `keydown` handler's mutual `!cur.sep`/`!cur.plus` guards prove "+" and a "-max" range can **never both be typed at once** — the UI itself is structurally exclusive, not just the server's defensive override.

## 2. Confirmed behavior for `experience_plus` and `experience_years_max`

1. **Accepted minimum experience values**: the 5 existing presets (`fresher`, `1-2`, `3-5`, `5-8`, `8+`) are unchanged by this phase, plus `'custom'` with a typed `experience_years` (0-99 whole years).
2. **`experience_plus`**: means "N or more years, no upper limit" (the web's typed "10+"). Only meaningful when `experience == 'custom'`; discarded (`False`) for any preset.
3. **`experience_years_max`**: the upper end of a typed "N-M years" range. Only meaningful when `experience == 'custom'`; discarded (`None`) for any preset.
4. **Display/submission**: both are hidden inputs on the web page, driven entirely by one combo box's typed text (`N`, `N+`, or `N-M`); digits go to `experience_years`, `+` to `experience_plus`, the second number of a range to `experience_years_max`.
5. **Mutual exclusivity**: confirmed both structurally (the combo's `keydown` handler refuses "+" once "-" has started, and vice versa) and authoritatively (`forms.py`'s `clean()`: `cleaned['experience_plus'] = False` unconditionally whenever `years_max is not None`). A supplied maximum always wins over "+".
6. **Requiredness**: `experience_years` (the minimum) is required only within `'custom'` mode (`'Enter the required years of experience.'` if missing). `experience_years_max` is always optional, even within `'custom'` — its absence is a normal "open minimum, no cap" state, not an error.
7. **Category differences**: **none found.** No branch in `forms.py`'s `clean()`, no `job_form.html` visibility rule (`.nonit-only`/`.tech-only`/etc. classes), and no model constraint ties `experience`/`experience_years`/`experience_plus`/`experience_years_max` to `job_category`/`job_classification`. This field behaves identically for IT, Non-IT × Technical, and Non-IT × Non-Technical — confirmed by the absence of any such rule, not assumed.
8. **Numeric constraints**: both fields are whole numbers, 0-99 inclusive (`EXPERIENCE_YEARS_MAX = 99`, "(2 digits)" in every over-limit message). Three distinct failure messages per field: non-numeric (`'invalid'`), negative (`'min_value'`), and over 99 (`clean_experience_years`/`clean_experience_years_max`'s own `ValidationError`). The minimum/maximum relationship rule (`'Minimum experience cannot be greater than maximum experience.'`) only applies when a maximum is actually supplied.
9. **Edit mode**: `job_form.html`'s pre-fill logic (`if (expSelect.value === 'custom') { ... expYears.value + (maxOn ? '-' + expMax.value : (plusOn ? '+' : '')) + ' Years' ... }`) confirms the same mutual-exclusivity rule governs how a *loaded* value is displayed: a loaded max takes priority for display over a loaded plus flag (though per the `clean()` rule, a legitimately saved row should never have both set at once).

## 3. Root cause of each gap

- `JobPostingSubmission`'s `experiencePlus`/`experienceYearsMax` fields, and `JobPostingRemoteDataSource`'s wiring of them into the POST body (`'experience_plus': data.experiencePlus ? 'True' : 'False'`, `'experience_years_max': data.experienceYearsMax`) and into `getJobForEdit`'s scrape (`_textValue(html, 'experience_plus') == 'True'`, `_textValue(html, 'experience_years_max')`), were **already fully correct** — confirmed by direct reading before any change, per the directive's "inspect before editing" instruction. The gap was entirely in `post_new_job_screen.dart`: no UI, no state variables, and a hardcoded `experiencePlus: false` / `experienceYearsMax: ''` at submission time threw away whatever an employer might have wanted to express, regardless of what they typed into the one `experience_years` field that did exist.

## 4. Files changed and purpose

- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added state: `bool _experiencePlus = false;` and `final _experienceYearsMax = TextEditingController();`.
  - Edit-mode load: `_experiencePlus = data.experiencePlus; _experienceYearsMax.text = data.experienceYearsMax;` alongside the existing `_experiencePreset`/`_experienceYearsTyped` load.
  - `dispose()`: added `_experienceYearsMax` to the controllers disposed.
  - `_localRequiredErrors()`: the `experience` branch now validates the minimum (`_experienceYearsError`, reused for both fields) and, when a maximum is supplied, validates it and the min/max relationship — see §5.
  - New helper `_experienceYearsError(String text, String invalidMessage)`: a direct, shared port of the field-level `'invalid'`/`'min_value'` messages plus the `> 99` method-level check, parameterised only by the one piece of wording that differs between the two fields.
  - UI: added a `CheckboxListTile` ("No upper limit (e.g. "10+ years")", wrapped in `Material(type: MaterialType.transparency, ...)` — see §5) and a new `AppTextField` ("Maximum years (optional)"), both nested inside the existing `if (_experiencePreset == 'custom')` block, with the Maximum years field conditionally hidden while the checkbox is checked.
  - `_submit()`: `experiencePlus`/`experienceYearsMax` now read from the new state instead of being hardcoded, with a submit-time backstop that forces `experiencePlus: false` whenever `experienceYearsMax` is non-empty — reproducing `clean()`'s own `cleaned['experience_plus'] = False` override even though the UI already makes the two mutually exclusive.
- **`lib/features/employer/domain/entities/job_posting_submission.dart`** — **not changed.** Confirmed by direct reading (§1 "Root cause") that `experiencePlus`/`experienceYearsMax` were already correctly typed and documented; per the directive's "change the domain model only if the current model cannot represent the source-defined values correctly," no edit was made.
- **`lib/features/employer/data/job_posting_catalog.dart`** — **not changed.** No experience-related constant needed adding (the 5 presets were already correct and untouched by this phase's gaps).
- **`lib/features/employer/data/job_posting_remote_datasource.dart`** — **not changed.** Confirmed already correct (§1 "Root cause"); inspected, not edited.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`** — added the new `Phase 55` test group (13 widget tests, §6).
- **`test/features/employer/data/job_posting_remote_datasource_test.dart`** — added 2 serialization tests confirming the datasource's pre-existing (and previously untested) `experience_plus`/`experience_years_max` wiring.

No other file was touched.

## 5. UI, state, validation, and payload changes

- **UI**: a `CheckboxListTile` for "10+" and an `AppTextField` for the maximum, both shown only when `_experiencePreset == 'custom'`; the maximum field additionally hides while the checkbox is checked. Checking the box clears any typed maximum (`_experienceYearsMax.clear()`), reproducing the web combo's structural exclusivity without inventing a new restriction.
  - **Incidental real-bug fix required for this UI to render safely in tests**: `CheckboxListTile` (via `ListTile`) paints its ink/ripple on the nearest `Material` ancestor; `AppCard`'s surface is a plain `Container`/`BoxDecoration`, not a `Material`, so its opaque background would visually hide the checkbox's own ripple/selection ink. Flutter's own framework assertion ("ListTile background color or ink splashes may be invisible") caught this immediately in the widget tests. Fixed by wrapping the `CheckboxListTile` in `Material(type: MaterialType.transparency, child: ...)`, a standard, narrowly-scoped fix — it does not touch `AppCard` itself or any other field on this screen.
- **State**: `_experiencePlus`/`_experienceYearsMax` persist independently of `_jobCategory`/`_jobClassification` — confirmed correct per §2 item 7 (no source rule ties experience to category), and verified by a dedicated test (§6, "survives switching Job Category").
- **Validation** (`_localRequiredErrors()`, errors keyed `'experience'` for the minimum/relationship, new key `'experience_years_max'` for the maximum — mirroring this screen's established one-error-per-logical-field convention from Phases 52-54):
  - Minimum: required (unchanged message `'This field is required.'` at the dropdown level), then `0-99` whole number (`'Enter a whole number of years (0-99).'`), negative (`'Experience years cannot be negative.'`), or `>99` (`'Experience years must not exceed 99 (2 digits).'`).
  - Maximum: only validated when non-empty (its absence is never an error — §2 item 6); same three-tier check with the maximum's own `'invalid'` wording (`'Enter the maximum experience as a whole number of years (0-99).'`).
  - Relationship: only checked when both values parse successfully and a maximum was supplied — `'Minimum experience cannot be greater than maximum experience.'`, shown under the same `'experience'` key as the minimum (matching the server's own `self.add_error('experience_years', ...)` attribution).
- **Payload**: `experiencePlus`/`experienceYearsMax` now reach `JobPostingSubmission` from real UI state instead of hardcoded `false`/`''`, with the submit-time mutual-exclusivity backstop described in §4. The existing `JobPostingRemoteDataSource.submit`/`submitEdit`/`getJobForEdit` wiring needed no change (§1).

## 6. Tests added and results

**`post_new_job_screen_test.dart`** — new group `Phase 55: experience range fields (experience_plus/experience_years_max)` (13 tests, all passing):

1. A normal minimum-experience preset still submits correctly (`experiencePlus: false`, `experienceYearsMax: ''`).
2. Selecting "No upper limit" produces `experiencePlus: true` and hides the Maximum years field.
3. A supplied Maximum years value is serialized correctly, with `experiencePlus: false`.
4. An empty optional Maximum years field submits successfully with an empty `experienceYearsMax`.
5. A negative minimum is rejected with `'Experience years cannot be negative.'`.
6. A minimum over 99 is rejected with `'Experience years must not exceed 99 (2 digits).'`.
7. A non-numeric maximum is rejected with `'Enter the maximum experience as a whole number of years (0-99).'`.
8. A maximum over 99 is rejected with `'Experience years must not exceed 99 (2 digits).'`.
9. A minimum greater than the maximum is rejected with `'Minimum experience cannot be greater than maximum experience.'`.
10. Checking "No upper limit" after typing a maximum clears it (re-unchecking shows an empty field, not the stale value).
11. An experience range survives switching Job Category (no source rule ties it to category).
12. Edit mode: a "10+" posting loads with the checkbox checked, the Maximum years field hidden, and resubmits the same values unchanged.
13. Edit mode: a range posting loads with Maximum years populated and the checkbox unchecked, and resubmits the same values unchanged.

**`job_posting_remote_datasource_test.dart`** — 2 new serialization tests:
1. `experience_plus` is sent as the literal string `'True'` (not a JSON bool) when "10+" is chosen, with `experience_years_max` empty.
2. A supplied `experience_years_max` is sent correctly, with `experience_plus` as `'False'`.

Directive items 1-13 are each covered by name above (items 6/9 together via tests 5-9; item 11 via test 11; item 12 via existing Phase 52/53/54 tests, confirmed still passing in the same run). No existing assertion was weakened.

## 7. Test counts

- Focused screen test file: **48 passing, 0 failing** (35 pre-existing + 13 new).
- Serialization (`job_posting_remote_datasource_test.dart`): **12 passing, 0 failing** (10 pre-existing + 2 new).
- Employer feature suite (`test/features/employer`): **161 passing, 0 failing** (146 pre-existing + 15 new).
- Full suite (`flutter test`): **2,523 passing, 0 failing** — exactly Phase 54's baseline of 2,508 plus these 15 new tests; no regressions.

## 8. Analyzer comparison

`flutter analyze`: **8 issues**, identical file, line, and message to the Phase 54 baseline — the same pre-existing `unused_element_parameter` warnings in unrelated resume-controller test files, untouched by this phase.

## 9. Device/emulator verification

**Not performed.** No emulator or physical device was launched; no legitimate employer account was available in this session, and none was fabricated; no live network call was made to `careerbuddy4u.com`; no authentication was bypassed. Verification in this phase is limited to static analysis and the Flutter widget/unit-test suite described above, consistent with the directive's "if device verification is unavailable, state that clearly."

## 10. Remaining unverified behavior

- **Live submission**: no real posting with `experience_plus=True` or a populated `experience_years_max` was ever submitted to `careerbuddy4u.com`; the server's acceptance of these values is taken from direct source reading (`forms.py`), not a live round trip.
- **Live combo-box UI parity**: the real web page's free-typing "N", "N+", "N-M" combo box was not visually compared in a browser during this phase; Flutter's checkbox + separate maximum field is a deliberately different, simpler input mechanism expressing the same underlying values (see §12), consistent with every prior phase's precedent of not reproducing the web's combo-box interaction model.
- **Edit-page scraping of `experience_plus`/`experience_years_max` from a real, live edited job** was not exercised against a real server response — `getJobForEdit`'s own existing test (`job_posting_remote_datasource_test.dart`) already covers this scraping logic generally, but no *new* live fixture with `experience_plus=True` or a real max was captured this phase; the new edit-mode screen tests use fabricated-but-schema-correct `JobPostingSubmission` fixtures instead of a live HTML scrape.

## 11. Confirmation of safety boundaries

- Both Django reference trees were read-only for this phase: only `grep`, `sed -n`, and `Read` were used against `jobs_app/forms.py`, `jobs_app/models.py`, and `templates/employer/job_form.html`. No file in either tree was created, edited, deleted, or renamed.
- `git status` in `Career_Buddy_LMS` shows the same pre-existing modified/untracked files as prior phases (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, several untracked `activities/tests_*.py` files) — none touched, read for editing, or referenced by this phase's changes.
- No backend endpoint, migration, database change, seed, or production-data mutation was made.
- No authentication, OTP, role, subscription, or access-control behavior was touched.
- No production account was used; no fabricated test account was invented or claimed; no live submission was made or claimed.
- `git status --short` in `Mobile_app` shows exactly the 5 files listed in §4 as modified (the first 2 carrying only their pre-existing Phase 54 diff, confirmed unmodified by this phase — see §4), plus the 3 pre-existing untracked Phase 52/53/54 reports. No unrelated file was created, reset, stashed, or overwritten.
- No release build, signing config, or Play Store deployment step was touched or attempted.
- No signing file, keystore, credential, token, API key, or OTP/auth-bypass mechanism was inspected, printed, or modified.
- The Phase 52 (category-specific required fields, work-mode options), Phase 53 (education requiredness), and Phase 54 (education option lists, custom qualification validation) fixes were all verified still in place and passing (§6, §7) — none were reverted, weakened, or altered by this phase.
- This phase implemented only the two named experience gaps (`experience_plus`, `experience_years_max`) — no other outstanding gap (text-field character rules, age-limit validation, application-contact validation, contract-duration validation) was touched, and the employer form was not redesigned; the one incidental fix made (§5's `Material` wrap) is a minimal, narrowly-scoped rendering correctness fix required for the new control itself to behave correctly, not a broader change.

## 12. Remaining employer job-posting gaps deliberately left outside this phase

- **Free-type-ahead combo UI**: as with Phase 54's education combo, the real web page lets an employer type "5", "10+", or "2-5" directly into one input; Flutter instead uses a dropdown + separate minimum field + checkbox + optional maximum field. The *validation outcomes and submitted values* are fully mirrored; the *input mechanism* is not, consistent with this project's established "do not redesign the form" boundary.
- **Live keystroke-level filtering** (the web combo refuses non-digit/`+`/`-` keystrokes as the user types) is not reproduced for the same reason this was left out of Phase 54's `education_other` field: submit-time validation is this project's established convention for every free-text/typed field on this form, not live input filtering.
- All gaps explicitly named as out-of-scope by the Phase 55 directive (text-field character rules, age-limit validation, application-contact validation, contract-duration validation) remain unaddressed, as instructed.
