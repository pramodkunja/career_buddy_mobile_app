# Phase 39 — Create Resume Workflow Report

## 1. Summary

Implemented the previously-missing free-form **Create Resume** builder (`career_app/create_resume_views.py`) — the single largest functional gap identified by every prior audit since Phase 15. This is a genuinely separate feature from both the Manual Resume Builder (role-driven, local-only draft) and AI Resume Parsing/ATS: a blank-canvas builder with no suggestions, server-backed draft persistence, server-rendered live preview, and server-generated PDF download.

**Scope delivered, end to end**: Personal details, Professional Summary, Skills (4 categories), Experience, and Education — 5 of the real backend's 10 content sections, chosen as the most commonly essential ones for a usable resume. Preview, PDF download, and the full drafts lifecycle (list/save/create/update/delete) are implemented for exactly this scope. The home screen's hero "Create Resume" button now opens this feature directly, matching the real web's own hero button destination exactly — correcting Phase 34's acknowledged interim compromise (a choice sheet between two other, different features).

**Scope deliberately not delivered this phase** (documented, not silently dropped): Projects, Certifications, Achievements, Internships/Volunteering, Languages, and Additional Information — 5 more sections the real backend also accepts. Submitting a form without them is not an error; the server's own `build_document()` simply omits any section with no entries, so every resume this phase can produce is a valid, honestly partial document, never a broken one.

**Device verification**: not performed. The physical Android device used in Phases 35-38 was disconnected this phase; an emulator was launched as a substitute but had insufficient storage to install the APK even after a safe, non-destructive cache trim. This is stated plainly in §9 rather than claimed.

## 2. Verified web routes and source files

Read in full this phase: `career_app/create_resume_views.py` (195 lines), `career_app/create_resume.py` (599 lines — the complete normalize/validate/build_document/draft_title/resume_filename logic), `career_app/models.py`'s `ResumeDraft` model, and the route registration in `business_english_lms/urls.py`.

| Route (all under `/resume-builder/create/...`) | View | Auth | Purpose |
|---|---|---|---|
| `POST create/preview/` | `preview_api` | None | Live preview — **always** returns a well-formed document, even with validation errors present |
| `POST create/pages/` | `pages_api` | None | Page-image preview rendered from the real generated PDF (requires a fully valid document) |
| `POST create/pdf/` | `pdf_download` | None | The real, server-rendered PDF (requires a fully valid document) |
| `GET create/drafts/` | `drafts_list` | **Login required** | Every saved draft belonging to the signed-in user |
| `POST create/drafts/save/` | `draft_save` | **Login required** | Create (no id) or update (own id) a draft — partial/invalid resumes may be saved |
| `GET create/drafts/<pk>/` | `draft_detail` | **Login required** | One draft's full data, scoped to `request.user` |
| `POST create/drafts/<pk>/delete/` | `draft_delete` | **Login required** | Delete, scoped to `request.user` |

Also confirmed directly (and load-bearing for the implementation decisions below):
- **Preview never rejects.** `preview_api`'s own docstring and code confirm the document is returned even with missing required fields — there is no `{ok:false}` branch for this one endpoint, unlike its siblings.
- **PDF/pages do reject** (`_ready_state()` runs full `validate()` first) with `{ok:false, errors:[...]}` at HTTP 400.
- **Drafts never run `validate()`.** A partial, invalid-for-PDF resume can still be saved as a draft — confirmed directly in `draft_save`.
- **`ResumeDraft.MAX_PER_USER = 20`** — exceeding it returns a specific, real server message at HTTP 400, not a generic error.
- The real `landing.html`'s `#create-resume` section is genuinely reachable by every visitor (no login wall on the builder itself), and its own `data-login="...?next=..."` attribute confirms the real web only prompts for sign-in at the save step — not before.

## 3. Route-to-feature parity comparison

| Workflow step | Web route/purpose | Required fields/validation | Flutter equivalent | Status |
|---|---|---|---|---|
| Personal details | `personal.*` in every payload | name/title/email/phone/city/state/country required (`PERSONAL_REQUIRED`) | `CreateResumePersonalStep` | **Implemented** |
| Professional Summary | `summary` | Optional; 50-1200 chars once non-empty | `CreateResumeSummaryStep` | **Implemented** |
| Skills | `skills.{technical,functional,soft,tools}` | 2-50 chars/skill, ≤30/category | `CreateResumeSkillsStep` | **Implemented** |
| Experience (repeatable) | `experience[]` | company/title/start date required per touched entry | `CreateResumeExperienceStep` | **Implemented** |
| Education (repeatable) | `education[]` | qualification/institution required per touched entry | `CreateResumeEducationStep` | **Implemented** |
| Projects/Certifications/Achievements/Internships+Volunteering/Languages/Additional | `projects[]`/`certifications[]`/etc. | Various, all optional sections | — | **Not implemented — documented gap, see §10** |
| Live preview | `preview_api` | N/A — always succeeds | `CreateResumePreviewScreen` + `CreateResumeDocumentView` | **Implemented** |
| PDF generation/download | `pdf_download` | Full `validate()` | `CreateResumePdfController` (temp file + `open_file`, same pattern as Manual Resume Builder) | **Implemented** |
| Page-image preview | `pages_api` | Full `validate()` | — | **Not implemented — see §10** (lower priority than the structured preview, which already shows the same content) |
| Draft list | `drafts_list` | Login required | `CreateResumeDraftsScreen` | **Implemented** |
| Draft save (create/update) | `draft_save` | Login required, no content validation | `CreateResumeBuilderController.save()` | **Implemented** |
| Draft detail (open/continue) | `draft_detail` | Login required, ownership-scoped | `CreateResumeDraftsScreen._openDraft` | **Implemented** |
| Draft delete | `draft_delete` | Login required, ownership-scoped, confirmation | `CreateResumeDraftsScreen._deleteDraft` (confirm dialog first) | **Implemented** |

## 4. Implementation decisions and why they match the web

- **No client-side validator was built.** Every other rule table in `create_resume.py` (per-field length ranges, date-range checks, duplicate-language detection, etc.) is extensive — rebuilding it client-side would duplicate business logic that already lives, authoritatively, on the server, and the live preview endpoint already returns the exact same `{field, section, message}` errors on every submission regardless of validity. This app surfaces those server-returned errors directly, inline, next to each field — correct by construction, never able to drift from the real rules.
- **No local autosave/debounce**, unlike the Manual Resume Builder. The real web's own Create Resume builder only persists via an explicit Save action (`draft_save` is never called on a timer) — this was confirmed directly rather than assumed, and the Flutter builder matches it: edits live only in memory until "Save" is tapped, with a "discard changes?" confirmation on leaving an unsaved, non-blank form.
- **The home screen's "Create Resume" CTA now goes directly to this feature**, replacing Phase 34's choice sheet. The real web's hero button scrolls straight to `#create-resume`; now that the feature exists, routing there directly is the faithful behavior, not a compromise. The Manual Resume Builder's own separate entry point (Role Picker → "Build Resume") is unchanged.
- **The builder/preview routes are public (`universalRoutes`), not authenticated-only** — a deliberate departure from the Manual Resume Builder's own stricter, app-only gate. This was verified, not assumed: the real `preview_api`/`pdf_download`/`pages_api` endpoints have no login requirement at all, and the real web itself lets any visitor use the builder. Only "My Resumes" (`createResumeDrafts`) requires authentication, matching `drafts_list`'s own real `@login_required`.
- **Generic widgets were reused, not duplicated**, per the task's own instruction: `ManualResumeTextField`, `ManualResumeCharCounter`, `ManualResumeEntryCard`, `ManualResumeMonthField`, and `confirmRemoveEntry` (all from the Manual Resume Builder's own `manual_resume_form_widgets.dart`) are imported directly rather than re-implemented, since their behavior is generic (a labelled text field, a repeatable-entry card shell, a month/year picker, a remove-confirmation dialog) and not specific to that other feature.
- **PDF handling reuses the existing, already-proven pattern exactly**: `CreateResumePdfController` mirrors `ManualResumePdfController`'s temp-file-then-`open_file` approach and its `_generation` counter guard (the Phase 32 fix for Riverpod 3.4.3's non-`autoDispose` invalidation semantics) line for line, adapted to this feature's own types. No new PDF-handling package or technique was introduced — `open_file`/`path_provider` are both pre-existing dependencies.
- **A real bug was found and fixed while building the drafts list**: `createResumeDraftsControllerProvider` was initially declared without `retry: (retryCount, error) => null`. Without it, Riverpod silently retries a failed `build()` several times with exponential backoff before surfacing the real error — exactly the same class of bug `dashboardControllerProvider`/`resumeHistoryControllerProvider` already guard against, with the exact same fix applied here, discovered because a test for the failure path hung for 30 seconds until the cause was traced.

## 5. Files created or changed

**New (29 files, all Phase 39):**
- Domain: `create_resume_state.dart`, `create_resume_document.dart`, `create_resume_validation_error.dart`, `create_resume_draft_summary.dart`, `create_resume_outcomes.dart`, `create_resume_repository.dart`
- Data: `create_resume_response_parsing.dart`, `create_resume_preview_parser.dart`, `create_resume_pdf_parser.dart`, `create_resume_page_preview_parser.dart`, `create_resume_remote_datasource.dart`, `create_resume_repository_impl.dart`
- Presentation: `create_resume_builder_controller.dart`, `create_resume_preview_controller.dart`, `create_resume_pdf_controller.dart`, `create_resume_drafts_controller.dart`, `create_resume_personal_step.dart`, `create_resume_summary_step.dart`, `create_resume_skills_step.dart`, `create_resume_experience_step.dart`, `create_resume_education_step.dart`, `create_resume_document_view.dart`, `create_resume_builder_screen.dart`, `create_resume_preview_screen.dart`, `create_resume_drafts_screen.dart`
- Tests: `create_resume_state_test.dart`, `create_resume_preview_parser_test.dart`, `create_resume_pdf_parser_test.dart`, `create_resume_builder_controller_test.dart`, `create_resume_drafts_controller_test.dart`, `create_resume_pdf_controller_test.dart`

**Modified:**
- `lib/core/network/api_endpoints.dart` — 7 new endpoint constants.
- `lib/app/router/route_paths.dart` — 3 new routes (`createResumeBuilder`/`createResumePreview` added to `universalRoutes`; `createResumeDrafts` left protected by omission, matching the real auth contract).
- `lib/app/router/app_router.dart` — 3 new `GoRoute` registrations.
- `lib/features/resume/presentation/providers/resume_providers.dart` — 4 new provider declarations.
- `lib/features/home/presentation/screens/home_screen.dart` — "Create Resume" CTA rewired to the new feature directly; the now-dead Phase 34 choice-sheet code removed.
- `test/features/home/presentation/screens/home_screen_test.dart` — the 6 choice-sheet tests replaced with 2 direct-navigation tests.
- `test/app/router/route_guards_test.dart` — 2 new test groups confirming the new routes' auth posture.

**No file in either Django reference directory was read for writing, let alone modified.**

## 6. Backend endpoints and payload contracts reused

Exactly the 7 routes in §2, with payload/response shapes read directly from source (snake_case field names — `start_year`, `start_month`, etc. — matching `normalize()`'s own `raw.get(...)` calls precisely, the same convention already established for the Manual Resume Builder's own endpoints). No endpoint was invented; no field name or response shape was guessed. Sensitive values (none exist in this contract beyond the user's own resume content, which this report does not reproduce) are not included here.

## 7. Validation, save/draft, preview/PDF, and deletion behavior implemented

- **Validation**: server-driven only (see §4) — errors display inline per field, matching `{field, section, message}` to the corresponding form control.
- **Save/draft**: explicit "Save" button; creates on first save, updates thereafter (the returned draft id is remembered); a failed save shows the real server message (including the specific "you can keep up to 20 resumes" case) without discarding the form; a successful save shows a brief confirmation banner.
- **Preview**: full structured document rendering (`CreateResumeDocumentView`, mirroring `build_document()`'s own `text`/`lines`/`entries`/`items` section kinds), with any outstanding validation errors shown as a clear "still missing for a downloadable PDF" banner above the preview — honest, not blocking.
- **PDF**: generated server-side, saved to a temp file, opened via the device's own PDF viewer (`open_file`) — the real, verified contract, not a client-side substitute.
- **Deletion**: confirmation dialog naming the specific resume before deleting; a failed delete shows an error and leaves the list untouched (never an optimistic "removed" state that silently reverts).

## 8. Automated test results

```
flutter test test/features/resume/domain/entities/create_resume_state_test.dart          → 9/9 passing
flutter test test/features/resume/data/create_resume_preview_parser_test.dart            → 4/4 passing
flutter test test/features/resume/data/create_resume_pdf_parser_test.dart                → 6/6 passing
flutter test test/features/resume/presentation/controllers/create_resume_builder_controller_test.dart → 14/14 passing
flutter test test/features/resume/presentation/controllers/create_resume_drafts_controller_test.dart  → 5/5 passing
flutter test test/features/resume/presentation/controllers/create_resume_pdf_controller_test.dart     → 8/8 passing
flutter test test/app/router/route_guards_test.dart                                      → 35/35 passing
flutter test test/features/home/                                                          → 26/26 passing
flutter test                                                                               → 2351 passing, 0 failing
```

Coverage against the task's own test list: items 1 (navigation), 2/3 (required-field validation surfacing), 3 (add/edit/remove/reorder — reorder is not a supported web operation, confirmed, so not implemented or tested), 4 (create/save with mocked backend), 5 (load/continue a draft), 6 (update an existing resume), 7 (preview rendering with fixtures), 8 (PDF at the file-write/open boundary, via the same fake-platform technique already established for the Manual Resume Builder), 9 (deletion confirmation + success/failure), 11 (network/server failures + retry) are all directly covered by the tests above. Item 10 (auth/ownership/permission failures) is covered structurally by the route-guard tests (§ "Create Resume routes" group) plus the existing, unmodified global 401→`UnauthorizedFailure` interceptor this app already relies on everywhere else — not re-tested with a bespoke mock for this feature specifically, consistent with how every other authenticated feature in this app already handles it. Item 12 (empty/loading/success/error states) is covered by the drafts controller tests' `AsyncData`/`AsyncError`/loading coverage.

## 9. Analyzer/build results and baseline comparison

```
flutter analyze  → 8 issues (the 7 pre-existing warnings, unchanged, plus 1 new warning of the exact same
                   pre-existing style/class — an unused optional constructor parameter on a test fake that
                   mirrors the identical, already-accepted pattern in 5 other Manual Resume Builder test files)
flutter test     → 2351 passing, 0 failing
```

Baseline comparison: Phase 38 reported 2307 passing / 0 failing / 7 warnings. This phase's net change (+44 tests) breaks down as: +48 new Create Resume / route-guard tests, −4 from consolidating 6 now-obsolete Phase-34 choice-sheet tests (testing behavior that no longer exists) into 2 correct direct-navigation tests. The analyzer count moved from 7 to 8 for the reason stated above — not a new category of issue, and explained rather than hidden.

A full `flutter build apk --debug` was run successfully this phase (as part of device-verification preparation, see §9 below) — the app compiles and packages correctly with every new file included.

## 10. Device verification results

**Not performed**, and not claimed as performed.

- The physical Android device (`RMX5004`) used throughout Phases 35-38 was disconnected at the start of this phase and did not reconnect (`adb devices` and a fresh `adb kill-server`/`start-server` cycle both confirmed no device attached).
- An Android emulator (`Pixel_9a`, API 37) was launched as a substitute and successfully booted (`flutter devices` showed it as `emulator-5554`).
- `flutter build apk --debug` succeeded, producing a working APK.
- Installing it failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE` — the emulator's `/data` partition was at 92% capacity with ~520MB free against a 180MB debug APK's real install footprint. A safe, non-destructive remedy (`adb shell pm trim-caches 2G`, which only clears app cache directories, never user data) was attempted and freed only ~10MB — nowhere near enough.
- Per this engagement's own standing caution (never wipe an emulator without asking first), no destructive remedy (factory-resetting the AVD, deleting and recreating it) was attempted without explicit approval.
- **What this means concretely**: the implementation above is verified by source-code review (the backend contract) and by a comprehensive automated test suite (48 new tests across parsers, controllers, and routing), but the actual on-screen rendering, real network round-trip to `https://careerbuddy4u.com`, and real PDF-open behavior on a live device were not observed this phase.

## 11. Remaining gaps, blocked features, and unverified behavior

- **Not implemented (documented, not silently dropped)**: Projects, Certifications, Achievements, Internships & Volunteering, Languages, and Additional Information sections — all real, existing capabilities of the web's Create Resume builder, each with its own field set and validation rules in `create_resume.py`, scoped out of this phase to deliver a smaller, genuinely complete and well-tested vertical slice rather than a larger, shallower, unverified one. Submitting without them produces a valid, honestly partial resume (confirmed via source: `build_document()` omits any section with no entries).
- **Not implemented**: the page-image preview (`pages_api`) — the structured document preview already shows the same content faithfully; the page-image variant was judged lower priority within this phase's time budget.
- **Not implemented**: reordering repeatable entries. Checked directly against the web source: `create_resume.py`'s own `order` field only supports `'auto'` (sort by date) or `'manual'` (preserve submitted order) — there is no reorder *action* in the backend contract itself for this app to reproduce; entries are submitted in the order they were added, matching `'auto'` behavior by omission.
- **Not verified live on any device or emulator this phase** — see §10. The next concrete step, once a device or working emulator is available, is exactly what was planned here: open the Create Resume builder as a guest (no login needed), fill in the 5 implemented sections, preview, and generate a PDF — all without touching any production account, since none of those three steps require authentication on the real backend.
- **Not verified**: the "My Resumes" (drafts) flow end-to-end against the live backend, since it requires an authorized account this session does not have credentials for, consistent with this phase's own rule against inventing one.

## Completion

Per this phase's own scope boundary: stopping here. Awaiting explicit approval before Phase 40 or any further change.
