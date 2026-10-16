# Phase 30 — Manual Resume Regression Tests and Verification Readiness

**Test-only phase.** No production Flutter source, dependency, route, provider, controller, widget, or configuration file was changed. No Django/web reference file was touched. The only files changed are 6 test files and this report.

## 1. Scope and files changed

Read first (per this phase's own instruction): `docs/PHASE_29_MANUAL_RESUME_END_TO_END_AUDIT.md` and the relevant sections of `docs/PHASE_25_MANUAL_RESUME_FOUNDATION_REPORT.md`–`PHASE_28_MANUAL_RESUME_OUTPUTS_REPORT.md`. `git status` was checked before any edit (70 lines — the Phase 28 end-state plus the Phase 29 report, confirmed identical to Phase 29's own closing count).

**Modified (test files only):**
- `test/features/auth/auth_controller_test.dart` — 3 new tests (work item 1), plus the pre-existing `_FakeResumeRepository` fake extended with configurable `previewResult`/`pagePreviewResult`/`pdfResult` fields (was: all three methods threw `UnimplementedError`) so the new tests can drive each controller to a non-idle state before logout.
- `test/app/router/route_guards_test.dart` — 5 new tests, one new `group` (work item 2). No change to `route_guards.dart`/`route_paths.dart` themselves.
- `test/features/resume/presentation/screens/manual_resume_preview_screen_test.dart` — 3 new tests (work item 3); the existing `_pump` helper gained an optional `size` parameter (default unchanged: `Size(400, 800)`), so every other existing test in this file is unaffected.
- `test/features/resume/presentation/screens/manual_resume_page_preview_screen_test.dart` — 5 new tests (work item 3); same `_pump`-helper extension as above.
- `test/features/resume/data/manual_resume_page_preview_parser_test.dart` — 1 new test (work item 4).
- `test/features/resume/data/manual_resume_page_preview_datasource_test.dart` — 1 new test (work item 4).
- `test/features/resume/data/manual_resume_pdf_parser_test.dart` — 1 new test (work item 4).
- `test/features/resume/data/manual_resume_pdf_datasource_test.dart` — 1 new test (work item 4).

**New:** `docs/PHASE_30_REGRESSION_TESTS_REPORT.md` (this file) only.

No new dependency was added. No `lib/` file was edited.

## 2. Test coverage added, per work item

### Work item 1 — Authentication invalidation tests

Inspected `AuthController._invalidateUserScopedProviders()` directly (unchanged this phase): `manualResumePreviewControllerProvider`, `manualResumePagePreviewControllerProvider`, and `manualResumePdfControllerProvider` were already present in that list (added in Phases 27/28), but — as the Phase 29 audit found — none had an explicit regression test naming them, unlike `manualResumeBuilderControllerProvider`'s own existing Phase 25 test.

Added 3 new tests in `auth_controller_test.dart`, each mirroring the existing Manual Resume Builder case's structure:
1. Drive `manualResumePreviewControllerProvider` to `ManualResumePreviewReadyState` via a successful `previewManualResume()`, call `logout()`, assert the state is back to `ManualResumePreviewIdle`.
2. Drive `manualResumePagePreviewControllerProvider` to `ManualResumePagePreviewReadyState`, same logout-then-assert-idle pattern.
3. Drive `manualResumePdfControllerProvider` to `ManualResumePdfValidationFailed` (a validation rejection, not a success — the success path already resets this specific controller to idle on its own right after saving the file, so a success state can't demonstrate the invalidation; a rejection is the one state that genuinely persists until something else changes it, making it the correct state to prove this with), then logout, then assert `ManualResumePdfIdle`.

All 3 pass. **Limitation honestly noted**: these tests prove the provider's state resets after `logout()` in a single `ProviderContainer` — the same proof technique the existing Phase 25 test already uses for the Builder controller — not a full "login as A, do something, logout, login as B, confirm B sees nothing of A's" two-account walkthrough in one connected test (the Phase 29 audit's finding 1's second half). No test in this codebase does that even for the Dashboard/Resume-Builder cases that already have their own tests, so adding it here alone would be inconsistent with the existing test architecture rather than filling a real gap specific to the Manual Resume feature; it is left as a known limitation, not invented or weakened to appear covered.

### Work item 2 — Authenticated route guard tests

Inspected `route_guards.dart`'s `computeRedirect()` and `route_paths.dart`'s `publicRoutes`/`universalRoutes` directly (both unchanged). Confirmed `manualResumeBuilder`, `manualResumePreview`, and `manualResumePagePreview` are in neither set.

Added a new `group('Manual Resume Builder routes', ...)` in `route_guards_test.dart` with 5 tests, run against all three route constants together (not just one representative route):
1. None of the three are in `publicRoutes` or `universalRoutes`.
2. `AuthUnauthenticated` → `RoutePaths.login` for all three.
3. `AuthAuthenticated` (student) → no redirect (`null`) for all three.
4. `AuthAuthenticated` (employer) → no redirect for all three too (confirmed these routes carry no student/employer-specific restriction, unlike `employerProtectedRoutes`).
5. `AuthUnknown` → `RoutePaths.splash` for all three (matching every other protected route while the session is still being determined).

All 5 pass. No route definition or guard logic was changed to make these pass — they confirm existing behavior only.

### Work item 3 — Narrow-screen (320px) layout tests

Inspected `ManualResumePreviewScreen` and `ManualResumePagePreviewScreen` (both unchanged this phase) and their existing tests, which previously pumped only at the default `Size(400, 800)`.

Extended each file's `_pump` helper with an optional `size` parameter (default unchanged, so no existing test's behavior changed) and added:
- **Structured preview screen** (3 tests): the real document on success, server validation errors, and a transport-failure retry view — all at 320×800, each asserting `tester.takeException()` is `null` (the standard way this codebase already detects a `RenderFlex` overflow or other layout exception in a test) plus that essential content (the candidate's name, the error message, the Retry button) is still present.
- **Page-image preview screen** (5 tests): a multi-page carousel, the "showing first N of total" truncation banner, the empty-pages state, server validation errors, and a transport-failure retry view — same 320×800 + no-exception + content-present pattern, covering every one of this screen's distinct states, not just the happy path.

All 8 pass — **no overflow or layout exception was found at 320px for either screen**, in any of the 8 states tested. This closes the exact gap the Phase 29 audit named (these were the only two Manual Resume Builder screens without a narrow-width test, unlike every one of the five wizard steps).

### Work item 4 — HTTP 500 JSON rejection-body coverage

Re-confirmed directly (read-only) against the current `royalStaffing_CB01/career_app/manual_resume_views.py` that both `preview_pages_api` and `pdf_download` have their own `except Exception:` branch that logs the error and returns HTTP 500 with the exact message used below, through the identical `{ok:false, errors:[{field:'', step:0, message:'...'}]}` envelope every other rejection uses. No request was ever sent to any real server to trigger this — every new test uses a fake HTTP adapter with a hand-built 500 response.

Added 4 new tests, one at the parser level and one at the datasource level for each flow:
- `manual_resume_page_preview_parser_test.dart`: `parseManualResumePagePreviewResponse()` on the exact 500 body (`"Page preview is unavailable. Use Download PDF to view the pages."`) returns `ManualResumePagePreviewRejected`, never `null` and never a fabricated `Ready` result.
- `manual_resume_page_preview_datasource_test.dart`: the same scenario sent through a fake `HttpClientAdapter` returning HTTP 500 — confirms the full Dio pipeline (not just the standalone parser function) handles it, since `getManualResumePagePreview()`'s request uses `validateStatus: (_) => true`, meaning a 500 reaches the parser exactly like any other status would.
- `manual_resume_pdf_parser_test.dart`: `parseManualResumePdfResponse()` on the exact 500 body (`"The PDF could not be generated. Please try again."`), delivered through the same bytes channel a genuine PDF success also uses, returns `ManualResumePdfRejected` — never treated as a corrupt PDF (the function's content-type-and-magic-bytes check already prevents this by construction; this test proves it for this specific real scenario).
- `manual_resume_pdf_datasource_test.dart`: the same scenario through the full Dio pipeline with `ResponseType.bytes` and a 500 status.

All 4 pass.

**Draft safety — verified by architecture, not by a new duplicate test.** Neither `ManualResumePagePreviewController`/its datasource nor `ManualResumePdfController`/its datasource ever call `ManualResumeDraftRepository.saveDraft()` or `.clearDraft()` (confirmed again by direct source read this phase — no such call exists in any of the four files). The controller layer only ever sees the already-parsed `ManualResumePagePreviewRejected`/`ManualResumePdfRejected` object — it has no visibility into the HTTP status code that produced it — so the existing "Builder controller integration" tests in `manual_resume_page_preview_controller_test.dart`/`manual_resume_pdf_controller_test.dart` (which already prove a rejection never touches the draft, using a 400-style rejection) already cover the 500 case identically, since the code path is the same one either way. Adding a second, functionally-identical controller-level test that only changes which HTTP status produced the input would be the kind of no-meaningful-coverage duplication this phase was explicitly told to avoid — so none was added. This reasoning, not an assumption, is why the 500 coverage added this phase stops at the parser/datasource layer.

**No genuine defect was found or exposed in this work item.** Both flows already handle the 500 case correctly, by construction (shape-based parsing, not status-code-based) — the gap the Phase 29 audit found was purely a missing test naming this exact scenario, now closed.

## 3. Exact test commands and observed results

Focused tests run first, in this order, each immediately after being written:

```
$ flutter test test/features/auth/auth_controller_test.dart
...
+14: All tests passed!   (15 tests total in the file, 3 new)
```
```
$ flutter test test/app/router/route_guards_test.dart
...
+32: All tests passed!   (33 tests total in the file, 5 new)
```
```
$ flutter test test/features/resume/presentation/screens/manual_resume_preview_screen_test.dart
...
+9: All tests passed!    (10 tests total in the file, 3 new)
```
```
$ flutter test test/features/resume/presentation/screens/manual_resume_page_preview_screen_test.dart
...
+13: All tests passed!   (14 tests total in the file, 5 new)
```
```
$ flutter test test/features/resume/data/manual_resume_page_preview_datasource_test.dart test/features/resume/data/manual_resume_page_preview_parser_test.dart
...
+24: All tests passed!   (25 tests total across both files, 2 new)
```
```
$ flutter test test/features/resume/data/manual_resume_pdf_datasource_test.dart test/features/resume/data/manual_resume_pdf_parser_test.dart
...
+33: All tests passed!   (34 tests total across both files, 2 new)
```

Then the broader regression pass:

```
$ flutter test test/features/resume/ test/features/auth/ test/app/
...
+518: All tests passed!   (519 tests, 0 failed)
```

## 4. Full-suite and analyzer results

```
$ flutter analyze
Analyzing Mobile_app...
warning • unused_element_parameter • test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart:78 (x2)
warning • unused_element_parameter • test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart:78 (x2)
4 issues found.
```
These 4 warnings are the same pre-existing ones first disclosed in the Phase 27 report and reconfirmed in the Phase 29 audit — unrelated to this phase's changes, not introduced or touched by any edit made this phase.

```
$ flutter test
...
+2292: All tests passed!
```
**2293 passed, 0 failed.** Compared against the Phase 29 baseline of **2273 passing**: +20 (the exact count of new tests added across all four work items: 3 + 5 + 8 + 4 = 20). The baseline was not assumed to still be current — it was re-run and re-confirmed identical in content before any test was added, and the delta after adding tests matches exactly, with no unrelated test newly failing or newly passing.

No test could not run; no test was skipped, weakened, or deleted to produce this result.

## 5. Discovered defects or coverage limitations

**No new defect was found or introduced this phase.** Every new test passed on its first correctly-written run (after fixing ordinary compile-time issues — missing imports, an undefined `Uint8List` import — while authoring the auth-controller tests; none of these were test-logic failures).

**Coverage limitations carried forward, now explicitly re-confirmed rather than re-guessed:**
1. The two-account "login A → do something → logout → login B → confirm clean" connected scenario (Phase 29 finding 1, second half) remains untested, for the architectural reason given in §2's Work item 1 discussion — not fixed this phase, since doing so was outside this phase's four named work items and the existing codebase has no precedent for this pattern even on the longer-standing Dashboard/Resume-Builder cases.
2. The known test-harness quirk from Phase 28 (3 test cases invoking a button's `onPressed` directly rather than simulating `tester.tap()`, in the page-preview carousel and the Generate PDF button tests) is unchanged this phase — it was not in scope for any of the four work items and touches widget-interaction tests, not the authentication/route-guard/narrow-width/500-handling areas this phase targeted.
3. Live, on-device, authenticated verification of any Manual Resume Builder flow remains unverified in this phase — see §8.

## 6. Confirmation: no production code, backend/web code, endpoints, dependencies, signing files, or deployment settings were changed

- `git status --porcelain` in `Mobile_app/` after all edits shows changes to exactly 2 test files beyond what Phase 28 already left modified (`test/app/router/route_guards_test.dart`, `test/features/auth/auth_controller_test.dart`), plus the 4 untracked test files already created by Phase 27/28 that gained new tests this phase (`manual_resume_preview_screen_test.dart`, `manual_resume_page_preview_screen_test.dart`, `manual_resume_page_preview_parser_test.dart`/`_datasource_test.dart`, `manual_resume_pdf_parser_test.dart`/`_datasource_test.dart`) and this report. Every `lib/` path in the diff is identical to the Phase 28/29 end-state — none was touched this phase.
- `git status --porcelain` in `Career_Buddy_LMS/` shows the same pre-existing modifications already disclosed in every prior phase's report, untouched by this one.
- `royalStaffing_CB01/` is not a git repository; the 1 file read this phase (`manual_resume_views.py`, to re-confirm the exact 500 rejection messages) was accessed via `Read` only, never written to.
- No signing file, credential, token, API key, or secret was inspected, printed, exposed, or modified. No dependency was added — `pubspec.yaml`/`pubspec.lock` are unchanged. No release build, deployment, or Play Store action was taken.

## 7. Request cancellation — unresolved product decision

**Still unresolved, and deliberately not implemented or further investigated this phase**, per this phase's explicit instruction #10. The Phase 29 audit's finding (no `CancelToken` anywhere in `lib/features/resume/`) stands unchanged — confirmed again this phase via the same grep, still zero matches. This remains a product decision for a future phase, not a test gap this phase's scope covers.

## 8. Authenticated on-device end-to-end verification — still blocked

**Still blocked**, for the identical reason recorded in the Phase 29 audit: no authorized test account is available in this environment, and none was created, searched for in private records, or bypassed via OTP this phase (per this phase's own explicit safety rules). No live device or emulator interaction was attempted in Phase 30 at all — every test added this phase is an automated unit/widget test using fake repositories, fake HTTP adapters, or pure static function calls (`computeRedirect()`), never a real network call or a real app launch. **Passing automated tests in this report are not evidence that the Manual Resume flow works end-to-end on a real device against a real server** — that remains exactly as unverified as the Phase 29 audit found it, and this phase does not claim otherwise anywhere above.

---

**Phase 30 is complete.** No Phase 31 work or follow-up fix has been started. Returning this report for review; awaiting explicit approval before any further phase.
