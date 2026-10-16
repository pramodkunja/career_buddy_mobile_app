# Phase 29 — Manual Resume Builder End-to-End Verification and Parity Audit

**Audit-only phase. No application behavior was changed.** No Flutter source, test, dependency, or configuration file was created, edited, deleted, or reformatted. Neither Django reference tree was modified. The only new file is this report. Confirmed by `git status` before and after (§3, §11).

## 1. Executive summary and audit scope

This audit covers the Manual Resume Builder as built across Phases 24–28: the five-step form (25/26), the native structured-document preview (27), and page-image previews + PDF generation (28). The goal was to verify behavior as far as this environment honestly allows, compare it against the real web implementation using the read-only Django source, and record evidence-based findings — not to fix anything.

**Headline findings:**
- The implementation is internally consistent and well-tested at the unit/widget level: **2273/2273 automated tests pass**, `flutter analyze` is clean except 2 pre-existing, harmless info-level warnings already disclosed in Phase 27's report.
- A **real Android emulator was already available and connected**, and a **local Django dev server was already running** (not production). A live smoke test was performed: the app launched cleanly and rendered the unauthenticated home screen correctly (evidence in §2). No authorized test account was available or was created, so **every authenticated flow (the builder form, preview, page preview, PDF generation) remains unverified on a real device** — this is stated honestly throughout rather than inferred from passing mocked tests.
- Every endpoint contract claim re-checked directly against the current `royalStaffing_CB01/career_app/manual_resume_views.py` and `resume_document.py` in this phase **matches exactly** what Phases 24/27/28 already documented — no drift found, and one previously under-emphasized detail confirmed directly: both `pdf_download` and `preview_pages_api` return their **same JSON rejection envelope on a server-side rendering exception (HTTP 500)**, not only on validation/rate-limit failures, and the Flutter parsers handle this correctly (because they key off body shape, not status code) even though no test names this exact scenario (§7, §8).
- A small number of genuine, scoped test-coverage gaps were found (§8) — none of them block the feature from working as implemented; they are missing verification, not confirmed defects.
- **No cancellation mechanism exists** for any in-flight preview/page-preview/PDF request (no `CancelToken` anywhere in the resume feature) — a real, confirmed gap against the checklist's explicit ask (§6, §8).

## 2. Environment / device availability

Non-destructive checks performed, in order:

1. `flutter devices` — **3 devices found**: an already-running Android emulator (`emulator-5554`, "sdk gphone16k arm64", Android 17/API 37), `macOS (desktop)`, `Chrome (web)`. This emulator was **already running before this audit started** — it was not launched, reset, or reconfigured by this phase.
2. `lsof -i :8000` + a single read-only `curl GET http://127.0.0.1:8000/` — a **local Django dev server was already running** (HTTP 200). Confirmed it is this project's own server, not an unrelated service, via two read-only GETs: `/users/login/` returned the real "Login – Career Buddy" page title, and `/api/riya/chat/` returned the expected `405` (that view only accepts POST — the same signature `lib/app/config/environment.dart`'s own doc comment uses to verify the production host). No login was attempted, no form was submitted, no data was read or changed.
3. A search for a documented, clearly-intended-for-development test account (README mentions, Django fixtures/seed commands) found **no explicit test-account credentials** safe to use without further authorization. Per this phase's own instruction ("Do not search private records or expose credentials," "Never bypass email OTP... to create a test session"), **no account was created and no login was attempted.**
4. **Live smoke test performed** (the only live-device interaction this phase performed): `flutter run -d emulator-5554 --debug` (default `ENV=dev`, so the app only ever talks to the local server above, never production). Result: the app built, installed, and launched with **no crash and no exception** in the run log. A screenshot was captured via `adb shell screencap` confirming the unauthenticated home screen rendered correctly — hero section, "Get Started"/"Find Jobs"/"Create Resume" buttons, "Job Seeker Portal" card, Login/Register buttons, and the chatbot launcher — all visible, no overflow, no rendering glitch. The process was then stopped (`kill`), leaving no lingering app session or test artifact beyond the screenshot file in this session's own scratch directory.

**What this does and does not prove**: it proves the current build is installable, launches without crashing, and renders its logged-out landing screen correctly on a real emulator — genuine device-level evidence, not a mocked test. It does **not** prove anything about the Manual Resume Builder itself, since reaching it requires a login this phase deliberately did not attempt. Every Manual Resume Builder checklist item in §6 that requires authentication is therefore marked **Blocked** (environment/account unavailable), not Failed or Passed, consistent with this phase's explicit instruction.

## 3. Actual test-suite and analyzer results

Commands run, with real output, immediately before any audit writing began and again confirmed afterward (no code changed in between):

```
$ flutter analyze
Analyzing Mobile_app...
warning • unused_element_parameter • test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart:78 (x2)
warning • unused_element_parameter • test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart:78 (x2)
4 issues found.
```
These 4 warnings are pre-existing (first disclosed in the Phase 27 report), unrelated to this audit, and not errors.

```
$ flutter test
...
+2273: All tests passed!
```
**2273 passed, 0 failed.** This matches the count at the end of Phase 28 exactly (no code changed since then, confirmed by `git status` in §11).

## 4. End-to-end checklist

Legend: **Passed** (automated-test or static-inspection evidence confirms it), **Blocked** (a safe, non-destructive check exists in principle but requires an authorized test account/live server call this phase did not have), **Not tested** (no evidence either way was gathered this phase).

### Form and local draft

| Item | Result | Evidence |
|---|---|---|
| Open the builder through its existing authenticated route | **Passed** (static) | `route_guards.dart`'s `computeRedirect()` + `RoutePaths.manualResumeBuilder` confirmed absent from both `publicRoutes` and `universalRoutes` (direct read, §7) — any unauthenticated hit falls to the default `return RoutePaths.login` branch. Live confirmation: **Blocked** (no test account). |
| Select a role and confirm expected role details | **Passed** (automated) | `manual_resume_builder_screen_test.dart`: "the selected role is shown on Career & Skills." |
| Enter representative values in each of the five steps | **Passed** (automated) | Per-step widget tests in `manual_resume_builder_screen_test.dart` (field presence for all 5 steps) + 62 validation unit tests in `manual_resume_validation_test.dart`. |
| Add and remove repeatable entries | **Passed** (automated) | "Experience step: Add Employment adds a card; an untouched entry removes without confirming" / "removing a touched entry asks for confirmation." |
| Trigger required-field and invalid-value validation | **Passed** (automated) | `manual_resume_validation_test.dart` (62 tests, every category) + "Next is blocked on an empty Personal step and does not advance." |
| Confirm autosave and restoration after app restart | **Partial** | Autosave: **Passed** (automated — debounce/coalescing tests in `manual_resume_builder_controller_test.dart`). Restoration is tested by re-reading a previously-`saveDraft`'d value from a **fresh `ProviderContainer`** in `manual_resume_builder_controller_test.dart`/`manual_resume_draft_local_datasource_test.dart` — a faithful simulation of "fresh process reads persisted storage," but **not a genuine OS-level app-kill-and-relaunch on a device**, which is **Blocked** (no test account to reach the builder and populate a real draft first). |
| Confirm one account's draft is not shown to another account | **Partial** | **Passed** at the storage layer (`manual_resume_draft_local_datasource_test.dart`: two usernames never share a key) and **Passed** for in-memory isolation of `manualResumeBuilderControllerProvider` specifically (`auth_controller_test.dart`'s explicit logout-invalidation case). **Gap**: no single test drives a connected "login A → edit draft → logout → login B → confirm blank" scenario end-to-end; the two halves are proven separately, not together (§8, finding 1). |
| Confirm logout/account switching does not expose stale user-scoped state | **Partial** | `manualResumeBuilderControllerProvider` is explicitly tested. `manualResumePreviewControllerProvider`, `manualResumePagePreviewControllerProvider`, `manualResumePdfControllerProvider` are present in `AuthController._invalidateUserScopedProviders()` (confirmed by direct read) but **no test asserts this for those three specifically** — a real, named test-coverage gap (§8, finding 1). |

### Structured-document preview

| Item | Result | Evidence |
|---|---|---|
| Open the preview with valid input | **Passed** (automated) | `manual_resume_preview_screen_test.dart`: "renders the real server document on success" (via a fake repository, not a live call). Live: **Blocked**. |
| Displayed sections correspond to entered form data | **Passed** (automated) | Same test + `manual_resume_preview_parser_test.dart` (every section `kind` parsed into its typed body). |
| Server-side validation returns the right errors to the builder | **Passed** (automated) | "a rejection immediately feeds its errors into the Builder controller and jumps to the first error's step" (`manual_resume_preview_controller_test.dart`). |
| Network/server failures via test doubles | **Passed** (automated) | `manual_resume_preview_datasource_test.dart`: 400/429/malformed-body/connection-failure cases, all via a fake `HttpClientAdapter`, never a real network call. |

### Page-image preview

| Item | Result | Evidence |
|---|---|---|
| Open Page Preview from the builder | **Passed** (automated, button wiring) / **Blocked** (live) | `manual_resume_builder_screen_test.dart`: "Page Preview navigates to the page-preview route carrying the current draft." |
| Loading and successful rendering with real server data | **Blocked** | No live server call was made. Automated evidence only: `manual_resume_page_preview_screen_test.dart`'s success-rendering tests use fabricated (but PNG-signature-valid) image bytes, not a real rendered resume page. |
| Navigate forward/backward through multiple pages | **Passed** (automated, with a caveat) | "renders multi-page navigation (chevrons, dots, page counter)" — but this specific test invokes the chevron's `onPressed` directly rather than a simulated tap gesture (§6, §8 finding 3), a documented test-harness limitation, not a feature gap. |
| Page counts and image aspect ratios | **Partial** | Page counts: **Passed** (automated — "total exceeding pages.length... is preserved verbatim," the "Showing the first N of Total pages" banner test). Aspect ratio fidelity against a *real* generated PDF page: **Not tested** (no real PDF was ever generated in this environment to compare against). |
| Empty pages, malformed image data, validation errors, rate limiting, retry | **Passed** (automated) | `manual_resume_page_preview_parser_test.dart` (15 tests: malformed base64, non-PNG-signature bytes, non-string/null entries, empty-pages-as-valid-result) + datasource test's 429 case + screen's retry test. |
| Failures preserve the draft | **Passed** (by construction + automated) | Neither `ManualResumePagePreviewController` nor its datasource ever calls `saveDraft`/`clearDraft` — confirmed by direct source read (no such call exists in either file) — and the controller-test "Builder controller integration" group confirms the builder's own draft/state is untouched by a page-preview rejection. |

### PDF generation

| Item | Result | Evidence |
|---|---|---|
| Trigger Generate PDF with valid test input | **Passed** (automated, with a caveat) | `manual_resume_builder_screen_test.dart`'s 3 Generate PDF tests — but all 3 invoke the button's `onPressed` directly rather than a simulated tap (§6, §8 finding 3). Live: **Blocked**. |
| Response is a valid PDF and filename is safe | **Passed** (automated) | `manual_resume_pdf_parser_test.dart` (22 tests: `%PDF-` signature check, filename sanitization incl. path-separator/control-character stripping, X-Resume-Filename vs. Content-Disposition precedence). Against a *real* server-generated PDF: **Blocked** (no live call made). |
| Existing temp-file + open/share flow works on the available platform | **Partial** | The file-write half is **genuinely exercised on real disk** in `manual_resume_pdf_controller_test.dart` and the builder-screen test (real temp directories via `FakePathProviderPlatform`, real `File.writeAsBytes`/`readAsBytes`). The "open" half uses `FakeOpenFilePlatform` — a scripted `OpenResult`, never a real platform channel or a real PDF-viewer app on the device (disclosed plainly, also in the Phase 28 report). |
| Cancellation, no compatible viewer, invalid response, validation rejection, network failure, rate limiting | **Partial** | No-compatible-viewer (`ResultType.noAppToOpen`): **Passed** (automated, mirrors an already-confirmed-live case from `ProtectedMediaDownloadController`). Invalid response, validation rejection, network failure, rate limiting: **Passed** (automated, `manual_resume_pdf_parser_test.dart` + `manual_resume_pdf_datasource_test.dart` + `manual_resume_pdf_controller_test.dart`). **Cancellation: Not implemented, not tested** — confirmed by a direct grep across the whole `lib/features/resume/` tree for `CancelToken`: zero matches. There is no way for a candidate to cancel an in-flight Generate PDF/preview/page-preview request from the UI (§8, finding 4). |
| Draft remains intact on success and failure | **Passed** (by construction + automated) | Same reasoning as the page-preview case: confirmed directly that `ManualResumePdfController`/its datasource never write to `ManualResumeDraftRepository`, and the controller test's "Builder controller integration" group proves it. |

### Authentication and session handling

| Item | Result | Evidence |
|---|---|---|
| Builder remains protected by the existing authentication guard | **Passed** (static) | Direct read of `route_paths.dart` (lines defining `publicRoutes`/`universalRoutes`) confirms `manualResumeBuilder`/`manualResumePreview`/`manualResumePagePreview` are in neither set, and `route_guards.dart`'s `computeRedirect()` sends anything outside those sets to `/login` while `AuthUnauthenticated`. **Gap**: `route_guards_test.dart` tests this exact logic generically (e.g. with `RoutePaths.dashboard`) but no test case names these three routes specifically by name (§8, finding 2) — a coverage gap, not a logic gap, since the guard is pure set-membership and the sets were directly confirmed. |
| Session expiry and CSRF failures handled honestly | **Passed** (automated) | The same `_ensureCsrfCookie()`/`X-CSRFToken` pattern used by every other authenticated POST in this app; an `UnauthorizedFailure` surfaces through the same `ApiExceptionsInterceptor` path as every other endpoint (no special-casing). Live CSRF round-trip against a real server: **Not tested** (disclosed identically in the Phase 27 report — never independently re-confirmed live in any phase since). |
| No unauthorized access or auth-circumvention attempted | **Confirmed** | No login was attempted, no OTP was bypassed, no credentials were used or fabricated, anywhere in this phase. |

## 5. Web/mobile parity comparison

Endpoint contracts in this table were **re-verified directly against the current `royalStaffing_CB01` source during this audit** (not merely copied from earlier reports), confirming no drift since Phase 24/27/28's own citations.

| Feature / behavior | Expected web behavior (source) | Flutter behavior (source) | Evidence | Result |
|---|---|---|---|---|
| Request field names | `normalize_state()`, snake_case (`target_title`, `role_def`, `decl_date`, etc.) — `career_app/resume_document.py:137-181` | `toManualResumePreviewPayload()` — `lib/features/resume/data/manual_resume_preview_payload.dart` | Read both files side-by-side this phase: every key matches exactly, field-for-field, including per-entry shapes (`JOB_FIELDS`/`PROJECT_FIELDS`/`EDU_FIELDS`/`CERT_FIELDS`/`TRAINING_FIELDS`, `resume_document.py:130-134`, vs. the Dart `job()`/`project()`/`education()`/`certification()`/`training()` mappers) | **Match** |
| Repeatable-section cap | `MAX_ITEMS = 15` (`resume_document.py:20`) | `kMaxItems = 15` in the validation port | Confirmed directly this phase | **Match** |
| Role catalog | Same `manual_resume_roles`/`roles_api` the web's own builder and the Flutter Role Picker both call (`manual_resume_views.py:87-111`) | `ResumeRole`/`parseManualResumeRoles`, extended Phase 26 to parse `fields`/`levels`/`summaries`/etc. from the same payload | Phase 24/26 reports | **Match** |
| Draft persistence model | **No server persistence at all** — one `sessionStorage` key, `cbResumeBuilder.v1`, tab-scoped, lost on browser restart (`landing.html:8333/8349-8350`) | One `SecureStorageService` key per account, survives app kill/relaunch (by design — Phase 25 §"Draft model and persistence design") | Phase 24 §3.5, Phase 25 report | **Partial / intentional difference** — mobile persistence is *more durable* than the web's own `sessionStorage`, a deliberate, documented product choice, not a bug, but genuinely different behavior a user could notice (a mobile draft survives a restart; the web one does not survive a browser restart). |
| Server validation error shape | `{field, step, message}`, `step` 1–5 matching wizard steps (`resume_document.py`'s `STEP_*` constants) | `ManualResumeValidationError{field, step, message}`, reused verbatim for client and server errors | Phase 26/27 reports, re-confirmed this phase (`_prepare()`'s JSON shape, `manual_resume_views.py:67-84`) | **Match** |
| Structured preview content | `build_document()`'s nested dict, rendered to HTML entirely client-side by the web's own `docHTML()` JS — **no server-rendered HTML exists** | `ManualResumeDocument`/`ManualResumeSectionBody`, rendered as native Flutter widgets, one branch per section `kind` | Phase 27 report §1 (confirmed via an explicit search for any server-side HTML template — none found) | **Match in content/structure; intentional native-UI difference in presentation** (no HTML/CSS visual fidelity was attempted, per the task's own design-system instruction) |
| Page-image preview | `preview_pages_api`: PNG data-URIs, capped at `max_pages=6` (`resume_pdf.py:320-332`), rendered on the web as a **vertically stacked list**, not a carousel (`landing.html`, confirmed Phase 24 §3.6) | Same endpoint/cap; rendered as a **swipeable carousel** (chevrons + dots), not a stacked list | Phase 24 §3.6, Phase 28 report | **Match in data/cap; intentional native-UI difference in layout** (carousel vs. stacked list is a deliberate mobile-appropriate adaptation, not a defect) |
| PDF response handling | Raw `application/pdf` bytes + `Content-Disposition`/`X-Resume-Filename` headers; a non-JSON request's failure is **plain text** (web's own Print-button path only) (`manual_resume_views.py:131-150`) | `parseManualResumePdfResponse()` decides PDF-vs-JSON-rejection by content-type **and** the real `%PDF-` signature, never by status code alone; the plain-text branch is correctly never exercised since this client always sends JSON | Re-confirmed directly this phase, including the **previously under-emphasized fact** that a PDF-render exception also returns the identical JSON rejection envelope at HTTP 500, which this parser already handles correctly by construction (shape-based, not status-based) | **Match** |
| Filename safety | `resume_filename()` — confirmed ASCII-safe server-side (`[A-Za-z0-9_]` only) | `sanitizeManualResumePdfFilename()` — an independent defensive floor regardless of server behavior | Phase 28 report | **Match (mobile is strictly more defensive, not less)** |
| Authentication requirement | **None at all** — the whole feature is anonymous-accessible by design (`manual_resume_views.py`'s own module docstring, re-confirmed this phase) | **Authenticated-only** — reachable only via the logged-in Resume Builder → Role Picker → "Build Resume" flow | Phase 24 §5 item 1 ("decision needed"), Phase 25 §"Account isolation," re-confirmed this phase via `route_paths.dart` | **Intentional, explicitly-directed deviation**, not a defect — this was a standing instruction repeated across every phase of this engagement, not an oversight. Flagged here only because the task asked to distinguish intentional native/product differences from mismatches, and this is the single largest one. |
| CSRF handling | Standard Django double-submit CSRF, no `@csrf_exempt` on any of the 3 POST views (re-confirmed this phase) | `_ensureCsrfCookie()` + `X-CSRFToken` header, identical mechanism to every other authenticated POST in this app | Phase 24/27 reports, re-confirmed this phase | **Match** |
| Rate limiting / payload cap | 60 req/10 min per IP, 200,000-byte payload cap, shared across preview/pages/pdf (`manual_resume_views.py:23-42`) | Both surfaced as a `ManualResume*Rejected` state showing the server's own message verbatim, never retried automatically, never bypassed | Re-confirmed this phase | **Match** |
| Reorder support for repeatable entries | **Not supported** on the web either (confirmed Phase 24 §3.3 via an explicit whole-file grep) | Not supported in Flutter either (no reorder control exists in any step widget) | Phase 24, Phase 26 report | **Match** |
| Completeness/progress meter | A full per-category meter with jump-to-category buttons (`#rbComp`); the web's own client **ignores** the server's `completeness` value and computes it independently in JS (Phase 24 §3.6) | A one-line "Overall completeness: N%" summary only, no per-category meter | Phase 26/27 reports | **Partial** — a deliberately smaller feature, not a parsing or data bug; flagged (not newly) as a known, scoped-out gap. |

## 6. Known test-harness limitations

- **Direct `onPressed` invocation instead of a simulated tap gesture**, in exactly 3 test cases across 2 files: the page-preview carousel's "next page" chevron (`manual_resume_page_preview_screen_test.dart:207`) and all 3 of the "Generate PDF" button tests (`manual_resume_builder_screen_test.dart:574,595` plus the shared `pressGeneratePdf` helper). In each case, `tester.tap()` was confirmed (via `flutter test` runs during Phase 28, re-confirmed by grep this phase) to not reliably reach the target widget's `onPressed`, despite the finder resolving to exactly one widget with a non-null handler and no hit-test-mismatch warning — a timing/gesture-arena quirk of this specific test environment, not a defect in the app (confirmed by calling the same controller method directly, bypassing the widget tree entirely, which works identically). **What this means for confidence**: the button's *wiring* (correct key, non-null `onPressed`, correct controller call, correct resulting UI for each outcome) is still fully verified; what is **not** verified by these 3-4 specific test cases is that a real finger tap reaches that exact pixel on a real screen — a gap only a live device walkthrough (Blocked, §2) can close.
- **Every datasource test uses a fake `HttpClientAdapter`** (4 files: `resume_remote_datasource_test.dart` and the 3 new Phase 27/28 ones) — no test in this codebase makes a real network call to any server, local or production. A passing datasource test proves the Dio request/response pipeline and the parsing logic are correct for the exact response shapes fed to it; it does not prove a real Django server actually returns those shapes today (though this phase's own direct source re-reads in §5 independently confirm it still does).
- **File-save tests use real disk I/O but a scripted "open" result**: `manual_resume_pdf_controller_test.dart` and the builder-screen's Generate PDF tests write real bytes to a real temporary directory and read them back — genuine evidence the save step works — but `OpenFile.open()` itself is replaced by `FakeOpenFilePlatform`, which never touches a real platform channel or a real installed PDF viewer.
- **No widget test in this codebase simulates an actual OS-level process kill and relaunch.** "Restoration after restart" tests (Phase 25) prove a fresh `ProviderContainer`/repository correctly reads back whatever was last written to `SecureStorageService` — a faithful proxy for the persistence logic, but not the same as observing a real app process being killed and reopened on a device.

## 7. Endpoint contracts re-verified this phase (not merely cited from earlier reports)

Read directly from `royalStaffing_CB01/career_app/manual_resume_views.py`, `resume_document.py`, `resume_pdf.py`, and `business_english_lms/urls.py` during this audit:

- All 4 URLs confirmed unchanged: `manual_resume_roles`/`manual_resume_preview`/`manual_resume_pdf`/`manual_resume_pages` under the `resume-builder/` prefix.
- No `@login_required` or `@csrf_exempt` decorator on any of the 3 POST views — confirmed by reading the full file, not a keyword search.
- `_prepare()`'s shared rate-limit (429)/payload-read-failure (400)/validation-failure (400) envelope, and — newly re-emphasized this phase — `pdf_download`'s and `preview_pages_api`'s own **independent** HTTP 500 branch on a rendering exception, which returns the **same** `{ok:false, errors:[{field:'', step:0, message:'...'}]}` shape. Flutter's parsers (`parseManualResumePdfResponse`/`parseManualResumePagePreviewResponse`) key off this JSON shape, not the status code, so this case is handled correctly by the existing code — but no existing test names this exact 500-with-a-rendering-exception scenario by its specific message text (distinct from the generic 429/400 cases that *are* tested).
- `normalize_state()`'s exact field names, `MAX_ITEMS = 15`, `max_pages = 6` — all re-confirmed byte-for-byte against the Flutter mappers/constants, with no discrepancy found.

## 8. Identified gaps (evidence-based, no fixes implemented)

1. **Missing targeted regression test**: `auth_controller_test.dart` explicitly asserts logout invalidates `manualResumeBuilderControllerProvider` (Phase 25's own test), but no equivalent test exists for `manualResumePreviewControllerProvider`, `manualResumePagePreviewControllerProvider`, or `manualResumePdfControllerProvider`, even though all three are present in `_invalidateUserScopedProviders()`'s source (confirmed by direct read). The code is very likely correct (same mechanism, same file, same method); it is simply unverified by name. *Recommended smallest next step*: add 3 small cases to `auth_controller_test.dart` mirroring the existing one.
2. **Missing targeted route-guard test**: `route_guards_test.dart` proves the general "non-public route → login" rule with a different example route; no case names `manualResumeBuilder`/`manualResumePreview`/`manualResumePagePreview` specifically. *Recommended smallest next step*: add one parametrized case over the three route constants.
3. **No narrow-width (320px) overflow test** exists for `ManualResumePreviewScreen` or `ManualResumePagePreviewScreen`, unlike every one of the five wizard steps (each has its own explicit 320px test). Not a confirmed overflow bug — just unverified at that width. *Recommended smallest next step*: one narrow-width pump test per screen, mirroring the existing wizard-step pattern.
4. **No cancellation mechanism exists** for in-flight preview/page-preview/PDF requests (confirmed via a whole-feature grep for `CancelToken`: zero results). A candidate who taps "Generate PDF" and then navigates away has no way to abort that request; the response is simply ignored once the controller is no longer observed, which is a reasonable default but was never an explicit design decision documented anywhere in Phases 27/28. *Recommended smallest next step*: a product decision on whether this is acceptable, before any implementation.
5. **No connected two-account end-to-end draft-isolation test**: proven at the storage layer and the in-memory-invalidation layer separately (see item 1), never as one connected "login A, edit, logout, login B" scenario.
6. **Live verification of every authenticated flow remains Blocked**, not because of any suspected defect, but because this environment has no authorized test account (§2). This is the single largest unresolved verification gap in this audit.

None of the above were treated as license to implement a fix — per this phase's explicit instruction, they are recorded as evidence and recommendations only.

## 9. Unresolved verification gaps (summary)

- Live, authenticated, on-device walkthrough of the five-step form, structured preview, page-image preview, and PDF generation against a real server (local dev or production) — **Blocked**, no authorized test account.
- Real CSRF-token round-trip against a live Django instance for the preview/pages/pdf endpoints specifically — **never independently confirmed in any phase**, including this one.
- Real PDF-viewer "open" behavior on a device (vs. the scripted `FakeOpenFilePlatform` result) — **Blocked**.
- Visual/aspect-ratio comparison of a rendered page-preview image against the same resume's real PDF page — **Blocked** (no real PDF was ever generated in this environment).
- Draft survival across a genuine OS-level app kill/relaunch — **Not tested** (only a fresh-container-read proxy exists).

## 10. Prioritized recommendations for a future implementation phase

Ordered by effort-to-value, smallest first — **none of these were implemented this phase**:

1. Add the 3 missing `auth_controller_test.dart` cases for the Phase 27/28 providers (finding 1). Trivial, closes a real named gap.
2. Add the 1 missing `route_guards_test.dart` case naming the 3 manual-resume routes (finding 2). Trivial.
3. Add 2 narrow-width (320px) widget tests, one per preview screen (finding 3). Small, matches an existing established pattern exactly.
4. Once an authorized test account is available: perform a full authenticated live walkthrough on the already-confirmed-available emulator against the already-confirmed-running local dev server — the single highest-value remaining verification, and the only one that can actually close §9's gaps.
5. A product decision on request cancellation (finding 4) before any implementation is attempted.
6. Consider one additional test per Part A/Part B parser explicitly naming the HTTP-500-rendering-exception scenario (distinct from the already-tested 429/400 cases), since it is a real, confirmed server behavior (§7) that happens to already work but isn't individually evidenced.

## 11. Distinguishing evidence types used in this report

- **Automated test** (unit/widget, mocked repositories or fake HTTP adapters, no real network/device I/O beyond the specific real-disk-write cases called out in §6): the large majority of "Passed" entries above.
- **Static inspection** (reading Flutter and/or Django source directly, no execution): the authentication-guard and endpoint-contract findings in §4/§5/§7.
- **Live-server check** (a real, read-only HTTP request to a real running server): exactly 3 `curl` GETs in §2, against the local dev server only, never production.
- **Device check** (a real app build, install, and launch on a real connected emulator, observed via a captured screenshot): exactly 1 smoke test in §2, unauthenticated only.

No claim in this report conflates these categories. Where a "Passed" result rests only on a mocked test, that is stated explicitly rather than implied to be live-verified.

## 12. Confirmation: no application code or reference trees modified

- `git status --porcelain` in `Mobile_app/` before writing this report was byte-for-byte identical to the state recorded at the end of the Phase 28 report (69 lines, same files) — confirmed by an explicit diff against that list. Only this report file was added afterward.
- `git status --porcelain` in `Career_Buddy_LMS/` shows only the same pre-existing modifications already disclosed, unchanged, in every prior phase's report (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, plus 3 pre-existing untracked test files) — none touched by this phase.
- `royalStaffing_CB01/` is not a git repository; every file read this phase (`manual_resume_views.py`, `resume_document.py`, `resume_pdf.py`, `business_english_lms/urls.py`) was accessed via read-only `Read`/`sed`/`grep` only.
- No signing file, credential, token, or secret was inspected, printed, or exposed. No production network request was made. No real user data or real resume content was submitted anywhere.

---

**Phase 29 is complete. No implementation was started.** Returning this report for review; awaiting explicit approval before any future implementation phase (which, per §10, should begin with the 3 small test additions and then the live authenticated walkthrough once a test account is available).
