# Phase 25 — Manual Resume Builder Foundation and Local Draft Persistence

## Scope delivered

The draft data model, local persistence with account isolation, a five-step
wizard state model, and the minimum screen needed to exercise and test all
of this. The complete per-step form, server-rendered preview, page previews,
and PDF generation are **not** implemented — see "Deferred to Phase 26"
below.

## Files changed

**New (domain)**
- `lib/features/resume/domain/entities/manual_resume_draft.dart` — the
  draft model, verified field-for-field against `career_app/resume_document.py`'s
  `normalize_state()` (Phase 24 audit): `role`, `roleDef`, `level`,
  `personal.*`, `targetTitle`, `domain`, `years`, `skills.*`,
  `employment[]`/`internships[]` (shared job-entry shape), `projects[]`,
  `education[]`, `certifications[]` (`issuer`), `training[]` (`provider`),
  `achievements`/`languages`/`additional`/`summary`, `declaration`, `place`,
  `declDate`, plus the local-only `currentStep` (1–5). No field was invented
  and none was silently dropped. Contains no credentials, tokens, or
  unrelated account data — only the form fields the real builder itself
  collects.
- `lib/features/resume/domain/repositories/manual_resume_draft_repository.dart`
  — `loadDraft`/`saveDraft`/`clearDraft`, each keyed by `username`.

**New (data)**
- `lib/features/resume/data/manual_resume_draft_local_datasource.dart` —
  `SecureStorageService`-backed persistence (the same encrypted-at-rest
  mechanism already used for the cached auth session and Mock Test history),
  keyed per account as `manual_resume_draft.v1.<username>`. Corrupt data, a
  non-object JSON value, or a mismatched schema version are all treated as
  "no draft" rather than thrown.
- `lib/features/resume/data/manual_resume_draft_repository_impl.dart` — maps
  a genuine storage exception to `Failed(UnexpectedFailure)`; everything
  else passes through as `Success`.

**New (presentation)**
- `lib/features/resume/presentation/controllers/manual_resume_builder_controller.dart`
  — `ManualResumeBuilderController` (`Notifier`), sealed
  `ManualResumeBuilderLoading`/`LoadFailed`/`Ready` states. `load()`,
  `goToStep`/`nextStep`/`previousStep` (clamped 1–5), `setRoleIfBlank`
  (fills the role only when the restored draft doesn't already have one —
  never overwrites an in-progress draft for a different role),
  `clearDraft()`.
- `lib/features/resume/presentation/screens/manual_resume_builder_screen.dart`
  — step indicator (Personal/Career & Skills/Experience/Education/Summary),
  a placeholder per step, Next/Previous bounded at the ends, a selected-role
  chip on the Career & Skills step, and a "Clear Draft" action with a
  confirmation dialog.

**Modified**
- `lib/features/resume/presentation/providers/resume_providers.dart` — new
  providers wired the same way as every other provider in this file
  (`manualResumeDraftLocalDataSourceProvider`, `manualResumeDraftRepositoryProvider`,
  `manualResumeBuilderControllerProvider`), reusing the existing
  `secureStorageProvider`.
- `lib/features/auth/presentation/controllers/auth_controller.dart` — added
  `ref.invalidate(manualResumeBuilderControllerProvider)` to
  `_invalidateUserScopedProviders()` (see "Account isolation" below).
- `lib/app/router/route_paths.dart` — new `manualResumeBuilder` route
  constant, deliberately **not** added to `publicRoutes`/`universalRoutes`
  (Decision 1: authenticated users only).
- `lib/app/router/app_router.dart` — registers the route, passing the
  tapped `ResumeRole` (if any) through as `extra`.
- `lib/features/resume/presentation/screens/role_picker_screen.dart` — the
  Role Picker's "Build Resume" tile is now enabled (was "Coming soon");
  tapping it closes the action sheet and navigates straight into the Manual
  Resume Builder with that role. "Skills" remains honestly disabled.
  "Resume Parsing & Interview" is completely unchanged.

No Django file in either reference tree was touched, and no new backend
endpoint was added or assumed — the draft never leaves the device.

## Draft model and persistence design

- **Why `SecureStorageService` and not a new package**: it's already the
  mechanism this codebase uses for sensitive per-device data (the cached
  auth session, Mock Test attempt history), so a resume draft — which can
  contain a name, phone number, email, and employment history — gets the
  same protection without adding a dependency.
- **Why `username`, not an invented ID**: `AuthUser` carries no numeric ID.
  Direct reads of the Django source (`users/forms.py`, `users/views.py`)
  confirmed `username` is the real unique account identifier, set only at
  registration and never exposed as an editable field on the profile-edit
  form, nor reassigned anywhere in the backend — so it's a stable,
  non-guessable key, not a display name standing in for identity.
- **Why one draft per account**: matches the real web's own one-draft model
  (Phase 24 confirmed the real `manual_resume_*` endpoints persist nothing
  server-side at all — this is a 100% local, client-only concept on both
  platforms).

## Account isolation and logout behavior

Two independent layers, matching the task's explicit requirement that one
account must never see another's draft, either mid-session or after a
restart:

1. **At rest**: every stored draft is namespaced by `username.` (e.g.
   `manual_resume_draft.v1.alice` vs. `manual_resume_draft.v1.bob`) — two
   accounts structurally never share a key, verified directly in
   `manual_resume_draft_local_datasource_test.dart`.
2. **In memory, within the same app process**: `manualResumeBuilderControllerProvider`
   was added to `AuthController._invalidateUserScopedProviders()`, the
   existing, previously-confirmed mechanism that already prevents a
   previous account's Dashboard/Resume Analysis state from surviving a
   login as someone else in the same process. Covered by a new test in
   `auth_controller_test.dart` mirroring the existing Resume Builder case.

A session expiring (an `UnauthorizedFailure` from `load()`) never deletes
anything — `clearDraft()` is called **only** from the screen's own
explicit, user-confirmed "Clear Draft" action. The two concerns (temporary
auth loss vs. a candidate's own in-progress work) are kept deliberately
separate, per the task's own instruction not to conflate them.

## Tests executed (actual results)

- `flutter analyze` — whole project: **No issues found.**
- `flutter test test/features/resume/ test/features/auth/` — **223 passed,
  0 failed.**
- `flutter test` (full suite) — **2054 passed, 0 failed** (up from 2008
  before this phase; no existing test was weakened or removed).

New test files:
- `test/features/resume/domain/entities/manual_resume_draft_test.dart` (9
  tests) — blank defaults, round-trip, certifications/training field-name
  distinction, defensive parsing of wrong types and non-map list entries,
  `currentStep` clamping in both `fromJson` and `copyWith`.
- `test/features/resume/data/manual_resume_draft_local_datasource_test.dart`
  (10 tests) — save/load/overwrite/clear, account isolation (two accounts
  never see each other's draft, clearing one never touches the other),
  corrupt data/wrong schema version/non-object JSON all read back as "no
  draft."
- `test/features/resume/data/manual_resume_draft_repository_impl_test.dart`
  (6 tests) — happy-path round-trip through the repository, and a genuine
  storage exception mapped to `Failed(UnexpectedFailure)` for all three
  operations.
- `test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart`
  (12 tests) — initial loading state, blank draft on first load, restoring
  a saved draft, a load failure surfacing as `LoadFailed` not a crash, an
  unauthenticated caller failing with `UnauthorizedFailure` rather than
  guessing a key, step bounds in both directions, `setRoleIfBlank` filling
  a blank draft but never overwriting an existing role, and `clearDraft`.
- `test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart`
  (7 tests) — blank-draft restore, Next/Previous navigation, role
  preservation across restore, a restored draft's own role never being
  overwritten by a newly-tapped one, a load failure's retryable error
  state, the Clear Draft confirmation dialog (cancel vs. confirm), and no
  horizontal overflow at 320/360/390px widths.
- Updated `test/features/auth/auth_controller_test.dart` — added the
  logout-invalidation test described above (12 tests in the file now, up
  from 11; none of the existing 11 were changed).
- Updated `test/features/resume/presentation/screens/role_picker_screen_test.dart`
  — the existing "Skills/Build Resume honestly disabled" test was updated
  to match the new, intended behavior (Skills alone is disabled now); a new
  test confirms tapping "Build Resume" closes the sheet and opens the
  Manual Resume Builder with the exact role tapped. All other existing
  tests in this file (search, category filter, Resume Parsing & Interview
  confirm/cancel/error flows, narrow-width rendering) are unchanged and
  still pass.

### A real bug found and fixed during testing

The first widget-test run of the new screen hung. Root cause, confirmed via
a disposable diagnostic test (since removed): `flutter test`'s fake-clock
binding never fires a real `Timer` on its own, and `Future.delayed(Duration.zero)`
is a real `Timer` even at zero duration — so a naive "settle `AuthController`'s
async restore before pumping" helper deadlocked forever instead of just
being slow. Fixed by using `tester.runAsync()` (the documented escape hatch
for genuine async work inside a widget test) and switching to bounded
`tester.pump()` calls instead of `pumpAndSettle()`, matching this codebase's
existing convention in `profile_screen_test.dart`.

Once that was fixed, a second, independent, real bug surfaced immediately:
`_StepIndicator`'s `Row` overflowed by 134px at a normal 400px-wide phone —
the step labels ("Career & Skills", etc.) had no width constraint. Fixed by
giving each step dot an `Expanded` slot and letting its label wrap/ellipsize
instead of forcing single-line natural width. Both are genuine fixes to
code written in this phase, not out-of-scope cleanup.

## Static analysis results

`flutter analyze` (whole project): **No issues found.**

## Limitations and work deferred to Phase 26

Per the task's own explicit boundary, none of the following were built —
the screen is a navigable shell proving the model/persistence/wizard-state
foundation, not a usable form yet:
- The actual per-step form fields (Personal details, Career & Skills
  selection, repeatable Experience/Education/Certification/Training
  entries, Summary/Declaration).
- The server-rendered preview call (`manual_resume_preview_api`).
- Page-by-page preview (`manual_resume_preview_pages_api`).
- PDF generation/download (`manual_resume_pdf_download`).

Building real form UI for this many fields would have gone well beyond "the
minimum reliable foundation" this phase asked for, so it is left for Phase
26 as instructed.

## Emulator/device testing disclosure

**Not performed.** As found and disclosed in Phase 24, this environment has
no Android emulator or connected device (`flutter devices` lists only
macOS/Chrome; no `adb`). All verification in this phase is `flutter
analyze` and `flutter test` (unit + widget tests using Flutter's test
binding), not an on-device run. No claim of on-device testing is made.

## Reference trees — untouched

- `royalStaffing_CB01/` is not a git repository, so no diff can be shown;
  it was only read from (`grep`/`Read`) to verify `resume_document.py`'s
  field shapes and `resume_roles.py`'s `role`→`slug` mapping — never
  written to.
- `Career_Buddy_LMS/` (git): `git status --short` shows pre-existing
  modifications (`activities/urls.py`, `activities/views.py`,
  `business_english_lms/urls.py`) and pre-existing untracked files
  (`activities/tests_activities_api.py`, `activities/tests_dashboard_api.py`).
  **None of these were touched by this phase** — this phase never ran any
  command inside `Career_Buddy_LMS/`. They are the user's own pre-existing,
  uncommitted work from outside this phase's scope, left exactly as found.

## Git status (Mobile_app)

```
 M lib/app/router/app_router.dart
 M lib/app/router/route_paths.dart
 M lib/features/auth/presentation/controllers/auth_controller.dart
 M lib/features/resume/presentation/providers/resume_providers.dart
 M lib/features/resume/presentation/screens/role_picker_screen.dart
 M test/features/auth/auth_controller_test.dart
 M test/features/resume/presentation/screens/role_picker_screen_test.dart
?? docs/PHASE_24_MANUAL_RESUME_BUILDER_AUDIT.md   (pre-existing, from Phase 24)
?? lib/features/resume/data/manual_resume_draft_local_datasource.dart
?? lib/features/resume/data/manual_resume_draft_repository_impl.dart
?? lib/features/resume/domain/entities/manual_resume_draft.dart
?? lib/features/resume/domain/repositories/manual_resume_draft_repository.dart
?? lib/features/resume/presentation/controllers/manual_resume_builder_controller.dart
?? lib/features/resume/presentation/screens/manual_resume_builder_screen.dart
?? test/features/resume/data/manual_resume_draft_local_datasource_test.dart
?? test/features/resume/data/manual_resume_draft_repository_impl_test.dart
?? test/features/resume/domain/entities/manual_resume_draft_test.dart
?? test/features/resume/presentation/controllers/manual_resume_builder_controller_test.dart
?? test/features/resume/presentation/screens/manual_resume_builder_screen_test.dart
```

No pre-existing uncommitted work in `Mobile_app/` was lost or altered —
the tree was clean except for the untracked Phase 24 report before this
phase began, and that report is still present, untouched.

---

**Stopping here, as instructed.** No work on Phase 26 (the full form,
preview, or PDF generation) has been started. Awaiting explicit approval
before proceeding.
