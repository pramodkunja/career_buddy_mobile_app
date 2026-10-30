# Phase 54 — Education Options and Custom Qualification Validation Parity

## 1. Source rules confirmed

Reference tree (read-only, never modified): `royalStaffing_CB01/jobs_app/` and `royalStaffing_CB01/templates/employer/job_form.html`.

**Per-category accepted preset values** — confirmed from three corroborating sources:

- `jobs_app/models.py:187-198`: `EDUCATION_CHOICES` (the full list, in declared order), `TECH_EDUCATION_KEYS = ['degree', 'diploma', 'iti', 'certification']`, `TECH_ONLY_EDUCATION_KEYS = ['degree', 'certification']`.
- `jobs_app/forms.py`'s `clean()` value-constraint rules (read in Phase 53, re-confirmed this phase): `dept_mode` (Non-IT × Technical) must pick from `TECH_EDUCATION_KEYS` or `'custom'`; `not dept_mode` (IT or Non-IT × Non-Technical) must not pick `TECH_ONLY_EDUCATION_KEYS`.
- `templates/employer/job_form.html:349-350` (the education combo's menu markup) + its `applyFieldMode()` JS (`job_form.html`, the block "Qualification presets: Degree / Diploma / ITI / Certification on the Technical sheet, the existing list elsewhere"): `li.hidden = tech ? !li.hasAttribute('data-tech') : !li.hasAttribute('data-it')`, where `const tech = isNonItTech();` — i.e. the *same* `dept_mode`/Non-IT×Technical boolean as the server.

All three sources agree: **IT and Non-IT × Non-Technical share one list; Non-IT × Technical gets a different, narrower list.** This was confirmed directly, not inferred from a single source.

**Stale-value handling on category/classification change** — `job_form.html`'s `applyFieldMode()`:
```js
if (eduMenu) {
    eduMenu.querySelectorAll('li').forEach(function (li) {
        li.hidden = tech ? !li.hasAttribute('data-tech') : !li.hasAttribute('data-it');
    });
    if (eduIsPreset()) {
        const items = ...querySelectorAll('li[data-value="' + eduSelect.value + '"]');
        if (!items.some(function (li) { return !li.hidden; })) eduApplyPreset('');
    }
}
```
`eduIsPreset()` is `Boolean(eduSelect.value && eduSelect.value !== 'custom')`. A selected **preset** no longer valid for the new mode is cleared to `''` (`eduApplyPreset('')` also clears `education_other`). A **typed/custom** value (`eduSelect.value === 'custom'`) is never touched by this block at all — "a preset that no longer applies is cleared (manual entries are kept)" per the template's own comment.

**`education_other` visibility and requiredness** — `forms.py` (re-read lines 905-918):
```python
if cleaned.get('education') == 'custom':
    other = self.normalise_education_text(cleaned.get('education_other'))
    if not other:
        self.add_error('education_other', 'Enter the educational qualification.')
    else:
        problem = self.education_text_error(other)
        if problem:
            self.add_error('education_other', problem)
        else:
            cleaned['education_other'] = other
else:
    cleaned['education_other'] = ''
```
This block is **unconditional on category** — it runs identically for IT, Non-IT × Technical, and Non-IT × Non-Technical whenever `education == 'custom'`. There is no category-specific variant of this rule; the directive's Phase 3 caveat ("if the web uses different custom-text rules for different categories, reproduce those differences") does not apply here — confirmed by direct reading, not assumed.

**`normalise_education_text` / `education_text_error`** — `forms.py:429-462`:
```python
EDUCATION_MAX_LEN = 60
EDUCATION_ALLOWED_RE = re.compile(r"^[A-Za-z0-9 ./,()&+'\-]+$")
EDUCATION_MESSAGES = {
    'too_long': f'Education must be {EDUCATION_MAX_LEN} characters or fewer.',
    'chars': "Education can contain only letters, numbers, spaces and . / - , ( ) & + '",
    'no_letters': 'Education must include letters, for example 10th, B.Tech or Diploma.',
    'digits': 'Numbers are allowed only as part of a qualification, such as 10th or 12th.',
}

@classmethod
def normalise_education_text(cls, text):
    return re.sub(r'\s+', ' ', (text or '')).strip()

@classmethod
def education_text_error(cls, text):
    if len(text) > cls.EDUCATION_MAX_LEN:
        return cls.EDUCATION_MESSAGES['too_long']
    if not cls.EDUCATION_ALLOWED_RE.match(text):
        return cls.EDUCATION_MESSAGES['chars']
    if not re.search(r'[A-Za-z]', text):
        return cls.EDUCATION_MESSAGES['no_letters']
    if (re.search(r'\d{3,}', text) or re.search(r'\d+(?![A-Za-z\d])', text)
            or len(re.findall(r'\d', text)) > 4):
        return cls.EDUCATION_MESSAGES['digits']
    return None
```
Corroborated verbatim (identical regexes and messages) in `job_form.html`'s own `eduTextError()` JS function, confirming this is the one true rule set, not a server/client divergence.

**Normalisation before submission**: `cleaned['education_other'] = other` — the server stores and expects the *normalised* text (whitespace collapsed, trimmed), not the raw typed input, whenever it's valid.

## 2. Accepted option set for each category/classification

| Category/classification | Accepted presets (order) | Evidence |
|---|---|---|
| IT | `below_10th, 10th, 11th, 12th, iti, diploma, ug, pg` (+ `custom`) | `EDUCATION_CHOICES` minus `custom` minus `TECH_ONLY_EDUCATION_KEYS`; `job_form.html:349`'s `data-it` items |
| Non-IT × Non-Technical | Same 8 as IT (+ `custom`) | Same `not dept_mode` rule/list — `forms.py` value-constraint check and `job_form.html`'s `data-it` items apply identically |
| Non-IT × Technical | `degree, diploma, iti, certification` (+ `custom`) | `TECH_EDUCATION_KEYS`, `tech_education_choices` property; `job_form.html:350`'s `data-tech` items |

## 3. Confirmed custom qualification rules

- **Shown**: whenever `education == 'custom'` (the "Enter manually" preset) — uniform across all categories.
- **Required**: only when `education == 'custom'`; otherwise `education_other` is discarded/irrelevant. Uniform across all categories (no category-specific variant exists).
- **Normalisation**: `re.sub(r'\s+', ' ', text).strip()` — collapse any run of whitespace to one space, then trim. Applied before both validation and submission.
- **Validation** (on the normalised text, in this exact order):
  1. Length over 60 → `'Education must be 60 characters or fewer.'`
  2. Not matching `^[A-Za-z0-9 ./,()&+'\-]+$` → `"Education can contain only letters, numbers, spaces and . / - , ( ) & + '"`
  3. No letters at all → `'Education must include letters, for example 10th, B.Tech or Diploma.'`
  4. A digit run of 3+ digits, OR a digit run not immediately followed by a letter/digit (a "standalone" number), OR more than 4 digits total → `'Numbers are allowed only as part of a qualification, such as 10th or 12th.'`
  5. Otherwise valid.
- **Submission contract**: `education` stays `'custom'`; `education_other` carries the normalised text (not the raw typed text) when valid, or `''` when `education != 'custom'`.

## 4. Root cause of each Flutter gap

- **Shared option list**: `kEducationPresets` (`job_posting_catalog.dart`) was a single flat list of all 10 presets, used identically via one `_dropdown(...)` call in `post_new_job_screen.dart` regardless of `_jobCategory`/`_jobClassification`. Nothing filtered it, so an employer could select a value the server's `clean()` value-constraint rules would reject (e.g. "Post-Graduate" on Non-IT × Technical, or "Degree" on IT) — this was the gap Phase 53's own report flagged as deliberately left open ("`TECH_EDUCATION_KEYS`/`TECH_ONLY_EDUCATION_KEYS`... a distinct 'accepted value set' class of gap").
- **No stale-value clearing for education**: `_onCategoryChanged`/`_onClassificationChanged` cleared other category-specific fields (`work_mode`, `notice_period`, etc. — the Phase 52 fix) but never touched `_educationPreset`, so a preset valid only on the sheet just left could remain selected and be submitted on the new sheet.
- **No `education_other` validation at all**: `_localRequiredErrors()` never checked `education_other` for emptiness or content when `_educationPreset == 'custom'`, and the custom `AppTextField` had no character/length filtering or error display wired to it (no `_fieldError('education_other')` call existed). An employer could type anything — or nothing — and it would reach the server unfiltered, needing a round trip to discover a rejection Flutter could have caught locally, exactly mirroring Phase 53's `education` gap one field deeper.

## 5. Files changed and purpose

- **`lib/features/employer/data/job_posting_catalog.dart`** — replaced the single `kEducationPresets` list with two category-specific lists, `kGeneralEducationPresets` (IT + Non-IT × Non-Technical, 8 presets) and `kTechEducationPresets` (Non-IT × Technical, 4 presets), preserving every existing value/label pairing exactly, with a doc comment citing the exact server/web evidence above.
- **`lib/features/employer/domain/entities/job_posting_submission.dart`** — updated the `educationPreset`/`educationOther` doc comments to reference the two new constants and to note `educationOther` is sent normalised (whitespace-collapsed, trimmed), matching the new submission behavior. No field/type change.
- **`lib/features/employer/presentation/screens/post_new_job_screen.dart`**:
  - Added `_educationOptionsFor(bool isNonItTech)`, mirroring the existing `_workModeOptionsFor` pattern, returning `kTechEducationPresets` when `isNonItTech` else `kGeneralEducationPresets`.
  - The education `_dropdown(...)` call now uses `_educationOptionsFor(_isNonItTech)` instead of the flat `kEducationPresets`.
  - `_onCategoryChanged` and `_onClassificationChanged` each gained a stale-education-preset clearing check (clears `_educationPreset` to `''` when it is a non-`'custom'` value no longer present in the newly-applicable option list) — mirroring the web page's `eduApplyPreset('')` behavior; `'custom'` values are explicitly exempted, matching "manual entries are kept."
  - Added `_normaliseEducationText` (static), `_educationMaxLen`/`_educationAllowedCharsRe` (static consts), and `_educationTextError` (static) — direct ports of `normalise_education_text`/`EDUCATION_MAX_LEN`/`EDUCATION_ALLOWED_RE`/`education_text_error`, same order of checks, same exact message text.
  - `_localRequiredErrors()` gained an unconditional (not category-gated) block: when `_educationPreset == 'custom'`, validates the normalised `_educationOther` text via the two helpers above and populates `errors['education_other']` accordingly.
  - The custom `AppTextField` for Qualification now has a trailing `_fieldError('education_other')`, matching the project's established error-display convention for other free-text fields.
  - `_submit()`'s `JobPostingSubmission` construction now sends `_normaliseEducationText(_educationOther.text)` instead of a bare `.trim()`, so the submitted value matches what the server itself would store.
- **`test/features/employer/presentation/screens/post_new_job_screen_test.dart`** — added the new `Phase 54` test group (13 tests, detailed in §6); no existing test was weakened or deleted.

No other file was touched. `job_posting_catalog.dart`'s and `job_posting_submission.dart`'s changes are scoped purely to the education constants/doc comments described above — no unrelated catalog entry was touched.

## 6. Tests added and results

New group `PostNewJobScreen — Phase 54: education options and custom qualification parity` (13 tests), all passing:

1. `IT shows the general education preset list, not the NON-IT×Technical sheet`
2. `Non-IT × Technical shows its own Degree/Diploma/ITI/Certification sheet, not the general list`
3. `Non-IT × Non-Technical shows the general education preset list, same as IT`
4. `a NON-IT×Technical-only Qualification (Degree) does not remain selected after switching to Non-Technical, and blocks submission again until re-picked`
5. `switching Job Category from Non-IT×Technical to IT clears a stale Degree selection`
6. `selecting "Enter manually" reveals the custom Qualification text field`
7. `empty custom Qualification text is rejected with the real server error`
8. `valid custom Qualification text passes local validation and reaches the repository`
9. `repeated internal whitespace in custom Qualification text is collapsed before submission`
10. `custom Qualification text with no letters is rejected with the real server error`
11. `a standalone number in custom Qualification text is rejected with the real server error`
12. `custom Qualification text over 60 characters is rejected with the real server error`
13. `correcting invalid custom Qualification text clears the validation error`

Education remaining required for both Non-IT classifications and optional for IT (directive items 6-7) continue to be covered by the still-passing Phase 53 tests, not duplicated here. The submitted `education`/`education_other` contract (directive item 13) is exercised directly by tests 8-9 above (`repo.submitted?.educationPreset`/`educationOther` assertions).

All 13 new tests pass; all pre-existing tests in this file (Phase 52's 9, Phase 53's 4, the original 5, and the 4 Edit-mode tests — 22 total before this phase) continue to pass unchanged.

## 7. Test counts

- Focused file (`post_new_job_screen_test.dart`): **35 passing, 0 failing** (22 pre-existing + 13 new).
- Employer feature suite (`test/features/employer`): **146 passing, 0 failing** (133 pre-existing + 13 new).
- Full suite (`flutter test`): **2,508 passing, 0 failing** — exactly Phase 53's baseline of 2,495 plus these 13 new tests; no regressions.

## 8. Analyzer comparison

`flutter analyze`: **8 issues**, identical file, line, and message to the Phase 53 baseline — the same pre-existing `unused_element_parameter` warnings in unrelated resume-controller test files, untouched by this phase.

## 9. Emulator/device verification

**Not performed.** No emulator or physical device was launched; no live network call was made to `careerbuddy4u.com` or any backend, consistent with the directive's "emulator verification is optional" and "do not fabricate an employer account... do not claim live submission or device verification." Verification in this phase is limited to static analysis and the Flutter widget-test suite described above.

## 10. Live-server behavior that remains unverified

- The exact live rendering/ordering of the education combo box's dropdown menu on `careerbuddy4u.com` was not visually confirmed in a browser — the option sets and ordering above come from direct source reading (`models.py`, `forms.py`, `job_form.html`), not a live page inspection.
- The real web page's combo box is a free-type-ahead input (any category can type arbitrary text that gets auto-converted to `'custom'` unless it exactly matches a preset label); Flutter's UI remains a plain dropdown + an explicit "Enter manually" option, a UI-shape difference pre-dating this phase (not introduced or changed by it — see §12). Whether this difference is ever perceived as a usability gap by real employers is unverified.
- Server rejection of an option this phase newly restricts (e.g., attempting to force-submit "Post-Graduate" on Non-IT × Technical via a non-UI path) was not tested against the live server — only against the validation rules as read from source.

## 11. Confirmation of safety boundaries

- Both Django reference trees were read-only for this phase: only `grep`, `sed -n`, and `Read` were used against `jobs_app/forms.py`, `jobs_app/models.py`, and `templates/employer/job_form.html`. No file in either tree was created, edited, deleted, or renamed.
- `git status` in `Career_Buddy_LMS` shows the same pre-existing modified/untracked files as Phase 53 (plus further untracked files that appeared from unrelated activity outside this session, e.g. `activities/tests_mcq_exercise_api.py`) — none of these were touched, read for editing purposes, or referenced by this phase's changes.
- No backend endpoint, migration, database change, seed, or production-data mutation was made.
- No authentication, OTP, role, subscription, or access-control behavior was touched.
- No production account was used; no fabricated test account was invented or claimed; no live submission was made or claimed.
- `git status --short` in `Mobile_app` shows exactly the same 4 modified files as Phase 52/53 (`job_posting_catalog.dart`, `job_posting_submission.dart`, `post_new_job_screen.dart`, `post_new_job_screen_test.dart`), now carrying this phase's additional diff on top, plus the two pre-existing untracked Phase 52/53 reports. No unrelated file was created, reset, stashed, or overwritten.
- No release build, signing config, or Play Store deployment step was touched or attempted.
- No signing file, keystore, credential, token, API key, or OTP/auth-bypass mechanism was inspected, printed, or modified.
- This phase implemented only the two named gaps (education option-list parity, custom qualification validation parity) — no other outstanding Item 5 gap (experience ranges, general text-field validation gaps, age-limit validation, contact validation, contract-duration validation) was touched, and the employer form was not refactored or redesigned; the dropdown + "Enter manually" UI shape from before this phase was preserved as-is (see §12).

## 12. Remaining job-posting gaps deliberately left outside this phase

- **Free-type-ahead combo UI**: the real web page lets an employer type any qualification directly into a single combo input (which silently resolves to a preset if it matches a label, or to `'custom'` otherwise), rather than Flutter's explicit dropdown + separate "Enter manually" text field. Reproducing this exact interaction model would be a UI redesign of the Education/Qualification control, explicitly out of scope ("do not redesign the job-posting form"); the *validation outcomes* (accepted presets, custom-text rules) are fully mirrored by this phase, but the *input mechanism* is not.
- **`education_other` live-keystroke filtering**: the web page's `eduCombo` input actively refuses disallowed keystrokes and a second consecutive space as the user types (`job_form.html`'s `keydown`/`input` handlers). Flutter's `AppTextField` for the custom qualification does not filter keystrokes; it validates on submit instead (and re-validates on correction, per test 13). This matches the project's established pattern for every other free-text field in this form (e.g. `functional_skills`, `application_contact`), none of which perform live keystroke filtering either, and was left consistent with that convention rather than introducing a one-off input formatter.
- All gaps explicitly named as out-of-scope by the Phase 54 directive (experience ranges, general text-field validation gaps, age-limit validation, contact validation, contract-duration validation) remain unaddressed, as instructed.
