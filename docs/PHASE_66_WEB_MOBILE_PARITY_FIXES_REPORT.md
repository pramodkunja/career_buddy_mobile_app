# Phase 66 — Web↔Mobile Parity Fixes: 3 Confirmed Mismatches

**Date:** 2026-10-27
**Scope:** exactly the 3 issues below. No other audit findings were touched in this phase.

---

## Issue A — "Resume Parsing & Interview" logged-out behavior

### Investigation and a mid-phase correction

The "updated" Django reference repo (`royalStaffing_CB01`) shows `resume_builder_home` (`career_app/views.py:815-820`) with **no** `@login_required` decorator — it checks `_can_access_resume(user) = user.is_authenticated` (`career_app/views.py:163-167`) and, for a guest, renders `templates/resume_locked.html`, a subscription-upsell page ("Resume Parsing Locked — Upgrade to Unlock", linking to `pro_page`). Based on this, the first implementation detected that page and showed the same upsell message with an "Upgrade to Unlock" button routing to the Subscription screen.

**Before finalizing, live-device testing (per this phase's own required step) surfaced a direct conflict**: two separate, read-only `curl` requests against the real production site —
```
GET https://careerbuddy4u.com/resume-builder/
→ HTTP/1.1 302 Found
  Location: /users/login/?next=/resume-builder/
```
— showed a genuine, consistent login-redirect, contradicting the reference repo's source. This discrepancy was surfaced to the user rather than silently resolved; the decision was to **match live production**: redirect straight to sign-in, with no error text, the same clean behavior "Build Resume" and "Find Jobs" already give a logged-out user.

### Django source referenced
- `royalStaffing_CB01/career_app/views.py:815-820` — `resume_builder_home` (reference repo, no login gate).
- `royalStaffing_CB01/career_app/views.py:163-167` — `_can_access_resume`.
- `royalStaffing_CB01/templates/resume_locked.html` — the upsell page (kept as a secondary, defensive detector).
- **Live production** `https://careerbuddy4u.com/resume-builder/` — confirmed via two separate anonymous GET requests: real 302 to `/users/login/?next=...`. This is the behavior the fix actually matches.

### Flutter files changed
- `lib/core/errors/exceptions.dart` — added `ResumeBuilderSignInRequiredException`.
- `lib/core/errors/failures.dart` — added `ResumeBuilderSignInRequiredFailure`.
- `lib/core/errors/exception_mapper.dart` — wired the new exception→failure mapping.
- `lib/features/resume/data/resume_html_parser.dart` — added `isResumeParsingLockedPage()` (secondary detector for the reference repo's upsell page).
- `lib/features/resume/data/resume_remote_datasource.dart` — `selectTargetRole()`: now checks `response.realUri.path.contains('/login')` (the same pattern already used by `EmployerDashboardRemoteDataSource.getDashboard`) OR the locked-page marker, and throws `ResumeBuilderSignInRequiredException` instead of misreading either case as `UnauthorizedException`.
- `lib/features/resume/presentation/widgets/career_role_action_sheet.dart` — `_confirmResumeParsing()`: on `ResumeBuilderSignInRequiredFailure`, pops the sheet and pushes `RoutePaths.login` directly, showing no error text.
- `lib/features/resume/presentation/screens/role_picker_screen.dart` — `_RoleActionSheetState._confirm()`: identical fix for this screen's own duplicate action sheet.
- `test/support/fake_http_client_adapter.dart` — added an optional `finalUri` param so a test can simulate Dio having auto-followed a redirect, without a real network call.

### Verified behavior
- A logged-out user tapping "Resume Parsing & Interview" is now redirected straight to the Job Seeker Sign In screen — **confirmed live on the Android emulator** (rebuilt debug app, same production backend): tapped the action, saw a brief loading spinner, then landed on "Job Seeker Sign In" with no error message of any kind.
- Genuine, unrelated failures (network/timeout/unexpected page shape) still show their own error text as before — unaffected by this change.

### Tests added/changed
- `test/features/resume/data/resume_remote_datasource_test.dart`: one test simulates the real production redirect (`finalUri: '.../users/login/'`) and asserts `ResumeBuilderSignInRequiredException`; a second covers the reference repo's locked-page body as a secondary path; the pre-existing "badge absent" test's expectation was corrected from `UnauthorizedException` to `UnexpectedResponseException` (true genuinely-unexpected-shape case) with an updated, accurate doc comment.
- `test/features/resume/presentation/widgets/career_role_action_sheet_test.dart`: replaced the stale "guest/expired session" test with one confirming the sign-in redirect and no error text shown.
- `test/features/resume/presentation/screens/role_picker_screen_test.dart`: same fix mirrored for this screen's own action sheet.

### Limitations
- No authorized test account exists, so the *authenticated* success path for this call (confirming the target-role badge echoes back) was not re-verified live this phase — it is unchanged code from Phase 23 and still covered by its own pre-existing passing tests.
- Whether production will ever actually serve `resume_locked.html` (the reference repo's own documented behavior) for this endpoint is unconfirmed; the secondary detector is kept defensively but may never fire in practice.

---

## Issue B — Separate Non-IT Technical and Non-Technical departments

### Investigation
The department **data** was already fully correct on the Flutter side (15 Technical + 6 Non-Technical, exact names/order, confirmed by direct JSON inspection) — Phase 43's work. The actual gap was narrower: the real website's path-picker popup has a step 2 with two distinct cards, "Technical" and "Non-Technical" (`templates/landing.html:6808-6826`), each linking to `career_path('technical')` / `career_path('non-technical')` — single-group pages. Flutter's own step 2 (already built, same labels/copy) collapsed both cards to the same combined `'non-it'` destination instead.

### Django source referenced
- `royalStaffing_CB01/activities/views.py:112-125` — `CAREER_TRACKS` dict (`'it'`, `'non-it'`, `'technical'`, `'non-technical'`) and `career_path(request, track)`.
- `royalStaffing_CB01/templates/landing.html:6746-6752` — panel-visibility conditions (`track == 'non-it' or track == 'technical'` shows the Technical panel; the equivalent for Non-Technical).
- `royalStaffing_CB01/templates/landing.html:6808-6826` — the path-picker popup's step 2 "Technical"/"Non-Technical" cards and their exact subtitle copy.
- `business_english_lms/urls.py:39` — `path('careers/<slug:track>/', activity_views.career_path, name='career_path')`.

### Flutter files changed
- `lib/features/resume/data/career_departments_asset_datasource.dart` — `load(track)` now branches: `'technical'` returns only the Technical group, `'non-technical'` returns only the Non-Technical group, `'it'`/`'non-it'` unchanged.
- `lib/features/home/presentation/widgets/home_path_picker_popup.dart` — split the single `onNonIt` callback into `onNonItTechnical` and `onNonItNonTechnical`, wired to the already-existing step 2 cards.
- `lib/features/home/presentation/screens/home_screen.dart` — wires the two new callbacks to `context.push(RoutePaths.careerDepartments, extra: 'technical' | 'non-technical')`.

### Verified behavior
- **Confirmed live on the Android emulator**: Non-IT → step 2 → "Technical" shows exactly the 7-department Technical list (screenshot: `Non-IT · Technical` heading, "Engineering Recruitment & Technical Staffing" etc., no Non-Technical departments present).
- **Confirmed live**: Non-IT → step 2 → "Non-Technical" shows exactly the 6-department Non-Technical list ("Workforce Outsourcing & Managed Staffing" etc.), no Technical departments present.
- The plain combined `'non-it'` view (reached via the inline "Choose Your Path" section's Non-IT card) is unchanged and still shows both groups together, matching the real website's own `track == 'non-it'` behavior.

### Tests added/changed
- `test/features/resume/data/career_departments_asset_datasource_test.dart`: 3 new tests — `'technical'` returns only the Technical group (matches the combined load's first group), `'non-technical'` returns only the Non-Technical group, and switching between the two always returns the correct, non-overlapping lists.
- `test/features/home/presentation/screens/home_screen_test.dart`: the 2 existing step-2 navigation tests were updated from asserting `'Career Departments Screen: non-it'` to the correct `'technical'` / `'non-technical'` destinations.

### Limitations
None identified — both new code paths were exercised by both automated tests and live emulator navigation.

---

## Issue C — Validate custom IT skills locally

### Investigation
Django's `custom_skill_error()` (`jobs_app/forms.py:167-180`) rejects a custom skill in this order: (1) length > 40 → a distinct truncated-preview message; (2) else, if it doesn't match the allowed character class **or** has fewer than 1 letter → one combined generic message. Flutter's `_addCustomItSkill()` already matched the character-class and length checks exactly but had no letter-count condition, so a purely numeric value like `"12345"` was accepted locally.

### Django source referenced
- `royalStaffing_CB01/jobs_app/forms.py:167-180` — `CUSTOM_SKILL_MAX_LENGTH`, `CUSTOM_SKILL_RE`, `custom_skill_error()`.

### Flutter files changed
- `lib/features/employer/data/job_posting_catalog.dart` — added `kCustomSkillLetterPattern` (`[A-Za-z]`).
- `lib/features/employer/presentation/screens/post_new_job_screen.dart` — `_addCustomItSkill()`: added the letter-presence check (`!kCustomSkillLetterPattern.hasMatch(raw)`, combined with the existing character-class check via `||`, matching Django's own combined condition), and split the "too long" case into its own branch with Django's exact truncated-preview message format.

### Verified behavior
- Numeric-only (`"12345"`): now rejected with `'"12345" is not a valid skill name. Use letters, numbers and . & / ( ) ' + # - only, one skill at a time.'` — the same generic message Django returns for this case.
- Whitespace-only: unchanged — silently ignored (no chip added, no error shown), which already matches the website's own effective behavior (neither platform accepts a blank skill; Flutter's UX of not surfacing an error on an untouched empty field is a reasonable, pre-existing choice, not a new gap).
- Alphabetic-only (`"Python"`) and mixed alphanumeric (`"Python3"`): accepted, unchanged.
- A value over 40 characters: now shows Django's own truncated-preview message format (`'"<first 20 chars>..." is too long; keep each skill under 40 characters.'`), previously collapsed into the generic message.

### Tests added/changed
- `test/features/employer/presentation/screens/post_new_job_screen_test.dart` — new "Phase 66" group: numeric-only rejected, whitespace-only silently ignored, alphabetic-only accepted, mixed alphanumeric accepted, over-40-characters rejected with the truncated-preview message. 5 tests, all passing.

### Limitations
- Live, authenticated verification of this exact field was not possible (no authorized employer test account) — verified via widget tests and `flutter analyze` only, consistent with every other employer-form finding in this project's history.

---

## Testing and verification (actually executed, exact results)

### Automated tests
```
$ flutter test
...
All tests passed!
```
**2,725 tests passed, 0 failed.** (Up from 2,710 before this phase — net effect of the tests listed above.) Re-run in full after every source change in this phase, not assumed from an earlier pass.

### Static analysis
```
$ flutter analyze
Analyzing Mobile_app...
No issues found!
```

### Git diff review
`git status --short` confirmed the only files touched by this phase are the 12 `lib/` files and 8 `test/` files listed above, plus this report — every other pre-existing modified/untracked file (Phase 52-65's employer work, the unrelated resume-controller-test fix, every prior `docs/PHASE_*`/audit report) is untouched.

### Emulator verification (actually performed, not inferred from source)
- Rebuilt and relaunched the debug app twice on the same pre-existing, already-running Android 14 emulator (`emulator-5554`) used by the prior audit — not wiped or recreated.
- **Issue B**: live-confirmed both the Technical-only and Non-Technical-only department lists render correctly and distinctly (screenshots captured).
- **Issue A**: live-confirmed the first (incorrect) implementation's actual server response via direct, read-only `curl` requests against production (surfacing the discrepancy), then live-confirmed the corrected implementation redirects cleanly to the Job Seeker Sign In screen with no error text (screenshot captured).
- **Issue C**: not live-tested — requires an authorized employer account, which was not available. Verified via widget tests and source inspection only, as stated above.
- No login was attempted with any credential; no form was submitted; no job posting, resume upload, or payment action was performed. All interactions were read-only navigation or GET requests, consistent with this phase's safety constraints.

---

## Unrelated work deliberately left untouched
- All 13 prior `docs/PHASE_52...` through `docs/PHASE_65...` reports (employer job-posting validation work).
- The 3 audit reports and `docs/audit_evidence/` from the immediately preceding audit task.
- `lib/features/employer/domain/entities/job_posting_submission.dart` and `test/features/employer/data/job_posting_remote_datasource_test.dart` (pre-existing uncommitted Phase 52-65 work).
- `test/features/resume/presentation/controllers/*_test.dart` and `test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart` (a pre-existing, unrelated syntax fix from before this session).
- Every other audit finding from the parity audit (nav-bar gaps, missing resume sections, tutorial card gating, malpractice-detection gaps, test-coverage gaps, the HTML-scraping architecture risk) — none of these were in this phase's scope and none were touched.

## Unresolved uncertainty
- The discrepancy between the "updated" Django reference repo (`royalStaffing_CB01`, no login gate on `resume_builder_home`) and live production (a real login redirect) remains unexplained — it's unknown whether the reference repo represents an in-progress, not-yet-deployed change, or whether production is running different/older code than the reference tree. This phase's fix matches production (per explicit decision), and the reference repo's documented behavior is kept only as a secondary, likely-dormant detector. If the reference repo is later deployed and genuinely replaces the login gate with the upsell page, this will need another look.
