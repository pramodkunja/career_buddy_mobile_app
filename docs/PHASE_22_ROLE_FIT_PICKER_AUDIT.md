# Phase 22 — Role-Fit Picker Audit & Implementation Planning

**Audit-only phase.** No Flutter application file was created, edited, or
deleted. Neither Django tree was modified. The only new file is this
report.

## 0. Preserved work

`git status --short` before and after this phase showed the identical
state: Phase 19's resume-counter changes, Phase 20's and Phase 21's
reports, and Phase 21's home-hero changes, all carried over untouched.
Nothing was reset, discarded, stashed, or rewritten.

## 1. Current website behavior (verified directly, updated repo)

**Where the picker appears**: every role card (`.role-card3[data-idx]` or
`[data-it-role]`) on the "Choose Your Path" section of `landing.html`
(and its `/careers/<track>/` track-detail variant) opens the same
`roleAct` dialog (`landing.html:7589-7622`) via `pickRole(b)`
(`landing.html:8729-8742`) — personally re-read and confirmed verbatim
against Phase 20's prior findings. Its 3 options, confirmed directly:

- **Skills** (`#raSkills`, `landing.html:7596`, handler
  `8744-8749`): for a department-sourced Non-IT card with its own skills-
  page hash, jumps there in-page; otherwise opens the read-only role-
  detail (`rm`) modal (`openRole(idx, lastBtn)`, no builder) or, for an
  IT-JSON-only role, calls `itSkills(raIt)` to render a skills breakdown
  inline in the IT panel. No navigation to a new page in any case.
- **Build Resume** (`#raBuild`, `landing.html:7604`, handler
  `8765-8771`): resolves or creates a `ROLES` entry (via `slugFor`/
  `customRole`, `8754-8764` — a role without a predefined template gets a
  *generic* form built from its own skill lines, not a dead end) and
  opens the same `rm` modal with the builder shown
  (`openRole(idx, lastBtn, true)`). This is the entry point into the
  (not-yet-built-in-Flutter) manual resume builder.
- **Resume Parsing & Interview** (`#raParse`, `landing.html:7612`,
  `data-base="{% url 'resume_builder' %}"`): a plain link whose `href` is
  set, in `pickRole()` itself (`landing.html:8740`), to
  `{% url 'resume_builder' %}?role=<role>&dept=<dept>&track=<tech|nonit>`
  — the already-known mechanic from Phase 18, reconfirmed verbatim.

**Optional, not mandatory**: confirmed — picking a role is never required
to reach any destination; skipping it entirely leaves every downstream
flow (resume upload, analysis, interview) byte-for-byte unchanged (Phase
18, reconfirmed this phase by re-reading `_remember_target_role`,
`career_app/views.py:200-214`: no `role`/`dept` query params → no
`session['rb_role']` key set → every later `if target:` check is simply
false).

**Session/server-side effects of `resumeBuilderHome?role=&dept=&track=`**
(verified directly, `career_app/views.py:814-820`):
- `resume_builder_home` is `@login_required` — an **anonymous** request
  (with or without the query params) is redirected to Django's login page
  first; Django's standard `@login_required` preserves the full request
  path (including the query string) in `?next=`, so the role selection
  survives a login round-trip and `_remember_target_role` runs once the
  user actually reaches the view post-login. No special handling exists
  or is needed for this — it is standard Django decorator behavior, not
  custom logic.
- For an **authenticated** request: `_remember_target_role` sets
  `request.session['rb_role'] = {role, dept, track, section}` only when
  both `role` and `dept` slugify to a non-empty string (`views.py:200-
  214`) — a malformed/partial query string is simply ignored, not an
  error.
- This session key is read later by `_check_role_fit` (inside
  `resume_job_match`, the existing upload/analyze endpoint Flutter already
  calls) and by `resume_start_interview`'s gate — both already fully
  verified in Phase 18, not re-derived here.
- No other view, model, or database row is touched by visiting
  `resumeBuilderHome` with these params — confirmed by reading the full
  view body (`views.py:814-829`): it only sets a session dict key and
  renders a template.

## 2. Existing Flutter behavior and the gap

Confirmed via `grep` across `lib/features/resume/` and
`lib/features/home/`: zero references to `role`, `dept`, `track`,
`roleFit`, or any picker concept anywhere. `ResumeBuilderController`'s
state (`ResumeIdle`/`ResumeUploading`/`ResumeResultState`, extended in
Phase 19 with `parseQuota`) carries no role concept at all. The gap is
total — this is new feature work, not a partial implementation.

## 3. Available role-catalog sources (verified, sizes summarized not dumped)

Three distinct sources exist, all already confirmed real and working
(Phase 18, re-verified this phase):

1. **Full department catalogs** — `static/data/it_departments.json`
   (52,659 bytes) and `static/data/nonit_departments.json` (62,664
   bytes), public static files (`{% static %}`-served, no login, no
   view). Structure: `[[group_name, [[dept_name, icon, [[role_name,
   [skill_line, ...]], ...]], ...]], ...]`. Measured directly (not
   estimated): **IT = 2 groups, 10 departments, 93 roles; Non-IT = 2
   groups, 21 departments, 202 roles. Combined: 31 departments, 295
   roles.** Only the IT file is actually `fetch()`-ed by the web's own JS
   (with explicit loading/error states, `landing.html:8197-8203`); the
   Non-IT data is typed directly into the template as a hardcoded JS
   array instead of fetched — **`nonit_departments.json` is confirmed to
   exist on disk and would very likely be served at the same public
   static URL pattern as the IT file (same directory, same Django static
   handling), but no template anywhere was found to actually `fetch()` it
   this way — this specific reachability was not independently load-
   tested and is flagged as an assumption, not a confirmed fact.**
2. **`roles_api`** (`career_app/manual_resume_views.py:87-111`,
   `@require_GET`, no login required, rate-limited per IP) — returns
   `client_payload()`'s predefined-template roles as clean, structured
   JSON. Counted directly in source: **39 occurrences of the `_role(`
   constructor call (1 is the function definition itself, so ~38
   built-in predefined roles)**, spread across 3 categories (`CATEGORY_
   LABELS`: "IT Role", "Non-IT · Technical", "Non-IT · Non-Technical").
   `get_roles()`'s own doc comment confirms this is "built-in defaults
   with admin overrides and additions" from a database table — meaning
   the exact live count can differ from the ~38 built-in ones and is not
   fully fixed in source alone.
3. **Custom/generic roles** (`career_app/resume_roles.py`'s
   `custom_role()`/the JS `customRole()`): not a separate catalog, but a
   confirmed fallback that builds a usable, generic resume-builder form
   from *any* role's own skill lines (from either catalog above) when no
   predefined template exists — meaning **"Build Resume" and "Skills" are
   not actually restricted to the smaller, templated role set**; they
   work for a full-catalog role too, just with a generically-built form
   instead of the hand-authored one for ~38 roles.

## 4. Option comparison

**Option A — Full catalog (295 roles / 31 departments)**
- Coverage: complete, matches the real web's "Choose Your Path" exactly.
- Usability: requires a genuine 2-level drill-down (track → department →
  role) and, almost certainly, search/filter — 295 flat items is not
  usable as a single scrollable list on a phone. This is real, non-
  trivial mobile UX design work, not a thin wrapper.
- Maintenance: lowest ongoing burden *if* fetched live each time (no
  Flutter-side data to keep in sync) — but the Non-IT half's fetchability
  via a public static URL, while likely, was not independently confirmed
  this phase (see §3).
- Payload: ~115KB combined, fetched once, reasonable to cache.

**Option B — `roles_api` (~38 built-in roles, admin-extensible)**
- Coverage: a meaningful subset — the roles with a hand-authored
  resume-builder template — but misses the bulk of the staffing/
  industry-specific Non-IT catalog (202 of 295 roles) entirely.
- Usability: a single scrollable, optionally category-filtered list is
  realistic at this size — no drill-down needed, closer to a typical
  mobile picker.
- Maintenance: zero Flutter-side burden (fetched live); the live set can
  grow via the admin table without any catalog ever needing a Flutter
  update.
- Payload: a single, already-login-free, already-clean JSON response —
  no raw-array parsing needed, unlike the department files' nested-array
  shape.
- Functional note (confirmed, §3): "Skills"/"Build Resume" are not
  functionally crippled by using this smaller set — `custom_role()`
  already generically supports any role regardless of source.

**Option C — A curated, hand-picked short list**
- Coverage: whatever subset is chosen — necessarily arbitrary, and the
  task's own instruction is explicit that this must not become invented
  role data. The only honest way to build Option C is as a curated
  *subset of* Option A or B's real data — which does not avoid fetching
  the real catalog, it only adds an extra, Flutter-side maintenance
  burden (the curated list must be manually kept in sync with whichever
  real source it's drawn from, every time that source changes — a
  genuine, ongoing risk of silently omitting newly-added valid roles).
- Recommendation: **not favored** — it inherits most of Option B's
  fetching work while adding a maintenance liability neither A nor B has.

## 5. Recommendation

**Start with Option B (`roles_api`) for the first implementation, with
Option A as a natural, explicitly-deferred expansion once the manual
resume builder itself is built.** Reasoning, source-grounded:

- Of the picker's 3 options, only **"Resume Parsing & Interview"** is
  currently wireable in Flutter at all (Resume Builder is real; the
  manual builder behind "Build Resume" is not built yet, confirmed
  Missing in Phase 15/18/20). That one option's correctness does not
  depend on which catalog is used — `_check_role_fit`/`find_role` accept
  a role from either source identically (Phase 18, reconfirmed). Starting
  with the smaller, simpler, already-structured source minimizes new UI
  complexity for a phase where the *other two* modal options can't fully
  pay off yet regardless.
- Option B avoids inventing a 2-level mobile drill-down UI this phase,
  which is substantial, undecided design work in its own right.
- Option A remains fully available later with no re-architecture: the
  same picker entry point (§6) and the same `setTargetRole`-style
  mechanism (§7) work unchanged regardless of which catalog feeds the
  role list — only the *data source and list UI* would need to grow.

This is a recommendation, not a decision made on the user's behalf — it
requires explicit sign-off before Phase 23 implements anything.

## 6. Proposed screen/modal flow (not implemented this phase)

- **Entry point**: inside the existing `ResumeBuilderScreen`'s upload
  form (`_UploadForm`), as a new, small, optional "Pick a target role"
  affordance — **not** inside the Phase 21 home hero, which this phase's
  own boundary explicitly protects from any change.
- **Role selection**: a dedicated, pushed Flutter screen (not a dialog) —
  295 or even ~38 items with icons/descriptions reads better as a full
  screen than a cramped bottom sheet, consistent with how this app
  already treats comparable browse flows (`ActivityListScreen`,
  `SkillUpScreen`).
- **The 3-option step**: once a role is tapped, a compact bottom sheet or
  simple dialog listing Skills/Build Resume/Resume Parsing & Interview —
  this part genuinely does map well to a modal, mirroring the web's own
  compact `roleAct` dialog. "Skills" and "Build Resume" would need their
  own honest handling decided in a future phase (an in-app skills summary
  for Skills; an honest "not yet available" state for Build Resume, never
  a fake placeholder); only "Resume Parsing & Interview" is wireable now.
- **Confirming "Resume Parsing & Interview"**: calls a new repository
  method (§7) to set the role server-side, then returns to the upload
  form, which should now show a "Target role: X · Y" indicator (mirroring
  `resume_builder.html:186-189`'s own badge) before the user taps the
  existing, unmodified "Analyze Resume with AI" button.
- **Skip behavior**: simply never opening the picker, or backing out of
  it — already confirmed fully inert server-side (§1) when no role/dept
  query params are ever sent; no extra "skip" plumbing is needed beyond
  not calling the new method.

## 7. Existing endpoints and verified request/response behavior

No new endpoint is proposed. Two existing, already-confirmed mechanisms
cover this entire feature:

- **Setting the role**: `GET resumeBuilderHome` (`ApiEndpoints
  .resumeBuilderHome`, already used by Phase 19's `getParseQuota()` and
  the pre-existing CSRF-priming call) with `role`/`dept`/`track` query
  parameters appended. This is the same endpoint Flutter already calls
  today — adding query parameters to an existing `Dio` GET is the only
  new wiring needed; the response body can be discarded (the session
  write is the only effect that matters) or optionally re-parsed with the
  existing `parseResumeParsesLeft` to refresh the quota badge for free.
- **Role data**: `GET {% url 'manual_resume_roles' %}` (`roles_api`, no
  login, confirmed `@require_GET`) for Option B; the two public static
  JSON files for Option A.
- Neither requires a new Django route, field, or response shape — fully
  consistent with this phase's "existing endpoints only" constraint.

## 8. Authentication, subscription, and session-side-effect considerations

- `resume_builder_home` is `@login_required` — an anonymous user
  attempting to set a role is sent through the existing login flow first
  (§1); Flutter's existing router guard already handles this identically
  for the plain (role-less) GET today (Phase 19/21), so no new auth
  logic is implied.
- No subscription/plan check applies to picking a role or to resume
  parsing itself (`_can_access_resume` = `is_authenticated` only,
  confirmed Phase 18) — only the *interview* step is paid-gated,
  unchanged and already handled entirely by the existing Mock Interview
  feature. No new subscription-awareness logic is needed for the picker.
  Per this phase's explicit instruction, `dashboard.payment_history
  [].is_plan_active` was not considered or used anywhere in this
  reasoning.
- Setting a role is a pure session-state write (§1) — no database row,
  no other user's data, no production side effect beyond the requesting
  user's own session.
- No network call to production and no test-account use occurred in this
  audit — every finding above is from static source reading.

## 9. Flutter files likely to require changes (future phase, not this one)

- `lib/features/resume/domain/repositories/resume_repository.dart` — new
  method, e.g. `Future<bool> setTargetRole({required String role,
  required String dept, required String track})`.
- `lib/features/resume/data/resume_remote_datasource.dart` — the GET-
  with-query-params implementation, reusing `ApiEndpoints
  .resumeBuilderHome`.
- `lib/features/resume/data/resume_repository_impl.dart` — thin pass-
  through, matching Phase 19's `getParseQuota()` convention.
- `lib/features/resume/presentation/controllers/resume_builder_controller.dart`
  — new state field for the selected role (nullable, matching Phase 19's
  `parseQuota` pattern) and a controller method to call `setTargetRole`.
- `lib/features/resume/presentation/screens/resume_builder_screen.dart` —
  the new "Pick a target role" entry point on the upload form, and a
  small role-display badge once one is set.
- New files: a role-picker screen, a role-data model/parser (whichever
  source is approved), and the 3-option bottom sheet.
- **Not touched**: `lib/features/home/` (Phase 21's hero, explicitly
  protected), `lib/features/mock_interview/` (interview gating already
  correct and untouched), anything related to Phase 19's free-analysis
  counter.

## 10. Focused future test plan

- **Role-data parsing**: a fixture of whichever source is approved parses
  into a usable list without data loss; a malformed/empty response
  degrades to "no roles available" rather than throwing.
- **Selection**: picking a role stores it in controller state; the 3-
  option sheet shows for the picked role; "Resume Parsing & Interview"
  calls `setTargetRole` with the exact expected query parameters
  (mirroring this engagement's established "assert the real outgoing
  request" convention, e.g. Phase 16/19's tests).
- **Skipping**: never opening the picker leaves `uploadAndAnalyze`'s
  outgoing request byte-for-byte identical to today's (the single most
  important regression guarantee — confirms this feature cannot silently
  change existing behavior for a user who ignores it entirely).
- **Persistence across the upload step**: the role badge remains visible
  through `ResumeUploading`→`ResumeResultState`, consistent with how
  Phase 19 threads `parseQuota` through the same transitions.
- **Errors**: a failed `setTargetRole` call (network error, unexpected
  response) must not block or corrupt the upload flow — best-effort,
  matching Phase 19's `getParseQuota()` failure handling exactly.
- **Existing resume-analysis behavior unaffected**: every existing
  `resume_builder_controller_test.dart`/`resume_builder_screen_test.dart`
  test continues to pass unmodified (the same regression bar Phase 19
  held itself to).
- **Existing free-analysis counter unaffected**: `getParseQuota()`'s own
  tests and behavior are untouched (this phase's own boundary).

## 11. Known limitations and product decisions needed

- **Product decision required**: approve Option B as the starting
  catalog (recommended, §5), or direct a different choice before Phase 23
  begins.
- **Product decision required**: how "Skills" and "Build Resume" should
  behave in Flutter given the manual builder doesn't exist yet — e.g.,
  defer both entirely and ship only "Resume Parsing & Interview" first,
  or build a minimal honest "Skills" summary view sooner. This audit
  takes no position beyond flagging it.
- **Unresolved, flagged not assumed**: whether `nonit_departments.json`
  is actually reachable at a public static URL was not independently
  verified this phase (§3) — relevant only if Option A is ever chosen.
- **Unresolved**: the exact *live* count of `roles_api`'s roles (admin-
  extensible beyond the ~38 built-in ones) was not and cannot be
  determined from source alone.

## 12. Git status confirmation

```
git status --short
```
at the end of this phase showed the exact same output as at the start —
only the pre-existing Phase 19/20/21 changes, untouched. No new file
beyond this report.

## 13. Explicit confirmation

No Flutter application source or test file was created, edited, or
deleted this phase. Neither Django tree
(`royalStaffing_CB01/`/`Career_Buddy_LMS/`) was modified — every file
read was via the Read/Bash(`grep`/`python3 -c`) tools only; file
modification times on every Django file read predate this session
(consistent with every prior phase's own confirmation pattern).

---

Phase 22 is complete. No implementation occurred. Awaiting explicit
approval on the recommended option (§5) and the open product decisions
(§11) before any Phase 23 work begins.
