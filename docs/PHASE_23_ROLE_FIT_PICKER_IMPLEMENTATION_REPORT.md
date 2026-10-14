# Phase 23 — Role-Fit Picker Implementation Report

**Scope:** implements Phase 22's recommended "Option B" role-fit picker —
only "Resume Parsing & Interview" is functional; "Skills"/"Build Resume"
are honestly disabled. No Django file was modified in either tree. No
manual resume builder, Skills feature, or full 295-role catalog work was
done.

## 1. Summary

Added an optional "Choose Target Role" entry point to the Resume Builder
upload form. Tapping it opens a dedicated, searchable/filterable picker
screen backed by the real `manual_resume_roles` JSON endpoint (no
hardcoded catalog). Picking a role opens a 3-action sheet mirroring the
real web's `roleAct` modal; only "Resume Parsing & Interview" is wired —
it sends the role to the server via the existing `resumeBuilderHome`
endpoint's `role`/`dept`/`track` query parameters (the same mechanism the
real landing page's role cards use), **verifies the server actually
echoed the selection back** before treating it as saved, and only then
returns the user to the upload form with a "Target role: X · Y" badge.
The existing upload/analyze flow, Phase 19's quota counter, and Phase 21's
home hero are all unmodified and fully covered by their own passing tests.

## 2. Files changed and created

**New:**
- `lib/features/resume/domain/entities/resume_role.dart` — `ResumeRole`
  entity, including a `track` getter mapping the role's `category` to the
  query-parameter value (verified distinct, see §3).
- `lib/features/resume/data/resume_role_parser.dart` — defensive JSON
  parsing for `manual_resume_roles`'s response.
- `lib/features/resume/presentation/controllers/role_picker_controller.dart`
  — `RolePickerController`/`RolePickerState` (loading/loaded/failed +
  search/category filtering).
- `lib/features/resume/presentation/screens/role_picker_screen.dart` —
  the picker screen plus the 3-action bottom sheet.
- `test/features/resume/presentation/screens/role_picker_screen_test.dart`
  (new, 11 tests).

**Modified:**
- `lib/core/network/api_endpoints.dart` — added `manualResumeRoles`.
- `lib/app/router/route_paths.dart` / `app_router.dart` — added
  `resumeRolePicker` (a mobile-only route; the real web has no separate
  page for this, only a modal — see the route's own doc comment).
- `lib/features/resume/domain/repositories/resume_repository.dart` —
  added `ResumeRoleSelection` typedef, `getRoles()`, `selectTargetRole()`.
- `lib/features/resume/data/resume_html_parser.dart` — added
  `parseTargetRoleBadge()` (the success-confirmation mechanism, §4).
- `lib/features/resume/data/resume_remote_datasource.dart` /
  `resume_repository_impl.dart` — implement the two new repository
  methods.
- `lib/features/resume/presentation/controllers/resume_builder_controller.dart`
  — added `targetRole` to `ResumeIdle`/`ResumeUploading`/`ResumeResultState`
  and a `setTargetRole()` method (details in §5).
- `lib/features/resume/presentation/providers/resume_providers.dart` —
  registered `rolePickerControllerProvider`.
- `lib/features/resume/presentation/screens/resume_builder_screen.dart` —
  the "Choose Target Role" entry point / badge.
- `test/app/client_flow_test.dart`, `test/features/auth/auth_controller_test.dart`,
  `test/features/resume/data/resume_html_parser_test.dart`,
  `test/features/resume/presentation/controllers/resume_builder_controller_test.dart`,
  `test/features/resume/presentation/screens/resume_builder_screen_test.dart`,
  `test/features/resume/presentation/screens/resume_history_screen_test.dart`
  — updated for the new interface methods (2 unrelated fakes needed only a
  compile-fix stub; the resume-specific ones gained real new tests, §7).

## 3. Verified endpoint and response schema

Re-verified directly in the updated Django source (not assumed from
Phase 22's summary):

- `GET /resume-builder/manual/roles/` (`business_english_lms/urls.py:93`,
  `name='manual_resume_roles'`), `@require_GET`, **not** `@login_required`.
  A bare GET (no `?slug=`/`?spec=`) returns `client_payload(full=True)` —
  confirmed by re-reading `manual_resume_views.py:87-111` line by line —
  **every** built-in role field (`fields`/`levels`/`summary_focus`/etc.),
  not the lighter `CARD_KEYS`-only shape the landing page's own inline
  script uses (that one calls `client_payload()` with no argument,
  defaulting to `full=False` — a genuinely different call site,
  `templatetags/manual_resume_tags.py:18`). Only the fields this picker
  needs (`slug`/`title`/`category`/`category_label`/`subtitle`) are kept
  in `ResumeRole`; the rest is parsed-and-discarded, not omitted to make
  parsing easier than it really is.
- Field mapping to the `role`/`dept`/`track` query parameters — traced
  precisely through `landing.html:8738-8740`'s `pickRole()` JS and
  `role_fit.py`'s `_template_roles()` key construction, confirmed they
  agree exactly: `role` = the role's `title`; `dept` = the role's
  `subtitle` (**not** a literal department name, despite the parameter's
  name); `track` = `'tech'` only when `category == 'it'`, `'nonit'` for
  **both** other categories (`'tech'`/`'nt'`) — the role's own `category`
  string and the `track` parameter share the word "tech" but are never
  interchangeable, a real, easy-to-get-wrong distinction now documented
  directly on `ResumeRole.track`.

## 4. Selection request format and success confirmation

`selectTargetRole()` sends `GET resumeBuilderHome?role=&dept=&track=` —
the same endpoint and mechanism `_remember_target_role`
(`career_app/views.py:200-214`) already uses for the real landing page's
role cards, confirmed directly. **Success is never assumed from a 200
status.** `resume_builder.html:186-189`'s own "Target role: {{
target_role.role }} &middot; {{ target_role.dept }}" badge — rendered
only when the session's `target_role` is truthy — is parsed from the
response (`parseTargetRoleBadge`) and compared against exactly what was
sent. A match is the only path to `Success`; an absent badge (e.g. an
anonymous/expired session redirected to `resume_builder_home`'s own
`@login_required` login page before the badge could ever render) or a
mismatched echo both throw `UnauthorizedException`, never silently
treated as success. This is covered by 4 dedicated datasource tests
(§7) including one that simulates a login-page response body directly.

## 5. Navigation and state-management decisions

- **Entry point location**: inside `ResumeBuilderScreen`'s upload form,
  not the Phase 21 home hero — an explicit instruction this phase
  followed, and independently confirmed still true (`home_screen_test.dart`
  passes unmodified, §9).
- **Picker screen vs. modal**: a dedicated pushed screen for role
  selection (the catalog, even at ~38+ admin-extensible roles, reads
  better as a full screen than a cramped sheet); the 3-action step is a
  bottom sheet, mirroring the real web's own compact `roleAct` dialog.
- **Return value, not shared mutable state**: the picker screen returns a
  `ResumeRoleSelection?` via `context.push<...>()`/`Navigator.pop()`,
  matching standard Flutter navigation-result conventions already
  implicit elsewhere in this app, rather than writing directly into
  `ResumeBuilderController`'s state from inside the picker.
  `ResumeBuilderController.setTargetRole()` is called only with an
  already-server-confirmed value — it makes no network call itself.
- **Controller split**: `RolePickerController` owns only catalog loading/
  search/filtering; the 3-action sheet's own save-in-flight/error state is
  local `ConsumerStatefulWidget` state (matching how `ResumeBuilderScreen`'s
  own `_UploadFormState` already manages transient UI state like the
  picked file, rather than routing every local concern through a
  controller).
- **`build()`-vs-`initState()` safety fix found and fixed during this
  phase's own testing**: the first version called `RolePickerController
  .load()` directly from `initState()`; `load()`'s first statement writes
  `state` synchronously, which Riverpod forbids during a widget's build
  phase — confirmed by a real `"Tried to modify a provider while the
  widget tree was building"` failure the moment the first test ran.
  Fixed by deferring the call to a post-frame callback (the same pattern
  `MockInterviewScreen` already uses), re-verified by rerunning every
  affected test afterward.
- **Role persistence across `ResumeBuilderController` transitions — a
  second real bug found and fixed via testing**: `targetRole` was
  originally threaded through `ResumeIdle`/`ResumeUploading` but not
  `ResumeResultState`, so `reset()` ("Analyze Another Resume") silently
  lost it after a *successful* analysis — caught by a new regression test
  expecting the role to survive `reset()`, which failed on the first
  implementation. Fixed by adding `targetRole` to `ResumeResultState` too
  (the result view itself has no use for it, but `reset()` needs to
  recover it), since the real Django session does **not** clear
  `rb_role` between analyses — showing "no role" after a successful
  analysis would have been a false display, not a correct reset.

## 6. Error handling and unsupported-action behavior

- **Role catalog fetch failure**: `RolePickerLoadFailed`, a real
  `AppErrorView` with retry — never a silent fallback to invented roles.
- **Empty catalog**: an honest "No roles are available right now." state,
  distinct from "No roles match your search." for a filtered-to-empty
  result — both are real, handled states, not errors.
- **Malformed role entries**: one bad entry (wrong field type, empty
  required field) is skipped individually; the rest of a real response
  still parses — verified directly (§7).
- **Selection failure**: shown as an inline error inside the action sheet;
  the sheet and the picker screen both stay open — never pops, never
  shows the badge, matching "never claim a role is saved when the server
  has not confirmed it."
- **"Skills"/"Build Resume"**: rendered as real, visible tiles with an
  honest "Coming soon" subtitle and `enabled: false` — confirmed (via
  test) that tapping them does nothing and the sheet stays exactly as it
  was, never a fake destination.

## 7. Tests added and exact results

- `test/features/resume/data/resume_remote_datasource_test.dart` — 9 new
  tests across `getRoles`/`selectTargetRole`: real endpoint/query-param
  verification, full-field parsing, empty catalog, malformed top-level
  response, one-bad-entry-skipped, network failure, exact success
  confirmation, login-redirect-shaped rejection, mismatched-echo rejection.
- `test/features/resume/presentation/screens/role_picker_screen_test.dart`
  (new file) — 11 tests: loading→loaded, retryable error, empty state,
  search filtering, no-matches vs. no-roles-at-all copy, category
  filtering, disabled-action tiles, confirmed-selection pop-with-result
  (asserting the exact `role`/`dept`/`track` sent), backing-out-returns-
  null, failed-selection-shows-inline-error-without-popping, narrow-width
  (320/360/390px) overflow check.
- `test/features/resume/presentation/controllers/resume_builder_controller_test.dart`
  — 5 new tests: `setTargetRole` makes no network call; an unselected
  role never affects ordinary analysis; the role survives a *failed*
  upload; `reset()` preserves the role (unlike the quota) — this is the
  test that caught §5's second bug; a late-resolving `loadParseQuota`
  doesn't clear an already-selected role.
- `test/features/resume/presentation/screens/resume_builder_screen_test.dart`
  — 4 new tests: the entry point is visible with no badge yet; tapping it
  navigates to the real route; confirming in the (stubbed) picker shows
  the badge only after it returns; backing out leaves the upload flow,
  including the ordinary "Analyze Resume with AI" button, completely
  unaffected.

**Commands and results:**
```
flutter test test/features/resume/ test/features/home/
→ 108 passed, 0 failed

flutter test
→ 2008 passed, 0 failed (full suite; 1978 prior + 30 new this phase)
```

## 8. `flutter analyze` result

```
flutter analyze
No issues found! (ran in 2.3s)
```
Run repeatedly scoped to the changed files during development and
whole-project at the end — clean throughout.

## 9. Manual verification

**None performed.** No emulator/device was used; no live navigation was
manually exercised. Every claim in this report about rendering,
navigation, request/response handling, and error states comes from the
automated test suite (§7) and direct, repeated re-reads of the Django
source (§3-4) — not from running the app.

## 10. Phase 19 / Phase 21 preservation confirmed

- `test/features/resume/presentation/screens/resume_builder_screen_test.dart`'s
  entire pre-existing "REGRESSION (Phase 19) — Free-plan analyses-
  remaining counter" group passes unmodified — the quota badge, its
  fetch timing, and its failure handling are untouched.
- `test/features/home/presentation/screens/home_screen_test.dart`'s
  entire pre-existing "REGRESSION (Phase 21)" group (unified hero, all 3
  CTA destinations, employer branch, responsive layout) passes
  unmodified — the home hero and its navigation were never touched this
  phase.

## 11. Django trees and signing files untouched

Every Django file read this phase (`manual_resume_views.py`,
`resume_roles.py`, `career_app/views.py`, `business_english_lms/urls.py`,
`templates/resume_builder.html`) has a modification time predating this
session, confirmed via `stat`. `android/key.properties` shows no change
in `git status`. No build, release artifact, or Play Store action
occurred.

## 12. Final Git status

```
git status --short
```
shows exactly the files listed in §2, plus the unrelated, pre-existing
Phase 19/20/21/22 changes (resume-counter feature, home hero, and the
three prior audit reports) carried over untouched. `Career_Buddy_LMS/`'s
own pre-existing uncommitted state (unrelated to this engagement) is
unchanged from before this phase.

## 13. Known limitations

- Only the ~38 built-in roles (plus any admin-added ones) from
  `manual_resume_roles` are offered — the full 295-role department
  catalog (Phase 22's "Option A") is not implemented, per this phase's
  explicit scope.
- "Skills" and "Build Resume" are visible but non-functional by design —
  no in-app skills summary or manual resume builder exists yet.
- The role-picker route (`resumeRolePicker`) has no web equivalent URL —
  it is a mobile-only page standing in for what's a modal on the real
  site, since Flutter's screen-based navigation doesn't have a direct
  modal-on-the-same-page equivalent for a catalog this size.
- This phase does not claim complete web parity for the role-fit
  feature — only the "Resume Parsing & Interview" action, using the
  smaller of two available real role catalogs.

---

Phase 23 is complete. Stopping here per instruction — awaiting explicit
review and approval before beginning Phase 24 or any other phase.
