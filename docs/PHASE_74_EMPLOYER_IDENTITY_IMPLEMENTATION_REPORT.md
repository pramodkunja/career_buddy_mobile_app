# Phase 74 — Employer Identity & Company Profile Data Parity Implementation Report

See `docs/PHASE_74_EMPLOYER_IDENTITY_PARITY_AUDIT.md` for the full
source-backed investigation this report implements.

## Summary of changes

The employer nav drawer's identity tile now shows the real company name and
logo (falling back to the real site's own "Employer Portal" text and a
generic icon when unresolved), plus the real site's static "Recruiter
Account" label — closing the gap Phase 73 found and deferred. The data is
sourced entirely by extending an existing fetch already used by the Company
Profile screen; no new network request, endpoint, or backend change was
introduced.

## Files modified and reasons

- **`lib/features/employer/domain/entities/employer_profile_form.dart`** —
  added `companyLogoUrl` (nullable `String`) to `EmployerProfileFormData`, as
  an optional constructor parameter so the one existing call site in
  `employer_company_profile_screen_test.dart` kept compiling unchanged.
- **`lib/features/employer/data/employer_profile_html_parser.dart`** — added
  `_companyLogoUrl(html)`, which scrapes the sidebar's own `<img ... alt="Company
  Logo">` tag (the stable anchor the real template always renders with that
  literal `alt` text) from the same HTML response
  `parseEmployerProfileFormHtml` already parses for the form's own fields;
  returns `null` when the template's own `{% else %}` icon is rendered
  instead (no logo on file).
- **`lib/shared/widgets/app_nav_drawer.dart`**:
  - `build()` now reads `employerProfileControllerProvider(false)` (only
    when `user != null && user.isEmployer`) and collapses loading/error to
    `null` via pattern matching, so the fallback and the "real data" cases
    share one code path.
  - The identity `ListTile` was replaced with a new `_EmployerIdentityTile`
    widget: shows the real company logo (via `resolveMediaUrl` +
    `Image.network` with an `errorBuilder` falling back to the existing
    generic business icon) or that icon when no logo is on file; shows the
    real company name or the real site's own `"Employer Portal"` fallback
    text; adds a static `"Recruiter Account"` subtitle; preserves the
    existing tap behavior (opens Company Profile).
  - Class-level doc comment updated: replaced the Phase 73 "found,
    documented, NOT implemented" paragraph with a Phase 74 paragraph
    describing the investigation, the chosen Case B path, and why it's safe.
- **`test/features/employer/data/employer_profile_html_parser_test.dart`** —
  added sidebar markup (logo present / icon fallback) to both existing
  fixtures and asserted `companyLogoUrl` for each case.
- **`test/features/auth/auth_controller_test.dart`** — added a
  `_FakeEmployerProfileRepository` and one new test mirroring the existing
  Dashboard cross-account-leak test, confirming
  `employerProfileControllerProvider` is refetched (not served stale) across
  a `logout()` → `loginEmployer()` cycle between two different employer
  accounts.
- **`test/shared/widgets/app_nav_drawer_test.dart`**:
  - Added `_FakeEmployerProfileRepository` and wired it into `_pumpDrawer`
    (default: a `Failed` result, so every pre-existing employer test that
    doesn't care about identity data exercises the real fallback path rather
    than attempting a live network call).
  - Fixed two Phase 73 tests that asserted on `find.text('acmehr')` (the
    identity tile no longer shows the username) — updated to assert the new
    fallback/real-data text instead.
  - Added a `'Phase 74 — employer identity tile'` group: valid name+logo;
    name with no logo (generic icon, not a broken image); blank saved name
    (falls back to "Employer Portal"); a failed fetch (fallback, no crash);
    a never-resolving fetch (loading fallback, no blank tile); a simulated
    image-load failure invoking the `Image`'s own `errorBuilder`.
  - Extended the existing candidate/guest non-leakage tests and the 320px
    layout test to also check the identity tile's own content.

## Before / after identity behavior

| State | Before | After |
|---|---|---|
| Employer with a saved company name + logo | Username + generic icon | Real company name + real logo image |
| Employer with a name but no logo on file | Username + generic icon | Real company name + generic icon (not a broken image) |
| Employer with no name saved / fetch still loading / fetch failed | Username + generic icon | "Employer Portal" (the real site's own fallback text) + generic icon |
| "Recruiter Account" label | Absent | Present, matching the real site's static badge |
| Tap target | Opens Company Profile | Unchanged |
| Candidate/guest sessions | No employer identity shown | Unchanged — still none shown |

## Data-source and state-management decisions

- Reused `employerProfileControllerProvider(false)` — the same provider the
  Company Profile screen already uses — rather than adding a new provider or
  controller. The drawer only watches it when the session is an employer, so
  a candidate/guest session never triggers this fetch.
- No redundant-request logic was needed: Riverpod's own `AsyncNotifier`
  caching means the drawer and the Company Profile screen share one fetch
  per session, not one each.
- Cross-session safety is inherited, not reimplemented: `AuthController`
  already invalidates this exact provider on every login/logout/register
  transition; a new test (`auth_controller_test.dart`) confirms this holds
  for two different employer accounts in the same app session.

## Loading, fallback, error, and session-clearing behavior

- **Loading**: the tile shows the fallback (generic icon, "Employer
  Portal") until the fetch resolves — never a blank tile.
- **Error** (fetch failed, e.g. session issue or no profile saved yet): same
  fallback, no error UI, no crash.
- **Missing/blank name**: falls back to "Employer Portal", matching the real
  site's own `|default:"Employer Portal"` template filter exactly.
- **Missing logo**: falls back to the existing generic business icon.
- **Logo fails to load** (bad URL, network error): the `Image.network`
  `errorBuilder` falls back to the same generic icon — verified by invoking
  the builder directly in a test.
- **Session end/switch**: `AuthController._invalidateUserScopedProviders()`
  already invalidates this provider on logout/login/register — confirmed by
  both source reading and a new dedicated test
  (`auth_controller_test.dart`'s Phase 74 test), so a different employer's
  session never sees a previous employer's cached name/logo.

## Automated test results

- `flutter analyze` on each modified file individually, then project-wide →
  **No issues found!**
- `flutter test test/features/employer/data/employer_profile_html_parser_test.dart`
  → **3 tests, all passed.**
- `flutter test test/features/auth/auth_controller_test.dart` → **16 tests,
  all passed** (includes the new Phase 74 cross-account test).
- `flutter test test/shared/widgets/app_nav_drawer_test.dart` → **51 tests,
  all passed** (45 pre-existing + 6 new Phase 74 identity tests, plus 2
  pre-existing Phase 73 tests updated to match the new identity content).
- `flutter test test/app/router/route_guards_test.dart` → **37 tests, all
  passed** (no regression).
- `flutter test test/features/employer/presentation/screens/employer_company_profile_screen_test.dart`
  → **1 test, passed** (no regression from the new optional
  `companyLogoUrl` field).
- `flutter test test/features/employer/presentation/screens/employer_dashboard_screen_test.dart`
  → **4 tests, passed** (no regression).
- `flutter test` (complete suite) → **2,854 tests, all passed, 0
  failures** (2,847 from before this phase + 7 new).
- `flutter analyze` (whole project) → **No issues found!**

## Emulator verification

- Used the existing `Android_Emulator_34` AVD (already running from the
  Phase 73 session, not wiped or recreated), device id `emulator-5554`.
- Relaunched the app and captured screenshots under
  `docs/audit_evidence/phase74/`:
  - `01_guest_home.png` — guest home loads cleanly with the Phase 74 code
    present.
  - `02_guest_drawer.png` — guest drawer is structurally identical to the
    Phase 71/73-verified state (Home, About Us, Skill Up, Resources,
    Industries, Create Resume, Contact Us, Job Seeker Login, Employer
    Login) — confirming the employer-only identity tile change has no
    effect on a guest session.
- **Authenticated employer identity was not live-verified**, for the same
  reason as every prior phase: no authorized employer test account is
  available, and inventing credentials is explicitly disallowed. All
  identity-tile states (valid name+logo, name with no logo, blank name,
  fetch failure, fetch still loading, image-load failure) were instead
  verified through the automated widget-test suite above, which exercises
  each state directly against the real widget tree using a controlled fake
  repository — not a live account, but not a guess either, since the
  fixtures mirror the real template markup read directly from
  `employer_base.html`.
- Narrow-screen layout (320px) and candidate/guest non-leakage were verified
  both automatically (widget tests) and structurally consistent with the
  live guest screenshot above.

## Remaining gaps and recommended next steps

None identified for this phase's scope. The one open item from Phase 73
(employer identity showing username instead of company data) is now closed.
A possible future improvement — not a gap, since it exceeds the real site's
own behavior — would be rendering a loading placeholder (e.g. a brief
shimmer) instead of the immediate "Employer Portal" fallback while the first
fetch is in flight; this was not done since the real site itself has no such
transition (a full page load either has the data or doesn't) and the task
explicitly asked not to introduce speculative UI beyond what's evidenced.

## Confirmation that prior phases and unrelated changes were preserved

- Every file changed is inside the Flutter project: the two employer-data
  files, the drawer, and three test files.
- Both Django reference directories (`royalStaffing_CB01`,
  `Career_Buddy_LMS`) remain read-only: no tracked-source file in either
  directory has a modification time after this phase's work began.
  `Career_Buddy_LMS` still carries only the same pre-existing, unrelated
  September diff noted in the Phase 73 report — untouched by this phase.
- No backend API, database schema, migration, authentication/authorization
  logic, subscription rule, or deployment configuration was changed.
- No existing, uncommitted work from Phases 52–73 was discarded — confirmed
  by the full 2,854-test suite passing (which includes every prior phase's
  own tests) and by live emulator verification of the guest drawer matching
  the Phase 71/73-verified structure exactly.
- Guest and candidate navigation/identity behavior is unchanged — the new
  data flow is gated strictly on `user != null && user.isEmployer`.

## Stop point

Per the task brief, this phase is complete and this is the final deliverable
for Phase 74. No Phase 75 or unrelated feature work has been prepared or
started; proceeding requires explicit approval.
