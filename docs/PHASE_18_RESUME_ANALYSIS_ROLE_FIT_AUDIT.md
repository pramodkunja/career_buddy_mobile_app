# Phase 18 — Resume Analysis Limit & Role-Fit Picker Audit

**Audit-only phase.** No Flutter `lib/`/`test/` file was created, edited, or
deleted. Neither Django tree was modified. No implementation occurred. See
§9 for the full confirmation.

## 1. Executive summary

Both features are **real, confirmed, optional** additions in the updated
backend, and both are **fully reproducible from the mobile app with zero
backend changes** — a materially better position than a typical gap,
because the two mechanisms involved (a session key set by a GET query
param, and a static JSON role catalog) require no new API, no new field,
and no product negotiation with the backend team.

- **Free analysis limit**: already a hard 4-analysis cap for Free-plan
  users only (paid plans are unlimited), counted by successful analyses
  only (a failed upload or failed AI call is free). Flutter already
  surfaces the hard-block message correctly (confirmed, not just
  probable). The one real gap — a proactive "3 of 4 left" indicator before
  the limit is hit — is addressable as a small, client-only change: the
  exact text already exists in a page Flutter's own CSRF-priming logic
  already fetches today, just currently discarded.
- **Role-fit picker**: fully optional and inert when skipped (confirmed —
  the gate only activates when a `role`/`dept` session key exists, which
  only a deliberate query-param request ever sets). The entire feature —
  role list, role selection, and the resulting pass/fail gate on the AI
  interview — can be reproduced by Flutter with no backend change: the
  role catalog is either a public static JSON asset or an existing
  no-login JSON API, and "picking a role" is just one extra GET to a page
  Flutter already requests, before the existing upload call.

Both are scoped as new, optional client-only feature work for a future
phase, not bug fixes — and both carry a product-sizing question (the full
role catalog is large; a smaller curated list may be more appropriate for
a first mobile version) that should be decided before implementation, not
during it.

## 2. Relevant source files

**Flutter** (`Mobile_app/lib/features/resume/`):
- `data/resume_remote_datasource.dart` — `uploadAndAnalyze`, `reanalyze`,
  `getHistory`, `_ensureCsrfCookie` (GETs `resumeBuilderHome` only when no
  CSRF cookie exists yet — see §3).
- `data/resume_html_parser.dart` — every scrape function; no function
  exists yet for `parses_left`/`parse_limit` or any role-fit-specific
  markup.
- `data/resume_repository_impl.dart`, `domain/repositories/resume_repository.dart`,
  `domain/entities/resume_analysis.dart`, `domain/entities/resume_history_item.dart`.
- `presentation/controllers/resume_builder_controller.dart` — `ResumeIdle`
  only carries an optional `errorMessage`; no count/plan field exists.
- `presentation/screens/resume_builder_screen.dart` — renders
  `errorMessage` via a plain `_ErrorBox`; no role picker, no counter badge.
- `core/network/api_endpoints.dart:455-462` — `resumeBuilderHome =
  '/resume-builder/'`, `resumeJobMatch = '/resume-builder/match/'`,
  `resumeReanalyze(id)`, `resumeHistory`.
- `core/errors/{exceptions,failures,exception_mapper}.dart` — confirmed
  `ValidationException`'s message flows verbatim into `ValidationFailure.message`
  (see §3).

**Django, updated repo** (`royalStaffing_CB01/`):
- `career_app/views.py:163-254` — `_can_access_resume`,
  `FREE_RESUME_PARSE_LIMIT`, `_resume_parses_left`, `_remember_target_role`,
  `_check_role_fit`, `_skillup_url_for`.
- `career_app/views.py:814-954` — `resume_builder_home`, `_builder_context`,
  `_parse_limit_reached`, `PARSE_LIMIT_MSG`, `resume_job_match`.
- `career_app/views.py:1077-1116` — `resume_start_interview`'s role-fit gate.
- `career_app/role_fit.py` (211 lines, full read) — `_roles()`,
  `_template_roles()`, `find_role`, `assess_role_fit`.
- `career_app/resume_roles.py` (1555 lines — sampled, not read in full;
  `client_payload()` confirmed as the predefined-template role source).
- `career_app/manual_resume_views.py:87-111` — `roles_api` (`@require_GET`,
  no login required).
- `templates/resume_builder.html:184-194` — the `parses_left`/`parse_limit`
  badge markup.
- `templates/resume_match_result.html:215-317,535-561` — role-fit badge,
  interview-lock notice, matching/missing-skills swap.
- `templates/landing.html:7612,8729-8743` — the role-card picker modal and
  `pickRole()`'s query-param construction.
- `static/data/it_departments.json` (52,659 bytes), `static/data/nonit_departments.json`
  (62,664 bytes) — the full role catalog, served as plain static assets
  (`{% static %}`), confirmed by direct file listing.

**Django, original repo** (`Career_Buddy_LMS/`): `career_app/views.py:974`
(`PASSING_SCORE = 70`, unrelated to this phase but cross-checked in Phase
17 — mentioned only to confirm the original repo has no equivalent of
either feature; `grep` found no `FREE_RESUME_PARSE_LIMIT`/`role_fit`/
`resume_roles` in it).

## 3. Verified free-analysis-limit contract

- `FREE_RESUME_PARSE_LIMIT = 4` (`views.py:173`).
- **Scope — free users only**: `_resume_parses_left(user)` returns `None`
  (meaning unlimited) for any non-`'free'` plan (`views.py:176-181`); paid
  users never see the badge or the block (confirmed by the template's own
  `{% if parses_left is not None %}` guard, `resume_builder.html:191`).
- **What counts**: `JobDescription.objects.filter(user=user).count()` — one
  row per *successful* analysis. The row is created at `views.py:906`,
  **after** text extraction, validation, and the AI call all succeed. A
  failed upload (unreadable file, failed AI call) returns an error
  *without* creating a row — confirmed by direct read: every error branch
  in `resume_job_match` (`views.py:850-903`) returns before reaching the
  `JobDescription.objects.create()` line. **Re-analysis also counts** (the
  module comment at `views.py:170-172` states this explicitly, and
  `resume_reanalyze`, read separately, follows the same create-after-success
  pattern).
- **What happens at the limit**: the very next POST to `resume_job_match`
  is short-circuited *before* reading the uploaded file at all
  (`_parse_limit_reached` check at `views.py:845-846`) and re-renders the
  upload form with `error=PARSE_LIMIT_MSG` — *"You have used all 4 Resume
  Parsing analyses included in the Free plan. Upgrade your plan to keep
  analysing resumes and unlock the AI Interview."*
- **Data available to the client**: `_builder_context()` (`views.py:823-829`)
  puts `parses_left` and `parse_limit` into the template context for
  `resume_builder_home`'s GET response — rendered as a stable, scrapeable
  badge: *"Free plan: `{{ parses_left }}` of `{{ parse_limit }}` resume
  analyses left"* (`resume_builder.html:191-194`). **This is the real,
  authoritative, server-computed value for this exact request** — not
  something Flutter would be calculating from local history. There is
  **no JSON API** for any of this (every one of these views calls Django's
  `render()`, confirmed directly, matching `resume_html_parser.dart`'s own
  top-of-file doc comment).
- **Current mobile behavior, confirmed (upgraded from the Phase 15 gap
  analysis's "Probable" to Confirmed this phase)**: the hard-block message
  already surfaces correctly end-to-end. `resume_html_parser.dart`'s
  `parseResumeBuilderError()` scrapes the `.error-box` text (which is
  exactly `PARSE_LIMIT_MSG` when the limit is hit) into a
  `ValidationException(fieldErrors, message)`
  (`resume_remote_datasource.dart:54-57`); `ExceptionMapper.map`
  (`exception_mapper.dart:16`) passes that `message` through verbatim into
  `ValidationFailure`; `resume_builder_controller.dart:45` surfaces
  `failure.message` as `ResumeIdle.errorMessage`; the screen renders it via
  `_ErrorBox` (`resume_builder_screen.dart:112-114`). Traced the full chain
  directly — no gap here.
- **The one real gap — proactive remaining-count display**: `parses_left`/
  `parse_limit` are never scraped or surfaced anywhere in Flutter today
  (confirmed by a zero-hit grep across `lib/features/resume/` for
  `parses_left|parseLimit|parse_limit`). **A genuinely small client-only
  fix is feasible**: `ResumeRemoteDataSource._ensureCsrfCookie()`
  (`resume_remote_datasource.dart:115-118`) already does `GET
  resumeBuilderHome` — the exact page containing this badge — but only
  conditionally (skipped once a CSRF cookie already exists from any
  earlier request this session) and its response body is discarded today.
  A reliable proactive counter needs its own deliberate GET of
  `resumeBuilderHome` each time the upload screen loads (not reusing the
  conditional CSRF-priming call), parsing out the badge text with one new,
  narrowly-scoped regex function in `resume_html_parser.dart` — no backend
  dependency.
- **Concurrency — an unresolved, backend-only risk, not fixable from
  Flutter**: `_parse_limit_reached()`'s check and the later
  `JobDescription.objects.create()` are two separate, unsynchronized
  statements (`views.py:845` and `906`) with the AI analysis call in
  between — a genuine TOCTOU window exists for two near-simultaneous
  requests (two tabs, two devices, or a double-tap) to both pass the check
  before either creates its row, which could let a Free user exceed 4.
  This contrasts with the existing Razorpay webhook's own
  `transaction.atomic()` + unique-constraint protection against a
  comparable race (`views.py:787-800`), confirmed by direct comparison —
  i.e. this codebase already knows how to close this kind of race
  elsewhere, just hasn't applied the same pattern here. **This is a
  backend-side observation for awareness, not something this phase
  recommends fixing** (Django is read-only this phase, and the fix would
  live entirely server-side regardless).

## 4. Verified role-fit-picker contract

- **Where it appears, and that it's optional**: a role-card picker modal
  on the landing page (`templates/landing.html:7612,8729-8743`). Tapping
  "Resume Parsing" inside that modal builds `{role, dept, track}` from the
  picked card and navigates to `{% url 'resume_builder' %}?role=...&dept=...&track=...`
  — i.e. a **GET to the exact same `resume_builder_home` endpoint** Flutter
  already calls (`ApiEndpoints.resumeBuilderHome`). `_remember_target_role`
  (`views.py:200-214`) only populates `request.session['rb_role']` when
  both `role` and `dept` query params are present and non-trivial
  (`_slug(role) and _slug(dept)`) — **confirmed optional and inert when
  skipped**: no query params → no session key → every downstream check
  (`_check_role_fit`, the interview gate) short-circuits to "no role
  picked," leaving the existing funnel byte-for-byte unchanged.
- **Available roles and representation**: roles come from **two
  overlapping sources**, both confirmed by direct read of `role_fit.py:50-71`:
  1. `static/data/it_departments.json` / `nonit_departments.json` — the
     full career-path catalog (the landing page's own department/role
     browser), 52,659 / 62,664 bytes, confirmed served as **plain public
     static files** (`{% static %}` in `landing.html:6742`, confirmed on
     disk) — fetchable directly, no Django view or auth involved.
  2. `career_app/resume_roles.py`'s `client_payload()['roles']` — the
     smaller set of roles with a full predefined manual-resume-builder
     template, also exposed as **clean JSON** via the existing, no-login
     `roles_api` view (`manual_resume_views.py:87-111`,
     `@require_GET`, rate-limited per IP but requires no session).
  A role is represented as `(track, dept, role)` — `track` is `'tech'` or
  `'nonit'`; `dept`/`role` are plain display strings, slugified
  server-side for lookup (`role_fit.py:46-47`). **Not invented** — this is
  the literal shape `find_role()` looks up by.
- **Effect on analysis/scoring/results**: `_check_role_fit` (`views.py:217-240`)
  runs inside `resume_job_match`, right after a successful analysis.
  `assess_role_fit` (`role_fit.py:176-211`) computes a skill-word-coverage
  score (`MIN_COVERAGE = 0.25`, plus a recruiting-specific function-term
  check) against the picked role's required skills. If the resume doesn't
  meet that bar, the **same `analysis` dict already being rendered is
  mutated in place**: `match_percentage` is forced to `0` and `analysis`
  (the summary text) is replaced with a role-specific explanation
  (`views.py:228-238`) — meaning **Flutter's existing parser would already
  correctly reflect a role-fit failure's score and summary without any new
  scraping**, since `matchPercentage`/`summary` are the same two fields it
  already reads (`resume_html_parser.dart:39-40,55-56`). The
  matching/missing-skills chip lists are also swapped to the role's own
  skill set when a role was picked and recognized
  (`resume_match_result.html:261-292`) — same `chip-found`/`chip-gap`
  markup Flutter already scrapes, so this also needs no new regex for the
  core lists. A role-specific match badge and a distinct "doesn't match
  this role" lock notice (`resume_match_result.html:215-227,309-317`) are
  additional, nice-to-have elements with no existing Flutter scrape —
  optional for a first implementation.
- **Server-side interview gate**: `resume_start_interview`
  (`views.py:1077-1116`) checks `target, fit = session['rb_role'],
  session['rb_role_fit']`; if a role was picked, is recognized
  (`fit['known']`), and the fit failed, it calls
  `messages.info(...)` with *"This resume does not match the {role} role
  you picked, so the AI Interview for that role is locked..."* and
  redirects to `resume_job_match` — **the exact same `messages.info()` +
  redirect pattern** as the already-handled ATS-90 gate (confirmed by
  direct side-by-side read of both blocks, `views.py:1089-1091` and
  `1092-1095`). Flutter's existing generic flash-message scraper (the same
  mechanism already confirmed working for the ATS-90 gate per the Phase 15
  gap analysis) would already surface this correctly **if** the picker is
  ever implemented — no new backend-message-handling code needed.
- **When no role is selected**: `target`/`fit` are both `None`/absent; the
  `if target and fit and not fit.get('ok')` gate in
  `resume_start_interview` is false; the funnel behaves exactly as it does
  today. **Confirmed**: existing Flutter resume-analysis behavior requires
  zero changes to keep working for a user who never sees a role picker.
- **Reproducibility without a backend change**: confirmed fully — the
  entire feature is: (1) show a role list (from one of the two JSON
  sources above), (2) GET `resumeBuilderHome` with `?role=&dept=&track=`
  once picked (session-setting side effect only — the response body isn't
  even needed), (3) proceed with the existing `uploadAndAnalyze` call
  unchanged. No new endpoint, field, or Django code is required.

## 5. Current mobile vs. updated website — side-by-side

| | Updated website | Current Flutter | Gap |
|---|---|---|---|
| Hard 4-analysis block | Shown via inline form error | Shown via scraped `.error-box` → `_ErrorBox` | **None** — confirmed working |
| Proactive "N of 4 left" | Badge on the upload page | Not shown anywhere | **Missing** — small, client-only fix available |
| Role picker | Landing-page modal, optional | Does not exist | **Missing** — new, optional feature; reproducible without backend work |
| Role-fit result badge/lock notice | Shown on the result page | N/A (no picker exists) | **Missing**, but only relevant once the picker exists |
| Behavior with no role picked | Unchanged funnel | Unchanged funnel | **Aligned** by construction |

## 6. Recommended implementation scope (for a future, separately-approved phase)

**A. Free analysis limit — small, self-contained, client-only**
- Existing behavior: hard block already correct (§3); nothing to fix there.
- Verified backend contract: `parses_left`/`parse_limit` rendered in
  `resume_builder_home`'s own HTML, Free-plan-only, authoritative per
  request; no JSON API exists or is needed.
- Confirmed mobile gap: no proactive counter.
- Recommended fix: one new parser function (e.g.
  `parseResumeParsesLeft(html)` returning a nullable `(left, limit)` pair,
  `null` meaning "badge absent" — correctly covering both "unlimited plan"
  and "parse failure" cases without guessing which), one new datasource
  method doing a dedicated `GET resumeBuilderHome` (independent of the
  CSRF-priming call, which must stay conditional and not be repurposed for
  this), and a small badge/banner in `resume_builder_screen.dart`'s idle
  state. Sized as a small phase on its own.
- Backend dependency: none. Unresolved question: whether to also surface
  the backend's own TOCTOU race (§3) as a known limitation in that future
  phase's write-up — a documentation note only, since no Flutter change
  can close a server-side race.

**B. Role-fit picker — larger, genuinely new feature, needs a product
decision first**
- Existing behavior: feature does not exist in Flutter at all.
- Verified web interaction and contract: §4, in full.
- Confirmed mobile gap: total — no picker, no role data, no role-fit
  display.
- Recommended approach: (1) a product decision on role-list scope — the
  full two-track department catalog (~115KB combined JSON, large) vs. the
  smaller predefined-template subset via `roles_api` (simpler integration,
  fewer roles) vs. a curated short list chosen for mobile; (2) a role-pick
  screen/step in the resume flow; (3) the one-GET-before-upload mechanism
  (§4); (4) optionally, the role-fit badge/lock-notice scraping for full
  parity, or deferring those as a follow-up polish item since the core
  score/summary already flow through existing scraping.
- Product decision needed before implementation: **which role data source
  to use**, and whether this is worth building at all given it's
  explicitly optional on the web and the core funnel already works without
  it — this phase takes no position on priority, only confirms
  feasibility.

## 7. Required regression tests and acceptance criteria (for the future implementing phase — none written this phase)

**Free analysis limit:**
- Parser: a `resume_builder_home` HTML fixture with the badge present at
  `3 of 4` → parses `(left: 3, limit: 4)`; a fixture with the badge absent
  (paid-plan fixture) → parses `null`, not a guessed value; a malformed/
  unexpected fixture → `null`, never throws.
- Datasource: the dedicated GET is made with the expected endpoint/method,
  independent of CSRF-cookie state.
- Controller/screen: the badge renders exactly the parsed left/limit
  values when present; renders nothing when `null`; existing hard-block
  error-message test(s) continue to pass unmodified (regression guard that
  this addition didn't disturb the already-working path from §3).

**Role-fit picker:**
- Role-data parsing: a fixture of whichever JSON source is chosen parses
  into a list of `(track, dept, role)` entries without data loss.
- Request construction: picking a role builds the exact `?role=&dept=&track=`
  query string Django expects (URL-encoded, matching `_remember_target_role`'s
  parsing); skipping the picker sends **no** such request and the existing
  `uploadAndAnalyze` call is completely unaffected (byte-for-byte the same
  request as today) — this is the single most important regression
  guarantee, since it's the one that keeps every existing resume-analysis
  test passing unmodified.
- Result handling: a role-fit-failed fixture (`match_percentage: 0`, the
  role-specific summary text) parses through the *existing* analysis
  parser correctly, with no special-casing needed; if the role-fit badge/
  lock-notice is implemented, its own fixtures (present/absent) are
  covered separately.
- Interview-gate flash message: a `resume_start_interview` redirect
  carrying the role-fit-blocked message is scraped by the existing generic
  flash-message mechanism — ideally confirmed with one fixture-based test
  even though the mechanism itself needs no code change, purely to lock in
  the exact message text against future backend changes.

## 8. Blockers, product decisions, unresolved uncertainties

- **Product decision (role-fit scope)**: see §6B — which role-data source
  to use, and whether this optional feature is worth the larger
  implementation effort versus the smaller free-analysis-limit fix.
- **Unresolved, backend-only**: the free-analysis-limit TOCTOU race (§3) —
  noted for awareness, explicitly not something this phase or Flutter can
  resolve.
- **Not independently re-verified this phase** (reasonable interpretation,
  not a confirmed fact): the precise visual rendering of the role-fit
  badge/lock-notice was read from template source only, not rendered live
  — their exact conditions (`views.py`/template `{% if %}` guards) are
  confirmed from source, but no live HTTP response was captured this
  phase for any of these pages (see §9).
- **`resume_roles.py`** was sampled (via `client_payload()`'s call site and
  the file's line count) rather than read in full (1,555 lines) — its
  exact role count/content was not enumerated this phase; only its
  existence, its JSON-API exposure via `roles_api`, and its relationship
  to `role_fit.py`'s `_template_roles()` were confirmed.

## 9. Git status and confirmation

```
git status --short   (Mobile_app/)
```
shows only the same pre-existing modified/untracked files carried over
from Phases 13-17 (parity-matrix, MCQ/Matching, auth-error-message, and
Mock Interview changes, plus their reports) — **zero new or modified
entries from this phase**. No `lib/` or `test/` file was touched. Both
Django trees (`royalStaffing_CB01/`, `Career_Buddy_LMS/`) were read-only
throughout — every file read this phase has a modification time
predating this session (verified via `stat`), and `Career_Buddy_LMS/`'s
own pre-existing uncommitted state (unrelated to this audit) was left
exactly as found. No live HTTP request was made to any server, production
or otherwise — every finding in this report comes from static source
reading.

---

Phase 18 is complete. Both features are confirmed real, optional, and
implementable without backend changes. No implementation was started.
Awaiting explicit approval before beginning Phase 19 or any implementation
work.
