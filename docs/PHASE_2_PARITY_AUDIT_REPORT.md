# Phase 2 — Web-to-Mobile Parity Audit: Executive Summary

Read-only audit. Full row-by-row evidence lives in
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`; this document summarizes it.
Produced by direct source reading in both repositories plus five focused
research passes (one per feature area), each citing exact file:line
evidence on both the Django and Flutter sides. No application source was
changed to produce either document.

## 1. Documentation read first

All eight required reports existed and were read in full before this audit
began: `docs/PRE_UPDATE_BASELINE_REPORT.md`, `docs/PREVIEW_AND_STATIC_DATA_AUDIT.md`,
`docs/WEB_MOBILE_GAP_ANALYSIS.md`, `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md`,
`docs/PHASE_5_REGRESSION_REPORT.md`, `docs/PHASE_6_READINESS_REPORT.md`,
`docs/PHASE_10_TEST_ENVIRONMENT_AND_QA_REPORT.md`,
`docs/PHASE_11_MANUAL_QA_REPORT.md`. None was missing. Per instruction,
every claim in these reports was **re-verified against current source**
during this audit, not assumed still true — several findings below are
explicit *corrections* to earlier reports where current source now
disagrees (e.g. MCQ is no longer a JSON exception; web's AI Writing has no
failure-fallback to port; JAM is HTTP-only on web too, not WebSocket-based).

## 2. Actual counts, derived from current source

- **25 feature modules** under `lib/features/` (unchanged from Phase 0's
  baseline, re-confirmed).
- **66 named route constants**; only **one** (`RoutePaths.jobDetail`)
  still resolves to a placeholder screen.
- **267 test files**, **1885 individual test cases** (per Phase 0's
  freshly-executed baseline this engagement; not re-run this phase per
  the task's "running the suite is not required" instruction — no source
  changed, so nothing would differ).
- **16 HTML-parser files** across `activities`(2), `employer`(9),
  `resume`, `mock_interview`, `dashboard`, `jam`, `group_discussion` —
  confirmed each targets a real, live Django page, not invented data.
- **20 distinct Employer workflows** individually traced against Django's
  `jobs_app`/`accounts_app`/`employer_portal` views (full table in the
  matrix) — 15 confirmed fully equivalent, 2 uncertain (post/edit job
  form field count unverifiable from source alone), 2 fragile-but-correct,
  1 architecturally equivalent/uncertain on the logout path.
- **80+ distinct feature/workflow rows** in the parity matrix, tallying:
  **34 Fully equivalent, 31 Partial, 4 Missing, 10 Intentionally
  different, 1 Blocked, 3 Uncertain, 1 N/A.**

## 3. Overall parity assessment — and its evidence limitations

**The mobile app is a substantial, largely faithful, and in several places
more careful conversion of the web application — not a 100% equivalent
one, and not a superficial one either.** The majority of core, everyday
workflows (activity/exercise taking across all 6 graded types, AI Listening/
Writing, resume upload/history, JAM's full assessment flow, GD's real-time
WebSocket session, Roleplay, 15 of 20 Employer workflows, the full
subscription checkout *contract*, ARIA chat/navigation/voice) are
genuinely, verifiably equivalent — read directly from both codebases, not
inferred from the mobile side alone.

At the same time, this audit found **two confirmed, severe defects that
were not previously documented anywhere in this engagement**, both found
by reading the actual Django framework/view source rather than assuming
mobile's implementation was correct:
1. **Password reset cannot actually change a password** — the app shows
   success while the real Django form is never processed.
2. **Profile saves (Job Seeker and Employer) silently report success and
   lose the edit when the session has expired** — the read-side version of
   this was known; the **write-side silent-failure was not**, and is worse
   (real data loss, not just a confusing display).

**Evidence limitations, stated plainly**: this audit is source-read-based.
"Fully equivalent" entries reflect that the code paths match, not that
they were exercised end-to-end on a device with a real account — this
engagement has been repeatedly blocked on live-account access (see
Phase 10/11), and that blocker is unchanged. Three matrix entries are
explicitly marked **Uncertain** rather than guessed at (the Skill-Up
WebView cookie-sharing question, the Employer post/edit job form's true
field count against live production, and Employer's specific logout
endpoint usage) — each names the exact device/account/production check
that would resolve it.

## 4. Gap register, by priority

**P0 — Critical** (confirmed, not contingent on future drift; blocks
essential use or causes real data loss):

| # | Finding | Evidence | Rationale |
|---|---|---|---|
| P0-1 | Password-reset confirm step never processes the real Django form; app reports false success | `reset_password_screen.dart:81-114` vs Django's own `contrib/auth/views.py:268-298`, read directly | A core account-recovery workflow is completely non-functional today, with no error shown — this is not a theoretical risk, it was confirmed by tracing Django's actual view logic |
| P0-2 | Job Seeker profile save treats a session-expired redirect as success; the edit is silently lost | `profile_remote_datasource.dart:281` | Real, inevitable (every session eventually expires), confirmed data loss with a false-success message |
| P0-3 | Employer profile save — identical defect, same severity | `employer_profile_remote_datasource.dart:68` | Same as P0-2 |

None of these three required speculation — each was confirmed by reading
the exact code path that fails, not inferred from symptoms.

**P1 — High** (core workflow missing or materially incorrect):

| # | Finding | Rationale |
|---|---|---|
| P1-1 | Job Seeker/Employer profile **load** shows a blank, zero-valued profile on an expired session with no error or forced logout (read-side counterpart of P0-2/3) | Affects every profile view after the (currently unverified-on-device, 2-week-default) session lifetime |
| P1-2 | Employer application-status update can silently downgrade a real application's status and trigger a wrong email to a real candidate, if the status-scrape regex ever misses | Correct *today*, but the failure mode is unusually consequential (external communication to a real person) for a parsing fragility |
| P1-3 | Mock Interview has no face-detection proctoring at all | A paid, gated, scored feature's integrity control is simply absent on mobile |
| P1-4 | Mock Interview allows typed answers for theory questions where web requires voice-only | Weakens the interview's own stated integrity model |
| P1-5 | Mock Tests/AMCAT/CoCubes omit all proctoring/violation-tracking, inconsistent with Mock Interview's own (partial) implementation | These quizzes determine certificate eligibility; the inconsistency itself is notable |
| P1-6 | Skill-Up WebView-embedded mock-test lessons likely don't share the session cookie, likely don't record attempts toward certificate eligibility | High-impact *if* confirmed; explicitly marked Uncertain, needs a device check before any fix |
| P1-7 | Login/signup/employer-login error messages collapse to one generic string, hiding lockout, wrong-portal, and specific field-validation messages | Real usability regression on auth-critical flows; 429 rate-limit messages are lost entirely via the shared exception mapper |
| P1-8 | GD and JAM have a language picker wired in the *controller* but **never called from any UI** — confirmed via exhaustive grep, zero call sites | Two live, voice-driven features are English-only on mobile despite the server and even the Flutter data layer already supporting language selection |
| P1-9 | Dashboard's "View & Apply" job card is dead (routes to a placeholder) despite the real job id being present in the scraped HTML and a complete, tested job-detail+apply screen already existing elsewhere in the app, just not wired to it | **Concrete, small, Flutter-only fix** — see §5 |
| P1-10 | Mock Interview's `suitable_jobs` (the reward for passing — unlocked job recommendations) is deliberately never parsed or shown | The primary motivational payoff of passing a mock interview is invisible on mobile |

**P2 — Medium** (significant secondary capability, validation, or
error-handling difference):

Checkout UX gaps (no pre-payment GST breakdown, no payment reference shown
on a post-capture verify failure, 429/500/502 messages not passed through,
no "Switch to Free Plan" action, renewal-window awareness not surfaced);
a cluster of silent-zero-default HTML-parser fallbacks that are all
**correct today but fragile to template drift** (Dashboard stats, GD
report scores, JAM profile stats, Employer dashboard counts/status);
Subscription catalog copy drift (Free-plan's 2 restriction items omitted,
badge/button copy differences); Certifications' missing content-type check
on downloads and a lost 400-validation message; AI Speaking's missing live
transcript and elevator-pitch special case; registration's missing
optional fields (selfie, multi-language rows, dynamic education rows);
Timer exercise missing per-task audio playback and its coaching panel;
MCQ missing a "previous score" card; Home page's 5 missing lower marketing
sections; the GST invoice feature having no mobile equivalent (bounded
impact, since web itself only emails it); Grammar's missing language
switcher and hardcoded (currently-accurate) slide-deck counts; session
restoration never validating with the server on relaunch (the root cause
behind P0-2/3 and P1-1, listed here as its own item since fixing the
profile-side symptoms doesn't fix this underlying gap).

**P3 — Low** (cosmetic, stale comments, minor UX, low-risk cleanup):

Several stale doc comments now describing real, working screens as
placeholders (`route_paths.dart:244-248,16-20,278-282`,
`login_screen.dart:35`, `auth_remote_datasource.dart:21-25`,
`skill_up_screen.dart:704`, `sub_activity_detail_screen.dart:291-294`,
`docs/BACKEND_CONTRACT_dashboard.md:3`); one confirmed dead code path
(`DashboardDataParsing.fromJson`, unused outside tests); Activity list's
header count using a filtered rather than total figure; missing prev/next
activity links for Free-plan users; logout landing on `/login` instead of
Home (web's behavior).

## 5. Highest-impact finding worth calling out specifically: the `jobDetail` placeholder is NOT backend-blocked

Every prior phase in this engagement (including this current audit's own
earlier Phase 0/1 work) described `RoutePaths.jobDetail` as blocked on a
missing stable job identifier. **This audit found that framing was
incomplete and the gap is substantially smaller than previously believed:**

- The real web dashboard template embeds the job's `pk` directly in each
  recommended-job card's link `href`
  (`{% url 'employer_portal:job_detail' job.pk %}` → `/employer/jobs/<pk>/`,
  confirmed via `employer_portal/urls.py:9` mounted at `/employer/` in
  `business_english_lms/urls.py:50`) — it's simply not displayed as
  visible text, so the existing scraper never extracted it.
- Flutter **already has** a complete, independently-tested integration for
  that exact URL: `PublicJobDetailScreen` at route `/jobs/:id`, backed by
  `public_job_detail_remote_datasource.dart` (full GET parse + POST apply,
  with CSRF, field-error parsing, and duplicate-application detection) and
  `public_job_detail_html_parser.dart` — confirmed via
  `ApiEndpoints.publicJobDetail(pk) => '/employer/jobs/$pk/'`, an **exact**
  match to the dashboard's link target.
- The only missing piece: `RecommendedJob` has no `id` field, the
  dashboard's HTML parser doesn't extract `job.pk` from the href, and
  `recommended_jobs_section.dart:195` pushes the placeholder route instead
  of `RoutePaths.publicJobDetail(job.id)`.

**This is a small, concrete, well-evidenced, Flutter-only fix** — not a
backend dependency, not speculative. The same wiring also resolves P1-10
(Mock Interview's hidden job recommendations), since both features land
on the same already-built screen.

## 6. Blocked and uncertain items

- **P1-6** (Skill-Up WebView cookie sharing) — needs a device test with a
  real account; not resolvable from source alone.
- **Employer post/edit job's true field count** — Flutter is documented as
  targeting a live-production form with ~46 fields, which diverges from
  the committed repo's 23-field model; cannot be confirmed correct or
  incorrect from source alone, needs a live-production comparison.
- **Employer logout** — no employer-specific logout call was found; it may
  correctly share the generic logout path, or may be a genuine gap; not
  conclusively traced.
- **Current-plan/expiry visibility** — technically resolvable via scraping
  (the data renders in HTML Flutter already fetches) but genuinely absent
  from any JSON contract; flagged to the backend owner as before, with the
  added, more precise note that a scrape-based interim fix is now a
  realistic option given the rest of the app's established pattern.
- **Session restoration's real-world behavior** — the mechanism is fully
  traced in source, but its actual behavior across a real app restart
  after a real session expiry has never been verified on a device, per
  every QA phase in this engagement (10, 11) reaching the same blocker.

## 7. Existing features that must be preserved (not touched this phase, explicitly confirmed healthy)

Everything marked "Fully equivalent" or "Intentionally different" in the
matrix — 44 entries total — represents real, working, in most cases
test-covered functionality that this audit explicitly confirmed is
**not** broken and should not be disturbed by any future phase chasing the
gaps above. Notably: all 6 exercise-submission types' scoring logic, GD's
real WebSocket implementation, JAM's full assessment flow, Roleplay's full
flow, 15 of 20 Employer workflows, Resume upload/history, AI Listening's
anti-replay token mechanism, the subscription checkout *contract* (its
security-critical signature verification and anti-tampering logic is
untouched and intact on both sides), and ARIA's chat/navigation/voice
system (re-confirmed, not re-litigated, per the standing instruction not
to re-open the stall-watchdog question without a product decision).

## 8. Tests and manual verification needed before claiming completion

- **P0-1/P0-2/P0-3** each need a new regression test once fixed: a
  data-source test asserting a login-page/redirect response is rejected
  (not silently treated as success), mirroring the pattern
  `DashboardRemoteDataSource` already establishes correctly.
- **P1-9** (jobDetail wiring) needs: a parser test asserting `job.pk` is
  extracted from the recommended-jobs `href`, and a widget test confirming
  the card navigates to `RoutePaths.publicJobDetail(id)`.
- **P1-6** (Skill-Up WebView) needs an actual device test with a real
  account before any fix is attempted — the finding is currently Uncertain
  by design, not confirmed.
- **No automated test was run this phase** (not required per the task's
  own instruction, and no source was changed that would alter the existing
  1885/1885 baseline recorded fresh in Phase 0 of this audit).
- **No manual QA was performed or claimed this phase** — this remains
  blocked exactly as Phase 10/11 documented (no usable test account); this
  audit did not attempt to work around that blocker, consistent with every
  prior phase's handling of it.

## 9. Recommended implementation sequence (for a future, separately approved phase — not started here)

1. Fix the three P0 items (password reset confirm, both profile saves) —
   small, well-scoped, code-only fixes with clear regression tests
   specified above.
2. Fix P1-1 (profile load page-identity check) alongside P0-2/3 since it's
   the same file and the same root cause.
3. Wire the jobDetail fix (P1-9) and the Mock Interview job-recommendations
   fix (P1-10) together, since both consume the same existing screen.
4. Wire the existing GD/JAM language pickers (P1-8) — UI-only, no backend
   dependency, low risk.
5. Fix P1-2 (employer application-status silent downgrade) — a
   defensive code change, not a redesign.
6. Everything else in the gap register, roughly in P1 → P2 → P3 order,
   with P1-3/4/5/6 (Mock Interview/Mock Tests proctoring) explicitly
   flagged as needing a **product decision** before engineering work
   starts, not an engineering judgment call.

## 10. Final safety checks

- **No Flutter or Django application source was modified.** Confirmed via
  `git status --short` in both repositories before and after this phase's
  work — identical to the state Phase 1 (static-data audit) left them in.
- **Pre-existing dirty/untracked files were preserved** in both
  repositories — the same modified/untracked file lists from every prior
  phase remain unchanged; this phase added exactly two new files (this
  report and the parity matrix).
- **No secrets or signing material were read or exposed.**
  `android/key.properties` was not touched, read, or referenced by any
  research agent or by this synthesis.
- **No production data was modified.** No network request was made to
  production, the local dev server, or any backend during this phase —
  every finding came from static source reading in both repositories.
- **Documentation files created this phase**:
  `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`,
  `docs/PHASE_2_PARITY_AUDIT_REPORT.md`.
- **Parts of the audit that could not be completed, and why**: three
  matrix entries remain Uncertain (§6) because they require a live device,
  a real account, or a live-production comparison this engagement does not
  have access to — each is named precisely rather than guessed at.

## Status

**This phase is complete as a read-only audit.** The mobile app is not
claimed to be "100% equivalent" to the web app — the evidence does not
support that claim, and this report does not make it. It is, based on
direct evidence from both codebases, a largely faithful conversion with a
specific, now well-documented set of gaps, three of which (P0-1/2/3) are
severe enough to warrant priority attention before any broader feature
work continues. No fix, removal, or cleanup was implemented. Awaiting
approval before Phase 3 or any remediation work.
