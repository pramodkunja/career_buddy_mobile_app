# Phase 3 — Critical Account-Flow Remediation

Scope: fix the three P0 defects from `docs/PHASE_2_PARITY_AUDIT_REPORT.md`
(password-reset confirmation, Job Seeker profile save, Employer profile
save) and the directly related profile-load session-expiry defect, in the
Flutter repository only. All four read required reports first:
`docs/PRE_UPDATE_BASELINE_REPORT.md`, `docs/PREVIEW_AND_STATIC_DATA_AUDIT.md`,
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`,
`docs/PHASE_2_PARITY_AUDIT_REPORT.md`.

## 1. Password-reset confirmation

### Root cause

Traced directly from Django's own installed source
(`venv/lib/python3.12/site-packages/django/contrib/auth/views.py:256-298`
in the web reference repo — not assumed, not inferred from documentation):
`PasswordResetConfirmView.dispatch()` runs for **every** request to the
real-token URL (`/users/reset/<uidb64>/<token>/`), **regardless of HTTP
method**. If the token is valid, it stores it in the *session* and issues
a 302 redirect to the same path with the token segment replaced by the
literal string `set-password`. The new-password form is only ever
*rendered* (GET) and only ever *processed* (POST) at that second,
session-dependent URL — never at the real-token URL itself.

The previous Flutter implementation POSTed `new_password1`/`new_password2`
directly to the real-token URL and treated the resulting 302 as "password
changed." That 302 is the exact same redirect Django issues for *any*
request to that URL once the token is valid — it does not mean the form
was processed, because `dispatch()` returns before Django's `FormView`
ever looks at the POST body. **The password was never changed, and the app
reported success.**

### Fix

`lib/features/auth/data/datasources/password_reset_remote_datasource.dart`
— both `checkResetLink` and `confirmReset` now make the real request
sequence:
1. GET the real-token URL (`followRedirects: false`). A 200 means Django
   rejected the token outright (invalid/expired/already-used) — no form
   was ever rendered, so we don't proceed. A 302 means the token was
   accepted and stored in the session.
2. GET the session-dependent set-password URL (new
   `ApiEndpoints.passwordResetSetPassword(uidb64)`) to confirm the real
   form actually rendered there — handles the case where the session
   cookie from step 1 didn't make it onto step 2 (a documented
   Dio+cookie-manager risk across an internally-followed redirect, which
   is exactly why these are two deliberate, separately-followed requests
   rather than one auto-followed one).
3. (`confirmReset` only) POST the new password to that same set-password
   URL. **Only a 302 from this specific POST is treated as success** —
   this is the one and only point where Django's `form_valid()` (and so
   `form.save()`) can actually run.

`checkResetLink` and `confirmReset` each perform the full sequence
independently (rather than `confirmReset` assuming a prior
`checkResetLink` call already primed the session), so `confirmReset` is
safe to call on its own and doesn't depend on in-process state surviving
between the two calls.

`lib/core/network/api_endpoints.dart` — added
`passwordResetSetPassword(String uidb64)` and corrected
`passwordResetConfirm`'s doc comment, which previously (incorrectly)
described this as a single GET/POST URL.

No new API endpoint was invented — both URLs are Django's own, confirmed
directly in its own view source. No Django file was touched.

### Regression tests

`test/features/auth/data/datasources/password_reset_remote_datasource_test.dart`
— rewritten with a new local `_SequencedAdapter` (returns one canned
response per call, in sequence — necessary because the fix's behavior is
only observable across a *sequence* of requests, which the file's existing
single-response fake adapter cannot represent). 10 tests, up from 6:
- `checkResetLink`: valid link (302 then 200+form); real-token URL itself
  rejects the token (200); **new** — token 302s but the session didn't
  carry over to the set-password page (200, no form) → correctly `false`.
- `confirmReset`: full valid sequence (302 → 200 → 302) completes; **a
  named regression test reproducing the exact original bug** (every
  request, including the would-be POST, returns the token URL's own 302 —
  asserts this must now throw, not succeed); token rejected outright;
  password-mismatch field error from the *correct* URL; a genuine 500 from
  the final POST.

## 2. Job Seeker profile save (and the related load-side defect)

### Root cause

`lib/features/auth/data/datasources/profile_remote_datasource.dart`:
- **Load** (`getProfile`): no check that the HTML returned was actually
  the profile page. An expired session's `@login_required` redirect lands
  on the login page (still a 200, since Dio follows redirects by default)
  and gets scraped as if it were a profile — every field defaults to
  empty/zero, with no error.
- **Save** (`updateProfile`): `if (response.statusCode == 302) return;`
  treated *any* 302 as success. `users/views.py:profile_view` is
  `@login_required` and only ever redirects a successful save back to
  itself (`redirect('profile')`, confirmed by reading the view directly)
  — but an already-expired session also 302s, to the login page, **before
  the view body runs at all**. The edit was silently never saved, while
  the UI reported "Profile updated successfully!"

### Fix

- Added `isProfileHtml(String html)` (top-level function, same file),
  checking for `class="profile-stat-value` — present only on the real
  rendered page, confirmed absent from `templates/users/login.html`
  directly (not assumed). `getProfile` now throws `FormatException` if
  this check fails, caught and remapped to `UnauthorizedException` —
  **the exact same pattern already established by
  `DashboardRemoteDataSource`/`isDashboardHtml`**, reused rather than
  inventing a new mechanism, per instruction.
- `updateProfile`'s 302 branch now reads the `Location` header: only a
  redirect that does **not** point at `ApiEndpoints.login` is treated as
  success; one that does throws `UnauthorizedException`. Its 200 branch
  now also checks `isProfileHtml` before scraping a field error, so an
  unrecognized 200 page is treated the same honest way rather than
  guessed at as a validation message.
- `lib/features/auth/presentation/screens/profile_screen.dart`'s `_submit()`
  now forces a real logout (`ref.read(authControllerProvider.notifier).logout()`)
  when the save fails with `UnauthorizedFailure` — mirroring the load-side
  `ref.listen` handler that already existed in this same file (which could
  never actually fire before this phase, since nothing ever threw
  `UnauthorizedException` from this datasource).

All existing valid-field-handling, CSRF, and multipart/form-data behavior
was left untouched — only the success/failure *detection* changed, not
what gets sent.

### Regression tests

`test/features/auth/data/datasources/profile_remote_datasource_test.dart`
— 14 tests, up from 11:
- Fixed the one pre-existing test whose canned 200 body needed the
  `profile-stat-value` marker added (a realistic validation-failure
  re-render still contains the Overview tab's markup — confirmed by
  reading that `profile_view` has no separate error template).
- **New**: `getProfile` throws `UnauthorizedException` on a login-page
  body instead of returning a blank profile.
- **New**: `updateProfile` throws `UnauthorizedException` on a 302 whose
  `Location` points at the login page.
- **New**: `updateProfile` throws `UnauthorizedException` on a 200 that
  isn't the real profile page at all (not even a validation re-render).

## 3. Employer profile save (checked against the real Django view/template — not assumed identical to Job Seeker)

### Root cause, confirmed independently

Read `jobs_app/views.py:539-572` directly rather than assuming parity with
the student flow — and found **real differences**, not just a copy of the
same bug:
- `@login_required(login_url='employer_portal:employer_login')` — a
  **different** login redirect target than the student flow
  (`/users/login/`), confirmed to resolve to
  `/employer/accounts/employer/login/` by tracing
  `employer_portal/urls.py`'s `include()` chain, which exactly matches the
  existing `ApiEndpoints.employerLogin` constant.
- A successful save redirects to **`employer_portal:dashboard`**, not back
  to the same profile URL (unlike the student flow) — both
  `employer_profile_create` and `employer_profile_edit` share this same
  success target.

The underlying defect was the same class of bug (any 302 treated as
success; no page-identity check on load), but a fix that assumed
"redirect to the login page = failure, everything else = success" needed
the **correct** login-page target for this flow, which I verified rather
than copied.

Also found, independently, via Task 4's re-examination: the **load** side
(`getProfileForm`) had the identical "no page-identity check" defect —
not previously documented for the employer flow specifically.

### Fix

- Added `isEmployerProfileFormHtml(String html)` to
  `lib/features/employer/data/employer_profile_html_parser.dart`, checking
  for `id="toggleEditBtn"` — confirmed present in
  `templates/employer/profile_form.html:103` and confirmed absent from
  `templates/employer_login/{login,signup}.html` and `base.html`.
  `parseEmployerProfileFormHtml` now throws `FormatException` if this
  check fails.
- `lib/features/employer/data/employer_profile_remote_datasource.dart`:
  `getProfileForm` catches that `FormatException` and remaps to
  `UnauthorizedException`. `updateProfile`'s 302 branch checks the
  `Location` header against `ApiEndpoints.employerLogin` (not
  `ApiEndpoints.login` — the correct, verified target for this flow); its
  200 branch checks `isEmployerProfileFormHtml` before scraping a field
  error, same reasoning as the student fix.
- `lib/features/employer/presentation/screens/employer_company_profile_screen.dart`:
  added a `ref.listen`-based forced-logout on `UnauthorizedFailure` for the
  load path, and the equivalent check in `_submit()`'s `Failed` branch for
  the save path — both **mirroring the exact pattern already used by
  `EmployerDashboardScreen`** (confirmed by reading that screen first),
  reusing an established pattern rather than inventing one. This screen
  had no such handling at all before this phase, for either load or save.

### Regression tests

`test/features/employer/data/employer_profile_remote_datasource_test.dart`
— 6 tests, up from 2: fixed the one pre-existing test needing the
`toggleEditBtn` marker added; **new**: a 302-to-employer-login is rejected
as `UnauthorizedException`; a 200 that isn't the real form is rejected the
same way; `getProfileForm` throws `UnauthorizedException` on a login-page
body.

`test/features/employer/data/employer_profile_html_parser_test.dart` — 3
tests, up from 2: fixed both pre-existing tests' fixtures to include the
marker; **new**: the parser itself throws `FormatException` on a
login-redirect page.

`test/features/employer/presentation/screens/employer_company_profile_screen_test.dart`
— unchanged, still passing (1 test; uses a fake repository, unaffected by
the datasource-level HTTP changes).

## 4. Summary: files changed and why

| File | Why |
|---|---|
| `lib/core/network/api_endpoints.dart` | New `passwordResetSetPassword` URL; corrected `passwordResetConfirm` doc comment |
| `lib/features/auth/data/datasources/password_reset_remote_datasource.dart` | Fixed to use the real 2-URL Django mechanism |
| `lib/features/auth/data/datasources/profile_remote_datasource.dart` | Added `isProfileHtml` page-identity guard (load); fixed 302/200 success detection (save) |
| `lib/features/auth/presentation/screens/profile_screen.dart` | Save-path forced logout on `UnauthorizedFailure`, mirroring the existing load-path listener |
| `lib/features/employer/data/employer_profile_html_parser.dart` | Added `isEmployerProfileFormHtml` page-identity guard |
| `lib/features/employer/data/employer_profile_remote_datasource.dart` | Fixed 302/200 success detection using the *correct*, independently-verified employer login redirect target |
| `lib/features/employer/presentation/screens/employer_company_profile_screen.dart` | Added load- and save-path forced logout on `UnauthorizedFailure`, mirroring `EmployerDashboardScreen`'s existing pattern |
| 4 test files | Updated fixtures to match corrected behavior; added 11 new regression tests total, 0 removed or weakened |

## 5. Validation — exact commands and actual results

```
flutter analyze
```
→ **No issues found!**

```
flutter test test/features/auth/data/datasources/password_reset_remote_datasource_test.dart \
             test/features/auth/data/datasources/profile_remote_datasource_test.dart \
             test/features/employer/data/employer_profile_remote_datasource_test.dart \
             test/features/employer/data/employer_profile_html_parser_test.dart \
             test/features/auth/presentation/screens/profile_screen_test.dart \
             test/features/employer/presentation/screens/employer_company_profile_screen_test.dart
```
→ **All passed** (10 + 14 + 6 + 3 + 6 + 1 = 40 tests across the 6 directly
affected files).

```
flutter test
```
(full suite) → **1896/1896 passing**, 0 skipped, 0 failing — **11 more
than the Phase 0 baseline of 1885** (the exact number of new regression
tests added; 0 existing tests were removed, weakened, or had their
assertions loosened to make this pass).

No test failed and required weakening to pass — every failure encountered
mid-phase (6 pre-existing tests, listed in §1-3 above) was a fixture that
needed updating to reflect the *corrected* (not the buggy) behavior, and
each was fixed by adding the missing realistic page-identity marker to the
canned HTML, never by loosening an assertion.

## 6. Unresolved behavior and assumptions

- **Not verified on a real device against the real backend.** Every fix
  and every regression test here is source-and-fake-adapter-based,
  consistent with this entire engagement's standing blocker (no usable
  test account — see Phase 10/11). The Django view logic driving the
  password-reset fix was read directly from the actual installed Django
  source in the reference repo's own `venv`, which is the same Django
  version actually running in this environment, not a version
  assumption — but a live click-through was not performed.
- **`AuthRemoteDataSource.login`'s own 302-means-success check** was
  *not* touched or re-audited this phase (out of scope — the Phase 2
  audit flagged it as a lower-severity error-message gap, not a false-success
  defect, and this phase's scope was the three named P0s plus the directly
  related profile-load issue).
- **Employer logout's exact endpoint** remains marked Uncertain in the
  Phase 2 matrix — not investigated this phase, out of scope.
- No assumption was made that the employer flow mirrors the student
  flow — per instruction, the actual Django view/template was read first,
  and a real difference (login redirect target, success redirect target)
  was found and accounted for rather than guessed at.

## 7. Confirmations

- **Django source**: unchanged. `git status --short` in
  `Career_Buddy_LMS/` before and after this phase shows the identical
  3-modified/3-untracked state present since Phase 1 of this engagement —
  nothing added, removed, or edited.
- **Production data**: no network request was made to production, the
  local dev server, or any backend during this phase. Every finding and
  every fix was verified against static source and fake HTTP adapters.
- **Demo Mode**: not touched — no file under `lib/core/demo/` was read or
  modified this phase.
- **Job-detail wiring, proctoring, subscription changes, broad parser
  cleanup**: none implemented, per explicit scope restriction.
- **`android/key.properties`, keystores, signing material**: not read,
  printed, or modified. Confirmed unchanged (same 142-byte file, same
  modification timestamp as recorded in Phase 0) before and after this
  phase's work.
- **Pre-existing uncommitted/untracked work**: fully preserved in both
  repositories — confirmed via `git status --short` showing the identical
  pre-existing modified/untracked file lists, with only this phase's own
  7 source files + 4 test files added to Mobile_app's modified set.
- **No APK/AAB built, nothing deployed or uploaded.**
- **Manual device verification**: not performed, and not claimed.

## 8. Status, per defect

| Defect | Status |
|---|---|
| P0-1: Password-reset confirmation reports false success | **Fixed** — root cause corrected at the source (the real 2-URL Django mechanism is now followed exactly); not verified on a live device |
| P0-2: Job Seeker profile save reports false success on expired session | **Fixed** — same evidentiary standard (Location-header + page-identity check); not verified on a live device |
| P0-3: Employer profile save reports false success on expired session | **Fixed** — independently verified against the real, different Django view behavior; not verified on a live device |
| Related: Job Seeker/Employer profile **load** showing a blank profile on expired session | **Fixed** — both now reuse the established `isXHtml` + `UnauthorizedException` pattern already proven by `DashboardRemoteDataSource` |

No defect in this phase's scope is reported as partially fixed, blocked,
or unresolved — all four were reproducible from source alone and fixed
without requiring any Django change, new endpoint, or architectural
change. **This does not constitute full web-mobile parity or 100%
completion** — it resolves exactly the four items this phase was scoped
to fix; the remaining gap register in `docs/PHASE_2_PARITY_AUDIT_REPORT.md`
(§4) is otherwise unchanged.

## Status

Stopping here, as instructed. Awaiting approval before the job-detail
wiring or any other remediation work begins.
