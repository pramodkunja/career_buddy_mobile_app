# Phase 14 — Login & Registration Error Message Audit and Remediation

Flutter-only fix. Django/web repository was read-only reference material
(nothing modified). No authentication rule, session/CSRF behavior, OTP
gate, role check, or subscription restriction was changed — only the
*message* shown for an already-correctly-detected failure.

## 1. Files inspected (Step 1)

**Flutter**: `lib/features/auth/data/datasources/auth_remote_datasource.dart`
(student login/register/OTP), `employer_auth_remote_datasource.dart`
(employer login/register/OTP), `lib/core/errors/{exceptions.dart,
failures.dart,exception_mapper.dart}` (shared exception→message mapping),
`login_screen.dart`, `register_screen.dart`, `employer_login_screen.dart`,
`employer_register_screen.dart` (error-display UI and loading/duplicate-
submission guards), `auth_controller.dart` (state machine feeding the
screens), and every existing test under `test/features/auth/` /
`test/core/errors/`.

**Django (read-only)**: `users/views.py` (`login_view:222-244`,
`register_view:153-188`, the lockout helpers `_login_is_locked_out`/
`_record_login_failure`/`_login_failure_keys:191-219`), `users/forms.py`
(`LoginForm:564-583`, `RegisterForm:175+`), `accounts_app/views.py`
(`EmployerLoginForm:32-41`, `EmployerLoginView:86-97`,
`employer_register:44-83`), `accounts_app/forms.py` (`EmployerRegisterForm`
— confirmed no `clean()` override), and the four relevant templates:
`templates/users/login.html`, `templates/employer_login/login.html`,
`templates/users/register.html`, `templates/employer_login/signup.html`.

## 2. Previous behavior and confirmed Django contract

All four flows (student login, employer login, student registration,
employer registration) already correctly distinguish success (302) from
failure (200 re-render) — that detection logic was already correct and
**was not changed**. The gap was narrower: every failure, regardless of
cause, reported one hardcoded generic string, even though Django's own
response already contains a real, specific, safe-to-show message.

**Confirmed from source, not assumed:**

- **Student login** (`users/views.py:222-244`): a lockout (5 failed
  attempts / 15 min, keyed by IP **and** username, either tripping blocks —
  `LOGIN_FAILURE_LIMIT=5`, `LOGIN_LOCKOUT_SECONDS=900`) is checked *before*
  form validation and flashes `'Too many failed login attempts. Please try
  again in a few minutes.'` via Django's `messages` framework (rendered in
  `base.html:224-235`'s shared `.messages-container`, the same `role=
  "alert"` pattern this app already scrapes elsewhere for flashed errors).
  Otherwise, `LoginForm.clean()` (`users/forms.py:575-583`) raises either
  Django's own default "wrong credentials" error or a distinct
  `"Employer accounts cannot log in through the student portal."` when the
  submitted credentials belong to an employer account — both rendered
  inside `login.html:49-65`'s own `.alert.alert-danger` block (which itself
  template-overrides Django's raw wording to a clean "Invalid username or
  password. Please try again." for the wrong-credentials case — this app
  now surfaces that already-sanitized text verbatim, never Django's raw
  message, so no account-existence information is newly exposed).
- **Employer login**: `EmployerLoginView` (`accounts_app/views.py:86-97`)
  is a bare Django `auth_views.LoginView` — confirmed no lockout logic and
  no `messages.error` call anywhere on this path. `EmployerLoginForm.clean()`
  (`accounts_app/views.py:32-41`) raises `"Student accounts cannot log in
  through the employer portal."` for the inverse case, rendered in
  `employer_login/login.html:84-99`'s own `.alert.alert-danger` block (same
  shape as student login, different inline style/icon margin class).
- **Student registration** (`users/views.py:153-188`): three branches exist
  — duplicate email (`messages.error` + `form.add_error('email', ...)` →
  "This email ID is already in use."), unverified email ("Verify this email
  address to continue."), and ordinary `form.is_valid()` failure (no flash
  at all, only each field's own error). All three ultimately render via the
  *same* per-field markup: `register.html`'s `{% if form.X.errors %}<div
  class="invalid-feedback d-block">{{ form.X.errors.0 }}</div>{% endif %}`
  — the exact convention `ProfileRemoteDataSource`'s own
  `_fieldErrorPattern` already scrapes elsewhere in this app — plus a
  `non_field_errors` block (`register.html:520-528`) for any whole-form
  error (confirmed `RegisterForm` never raises one today, but the template
  renders it if one ever appears).
- **Employer registration**: identical shape — `signup.html` uses the same
  `invalid-feedback d-block` convention per field, plus the same
  `non_field_errors` block (confirmed `EmployerRegisterForm` has no
  `clean()` override either). `EmployerRegistrationData`'s own doc comment
  already confirms it mirrors `EmployerRegisterForm` 1:1 — no omitted-field
  gap exists here (unlike student registration's selfie/multi-language/
  extra-education omissions, which are a separate, unaddressed gap this
  phase does not touch).
- **429 (rate limit)**: `AuthRemoteDataSource.sendOtp`/
  `EmployerAuthRemoteDataSource.sendOtp` already construct
  `RateLimitException(errorMessage ?? '...')` with the real server body
  text — but `ExceptionMapper.map`'s `RateLimitException() => const
  RateLimitFailure()` branch discarded it, always showing
  `RateLimitFailure`'s own hardcoded message instead.

## 3. Classification (Step 2)

| Category | Where it applies here | Treatment |
|---|---|---|
| Client-side validation | `Validators.required`/`.email`/etc. in all 4 screens | Unchanged — already correct, out of scope |
| Authentication rejection | Student/employer login's wrong-credentials case | Now shows Django's own (already account-existence-safe) wording verbatim, never paraphrased |
| Authentication rejection — portal mismatch | "Employer accounts cannot log in through the student portal." / "Student accounts cannot log in through the employer portal." | Now shown verbatim — a real, safe, actionable message (not an existence leak: it reveals nothing about which *username* exists, only that *this* submitted credential pair belongs to the other portal) |
| Authentication rejection — lockout | Student login only | Now shown verbatim via the flashed-message fallback |
| Registration rejection | Duplicate email, weak/common password, any other Django field error | Now scraped and shown per field, joined one per line |
| Verification/OTP failure | `sendOtp`/`verifyOtp`'s existing JSON-body error surfacing | **Unchanged** — already correctly surfaces the real server `error` field; only the *429* case was broken (see below), fixed via the shared mapper |
| Connectivity failures | `NetworkUnavailableException`/`RequestTimeoutException` | Unchanged — already neutral, correct, out of scope |
| Unexpected server failures | `ServerException`/`UnexpectedResponseException`/malformed bodies | **Unchanged** — `ServerFailure`'s existing neutral "Something went wrong on our end..." message already satisfies Step 3's "neutral fallback for unknown errors" requirement; deliberately not touched (reworking the generic 5xx mapping would ripple into every other feature, not just login/registration — out of this phase's scope) |
| Rate limiting (429) | `sendOtp` during registration's OTP step | **Fixed** — the real body message is no longer discarded |

## 4. Implementation (Step 3)

**`lib/core/errors/exceptions.dart`**: `RateLimitException`'s own default
message changed from `'Too many requests.'` to `'Too many attempts. Please
wait a moment and try again.'` — the same wording `RateLimitFailure` always
showed before this fix, so every *other*, unrelated 429 call site in this
app (`ApiExceptionsInterceptor`'s generic interceptor, Mock Interview's own
429 handling) shows byte-for-byte the same text as before. Only a caller
that supplies its own specific message (the auth OTP endpoints) is
affected.

**`lib/core/errors/failures.dart`**: `RateLimitFailure` now takes an
optional message (`[super.message = '...']`), mirroring `ForbiddenFailure`'s
existing pattern exactly.

**`lib/core/errors/exception_mapper.dart`**: `RateLimitException() => const
RateLimitFailure()` → `RateLimitException(message: final msg) =>
RateLimitFailure(msg)` — the only line changed in this file.

**`lib/features/auth/data/datasources/auth_remote_datasource.dart`**:
- `login()`: new `_parseLoginFailureMessage` tries `login.html`'s own
  form-error block first (`_loginFormErrorPattern`), then `base.html`'s
  shared flashed-message pattern (`_flashedMessagePattern`, the exact same
  technique already established for other flashed errors in this app),
  falling back to the existing generic string (renamed
  `_genericLoginFailureMessage`, wording unchanged) if neither matches.
  Added `responseType: ResponseType.plain` to the POST options (the method
  now needs to reliably read the body — matching every other datasource in
  this app that reads a response body, e.g. `ProfileRemoteDataSource`).
- `register()`: new `_parseRegisterFailureMessage` collects every
  `invalid-feedback d-block` field error (`_registerFieldErrorPattern`,
  identical regex to `ProfileRemoteDataSource`'s own) plus any
  `non_field_errors` entry (`_registerNonFieldErrorPattern`), deduplicates,
  and joins them one per line; falls back to the existing generic string
  (`_genericRegisterFailureMessage`) if nothing matched. Same
  `responseType: ResponseType.plain` addition.

**`lib/features/auth/data/datasources/employer_auth_remote_datasource.dart`**:
the same two changes, scoped to `employer_login/login.html`'s and
`signup.html`'s own (slightly different but structurally equivalent)
markup — `EmployerAuthRemoteDataSource` has no lockout/flash path to also
check (confirmed in §2), so `login()`'s fallback chain is one step shorter
than the student version.

**No screen, controller, or widget file was changed.** `login_screen.dart`,
`register_screen.dart`, `employer_login_screen.dart`,
`employer_register_screen.dart`, and `auth_controller.dart` already render
whatever single `failure.message` string the repository layer produces
(confirmed: `AuthUnauthenticated(failure.message)` in `auth_controller.dart`,
displayed via each screen's existing `_ErrorAlert`/`_submitError` widget) —
fixing the *data* fixed the *UI* automatically, with zero new
architecture, exactly per Step 3's "reuse existing... UI components"
instruction. Existing loading-state (`isLoading`/`_submitting`) duplicate-
submission guards were inspected and are unchanged.

## 5. Each changed error case and the resulting message

| Flow | Case | Message shown now |
|---|---|---|
| Student login | Wrong credentials | "Invalid username or password. Please try again." (Django's own template-sanitized wording) |
| Student login | Employer account on student portal | "Employer accounts cannot log in through the student portal." |
| Student login | Lockout (5 attempts / 15 min) | "Too many failed login attempts. Please try again in a few minutes." |
| Student login | Unrecognized response shape | "Invalid username or password, or this account cannot sign in here." (unchanged fallback) |
| Employer login | Wrong credentials | "Invalid username or password." (Django's own template-sanitized wording) |
| Employer login | Student account on employer portal | "Student accounts cannot log in through the employer portal." |
| Employer login | Unrecognized response shape | "Invalid username or password, or this account cannot sign in through the employer portal." (unchanged fallback) |
| Student/employer registration | Duplicate email, unverified email, any Django field error | The real field message(s), one per line |
| Student/employer registration | Unrecognized response shape | The existing generic registration message (unchanged fallback) |
| OTP send (either flow) | 429 rate-limited | The real server body text (or its own existing fallback string), no longer discarded |

## 6. Tests added and results

- `test/features/auth/data/datasources/auth_remote_datasource_test.dart` —
  3 new tests: employer-account-on-student-portal scrape, lockout-flash
  scrape, generic fallback when nothing matches.
- `test/features/auth/data/datasources/auth_remote_datasource_register_test.dart` —
  3 new tests: duplicate-email scrape, multiple-simultaneous-field-errors
  joined one per line, generic fallback.
- `test/features/auth/data/datasources/employer_auth_remote_datasource_test.dart`
  (new file — none existed for this class before) — 4 tests: student-on-
  employer-portal scrape, login fallback, unverified-email scrape,
  registration fallback.
- `test/core/errors/exception_mapper_test.dart` — 2 new tests: a
  `RateLimitException`'s custom message now passes through; a bare
  `RateLimitException()` still shows the same generic wording as before
  (proves the unrelated 429 call sites — the generic interceptor, Mock
  Interview — are unaffected).

```
flutter test test/features/auth/data/datasources/auth_remote_datasource_test.dart \
  test/features/auth/data/datasources/auth_remote_datasource_register_test.dart
→ 11/11 passed

flutter test test/features/auth/data/datasources/employer_auth_remote_datasource_test.dart
→ 4/4 passed

flutter test test/core/errors/exception_mapper_test.dart
→ 5/5 passed

flutter test test/features/auth/ test/core/errors/
→ 83/83 passed (before adding the 12 new tests above; all pre-existing
  tests — including the registration/profile/employer-screen suites that
  exercise the same shared `ValidationException`/`ExceptionMapper` path —
  still pass unchanged)
```

## 7. Formatting and analysis (Step 5)

```
flutter analyze lib/core/errors/ lib/features/auth/ test/core/errors/ test/features/auth/
→ No issues found!

flutter analyze (whole project)
→ No issues found!
```

**Formatting**: `dart format --output=none --show=changed` on the 9 files
touched this phase reports all 9 as "would reformat" under its 80-column
default. This is the same, already-documented repo-wide characteristic
Phase 10 identified (this codebase's actual, consistent style uses a wider
column width than `dart format`'s default — confirmed there against an
untouched baseline file) — not something introduced this phase. Consistent
with that precedent, no blanket `dart format` was run (it would rewrite
large, unrelated stretches of these files); each edit was written by hand
in this codebase's own established style.

**Full suite**:
```
flutter test
→ 1938 passed, 0 failed
```
Baseline immediately before this phase (end of Phase 12) was **1926**.
**+12**, matching exactly the 12 new tests added across the four files
above (3 + 3 + 4 + 2). Zero regressions anywhere else in the suite.

No live device, emulator, or production backend was used anywhere in this
phase — every result above is from the local Flutter toolchain against
fake-HTTP-adapter test doubles built from the Django template markup read
directly this phase, exactly matching this engagement's established
methodology for this class of fix.

## 8. Remaining uncertainty / cases not addressed

- **`?next=` support** (student login): web honors a `?next=` redirect
  target after login; mobile doesn't use/need one the same way (no deep
  equivalent of arbitrary redirect targets in this app's navigation model)
  — noted in the matrix as a separate, distinct, still-open gap, not an
  error-message issue and out of this phase's scope.
- **Student registration's omitted optional fields** (selfie, multi-
  language rows, dynamic extra-education rows) — unchanged, a separate,
  already-tracked gap (`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`'s own
  row), not an error-message issue.
- **Generic 5xx/`UnexpectedResponseException` wording** — deliberately left
  untouched; `ServerFailure`'s existing neutral message already satisfies
  the "neutral fallback, never raw internals" requirement, and reworking it
  would affect every feature in the app, not just login/registration (out
  of this phase's explicit scope boundary).
- No case was found where the existing backend contract couldn't establish
  a safe, specific message — every branch identified in §2 was fully
  traceable to real, confirmed Django source and template markup.

## 9. Confirmations

- **Django/web repository was not modified** — read-only access only;
  every template/view/form cited above was read, never written.
- **No API, request payload, authentication/session/CSRF behavior, OTP
  gate, role check, or subscription restriction was changed** — the
  302-vs-200 success/failure detection, the CSRF token flow, the OTP-gate
  logic, and every validator are byte-for-byte unchanged; only the
  *message text* shown for an already-correctly-detected failure changed.
- **No real user account, production personal data, or live registration
  flow was used for testing** — every test uses a crafted HTML fixture
  modeled on the Django template source read this phase, run entirely
  through the existing `FakeHttpClientAdapter` test double.
- **No manual QA, backend verification, or live-device test is claimed** —
  every result in §6/§7 is from the automated Flutter test suite/analyzer,
  run locally this phase.
- No dependency, build setting, signing asset, or production data was
  touched. No build, deploy, or upload step was run.

## 10. Parity matrix update

Four rows updated in `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` — "Job
Seeker login," "Employer login," "Job Seeker registration + email OTP,"
"Employer registration" — each reflecting the fix with evidence, per §2-§6
above. Employer login and Employer registration moved from **Partial** to
**Fully equivalent** (their only gap was the message-collapsing issue,
now fixed). Job Seeker login and Job Seeker registration remain
**Partial**, narrowed to their separate, still-open gaps (`?next=` support;
omitted optional registration fields) — neither addressed this phase. The
summary counts at the bottom of the matrix were updated accordingly
(Fully equivalent 34→36, Partial 31→29).

---

Phase 14 complete. Per the stated scope boundary, no subscription UX,
invoice functionality, or broader authentication refactoring was started.
Stopping here.
