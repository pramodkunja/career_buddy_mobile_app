# Preview, Demo, Mock, and Static Data Audit (Phase 1)

Read-only audit. No Flutter or Django source was modified. Findings below
were produced by direct source reading (this session) plus two focused,
read-only research passes covering all 25 feature modules between them —
every finding cites an exact file and line. `android/key.properties` was
not read, printed, or touched at any point, per the explicit restriction.

## 0. Architecture context needed to interpret every finding below

Before classifying anything, one structural fact has to be stated plainly,
because it reframes most of what might otherwise look like "mock data":
**this app's primary real-data integration strategy, for several modules,
is live HTML-scraping of the actual production Django pages — not JSON.**
`lib/core/network/api_endpoints.dart`'s own doc comments confirm this
directly: a JSON API exists in the Django source for Dashboard, the
Activities list, and MCQ exercises (`docs/BACKEND_CONTRACT_dashboard.md`,
`docs/BACKEND_CONTRACT_activities.md`), but each was **confirmed, live,
not deployed to production** (anonymous `GET`s return a genuine Django
404). Rather than inventing data to compensate, this app instead calls the
real HTML page the browser would get and parses it
(`dashboard_html_parser.dart`, `activities_html_parser.dart`,
`mcq_exercise_html_parser.dart`, and 13 more `*_html_parser.dart` files
across `employer` (8), `resume`, `mock_interview`, `jam`, and
`group_discussion`). This is a deliberate, documented, and — per both
research passes below — **correctly implemented** integration path, not a
mock or placeholder. Treat every `*_html_parser.dart` file as "real,
possibly fragile" unless a specific finding below says otherwise.

## 1. Complete inventory of preview/demo entry points

A single, coherent "Demo Mode" system — not scattered ad-hoc switches.
Confirmed by an exhaustive `grep` for `kDebugMode`/`kReleaseMode`/`kProfileMode`
across all of `lib/`: the only occurrences outside `lib/core/demo/` are this
system's own two wiring points (`route_guards.dart`, `app_router.dart`,
`login_screen.dart`) and `environment.dart`'s unrelated, already-documented
release-build safety guard (refuses to ship a release build pointed at the
dev server). **No other mock-mode switch exists anywhere in the app.**

**Core files** (`lib/core/demo/`): `demo_mode.dart` (the two providers),
`demo_mode_toggle.dart` (the AppBar action), `demo_entry_screen.dart` (the
`/demo` route), plus 10 in-memory demo repositories: `demo_activities_repository.dart`,
`demo_mcq_exercise_repository.dart`, `demo_ai_listening_repository.dart`,
`demo_ai_reading_repository.dart`, `demo_ai_speaking_repository.dart`,
`demo_ai_writing_repository.dart`, `demo_bingo_exercise_repository.dart`,
`demo_fill_blank_exercise_repository.dart`, `demo_generic_writing_repository.dart`,
`demo_matching_exercise_repository.dart`.

**Entry point 1 — "Preview Demo (Debug)" button**, `login_screen.dart:509-518`:
```dart
if (kDebugMode) ...[
  ... AppButton(label: 'Preview Demo (Debug)', ..., onPressed: ... => context.go(RoutePaths.demoEntry)),
],
```
`kDebugMode` is a Dart compile-time constant — this entire widget subtree is
**eliminated by the compiler**, not merely hidden, in a release build.

**Entry point 2 — Demo Mode toggle (flask icon)**, `demo_mode_toggle.dart`,
embedded in `activity_list_screen.dart` (the real, first screen reached
after a real login): renders `SizedBox.shrink()` and is otherwise a no-op
when `!kDebugMode`.

**The `/demo` route** (`RoutePaths.demoEntry`, `route_paths.dart:392-399`):
registered unconditionally in `app_router.dart:114-115` (the route *exists*
in a release build's table), but `DemoEntryScreen.initState`
(`demo_entry_screen.dart:30-38`) immediately calls `context.go(RoutePaths.login)`
and never touches `demoModeEnabledProvider` when `!kDebugMode` — so reaching
this path in a release build (e.g. a stale deep link) does nothing beyond
bouncing to the login screen. Two independent, redundant gates, confirmed
by reading both files directly, not inferred from comments alone.

**Router-level bypass** — `app_router.dart:98`:
```dart
demoBypass: kDebugMode && ref.read(demoModeEnabledProvider),
```
and `route_guards.dart:20`: `if (demoBypass) return null;` — this is a
**blanket** bypass: when Demo Mode is toggled on in a debug build,
`computeRedirect` lets *any* matched route through, not only the
demo-wired ones. This is correctly scoped to debug builds only, but it is
broader than "swap 9 modules' data" — see §6 finding D1 for the one minor,
debug-only consequence this creates.

**Which feature modules Demo Mode actually swaps data for** (confirmed
independently by both research passes, identical conclusion): `activities`
+ its `mcq` exercise type, `ai_listening`, `ai_reading`, `ai_speaking`,
`ai_writing`, `bingo`, `fill_blank`, `generic_writing`, `matching` — **9 of
25 modules**. The other 16 (`aria_chat`, `auth`, `certifications`,
`dashboard`, `employer`, `grammar`, `group_discussion`, `home`, `jam`,
`mock_interview`, `mock_tests`, `resume`, `roleplay`, `skill_up`, `splash`,
`subscription`, `timer_exercise`) have **no** Demo Mode wiring at all —
confirmed by `timer_exercise_providers.dart`'s own comment and by grepping
for `core/demo` imports in each module.

**Wiring pattern** (identical in every one of the 9 modules, e.g.
`activities_providers.dart:18-21`):
```dart
final activitiesRepositoryProvider = Provider<ActivitiesRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoActivitiesRepository();
  return ActivitiesRepositoryImpl(ref.watch(activitiesRemoteDataSourceProvider));
});
```
`demoModeActiveProvider` (`demo_mode.dart:24-27`) is hard-`false` whenever
`kDebugMode` is `false` — a third, independent gate on top of the two
above, at the exact point every demo repository is actually selected.

## 2. Exact recommendation for the Preview Demo (Debug) link and screen

**Do not remove.** This is Classification 3 (development-only tooling),
not Classification 1 (obsolete user-facing demo feature) — the two are
easy to conflate from the name alone, and the evidence clearly distinguishes
them:
- It solves a real, stated problem: `demo_mode.dart`'s own comment says the
  local development database is **intentionally empty** of
  `Activity`/`SubActivity`/`Exercise` rows, so without Demo Mode a developer
  cannot exercise 9 of this app's feature modules locally at all.
- It is triple-gated to debug builds (compile-time elimination of the
  entry button, a runtime check in the entry screen, and a hard-`false` on
  the provider that actually swaps data) — confirmed by reading all three
  gates directly, not assumed from a single comment.
- It never fabricates data in front of a real user: `demoModeActiveProvider`
  cannot be `true` in a release build under any code path found.
- A real automated test already covers its navigation behavior
  (`test/core/demo/demo_navigation_test.dart`, found by the research pass) —
  removing the feature would require deleting or substantially rewriting a
  test that currently has nothing wrong with it, which the task's own
  restrictions prohibit doing without cause.

**Explicit impact assessment of removing it** (as the task requires):
removing the Preview Demo link/screen would have **zero effect on any real
user-facing route, the production API contract, or any non-debug
workflow** — every gate confirms it cannot run outside a debug build. It
**would** eliminate the only way a developer can currently exercise
Activities/MCQ/AI-listening/AI-reading/AI-speaking/AI-writing/Bingo/
Fill-blank/Generic-writing/Matching screens against an empty local
database, and would require touching roughly 23 files (10 demo
repositories + `demo_mode.dart`/`demo_mode_toggle.dart`/`demo_entry_screen.dart`
+ the 9 provider files' conditional branches + `route_guards.dart`'s
`demoBypass` parameter + `app_router.dart`'s wiring + the route constant +
`demo_navigation_test.dart`) for something that was not shown to be
obsolete. **Recommendation: keep as-is. This does not meet the task's own
bar for removal** ("remove only obsolete... functionality after it has
been proven unnecessary") — it has been proven *necessary* for local
development, not unnecessary.

## 3. The `jobDetail` placeholder — a separate conversion finding, not a demo/mock issue

`RoutePaths.jobDetail` (`route_paths.dart:236-242`) still resolves to a bare
`ComingSoonScreen` (`app_router.dart:332`). This is the **only** remaining
placeholder route found in the entire 66-route table (re-confirmed this
phase, matching Phase 0's baseline). Root cause, read directly from the
route's own doc comment and confirmed against the real data flow: the
Dashboard's "recommended jobs" section (`recommended_jobs_section.dart:195`)
shows real, live-scraped job data (see §0), but the scraped HTML job cards
carry **no stable id field to deep-link to** — there is nothing to build a
Job Detail screen against yet, not a missing screen implementation. This is
a genuine, understood, pre-existing **conversion gap**, explicitly recorded
here as required, and **not implemented in this phase**.

## 4. Static/mock data inventory, by severity

### 4a. Could mask a real failure — the load-bearing findings

**F1 — `auth`: an expired session can render as a blank, all-zero profile
instead of logging out.**
- File: `lib/features/auth/data/datasources/profile_remote_datasource.dart`,
  `getProfile()` (~L161-209).
- Unlike `DashboardRemoteDataSource` (which checks `isDashboardHtml` and
  throws `UnauthorizedException` on a mismatch), this data source uses
  `validateStatus: (_) => true` and only checks `statusCode == 200` — it
  never confirms the HTML it received is actually the profile page. Since
  Dio follows redirects by default and `ApiClient` has no
  redirect-to-login interceptor, a session that has expired lands on the
  real login page (still a 200) and gets parsed *as if it were a profile*.
- Resulting defaults: `fullName`/`username`/`email` → `''`,
  `activitiesStarted`/`completedSubs`/`totalScore` → `0`, `recentResults`
  → `[]`, English level → `'intermediate'`, additional-educations JSON →
  `'[]'`.
- User-visible effect: `ProfileScreen` shows an empty "@" profile with zero
  stats, no error, no forced logout.
- **Compounding risk**: `english_level`/`bio`/`additional_educations_json`
  are posted back unchanged on Save — if this silent-default path is ever
  hit mid-session (not just at load), a profile save could overwrite a
  real value with the fallback.
- **Classification: 2 (production fallback that may mask an API
  failure).** **Recommendation**: add an `isProfileHtml`-style page-identity
  guard to `getProfile()`, mirroring `DashboardRemoteDataSource`'s existing,
  proven pattern exactly, throwing `UnauthorizedException` on a mismatch.
  **Regression test needed**: a data-source test asserting that a
  login-page HTML body (not a profile page) throws `UnauthorizedException`
  rather than returning a `Profile` with empty/zero fields — this is a
  reproducible, fixable, in-scope finding for a future phase, not a
  documentation-only note.

**C1 — `resume`/`activities`: subscription-tier gating is inferred from
exact HTML substring matches, confirmed correct today but silently brittle.**
- Files: `resume/data/resume_html_parser.dart:82,87`
  (`canInterview = html.contains('Try Interview')`,
  `isAtsOnly = html.contains('ATS Score')`),
  `activities/data/activities_html_parser.dart:67`
  (`isFreePreview = html.contains('Free Plan — choose any one')`).
- **Verified, not assumed**: cross-checked against the actual local Django
  templates — `'Try Interview'` only appears inside
  `{% if can_interview %}` (`resume_match_result.html:218-220`), `'ATS
  Score'` only inside `{% if is_ats_only %}` (`:196`), neither string
  appears in `base.html`/`includes/aria_assistant.html` (so a false match
  from shared chrome isn't currently possible), and `'Free Plan — choose
  any one'` matches `activities/list.html:15` exactly.
- `resume_html_parser.dart:40` additionally defaults `matchPercentage` to
  `0` when its own regex misses.
- **Classification: 5 (legitimate, currently correct)**, but flagged
  distinctly because a web copy change (not an API failure) would silently
  flip real subscription gating with no error surfaced anywhere. **No fix
  recommended now** — the task explicitly says not to assume every
  hardcoded value is a problem and to recommend a targeted fix only where
  evidence shows an actual break; there is none here today. Recorded as a
  **standing brittleness risk worth a smoke-test**, not a confirmed defect.

**C2 — `mock_interview`: malformed responses render plausible-looking
invented defaults instead of surfacing an error.**
- `mock_interview_remote_datasource.dart:76-83,110`: `progress ?? '1/20'`,
  `time_limit ?? 30`, `topic ?? 'General'`, `difficulty ?? 'Easy'`,
  `score ?? 0`.
- `mock_interview_html_parser.dart:61-98`: total score, average, answered
  count, and per-question scores all default similarly.
- **Why this is worse than F2 below**: these defaults (`'1/20'`, a 30s
  timer, `'General'`) look like real, specific data rather than an obvious
  empty state — a user has no visual cue anything went wrong.
- **Classification: 2.** **Recommendation**: these fields should fail
  loudly (throw a parse/validation exception) rather than default, exactly
  matching this codebase's own already-established pattern elsewhere (e.g.
  exercise loaders throwing `ValidationException` when `questions-data` is
  missing, per §4c). **Regression tests needed**: one per defaulted field,
  asserting a missing/malformed value throws rather than silently
  substituting.

**C3 — `group_discussion`: report scores default to 0 on a fragile,
inline-style-dependent regex.**
- `gd_report_html_parser.dart:22-41,63-64`: overall and per-dimension
  scores default to `0`; the regex keys off inline styles like
  `color:#7c3aed`. `gd_speaker.dart:16-22` additionally mis-attributes an
  unrecognized speaker key to `GdSpeaker.user`.
- **Classification: 2 (lower severity than C2)** — a broken report shows a
  plausible-looking all-zero score rather than an error. **Recommendation**:
  same pattern as C2 — fail loudly on a parse miss rather than defaulting.

**C4 — `employer`: dashboard counts default to 0, and an unrecognized job
badge is mislabeled as `'draft'`.**
- `employer_dashboard_html_parser.dart:17-19,41-42`: total/active
  jobs and applications counts default to `0`; job status defaults to
  `'draft'` when no Active/Closed/Draft badge text matches.
- **Why this one is distinct from a plain zero-default**: mislabeling a
  genuinely *live* job as `'draft'` is actively incorrect information shown
  to an employer about their own posting, not just an empty/zero state.
- **Classification: 2.** **Recommendation**: default job status to an
  explicit "Unknown" state distinct from `'draft'`, and surface counts as
  "—" rather than `0` when the identity check on the page itself still
  passes but a specific stat's regex misses.

### 4b. Lower-severity, worth awareness, not urgent

- **F2 — `dashboard`**: `dashboard_html_parser.dart`'s `_parseStats`
  (L59-71) defaults individual stat values to `0` when the page is
  confirmed real (passes `isDashboardHtml`) but a specific
  `stat-card-value` regex misses. Lower risk than F1/C2-C4 because the
  page-identity guard already catches the big failure mode (an expired
  session); this is only about finer-grained template drift within an
  already-confirmed-real page.
- **F3 — `certifications`**: `downloadCertificateBytes`
  (`certifications_remote_datasource.dart:86-96`) saves response bytes to
  a `.pdf` file with no content-type or `%PDF` magic-byte check — a
  followed redirect to a login page would be silently saved as a
  "certificate" that then fails to open. Edge case, not static/mock data.
- **C5 — `jam`**: `jam_html_parser.dart:350-351` defaults `totalSessions`/
  `totalMinutes` to `0` on a regex miss — same low-severity pattern as F2.
- **C6 — shared exercise-submit score fallback** (`fill_blank`,
  `matching`, `generic_writing`, `timer_exercise`, and MCQ/bingo's
  equivalent): `*_submission_result_model.dart` uses the app's own
  client-computed score only when the **successful** server response omits
  `score`/`max_score` — `attempt` itself has no default and throws if
  missing. This mirrors the real web's own JavaScript scoring fallback
  exactly (confirmed by in-code comments citing it) and never fires on an
  API *failure*. **Classification: 5 — keep.**
- **Dead code (not demo data)**: `dashboard_data_model.dart`'s
  `DashboardDataParsing.fromJson` extension is unused anywhere in `lib/`
  outside of tests — a genuine leftover from when the (still-undeployed)
  JSON endpoint was expected to be consumed directly. Safe, low-priority
  cleanup candidate for a future phase; not demo/mock data and not
  currently causing any behavior.
- **Stale comments, not code defects**: `dashboard_screen.dart:30-31,54`
  still describe the dashboard contract as "not-yet-implemented"; `skill_up_screen.dart:704`
  says "CERTIFICATIONS TAB — placeholder" immediately above code that
  renders the real `CertificationsSection`; `route_paths.dart:480-489`
  (`resumeInterviewPlaceholder`) describes a ComingSoon screen that
  `app_router.dart:274-275` has since replaced with the real
  `MockInterviewScreen`. None of these affect behavior — recommend a
  documentation pass, not a code change.

### 4c. One silent API-failure fallback outside the HTML-parser family

**A1 — `mock_interview`: a failed video upload is reported as success,
by design.**
`mock_interview_repository_impl.dart:81-87`, `uploadInterviewVideo`:
```dart
} on AppException catch (_) {
  return const Success(false);
}
```
Any network/server error during the interview-video upload is swallowed
and reported as "not stored," with no error reaching the user. The
in-code comment states this deliberately mirrors the real web page's own
give-up-after-one-retry behavior, and the controller already defers video
handling as non-critical. **Classification: 5 (intentional, matches real
web behavior, touches no scores) — keep, no action recommended.**

## 5. Legitimate static content that must be preserved (Classification 5)

Confirmed, across both research passes, as real and correctly non-API
content — explicitly **not** flagged as mock/demo data, since each is
either copied-from-the-real-web reference/prompt content with server-side
scoring, or plain UI/form configuration:

- `ai_listening`/`ai_reading`/`ai_speaking`/`ai_writing`: bundled
  stories/passages/topics (`listening_story.dart`, `reading_passage.dart`,
  `speaking_topic.dart`, `writing_topic.dart`) — prompts and reference
  text only; all scoring is server-side (and, notably, `ai_speaking`/
  `ai_writing` controllers **explicitly declined to port the web's
  client-side fallback scoring**, showing retryable errors instead of an
  invented score on failure — a positive example of this codebase's own
  stated design philosophy working as intended).
- `grammar`: all 9 topics load from the bundled `assets/data/grammar_data.json`,
  a documented copy of the backend's own constants; slide
  illustrations/video/audio remain genuinely live.
- `skill_up`: the entire hub's static content (`skill_up_data.dart`, 729
  lines) is hand-copied from the real static `index.html`; lesson content
  itself opens real backend static URLs. One minor, pre-existing copy
  inconsistency noted (hero text says "45+", a stat tile says "48") —
  inherited from the web page itself, not introduced by the Flutter port.
- `subscription`: `SubscriptionCatalog`'s prices/features are static,
  copied from `pro.html`; the amount actually charged always comes from
  the live `create_razorpay_order` response. The "can't check your current
  plan" banner (`subscription_screen.dart:80-83`) is **re-confirmed
  honest** — nothing in `lib/` reads or fabricates a current plan; this
  matches every prior phase's finding exactly.
- `roleplay`: topic configuration copied from the backend's
  `TOPIC_PRACTICE_CONFIG`; generated content/analysis/scoring is fully
  API-driven, with `'Good job practicing!'` as a documented, web-matching
  empty-feedback fallback (not an error-path fallback).
- `mock_tests`: `kQuizSubjects` and screen subtitle copy are static;
  questions and scoring are fully API-driven with `requireList`/
  `UnexpectedResponseException` on malformed responses — "mock" in the
  module name refers to a real practice-test product feature, not fake
  data.
- `employer`: `job_posting_catalog.dart`'s dropdown/skill options are
  static form configuration copied from the live form — not mock data.
- Assorted UI-only constants with no API involvement at all (GD's 5
  suggested-topic chips, resume template cards pointing at real backend
  static files, employer's "How It Works" steps, grammar's features
  strip, `home`/`splash`'s static labels and auth-driven routing) —
  confirmed not to mask anything, since nothing behind them is ever meant
  to come from an API.
- `aria_chat`'s entire welcome-question/action-route system
  (`aria_welcome_catalog.g.dart`, `aria_welcome_translations.g.dart`,
  `aria_welcome_section.dart`, `aria_action_routes.dart`,
  `aria_welcome_reply.dart`) — re-confirmed, independent of this
  engagement's earlier phases' conclusion: generated verbatim from
  production's own `static/js/BOTscript.js`, pure string/route mapping
  with no I/O, never substitutes for a failed API call (`tapWelcomeCard`
  never calls the API at all, matching the web's own `runWelcomeAction()`).
  TTS falling back to on-device voice on failure, and chat/voice error
  turns showing honest retry messages (not fake replies), are both
  correctly implemented, previously-understood, and reconfirmed here.
- `dashboard`'s empty states ("No activities started yet.", "No exercises
  completed yet.") and its hiding of empty job/payment sections are honest
  and intentional, matching the real web template's own `{% empty %}`
  blocks.
- Supplementary-navigation controllers that silently empty on failure
  (`adjacent_activities_controller.dart:32`,
  `sub_activity_siblings_controller.dart:33`) — Previous/Next links and
  sibling-position sidebar disappear quietly on an API error, but the
  screen's *main* content still shows its own proper error state. Minor,
  documented, intentional — keep.
- Activity-detail-from-list-page reconstruction
  (`activities_remote_datasource.dart:70,93,106-112`) — triggers for
  synthetic/negative ids (workshop/module cards) or an unexpected
  redirect target, always via a real HTTP call to the real list page, and
  throws `NotFoundException` if the id genuinely isn't found. Not an
  API-failure fallback.

## 6. Minor, debug-only risk worth one line (Classification 6)

**D1**: because `demoBypass` (§1) is a blanket route-guard bypass rather
than being scoped to only the 9 demo-wired modules, a developer who
enables Demo Mode and then manually navigates to a *non*-demo-wired
screen (e.g. Dashboard) while unauthenticated would reach it without a
redirect, after which that screen's real, unmocked datasource would
receive an unauthenticated response and (per §4's `isDashboardHtml`-style
guards, where present) correctly surface as a logout/error rather than a
crash. This is debug-only, requires a deliberate developer action, and
degrades safely — recorded as an uncertainty/low-priority item for the
project owner to decide on (e.g. scoping `demoBypass` more tightly), not a
confirmed defect requiring a fix.

## 7. Test-only fixtures (Classification 4 — explicitly out of scope, kept)

Confirmed present and healthy, named without further analysis per the
task's own instruction: `test/support/fake_http_client_adapter.dart`,
`fake_open_file_platform.dart`, `fake_path_provider_platform.dart`, and a
`_Fake*`/`Fake*` repository or service per feature module (full list
gathered by both research passes spans `activities`, all four AI modules,
`aria_chat`, `auth`, `bingo`, `certifications`, `dashboard`, `employer`,
`fill_blank`, `generic_writing`, `grammar`, `group_discussion`, `home`,
`jam`, `matching`, `mock_interview`, `mock_tests`, `resume`, `roleplay`,
`skill_up`, `subscription`, `timer_exercise` — every module except
`splash`, which has no tests at all). `test/core/demo/demo_navigation_test.dart`
specifically covers the Demo Mode system itself (§1/§2). None of these
were modified, weakened, or deleted — none needed to be, for an audit
phase.

## 8. Summary classification table

| # | Finding | Classification | Action this phase |
|---|---|---|---|
| Demo Mode (whole system) | Dev tooling, 9 modules, triple-gated | 3 | None — recommend keep |
| `/demo` route + Preview Demo button | Dev tooling entry points | 3 | None — recommend keep |
| D1 (blanket `demoBypass`) | Minor debug-only edge case | 6 | None — flagged for owner |
| `jobDetail` placeholder | Real conversion gap (no stable job id) | separate finding, not demo/mock | None — recorded only |
| F1 (`auth` profile, no page guard) | Could mask expired-session failure | 2 | None — fix recommended, test specified |
| C2 (`mock_interview` defaults) | Could mask malformed response | 2 | None — fix recommended, tests specified |
| C3 (`group_discussion` report) | Could mask malformed response | 2 | None — fix recommended |
| C4 (`employer` dashboard counts/status) | Could mask malformed response, mislabels live job | 2 | None — fix recommended |
| C1 (`resume`/`activities` text-gate) | Real, correct, brittle | 5 (flagged) | None — no evidence of current breakage |
| F2, F3, C5 | Lower-severity template-drift/edge cases | 2 (low) | None — awareness only |
| C6, A1, and §5's full list | Legitimate, intentional, web-matching | 5 | None — keep |
| Dead `DashboardDataParsing.fromJson` | Unused code, not demo data | separate, minor | None — cleanup candidate |
| Stale doc comments (3 locations) | Documentation only | separate, minor | None — doc pass candidate |
| Test fixtures (all modules) | Out of scope | 4 | None — kept |

**Zero findings fell into Classification 1** (confirmed obsolete
user-facing demo feature) — the one feature with "demo" in its name is
Classification 3, not 1, and should not be removed.

## 9. Remaining uncertainties and blockers

- **F1, C2, C3, C4 are reproducible, in-scope fixes** for a future phase
  (each has an exact file/condition and a concrete recommended change plus
  the regression test it needs) — none were implemented here, per this
  phase's explicit restriction.
- **C1's brittleness** has no current evidence of breakage; a decision on
  whether to add a smoke-test for it (rather than a code change) is owner
  territory, not resolved here.
- **`jobDetail`** remains blocked on the scraped job-recommendation data
  lacking a stable id — resolving this requires either the real
  `/activities/api/`-style JSON endpoint being deployed with an id field,
  or extending the scraper, neither of which is in scope for this audit.
- **D1** (blanket demo-mode route bypass) is a judgment call for the
  project owner, not a defect this report asserts needs fixing.
- No test was run this phase — nothing audited here required executing
  the suite to resolve; all findings came from direct source reading.

## Status

Audit complete. No source file was changed in either repository. Waiting
for approval before Phase 2 or any removal/fix work, per instruction.
