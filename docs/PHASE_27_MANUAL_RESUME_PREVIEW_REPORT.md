# Phase 27 — Manual Resume Builder: Server Preview & Validation Feedback

## Scope delivered

The Manual Resume Builder now submits the current draft to the real
`preview_api` endpoint and shows the server's own assembled resume, with
server-side validation feedback wired into the existing Phase 26 step/
field error machinery. Page-image previews and PDF generation remain out
of scope, as instructed.

## 1. Mandatory inspection — what was actually confirmed

Read `docs/PHASE_24_MANUAL_RESUME_BUILDER_AUDIT.md`, `PHASE_25_MANUAL_RESUME_FOUNDATION_REPORT.md`,
`PHASE_26_MANUAL_RESUME_FORM_REPORT.md`, and the current `ManualResumeDraft`,
`ManualResumeBuilderController`, `ManualResumeBuilderScreen`, the five step
widgets, `ResumeRepository`/`ResumeRemoteDataSource`, and the existing
CSRF-priming pattern (`_ensureCsrfCookie()` + `readCookie('csrftoken')` +
`X-CSRFToken` header) already used by `uploadAndAnalyze`/`reanalyze`.

Then re-verified the updated Django source directly rather than trusting
the prior audit at face value, specifically because the task explicitly
warned not to assume it was complete:

- **URL and method**: `/resume-builder/manual/preview/`
  (`business_english_lms/urls.py:93-96`, `name='manual_resume_preview'`),
  `@require_POST` only — confirmed unchanged from Phase 24's finding.
- **Auth**: no `@login_required` on the real endpoint (confirmed again,
  directly) — this Flutter feature still restricts it to authenticated
  users only, by the same deliberate Phase 25 product decision, not
  because the server requires it.
- **CSRF**: standard Django CSRF middleware, no `@csrf_exempt`. The real
  web's own `generate()` JS sends `X-CSRFToken` sourced from a hidden
  `{% csrf_token %}` form field — functionally the same double-submit
  token this app's existing `csrftoken`-cookie-based priming already
  produces, so the existing mechanism was reused as-is, not reinvented.
- **Request body**: `_read_state()`
  (`career_app/manual_resume_views.py:45-56`) reads raw `request.body` only
  when `request.content_type == 'application/json'`; otherwise it falls
  back to a `payload` form field (used only by the hidden Print/PDF form,
  irrelevant to this phase's JSON-only submission). **This confirmed a
  real correctness risk before any code was written**: `normalize_state()`
  reads **snake_case** keys (`target_title`, `role_def`, `decl_date`) —
  not [ManualResumeDraft.toJson]'s camelCase local-persistence schema.
  Sending `toJson()` directly would have silently dropped every one of
  those fields server-side. A dedicated mapping function was written
  specifically to avoid this (see "Files changed" below).
- **Response shapes**: confirmed byte-for-byte from source — success is
  `{ok:true, document, warnings, completeness, filename}`; every rejection
  branch (validation failure, rate limit, unreadable payload) is
  `{ok:false, errors:[{field,step,message}], completeness?}`, differing
  only in HTTP status (400/429/400) and whether `completeness` is present
  (only for a genuine validation failure).
- **Is `document` HTML?** — **No.** Confirmed directly: `document` is a
  plain nested JSON structure (`build_document()`'s return dict,
  `resume_document.py:543-662`); all HTML markup for this preview is
  generated entirely client-side by the real web's own JS function,
  `docHTML()` (`templates/landing.html:8950-8974`). No Django template or
  server-rendered HTML fragment for this preview exists anywhere in either
  reference tree — confirmed by an explicit search. This directly decided
  the rendering approach: Flutter renders the JSON natively (see §4).
- **Limits**: 200,000-byte payload cap and the shared 60-requests-per-
  10-minutes rate limit (confirmed unchanged from Phase 24) — this phase
  neither modifies nor attempts to bypass either; a limit hit is simply
  shown to the candidate as the server's own message.

## 2. Files changed

**New (domain)**
- `manual_resume_document.dart` — `ManualResumeDocument`, `ManualResumeContact`,
  and a sealed `ManualResumeSectionBody` (`TextBody`/`BulletsBody`/
  `JobsBody`/`ProjectsBody`/`SkillsBody`/`CompactBody`/`EducationBody`/
  `DeclarationSectionBody`/`UnknownBody`) mirroring `docHTML()`'s own
  per-`kind` switch exactly.
- `manual_resume_completeness.dart` — `ManualResumeCompletenessSummary`/`Category`.
- `manual_resume_preview_outcome.dart` — sealed `ManualResumePreviewOutcome`
  (`Ready`/`Rejected`), reusing Phase 26's own `ManualResumeValidationError`
  verbatim for server errors (identical shape to the client-side validator's
  own errors).

**Modified (domain) — extending, not replacing, Phase 23/26's work**
- `resume_repository.dart` — added `previewManualResume(ManualResumeDraft)`.

**New (data)**
- `manual_resume_preview_payload.dart` — `toManualResumePreviewPayload()`,
  the snake_case request mapping described above.
- `manual_resume_preview_parser.dart` — parses the response into
  `ManualResumePreviewOutcome`, `null` for anything unparseable (mapped to
  a real failure, never a fabricated success).

**Modified (data)**
- `resume_remote_datasource.dart` — added `previewManualResume()`, reusing
  the exact `_ensureCsrfCookie()`/`X-CSRFToken` pattern, sent as
  `Content-Type: application/json` (not the `multipart/form-data` every
  other POST here uses — confirmed this endpoint needs the different
  content-type).
- `resume_repository_impl.dart` — added the matching implementation.
- `api_endpoints.dart` — added `manualResumePreview`.

**New (presentation)**
- `manual_resume_preview_controller.dart` — a dedicated
  `ManualResumePreviewController` (deliberately separate from
  `ManualResumeBuilderController`, which still owns the draft and its
  local persistence — a preview failure can never put the autosave state
  machine at risk, and vice versa). States: `Idle`/`Loading`/`ReadyState`/
  `ValidationFailed`/`Failed`. `generate()` is a no-op while already
  loading (duplicate-submit prevention); a validation rejection
  immediately feeds its errors into the Builder controller (see below).
- `manual_resume_document_view.dart` — the native rendering of
  `ManualResumeDocument`, one branch per section `kind`.
- `manual_resume_preview_screen.dart` — loading/success/rejected/failed
  states, "Go to step" actions on each server error, a "Back to Builder"
  action, and a retryable error view for a transport failure.

**Modified (presentation)**
- `manual_resume_builder_controller.dart` — `ManualResumeBuilderReady`
  gained `serverErrors` (shown unconditionally, unlike client errors which
  need `touched`/`showAllErrors`) and `setServerErrors()`/`clearServerErrors()`;
  `visibleErrors` now unions client and server errors, client taking
  priority per field so the same field is never shown twice.
- `manual_resume_builder_screen.dart` — added a "Preview Resume" action
  that pushes the new route carrying the current draft as `extra`.
- `resume_providers.dart` — added `manualResumePreviewControllerProvider`.
- `auth_controller.dart` — added `manualResumePreviewControllerProvider` to
  `_invalidateUserScopedProviders()` (the preview echoes back the same
  candidate content as the draft, so it needs the same cross-account
  protection).
- `route_paths.dart`/`app_router.dart` — added `manualResumePreview`
  (not in `publicRoutes`/`universalRoutes`, same reasoning as
  `manualResumeBuilder`: the real endpoint has no login requirement, but
  this entry point is only ever reached from an already-authenticated
  builder session).
- `resume_role_parser.dart`/`resume_role.dart` — unaffected by this phase;
  listed here only because earlier phases' diffs remain in the same files
  (no new changes made to them this phase).

No Django file in either reference tree was touched, and no new backend
endpoint was added — the draft and the preview request both go to the
one, already-existing, already-audited endpoint.

## 3. Request/response mapping (confirmed from source, not assumed)

Request: `POST /resume-builder/manual/preview/`, `Content-Type:
application/json`, header `X-CSRFToken: <csrftoken cookie value>`, body =
`toManualResumePreviewPayload(draft)` — snake_case keys matching
`normalize_state()`'s own `raw.get(...)` calls exactly; `currentStep` is
never sent (confirmed the server has no such concept at all).

Response: parsed by `parseManualResumePreviewResponse()` purely from the
JSON body shape (`ok` key), not the HTTP status code — a 400 validation
failure, a 429 rate limit, and a 400 unreadable-payload response all share
the identical `{ok:false, errors:[...]}` envelope, so they're unified into
one `ManualResumePreviewRejected` outcome rather than three separate code
paths.

## 4. HTML rendering approach and security considerations

**No HTML is ever rendered or executed for this preview.** Since
`preview_api` returns pure structured JSON (confirmed directly, §1), the
only faithful and safe approach is to build the resume view natively in
Flutter, mirroring the real web's own `docHTML()` JS function's per-section
logic widget-for-widget (`ManualResumeDocumentView`, one branch per
`kind`). This sidesteps essentially the entire "HTML security
requirements" checklist by construction:

- No script execution risk — there is no HTML/JS to execute; every
  rendered element is this app's own typed Flutter widget built from plain
  strings and lists the parser already validated.
- No WebView, so no session-cookie/credential-exposure risk to weigh —
  `webview_flutter` (already a project dependency, used for Skill Up
  lesson pages) was deliberately **not** used here, since there is no
  remote page to load.
- Contact links (`tel:`/`mailto:`/`https:` hrefs the server returns) open
  only via `url_launcher`'s `LaunchMode.externalApplication` — the same
  pattern this codebase already uses on `resume_builder_screen.dart` —
  meaning a malformed or unexpected `href` can at worst hand a URI to the
  OS's own app chooser/browser, never execute anything inside this app or
  carry this app's own session state to an external origin.
- No new dependency was added. `url_launcher` already existed in
  `pubspec.yaml` for exactly this kind of external link.

## 5. Server validation mapping and error behavior

`ManualResumeValidationError` (Phase 26's own client-side validator type)
is reused verbatim for server errors — the server's own `{field, step,
message}` shape is identical, so no new error type was needed. The moment
`ManualResumePreviewController.generate()` receives a
`ManualResumePreviewRejected`, it immediately calls
`ManualResumeBuilderController.setServerErrors()`, which makes every
server error visible and jumps the draft to the first error's own step —
so returning from the preview screen **by any means** (a specific "fix
this" tap, the plain back button, or "Back to Builder") already shows the
right step with the right fields flagged, not only when a specific action
is taken. A general error (`field: ''`, e.g. the rate-limit message) is
still shown — on the preview screen itself as a plain list item, and on
the Builder it simply has no specific field to attach to. A success
clears any stale server errors. The local draft is never read from or
written to by any part of this flow except to build the outgoing request
— every field and repeatable entry is exactly as the candidate left it,
confirmed by a dedicated round-trip test ("Back to Builder" pops without
clearing the draft).

Client-side validation (Phase 26) is completely unchanged and still runs;
nothing in this phase describes it as a guarantee of server acceptance —
the whole point of this phase is that the server's own answer is what's
shown.

## 6. Tests executed and actual results

- `flutter analyze` (whole project): **No issues found**, except four
  harmless `unused_element_parameter` info-level warnings on fake-repository
  constructor parameters not exercised by every test in that file (the
  same style already present from Phase 26) — not an error, not a behavior
  concern.
- Focused resume feature tests + auth/client-flow regression
  (`test/features/resume/ test/features/auth/ test/app/client_flow_test.dart`):
  **320 passed, 0 failed.**
- Full `flutter test`: **2189 passed, 0 failed** (up from 2147 before this
  phase; no existing test was weakened, skipped, or deleted).

New test files (≈44 new tests):
- `manual_resume_preview_payload_test.dart` (9) — exact snake_case request
  mapping for every field, confirming `currentStep` is never sent and the
  `current`/no-`current` distinction between employment/internships vs.
  projects.
- `manual_resume_preview_parser_test.dart` (10) — a full success response
  parsed into every section `kind` correctly, an unrecognised `kind`
  degrading safely, validation/rate-limit/unreadable-payload rejections,
  and every malformed-response case (non-map body, missing/non-bool `ok`,
  `ok:true` with no document, `ok:false` with no errors, an empty-but-valid
  document).
- `manual_resume_preview_datasource_test.dart` (7) — the real CSRF-priming
  GET-then-POST sequence, the exact JSON payload sent over the wire, 200/
  400/429 responses parsed correctly, a malformed body throwing (never a
  fabricated success), and a genuine connection failure mapping to an
  `AppException`.
- `manual_resume_preview_controller_test.dart` (9) — idle → loading →
  ready/rejected/failed transitions, duplicate-submit prevention, retry,
  and the two-way Builder-controller integration (a rejection populates
  `serverErrors` and jumps to the right step; a success clears stale
  ones).
- `manual_resume_preview_screen_test.dart` (8) — a genuine loading state
  (held open via a `Completer`, not a timing guess), the real document
  rendering on success, server errors with a working "go to step" action,
  a confirmed round-trip back to the builder with the draft intact, a
  retryable transport-failure view, and an empty-document response
  rendering without crashing.
- Updated `manual_resume_builder_screen_test.dart` — added a test
  confirming "Preview Resume" navigates to the new route carrying the
  exact current draft as `extra`.
- Updated `manual_resume_builder_controller_test.dart`,
  `auth_controller_test.dart`, `role_picker_screen_test.dart`,
  `resume_builder_controller_test.dart`, `resume_builder_screen_test.dart`,
  `resume_history_screen_test.dart`, `client_flow_test.dart` — each gained
  the new `previewManualResume()` method on their local `ResumeRepository`
  fakes (an interface addition every implementer must satisfy); no
  existing test logic in any of them changed.
- Regression coverage (all still passing, unchanged behavior): Phase 19's
  resume-analysis quota counter, Phase 23's Role-Fit Picker and Resume
  Parsing & Interview flow, and Phase 26's full five-step form,
  validation, debounced autosave, and narrow-width rendering.

### Two real bugs found and fixed during testing (not just added)

1. A test helper (`GetPrimesCsrfAdapter`'s generic usage) didn't set a
   `content-type: application/json` response header, so Dio's default
   transformer returned the raw string instead of a decoded `Map` —
   every datasource test initially failed with "Unexpected response from
   server" even on a genuinely valid success body. Fixed with a local
   adapter variant (matching this codebase's own established per-file
   adapter convention) that sets the header; not a product bug, but worth
   recording since it could otherwise have masked a real parsing problem.
2. Two of my own test fixtures used an unsafe `Map` spread
   (`{...someMap as Map, ...}`) that produced a type Dio's parser
   legitimately rejected — a test-authoring mistake, not a parser bug;
   fixed by writing the fixture as an explicit `Map<String, dynamic>`
   literal.

## 7. Emulator/device testing status

**Not performed.** As found and disclosed in Phases 24–26, this
environment has no Android emulator or connected device (`flutter
devices` lists only macOS/Chrome; no `adb`). All verification in this
phase is `flutter analyze` and `flutter test` (unit + widget tests using
Flutter's test binding and a fake HTTP adapter exercising the real Dio
pipeline), never a real network call to production or any other server.
No claim of on-device or production testing is made.

## 8. Remaining differences from web behavior / unverified assumptions

- **Email-validation parity** and **Unicode name-matching approximation**
  — both already disclosed in Phase 26's report and unchanged by this
  phase (this phase added no new validation rules, only a server-response
  display path for the existing ones).
- **The completeness/progress meter** — shown only as a one-line "Overall
  completeness: N%" summary, not the real web's full per-category meter
  with jump-to-category buttons, consistent with Phase 26's own
  deliberate scope decision.
- **The exact visual fidelity of the rendered resume** (fonts, spacing,
  page-break behavior) is **not** pixel-matched to `docHTML()`'s CSS —
  intentionally, per the task's own "use the existing application's
  design system" instruction. The **content and structure** (every
  section, in the server's own order, every field the server returned)
  is faithful; the visual presentation is this app's own design language.
- **CSRF token value** was never independently confirmed to round-trip
  correctly against a real Django server in this phase (no server
  available to test against) — the mechanism itself is identical to the
  one already proven working for `uploadAndAnalyze`/`reanalyze` in earlier
  phases, so this is treated as a reasonable extension of already-verified
  behavior, not a fresh, independently-confirmed fact for this specific
  endpoint.

## 9. Django trees — untouched

- `royalStaffing_CB01/` is not a git repository; confirmed via file
  modification timestamps (`stat`) on every source file read this phase
  (`manual_resume_views.py`, `resume_document.py`, `business_english_lms/urls.py`,
  `templates/landing.html`) — all show timestamps that predate this
  session's work, unchanged by today's reads.
- `Career_Buddy_LMS/` (git): `git status --short` shows the same
  pre-existing modifications already disclosed in the Phase 25/26 reports
  (`activities/urls.py`, `activities/views.py`, `business_english_lms/urls.py`)
  and pre-existing untracked files, plus one additional untracked file
  (`activities/tests_mcq_exercise_api.py`) that appeared sometime after
  Phase 26 — **none of these were touched by this phase**, which never
  ran any command inside `Career_Buddy_LMS/` at all. All are the user's
  own pre-existing, uncommitted work from outside this phase's scope,
  left exactly as found.

## Page-image preview and PDF generation — confirmed out of scope

Neither was implemented, referenced as a dependency, nor stubbed. The only
endpoints this phase calls are `manual_resume_preview` (new this phase)
and the ones Phase 23/25/26 already called (`manual_resume_roles`); `
manual_resume_pdf`/`manual_resume_pages` were read during inspection
(§1) but never invoked from any Flutter code added this phase.

## Git status (Mobile_app)

```
 M lib/app/router/app_router.dart
 M lib/app/router/route_paths.dart
 M lib/core/network/api_endpoints.dart
 M lib/features/auth/presentation/controllers/auth_controller.dart
 M lib/features/resume/data/resume_remote_datasource.dart
 M lib/features/resume/data/resume_repository_impl.dart
 M lib/features/resume/data/resume_role_parser.dart
 M lib/features/resume/domain/entities/resume_role.dart
 M lib/features/resume/domain/repositories/resume_repository.dart
 M lib/features/resume/presentation/providers/resume_providers.dart
 M lib/features/resume/presentation/screens/role_picker_screen.dart
 M test/app/client_flow_test.dart
 M test/features/auth/auth_controller_test.dart
 M test/features/resume/presentation/controllers/resume_builder_controller_test.dart
 M test/features/resume/presentation/screens/resume_builder_screen_test.dart
 M test/features/resume/presentation/screens/resume_history_screen_test.dart
 M test/features/resume/presentation/screens/role_picker_screen_test.dart
?? docs/PHASE_24_MANUAL_RESUME_BUILDER_AUDIT.md          (pre-existing, Phase 24)
?? docs/PHASE_25_MANUAL_RESUME_FOUNDATION_REPORT.md      (pre-existing, Phase 25)
?? docs/PHASE_26_MANUAL_RESUME_FORM_REPORT.md            (pre-existing, Phase 26)
?? lib/features/resume/data/manual_resume_draft_local_datasource.dart       (Phase 25)
?? lib/features/resume/data/manual_resume_draft_repository_impl.dart        (Phase 25)
?? lib/features/resume/data/manual_resume_preview_parser.dart              (new, Phase 27)
?? lib/features/resume/data/manual_resume_preview_payload.dart             (new, Phase 27)
?? lib/features/resume/domain/entities/level_common_suggestions.dart       (Phase 26)
?? lib/features/resume/domain/entities/manual_resume_completeness.dart     (new, Phase 27)
?? lib/features/resume/domain/entities/manual_resume_document.dart         (new, Phase 27)
?? lib/features/resume/domain/entities/manual_resume_draft.dart            (Phase 25)
?? lib/features/resume/domain/entities/manual_resume_preview_outcome.dart  (new, Phase 27)
?? lib/features/resume/domain/repositories/manual_resume_draft_repository.dart (Phase 25)
?? lib/features/resume/domain/validation/                                  (Phase 26)
?? lib/features/resume/presentation/controllers/manual_resume_builder_controller.dart (Phase 25/26, extended Phase 27)
?? lib/features/resume/presentation/controllers/manual_resume_preview_controller.dart  (new, Phase 27)
?? lib/features/resume/presentation/screens/manual_resume_builder_screen.dart (Phase 25/26, extended Phase 27)
?? lib/features/resume/presentation/screens/manual_resume_preview_screen.dart (new, Phase 27)
?? lib/features/resume/presentation/widgets/manual_resume_career_step.dart (Phase 26)
?? lib/features/resume/presentation/widgets/manual_resume_document_view.dart (new, Phase 27)
?? lib/features/resume/presentation/widgets/manual_resume_education_step.dart (Phase 26)
?? lib/features/resume/presentation/widgets/manual_resume_experience_step.dart (Phase 26)
?? lib/features/resume/presentation/widgets/manual_resume_form_widgets.dart (Phase 26)
?? lib/features/resume/presentation/widgets/manual_resume_personal_step.dart (Phase 26)
?? lib/features/resume/presentation/widgets/manual_resume_summary_step.dart (Phase 26)
?? test/features/resume/data/manual_resume_draft_local_datasource_test.dart (Phase 25)
?? test/features/resume/data/manual_resume_draft_repository_impl_test.dart  (Phase 25)
?? test/features/resume/data/manual_resume_preview_datasource_test.dart    (new, Phase 27)
?? test/features/resume/data/manual_resume_preview_parser_test.dart        (new, Phase 27)
?? test/features/resume/data/manual_resume_preview_payload_test.dart       (new, Phase 27)
?? test/features/resume/domain/                                           (Phase 26)
?? test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart (Phase 25/26, extended Phase 27)
?? test/features/resume/presentation/controllers/manual_resume_preview_controller_test.dart  (new, Phase 27)
?? test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart (Phase 25/26, extended Phase 27)
?? test/features/resume/presentation/screens/manual_resume_preview_screen_test.dart (new, Phase 27)
```

No pre-existing uncommitted work in `Mobile_app/` was lost or altered —
the only pre-existing items in the tree (the Phase 24/25/26 docs) remain
exactly as they were.

---

**Stopping here, as instructed.** No work on Phase 28, page-image
previews, or PDF generation has been started. Awaiting explicit approval
before proceeding.
