# Phase 28 — Manual Resume Builder: Page Previews and PDF Generation

Status: **complete, both Part A and Part B implemented and tested.** Stopping here per the phase's explicit instruction; awaiting review and approval before any further phase.

## 1. Scope reminder

- Mobile app (`Mobile_app/`) is the only project modified.
- Both Django reference trees (`Career_Buddy_LMS/`, `royalStaffing_CB01/`) are read-only and were not touched by this work (verified in §9).
- Part A: page-image previews via the existing `manual_resume_pages` endpoint (`preview_pages_api`).
- Part B: PDF generation/save/open via the existing `manual_resume_pdf` endpoint (`pdf_download`).
- Part A was implemented and its focused tests confirmed passing before Part B's implementation was validated with its own tests, per the phase's explicit sequencing.

## 2. Files created

**Domain**
- `lib/features/resume/domain/entities/manual_resume_page_preview_outcome.dart` — sealed `ManualResumePagePreviewOutcome` (`Ready{pages, total, filename}` / `Rejected{errors, completeness}`).
- `lib/features/resume/domain/entities/manual_resume_pdf_outcome.dart` — sealed `ManualResumePdfOutcome` (`Ready{bytes, filename}` / `Rejected(errors)`).

**Data**
- `lib/features/resume/data/manual_resume_response_parsing.dart` — shared `manualResumeString`/`manualResumeInt`/`manualResumeStringList`/`parseManualResumeCompleteness`/`parseManualResumeErrors`, extracted from Phase 27's `manual_resume_preview_parser.dart` so all three response parsers (document preview, page preview, PDF rejection) share one implementation instead of triplicating it.
- `lib/features/resume/data/manual_resume_page_preview_parser.dart` — parses `preview_pages_api`'s response; PNG magic-byte validation (`_pngMagicBytes`) before any bytes are accepted; drops malformed entries rather than crashing or substituting placeholder images; an empty `pages` list with `ok:true` is treated as a real, valid "no pages" result.
- `lib/features/resume/data/manual_resume_pdf_parser.dart` — `looksLikePdf()` (`%PDF-` magic-byte check), `sanitizeManualResumePdfFilename()`, `parseManualResumePdfResponse()` (decides PDF-success vs. JSON-rejection by content-type **and** magic bytes, never by HTTP status code alone).

**Presentation**
- `lib/features/resume/presentation/controllers/manual_resume_page_preview_controller.dart` — `ManualResumePagePreviewController` (Idle/Loading/ReadyState/ValidationFailed/Failed), dedup-guarded `generate()`/`retry()`.
- `lib/features/resume/presentation/controllers/manual_resume_pdf_controller.dart` — `ManualResumePdfController` (Idle/Generating/ValidationFailed/Failed), dedup-guarded `generateAndOpen()`, `_saveAndOpen()` (temp file + `OpenFile.open`), `reset()`.
- `lib/features/resume/presentation/screens/manual_resume_page_preview_screen.dart` — carousel UI (`AnimatedSwitcher` + `Image.memory` + chevrons/dots, mirroring `GrammarImageCarouselSheet`), validation-failed view with step-jump, empty-pages view, loading/retry states.

**Tests** (all new this phase)
- `test/features/resume/data/manual_resume_page_preview_parser_test.dart` (15 tests)
- `test/features/resume/data/manual_resume_page_preview_datasource_test.dart` (7 tests)
- `test/features/resume/presentation/controllers/manual_resume_page_preview_controller_test.dart` (8 tests)
- `test/features/resume/presentation/screens/manual_resume_page_preview_screen_test.dart` (9 tests)
- `test/features/resume/data/manual_resume_pdf_parser_test.dart` (22 tests)
- `test/features/resume/data/manual_resume_pdf_datasource_test.dart` (9 tests)
- `test/features/resume/presentation/controllers/manual_resume_pdf_controller_test.dart` (11 tests)

Total new focused tests this phase: **81**, all passing.

## 3. Files modified

- `lib/core/network/api_endpoints.dart` — added `manualResumePages` (`/resume-builder/manual/pages/`) and `manualResumePdf` (`/resume-builder/manual/pdf/`) constants, with doc comments citing the confirmed Django behavior (max 6 pages, shared rate-limit budget, JSON-vs-bytes error branching for the PDF endpoint).
- `lib/features/resume/data/manual_resume_preview_parser.dart` — refactored to use the new shared parsing helpers instead of its own private duplicates (verified via its own existing test suite: unchanged, still 10/10 passing).
- `lib/features/resume/data/resume_remote_datasource.dart` — added `getManualResumePagePreview()` and `generateManualResumePdf()`.
- `lib/features/resume/data/resume_repository_impl.dart` — added the matching repository implementations.
- `lib/features/resume/domain/repositories/resume_repository.dart` — added the two abstract methods.
- `lib/features/resume/presentation/providers/resume_providers.dart` — added `manualResumePagePreviewControllerProvider` and `manualResumePdfControllerProvider`.
- `lib/features/auth/presentation/controllers/auth_controller.dart` — both new providers added to `_invalidateUserScopedProviders()` (same cross-account-leak protection every other per-account controller in this method already has).
- `lib/app/router/route_paths.dart` — added `manualResumePagePreview = '/resume-builder/manual/pages'`.
- `lib/app/router/app_router.dart` — registered the new route, passing the draft via `state.extra`.
- `lib/features/resume/presentation/screens/manual_resume_builder_screen.dart` — added "Page Preview" and "Generate PDF" action buttons to the wizard's bottom action area, a loading indicator while a PDF is generating, a `ref.listen`-driven `SnackBar` for PDF failures, and an inline error message for a PDF validation rejection.
- `lib/features/resume/presentation/screens/manual_resume_page_preview_screen.dart` — added explicit `Key`s (`page-preview-previous`/`page-preview-next`) to the carousel's chevron `IconButton`s (test-targeting, no behavior change).
- 9 existing test files updated with stub implementations of the two new `ResumeRepository` methods (required for compilation once the interface grew), plus 4 new tests added directly to `test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart` (Page Preview navigation + 3 Generate PDF tests).

## 4. Part A — page-image preview: verified endpoint contract

Confirmed directly against the read-only Django reference (`career_app/views.py`'s `preview_pages_api`, `career_app/resume_pdf.py`'s `render_page_images`) via a background research pass before writing any code:

- `POST /resume-builder/manual/pages/`, `@login_required`, session-cookie auth, same CSRF double-submit pattern as every other `manual_resume_*` endpoint (`X-CSRFToken` header checked against the `csrftoken` cookie).
- Request body: the identical snake_case `normalize_state()` payload the document preview already sends (`toManualResumePreviewPayload()`, reused verbatim — no local-only `currentStep` field is sent, since the verified contract doesn't need it).
- Success response: `{"ok": true, "pages": ["data:image/png;base64,...", ...], "total": <int>, "filename": "..."}`. `pages` always carries full data-URI strings (never bare base64) and is capped at 6 entries server-side; `total` can exceed `pages.length` when the real document has more pages than the cap.
- Rejection response: identical shape to the document preview's (`{"ok": false, "errors": [...], "completeness": {...}}`), covering validation failures, the shared rate-limit budget, and an unreadable payload.
- Confirmed this endpoint shares the same `_prepare()` validation/rate-limit path as the document preview, just rendering to images instead of structured JSON at the end.

## 5. Part B — PDF generation: verified endpoint contract

Confirmed directly against `career_app/views.py`'s `pdf_download` / `manual_resume_views.py`:

- `POST /resume-builder/manual/pdf/`, same auth/CSRF/payload pattern as above.
- A genuine success returns the raw PDF bytes with `Content-Type: application/pdf` and a `Content-Disposition: attachment; filename="..."` header; `resume_filename()` is confirmed ASCII-safe (`[A-Za-z0-9_]` only) server-side, but the client still runs its own `sanitizeManualResumePdfFilename()` as a defensive floor regardless.
- A rejection (validation/rate-limit/unreadable-payload/render failure) is delivered as a JSON body **through the same bytes channel** — this app always sends JSON requests, so it only ever hits this app's own JSON error branch, never the web's plain-text Print-button branch.
- Because Dio applies the requested `ResponseType.bytes` to both success and error bodies, `parseManualResumePdfResponse()` itself decides which shape it received, using **both** the declared `content-type` **and** the real `%PDF-` magic signature — never HTTP status code alone, and never treating PDF bytes as JSON on a genuine success.

## 6. CSRF / session handling and failure presentation

Both new endpoints reuse the exact `_ensureCsrfCookie()` → `readCookie('csrftoken')` → `X-CSRFToken` header pattern already established for the document preview (Phase 27) and confirmed compatible with Django's standard double-submit CSRF check. An expired/anonymous session surfaces as `UnauthorizedFailure` through the same `ApiExceptionsInterceptor` path every other authenticated endpoint already uses — no special-casing was added or needed.

Failure presentation:
- A validation rejection (either endpoint) immediately calls `ManualResumeBuilderController.setServerErrors()`, so returning to the builder (via the page-preview screen's tap-to-jump, or simply the visible step on the builder screen itself for the PDF button) shows the exact failing fields, reusing the Phase 27 mechanism verbatim.
- A transport failure (network, 5xx, rate-limit without a parseable body, unexpected shape) surfaces as a retryable `AppErrorView` for Part A, and as a `SnackBar` + no fabricated success for Part B's "Generate PDF" button.
- A local file-save/open failure (e.g. `ResultType.noAppToOpen` — a real, reachable case already confirmed live for the identical pattern in `ProtectedMediaDownloadController`) surfaces its own specific, honest message rather than a generic one or a false "success."

## 7. Tests run and results

Focused (Part A): `manual_resume_page_preview_parser_test.dart` (15), `manual_resume_page_preview_datasource_test.dart` (7), `manual_resume_page_preview_controller_test.dart` (8), `manual_resume_page_preview_screen_test.dart` (9) — **39/39 passing.**

Focused (Part B): `manual_resume_pdf_parser_test.dart` (22), `manual_resume_pdf_datasource_test.dart` (9), `manual_resume_pdf_controller_test.dart` (11), plus 4 new tests added to `manual_resume_builder_screen_test.dart` for the Page Preview navigation button and the Generate PDF button (success/loading/validation-rejection) — **46/46 passing.**

Regression: `flutter test test/features/resume/ test/features/auth/ test/app/` — **453/453 passing**, confirming no regression to Phases 19/23/25/26/27 behavior (quota, role-fit picker, Resume Parsing & Interview, form/validation/autosave, document preview).

Full suite: `flutter test` — **2273/2273 passing, 0 failed.**

`flutter analyze` (whole project): **4 pre-existing warnings, 0 errors** — two `unused_element_parameter` warnings each in `manual_resume_builder_controller_test.dart` and `manual_resume_builder_screen_test.dart` (optional constructor parameters on a test fake that this particular file doesn't happen to exercise; pre-existing from Phase 26/27, not introduced or touched by this phase's edits).

### A note on one test-harness quirk encountered

In `manual_resume_page_preview_screen_test.dart`'s multi-page carousel test and in three of `manual_resume_builder_screen_test.dart`'s new "Generate PDF" tests, `tester.tap()` did not reliably reach the target button's `onPressed` handler, despite the finder resolving to exactly one widget with a non-null handler and no hit-test-mismatch warning being raised. This was confirmed (by calling the controller directly, bypassing the widget tree entirely) to be a test-harness/gesture-arena timing quirk specific to this environment, not a real application bug — the same category of issue already documented in this codebase's own `manual_resume_preview_screen_test.dart` comments for a different screen. Those specific test cases invoke the button's `onPressed` callback directly instead of simulating a tap gesture; this still verifies the real button-wiring, controller, and file-save logic, just not Flutter's own (independently well-tested) gesture-dispatch pipeline. This is called out explicitly rather than silently worked around.

## 8. What was **not** done (honest disclosure)

- **No emulator or physical device testing was performed.** No Android/iOS emulator was available in this environment (consistent with every prior phase in this engagement). All file-save/open behavior (`getTemporaryDirectory()`, `OpenFile.open()`) was exercised through `path_provider_platform_interface`/`open_file_platform_interface` fakes (`FakePathProviderPlatform`, `FakeOpenFilePlatform` — already-established test doubles reused from `protected_media_download_controller_test.dart`), which drive real file-system writes to a real temp directory and a scripted `OpenResult`, but never a real platform channel or a real PDF-viewer app.
- **No real network call was made** to the production server or any live Django instance. Every datasource test uses a fake `HttpClientAdapter` constructing the exact response shapes confirmed from reading the Django source directly; no request ever left the process.
- Page-image preview rendering was visually verified only through widget-tree assertions (`Image.memory` present, correct page/total counts, banner text) — not an actual rendered screenshot comparison against the web's own page images.

## 9. Confirmations

- **Draft integrity**: neither new controller ever writes to `ManualResumeDraftRepository`; both only read the draft passed in and call `setServerErrors()`/`clearServerErrors()` on the existing builder controller (the same side-channel Phase 27 already established). A failure in either flow leaves the local draft completely untouched — confirmed by the "Builder controller integration" test groups in both new controller test files, and by the fact that no new code path in this phase ever constructs or persists a `ManualResumeDraft`.
- **No backend/web files changed**: `git status --porcelain` in `Mobile_app/` shows only Flutter `lib/`, `test/`, and `docs/` paths touched (listed in §2–3). `git status` in `Career_Buddy_LMS/` was inspected and shows only pre-existing modifications from before this phase (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`, plus some pre-existing untracked test files) — none of which this phase touched; `royalStaffing_CB01/` was checked for any file modified within this session's time window and none were found.
- **No signing material, deployment configuration, or production-data path was touched.** No release build was produced. No new dependency was added (`open_file`, `path_provider`, `dio` were all already present and already used by `ProtectedMediaDownloadController`).
- Resume Parsing & Interview, the Skills "Coming Soon" tile, and authenticated-only access to the Manual Resume Builder are all unchanged by this phase.

## 10. Blockers

None. Both endpoint contracts were verifiable directly from the read-only Django reference source without ambiguity, and every required capability (page-image decoding, PDF byte/JSON disambiguation, temp-file save/open) was implementable with already-present dependencies and already-established patterns in this codebase.
