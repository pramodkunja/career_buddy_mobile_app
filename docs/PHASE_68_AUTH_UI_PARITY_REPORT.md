# Phase 68 — Authentication Screen UI Parity Report

**Date:** 2026-10-27
**Scope:** the 4 confirmed auth-screen findings from `docs/PHASE_67_UI_PARITY_AUDIT.md`: `UI-A-006` (Employer Login banner), `UI-A-001`/`UI-A-002`/`UI-A-003` (Job Seeker Login logo/subtitle/wording), and `UI-A-004` (Registration header). No other screen or roadmap item was touched.

## Findings addressed

### UI-A-006 (High) — Employer Login missing branding banner

**Investigation and a mid-phase correction to the Phase 67 finding itself.** The Phase 67 audit found the Employer Login screen missing its banner, based on a doc comment in `employer_login_screen.dart` claiming the real template is a single centered card, "genuinely different" from the student login's two-pane layout. Re-reading the actual template this phase found that claim is now **wrong** — but importantly, not fabricated: diffing against the **original** Django reference confirmed it:

- **Original reference** (`Career_Buddy_LMS/templates/employer_login/login.html:18,26,75,77`) — does still have the old single-card `.login-card`/`.login-icon-box` markup the existing Flutter screen and its doc comment were built from.
- **Updated reference** (`royalStaffing_CB01/templates/employer_login/login.html:17-34`) — has since been redesigned to the exact same shared `.auth-banner-left`/`.auth-card-container` shell the student login page uses. `accounts_app/views.py:86-88` confirms `EmployerLoginView.template_name` is still this file.

This is a genuine website update between the two reference snapshots, not a research error, and is exactly the kind of discrepancy the task asked to be recorded rather than silently resolved by guessing.

**Website source consulted:** `royalStaffing_CB01/templates/employer_login/login.html:17-34` (banner markup/copy), `static/css/style.css:2038-2210` (`.auth-*` layout/colors), `static/css/style.css:2852-2892` (`.auth-banner-brand` wordmark/tagline treatment).

**Flutter files changed:**
- `lib/shared/widgets/auth_branding_pane.dart` (new) — the shared banner shell both login pages now use: real `logo-mark-light.png` asset, "Career"+"Buddy" (gold) wordmark, "SINCE 2026" tagline, heading, subtitle, and a 4-item check-list, all parameterized.
- `lib/features/auth/presentation/screens/employer_login_screen.dart` — rebuilt the body as a two-pane layout (`AuthBrandingPane` + a form pane), matching `LoginScreen`'s own proven responsive structure (stacks below 860px, same as the real page's own breakpoint). Removed the old single `.login-card` lock-icon header and the duplicate "Hire talent..." line (now carried by the banner). All existing form fields, the error alert, Sign In, Create Employer Account, and the "Looking for the student portal?" link are unchanged in content and behavior.
- Doc comment corrected to explain the real discrepancy (reference-repo update) instead of repeating the now-wrong "single card" claim.

**A real, newly-introduced bug found and fixed during this same change:** the new "Don't have an account?" divider row initially overflowed at narrow phone widths (confirmed via widget test at 360px — not a pre-existing issue, introduced by this phase's own edit) because the divider text wasn't wrapped in a shrinkable `Flexible`/`overflow: ellipsis`, unlike `LoginScreen`'s already-proven version of the same row. Fixed by matching that exact pattern. Caught entirely by the widget tests added for this phase, not just visual inspection.

### UI-A-001/UI-A-002/UI-A-003 (Medium/Low) — Job Seeker Login logo, subtitle, and wording

**Website source consulted:** `royalStaffing_CB01/templates/users/login.html:7-23`.

**Flutter files changed:** `lib/features/auth/presentation/screens/login_screen.dart`.

**What changed:**
- Replaced the hand-drawn navy box + generic `Icons.school_outlined` with the real bundled `assets/images/logo-mark-light.png` asset (already present in the project and declared in `pubspec.yaml`, already used correctly by `AppTopBar`'s own, differently-sourced navbar wordmark) — via the new shared `AuthBrandingPane`.
- Wordmark now matches the real markup exactly: "Career" (white) immediately followed by "Buddy" (gold, `AppColors.accent`) with no space — confirmed from `login.html:12`'s literal `<span>Career<b>Buddy</b></span>` — plus the "SINCE 2026" tagline beneath it (`style.css:2866-2892`), which the screen had never shown at all.
- Subtitle corrected: `'Continue your journey to Business English mastery and career growth.'` → `'Continue your journey to career growth.'` (the real page has no "Business English mastery and" clause — `login.html:17`).
- First feature-list line corrected: `'20+ Comprehensive Learning Activities'` → `'20 + Comprehensive Learning Activities'` (the real page literally has a space before the `+`, `login.html:19` — reproduced exactly as written on the real page, however it looks).
- Stale doc comment corrected (previously claimed register/password-reset/employer screens "don't exist in the Flutter app yet" — all three are fully built).

**`AuthBrandingPane` extraction:** since both login pages now need the identical banner shell with only copy differences, the shell was extracted into one shared widget (`lib/shared/widgets/auth_branding_pane.dart`) rather than duplicated — matching the real website's own shared-markup relationship between the two templates, and directly following the task's instruction to "inspect shared authentication components to avoid introducing inconsistent styles."

### UI-A-004 (Medium) — Registration header

**Website source consulted:** `royalStaffing_CB01/templates/users/register.html:1-26` (the page's own inline `<style>` block) and `:131-135` (the header markup).

**Flutter file changed:** `lib/features/auth/presentation/screens/register_screen.dart`.

**What changed:** the bare `AppBar(title: Text('Create Account'))` was replaced with `AppBar()` (kept only for its back button) plus a new in-body `RegisterHeader` widget reproducing the real page's own header exactly: a centered 72×72 blue-gradient (`#185adb` → `#1d4ed8`) icon box with a white `person_add` icon (the real page's own `fa-user-plus`), the heading "Candidate Registration", and the subtitle "Create your account to access learning activities, resume builder & job matching" (`register.html:133-134`, copied verbatim). `RegisterHeader` was made a public, non-underscore widget specifically so it can be tested in isolation (see Testing below) — this is its only reason for being public; it isn't otherwise reused elsewhere.

## A newly-discovered, deliberately untouched issue

While adding this phase's first-ever test file for `RegisterScreen` (none existed before), pumping the full screen surfaced a **pre-existing, unrelated** layout bug: several of the screen's own `DropdownButtonFormField`s (built by its `_dropdown` helper, `register_screen.dart:584-598`) have no `isExpanded: true`, so Flutter sizes the closed button to the widest `DropdownMenuItem` among all its options regardless of the field's actual width — a standard Flutter pitfall. This produces a real `RenderFlex` overflow (65–162px, confirmed via the widget test's own stack trace naming `register_screen.dart:590:12`) at phone-width viewports. This was never caught before because, until this phase, the screen had zero test coverage.

**This is explicitly out of Phase 68's scope** (a header/visual-parity phase for 3 named findings, not a dropdown-layout fix) and was **not fixed**. It is recorded here, and the tests added for this phase drain the known, pre-existing exceptions so they can still verify what Phase 68 actually changed without either masking the discovery or silently fixing something unapproved. Recommend a dedicated follow-up phase to add `isExpanded: true` to `_dropdown()`.

## Confirmation that existing authentication logic was preserved

No change was made to: form validation rules or messages, the `_submit()`/`login()`/`loginEmployer()`/`register()` call sites, password-visibility toggling, OTP flow, loading-state handling, error-message mapping, or any navigation destination. All three screens' submit buttons, secondary links, and field requiredness are byte-identical to before this phase except for the Employer Login divider's wrapping fix (a pure layout fix, not a behavior change). Confirmed by the full regression-test results below, all of which pass unchanged except where this phase's own new/updated assertions apply.

## Tests added/changed and exact results

- `lib/shared/widgets/auth_branding_pane.dart` — new shared widget, exercised indirectly by both screens' own tests below (no separate unit test file, since it has no behavior of its own beyond rendering its parameters).
- `test/features/auth/presentation/screens/login_screen_test.dart` — updated the existing branding-pane test for the corrected wordmark/subtitle/spacing; added a new test asserting the real `logo-mark-light.png` asset is used and `Icons.school_outlined` is gone.
- `test/features/auth/presentation/screens/employer_login_screen_test.dart` — added a `branding banner (Phase 68)` group: banner heading/subtitle/logo/4-item feature list presence, a wide (≥860px) two-pane layout check, and a narrow-phone (360px) no-overflow check (the one that caught the divider-wrapping bug described above).
- `test/features/auth/presentation/screens/register_screen_test.dart` (**new file** — none existed before) — an isolated `RegisterHeader` test group (icon/heading/subtitle, no pre-existing noise) plus a full-screen group that explicitly drains the pre-existing, documented dropdown-overflow exceptions so it can still verify the AppBar no longer duplicates the title and that all existing fields are still present.

```
$ flutter test test/features/auth/presentation/screens/login_screen_test.dart
...
All tests passed! (17 tests)

$ flutter test test/features/auth/presentation/screens/employer_login_screen_test.dart
...
All tests passed! (9 tests)

$ flutter test test/features/auth/presentation/screens/register_screen_test.dart
...
All tests passed! (4 tests)
```

### Full test-suite results

```
$ flutter test
...
All tests passed!
```
**2,741 tests passed, 0 failed** (up from 2,733 at the end of Phase 67 — net +8 from this phase's additions). Actually executed this session in full, not assumed from the historical 2,733 baseline the task brief cited.

### Analyzer results

```
$ flutter analyze
Analyzing Mobile_app...
No issues found!
```
Run after every file change in this phase and once more at the end — clean throughout.

### Git status / diff review

`git status --short` at the end of this phase shows exactly: 3 modified auth screens (`login_screen.dart`, `employer_login_screen.dart`, `register_screen.dart`), 1 new shared widget (`auth_branding_pane.dart`), 3 test files touched (2 modified, 1 new), plus this report and the `docs/audit_evidence/phase68/` screenshots. Every other file in the working tree (Phases 52-67's own prior work, the unrelated pre-existing resume-controller-test fix, every prior `docs/` report) is untouched — confirmed by diffing the full file list against the phase-start baseline.

## Emulator checks actually performed

Rebuilt and relaunched the debug app on the same pre-existing, already-running Android 14 emulator used throughout this project (not recreated, not wiped). All three screens are guest-reachable, so this was genuine live verification, not just source inspection:

- **Login screen**: confirmed live — real logo mark, "Career**Buddy**" wordmark with gold "Buddy", "SINCE 2026" tagline, and the corrected subtitle all render correctly; scrolled to confirm the rest of the form (fields, Sign In, Create Free Candidate Account, Employer Portal Sign In) is unchanged and renders without overflow.
- **Employer Login screen**: confirmed live — the new banner renders with the real "Welcome Back!" heading, the real hiring subtitle, and all 4 employer feature bullets with check icons; scrolled to confirm the "Don't have an account?" divider (the bug found and fixed during this phase) renders cleanly with no overflow, and all existing fields/buttons are present and unchanged.
- **Registration screen**: confirmed live — the new gradient icon box, "Candidate Registration" heading, and subtitle render correctly with no duplicate AppBar title; scrolled through the form confirming all existing sections (Account, Personal, Identity, Education, Location, Abroad Experience) and the "Create Account" submit button are present and unchanged.

No login, registration, OTP, or password-reset form was submitted at any point — every interaction was navigation and visual inspection only, consistent with the app's production-default backend and this phase's explicit safety constraints.

Screenshots are stored in `docs/audit_evidence/phase68/`:
- `01_after_login_screen_banner.png` / `02_after_login_screen_form.png`
- `03_after_employer_login_banner.png` / `04_after_employer_login_form.png`
- `05_after_register_header.png` / `06_after_register_form_education_section.png` / `07_after_register_submit_button.png`

**No "before" screenshots exist** — none were captured prior to making the code changes (the exact prior source of all three screens is quoted in full above and was read directly before editing; recreating a "before" build solely for a screenshot was judged not worth a second build/relaunch cycle given the prior source is already fully documented here). This is stated plainly rather than fabricating or backdating a before-image.

## Unresolved differences and access limitations

- The pre-existing `DropdownButtonFormField` overflow bug in `RegisterScreen` (described above) remains unfixed, by design — out of this phase's scope.
- Pixel-perfect parity was not claimed anywhere in this report — differences that remain are platform-appropriate simplifications, explicitly noted inline: the real page's decorative tagline divider lines (CSS `::before`/`::after` either side of "SINCE 2026") were not reproduced (a desktop-only flourish, not a content omission); viewport/device details for every screenshot are the same Android 14 emulator at its native resolution (1080×1920, 420dpi, ≈411 logical px width) unless otherwise noted.
- No authenticated flow (a real login/registration submission) was exercised live — only the visual/navigational surface was verified, consistent with the task's explicit prohibition on submitting these forms against the production-backed test build.

## Unrelated work deliberately left untouched

- All Phase 52-67 work (employer job-posting validation, Phase 66's sign-in/department-split/custom-skill fixes, Phase 67's subscription/role-picker/nav-drawer fixes) — untouched.
- Every other Phase 67 audit finding not in this phase's approved scope (`UI-A-005` internal-only doc comment was already folded into the `UI-A-001` fix since it was a one-line, directly-adjacent correction in the same file; everything else — Create Resume's missing sections, the rest of the nav-drawer gap, Subscription's remaining cosmetic items, Employer screens' visual layout, Skill-Up WebView fullscreen, etc. — is untouched, per instructions).
- The password-reset flow (`UI-A-007`, already `MATCHED` per Phase 67) and the footer (`UI-A-012`, not evaluated in Phase 67) were not touched — neither was in this phase's approved scope.
