# Phase 12 — Fix Silent Parser-Fallback Defects (englishLevel, openings)

Flutter-only fix, implementing the single recommended next phase from
`docs/PHASE_11_REMAINING_PARITY_REVIEW.md` §6: the two new "false success"
parser-fallback defects found during that audit's sweep. Django/web repo
was not modified (read-only, and not even needed this phase — both fixes
are pure Flutter-side parsing/validation changes against an already-stable
backend contract).

## 1. The two defects fixed

### A. `ProfileRemoteDataSource._extractEnglishLevel`

`englishLevel` (`users/profile.html`'s `english_level` `<select>`) has
**no edit-tab UI anywhere in this app** — it exists purely so
`updateProfile()` can echo the server's current value back unchanged
(Django's `english_level` is `required=True` with no Flutter control to
set it; omitting it entirely would fail every save). Previously, if the
`<select>` block or its `selected` option couldn't be matched, the parser
silently substituted `'intermediate'` — a plausible, real-looking answer —
which then got unconditionally re-POSTed as the user's actual English level
on every subsequent profile save, with no error ever surfaced. Since the
field has no UI, a user could never notice or correct a wrong value.

### B. `JobPostingRemoteDataSource._parseJobForm`'s `openings` field

Scraped from the live job-edit form and used to seed the Edit screen's
"Total Openings"/"Number of Vacancies" text field. Previously defaulted to
`1` on a parse miss, then re-POSTed verbatim on save. Lower severity than
(A) because the value is at least visible in a text field an employer
*could* notice — but the same shape of defect: a guessed count presented as
if it were the job's real current value.

Both were confirmed correct against current markup (i.e. **latent**, not
currently manifesting) before this fix — consistent with how this
engagement has always classified this defect class (same as the
already-fixed Phase 6 employer-status bug).

## 2. Remediation approach

Mirrors Phase 6's own established pattern exactly: **make the field
nullable, fail loudly, never let a guessed value reach a save.**

- **`englishLevel`**: `ProfileOverview.englishLevel` and
  `ProfileEditData.englishLevel` are now `String?`.
  `_extractEnglishLevel` returns `null` (not `'intermediate'`) on either
  failure path. `ProfileRemoteDataSource.updateProfile()` now checks
  `data.englishLevel` first and **throws a `ValidationException` before
  building any request** if it's `null` — the existing `_submit()` →
  `Failed(failure)` → `_submitError = failure.message` UI wiring in
  `profile_screen.dart` already surfaces this cleanly with **zero screen
  changes needed**.
- **`openings`**: `JobPostingSubmission.openings` is now `int?`.
  `_parseJobForm` returns `int.tryParse(...)` directly (no `?? 1`).
  `post_new_job_screen.dart`'s edit-seeding (`_openings.text = ...`) now
  shows an empty string instead of a guessed number when `null` — which
  the screen's **own existing** "Please enter a valid numeric value."
  validator (unchanged) already blocks Save on, with **zero new
  validation/UI code**. `JobPostingRemoteDataSource._postJob`'s POST-body
  construction uses `data.openings?.toString() ?? ''` as a defense-in-depth
  fallback (never expected to fire in practice, since the screen's own
  validator guarantees a real value by the time a submission is built —
  but an empty string there is still an honest "missing" signal the
  server's own `err_openings` validation would correctly reject, never a
  guess).

Neither fix required a new exception/failure type, a new dependency, a
backend change, or a UI redesign — both reuse infrastructure that already
existed for exactly this purpose.

## 3. Files changed

- `lib/features/auth/domain/entities/profile_data.dart` — `englishLevel`
  nullable on both `ProfileOverview` and `ProfileEditData`; doc comments
  updated.
- `lib/features/auth/data/datasources/profile_remote_datasource.dart` —
  `_extractEnglishLevel` returns `String?`; `updateProfile()` guards
  against `null` before any network call.
- `lib/features/employer/domain/entities/job_posting_submission.dart` —
  `openings` nullable; doc comment updated.
- `lib/features/employer/data/job_posting_remote_datasource.dart` —
  `_parseJobForm`'s `openings` parse no longer defaults to `1`; `_postJob`'s
  POST body handles `null` safely.
- `lib/features/employer/presentation/screens/post_new_job_screen.dart` —
  edit-seeding shows blank instead of a guessed number.
- `test/features/auth/data/datasources/profile_remote_datasource_test.dart` —
  replaced the one existing test whose premise was now wrong ("defaults
  ... safely" asserted `'intermediate'`) with two new ones asserting
  `null`, plus one new `updateProfile` regression test.
- `test/features/employer/data/job_posting_remote_datasource_test.dart` —
  one new regression test.
- `test/features/employer/presentation/screens/post_new_job_screen_test.dart` —
  one new regression test (full widget-level: blank field + blocked save).

No other file was touched. No Django/web file was read or modified this
phase.

## 4. Before/after behavior

| Scenario | Before | After |
|---|---|---|
| Profile page's `english_level` select/selected-option missing from markup | `englishLevel = 'intermediate'`, silently resubmitted on next save | `englishLevel = null`; `updateProfile()` throws before sending anything; screen shows a clear error, no save occurs |
| Profile page's `english_level` select present and matched | Unchanged — real value used | Unchanged — real value used |
| Job-edit form's `openings` input missing/unparseable | `openings = 1`, shown as if real, resubmitted on save | `openings = null`; Edit screen shows the field blank; existing validator blocks Save until a real number is entered |
| Job-edit form's `openings` input present and parseable | Unchanged — real value used | Unchanged — real value used |
| `bio`/`additionalEducationsJson` missing from markup | Defaults to `''`/`'[]'` | **Unchanged** — these two still default safely (never resubmitted as a guessed *choice*, just an empty string/array, which was never the defect) |

## 5. Tests and verification

```
flutter analyze lib/features/auth/ test/features/auth/
  No issues found!
flutter analyze lib/features/employer/ test/features/employer/
  No issues found!
flutter analyze (whole project)
  No issues found!

flutter test test/features/auth/data/datasources/profile_remote_datasource_test.dart
  (part of the auth suite run below)
flutter test test/features/employer/data/job_posting_remote_datasource_test.dart
  10/10 passed, including the new regression test
flutter test test/features/employer/presentation/screens/post_new_job_screen_test.dart
  9/9 passed, including the new regression test
flutter test test/features/employer/ test/features/auth/ test/app/
  257/257 passed

flutter test (full suite)
  1926 passed, 0 failed
```

Baseline immediately before this phase (end of Phase 10) was **1922**
passing. **+4**, matching exactly the 4 new regression tests added (2 net
new in the profile datasource test — one old test replaced by two new ones
— plus 1 in the job-posting datasource test, plus 1 widget test). Zero
regressions anywhere else in the suite.

No live device, emulator, or production backend was used. Every result
above is from the local Flutter toolchain against the existing
fake-HTTP-adapter test doubles, exactly matching how Phase 6 (the
precedent this phase followed) was itself verified.

## 6. Confirmations

- **Both defects are fixed using the exact nullable/fail-loud pattern
  Phase 6 established** — no new exception/failure type, no new
  dependency, no backend/Django change.
- **No other behavior changed**: `bio`/`additionalEducationsJson`'s
  existing safe-empty-default behavior is untouched; every other field in
  both affected files is untouched; the happy path (markup matches,
  real value scraped) is byte-for-byte unchanged for both fixes, confirmed
  by the existing (unmodified) tests for the matched-value case still
  passing.
- **Django/web repository was not modified** — not read this phase either;
  both fixes were fully specified by Phase 11's own citations, re-verified
  directly from current Flutter source before changing anything.
- No dependency, build setting, signing asset, or production data was
  touched.
- No build, deploy, or upload step was run.

---

Phase 12 complete. Per Phase 11's own prioritization, the next strongest
candidates for a future phase remain **GST invoice link-out** (P1-D) and
**generic login/registration error messages** (P1-E) — neither started
this phase, per the instruction to keep this phase narrowly scoped to the
two silent-fallback defects only. Awaiting direction on what to take up
next.
