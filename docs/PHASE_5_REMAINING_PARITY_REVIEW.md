# Phase 5 — Remaining Feature-Parity Review and Prioritization

Audit-only phase. No application source, test, or Django file was
modified. Only the parity matrix was corrected where current source
proved a classification stale (details in §6).

## 1. Audit scope and evidence inspected

Read in full before any classification: `docs/PRE_UPDATE_BASELINE_REPORT.md`,
`docs/PREVIEW_AND_STATIC_DATA_AUDIT.md`,
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`,
`docs/PHASE_2_PARITY_AUDIT_REPORT.md`, `docs/PHASE_3_CRITICAL_FIXES_REPORT.md`,
`docs/PHASE_4_JOB_DETAIL_WIRING_REPORT.md`.

Git status checked first in both repositories — both confirmed byte-identical
to the state Phase 4 left them in (Mobile_app: the same 16 modified
source/test files from Phases 3-4 plus the same untracked doc/module set;
Career_Buddy_LMS: the same 3-modified/3-untracked state present since
Phase 1 of this engagement). No one else has touched either repository
between phases.

Per instruction, no finding below was carried forward on trust alone.
Every item was re-checked against current source this phase: the four
Phase 3/4 fixes were spot-verified still present (grep-confirmed:
`isProfileHtml`, `isEmployerProfileFormHtml`, `passwordResetSetPassword`,
`RecommendedJob.id` + its conditional navigation all still in place), and
a representative cross-section of the still-open Phase 2 gap-register
items was independently re-read from the actual current files (not
assumed from the old report's line numbers) — detailed per-item below.
`flutter analyze` and the full `flutter test` suite were also re-run fresh
as part of this verification (not required by this audit-only phase, but
cheap and directly useful for confirming no drift): **clean analyze,
1898/1898 passing**, identical to Phase 4's own reported result.

## 2. Confirmed fixes from Phases 3 and 4 — re-verified, not assumed

| Fix | Re-verification performed this phase |
|---|---|
| Password-reset confirm now follows the real 2-URL Django sequence | `grep -c passwordResetSetPassword` → 4 occurrences still present in `password_reset_remote_datasource.dart` |
| Job Seeker profile load/save session-expiry handling | `grep -c isProfileHtml` → 4 occurrences still present in `profile_remote_datasource.dart` |
| Employer profile load/save session-expiry handling | `isEmployerProfileFormHtml` confirmed present in both `employer_profile_html_parser.dart` and `employer_profile_remote_datasource.dart` |
| Dashboard "View & Apply" wired to the real job-detail screen | `RecommendedJob.id` field and `recommended_jobs_section.dart`'s conditional `onPressed: job.id == null ? null : () => context.push(RoutePaths.publicJobDetail(job.id!))` both confirmed present |

All four remain intact, all four are reflected in a clean `flutter
analyze` and a full passing test suite. **No regression found.**

## 3. Ranked list of remaining parity gaps

Severities use this phase's stated scale: **P0** critical
security/data-integrity/false-success; **P1** important broken workflows
or substantial functional differences; **P2** partial functionality,
fragile parsing, or important UX gaps; **P3** cosmetic/stale/low-impact.

**No P0 items remain.** The three confirmed false-success defects
(password reset, both profile saves) were the only items that met this
phase's strict P0 bar — a *currently* manifesting false-success condition,
not a latent one — and all three are fixed and re-verified above.

### P1 — important broken workflows / substantial functional differences

| # | Feature / workflow | Evidence (re-checked this phase) | Web vs. mobile behavior | Status | Suggested minimal remediation | Regression tests needed | Live-backend testing needed? |
|---|---|---|---|---|---|---|---|
| P1-1 | Employer application-status silent downgrade | `employer_application_detail_html_parser.dart:42`: `status: statusMatch?.group(1) ?? 'applied'`, re-confirmed present and unchanged. The edit screen seeds its dropdown from this value and re-POSTs it alongside any notes-only edit. | Web: a status *change* triggers a real candidate email. Mobile: if the status-parse regex ever misses (currently it doesn't — re-matches today's template), an employer editing only notes would silently re-send `status=applied`, possibly downgrading a live application and emailing the candidate incorrectly. | **Confirmed, latent** (correct against current markup; the risk is in what happens *if* it drifts) | Don't let a notes-only save implicitly carry a (possibly wrong) status; only send `status` when the user actually changed it, or validate the scraped value against a known-good set before using it as a default | A parser test for an unrecognized/missing status-select value; a screen/controller test asserting a notes-only save does not include a status field (or includes the server's own echoed value, never a locally-defaulted one) | No — reproducible from a crafted HTML fixture |
| P1-2 | Mock Interview: no face-detection proctoring | `mock_interview_controller.dart:15-39` re-read: confirmed `FACE_NOT_DETECTED`/`MULTIPLE_FACES` are still never reported; no face-detection call anywhere in the camera service | Web uses `face-api.js` for continuous face-presence checking during the interview. Mobile has none. | **Confirmed, unchanged** | Out of narrow-fix territory — needs a product/engineering scoping decision (a native face-detection library, camera-frame sampling cadence, battery/perf tradeoffs), not a small patch | N/A until scoped | Yes — proctoring behavior needs device camera testing, not just source review |
| P1-3 | Mock Interview: typed answers allowed for voice-only theory questions | `mock_interview_question_view.dart:12-19,167-184` re-read: a `TextField` is still always available alongside on-device STT | Web only accepts speech for theory questions (no visible text input). Mobile lets a candidate type or paste an answer. | **Confirmed, unchanged** | A product decision first (is this an intentional accessibility allowance, or an integrity gap to close?) — not purely an engineering call | Depends on the decision | No |
| P1-4 | Mock Tests/AMCAT/CoCubes: no proctoring, inconsistent with Mock Interview | `mock_test_intro_view.dart:13-18` re-read: doc comment still explicitly states proctoring is "deliberately" omitted, with its own stated reasoning (fullscreen/visibilitychange "can't do what the web does" on mobile) | Web enforces fullscreen + tab-switch detection with auto-submit after 3 violations for these quizzes, which count toward certificate eligibility. Mobile has none, while Mock Interview (a different feature) *does* track violations. | **Confirmed, unchanged** | Product decision: either bring quiz proctoring up to Mock Interview's level, or explicitly accept the asymmetry — not a unilateral engineering fix | Depends on the decision | No for the gap itself; yes if a fix is attempted, to confirm UX |
| P1-5 | GD/JAM language picker not wired to any UI | Grepped exhaustively this phase: **zero** call sites of `.setLanguage(` anywhere under `lib/features/group_discussion/` or `lib/features/jam/`. The controller methods exist and work (confirmed by their own unit tests); nothing in any screen calls them. | Web lets a user pick a practice language for GD/JAM sessions. Mobile always runs both in English, with no picker shown, despite the plumbing already existing. | **Confirmed, unchanged** | Add a language-picker UI control to the GD/JAM session-start screens (reusable pattern already exists elsewhere in this app, e.g. ARIA's/Roleplay's own language pickers) calling the existing `setLanguage` methods — no backend change needed | A widget test per screen confirming the picker is present and calls `setLanguage`; a controller test (if not already covered) confirming the chosen language is sent on session start | No — purely a UI wiring gap |
| P1-6 | Skill-Up WebView-embedded mock-test lessons may not share the session cookie | Re-read `skill_up_data.dart`'s WebView lesson entries and re-grepped for `WebViewCookieManager`/`setCookie` across `lib/` — still zero hits | Web's same-origin iframe sends the session cookie automatically, so an attempt counts toward certificate eligibility. Mobile's WebView has no confirmed cookie-sharing mechanism. | **Uncertain — not confirmed either way without a device test** (carried forward unchanged from Phase 2; no new evidence this phase) | Cannot be minimally remediated without first confirming the defect on a device | A device-based manual check first; automated regression tests only make sense once the actual behavior is confirmed | **Yes — this is the one item in this list that is specifically blocked on live/device verification, not just re-auditable from source** |
| P1-7 | Mock Interview `suitable_jobs` (job recommendations) not parsed or shown | Re-read `mock_interview_html_parser.dart:49-56` and `interview_analytics.dart:30`: confirmed still not parsed. **New finding this phase**: both doc comments still cite the *reason* as "this app has no Job Detail screen to route it to yet" — that reasoning is now **factually stale** post-Phase-4 (a real job-detail screen and a proven href→id extraction technique both now exist), even though the underlying gap (the feature itself is still unbuilt) is still accurately described as open. | Passing the mock interview (score ≥70) unlocks job recommendations on web — the primary reward for passing. Mobile shows nothing. | **Confirmed, unchanged** (functionally) / **stale reasoning in 2 doc comments** (a P3-scale documentation issue, separate from the P1-scale functional gap) | Parse `suitable_jobs` from `resume_analytics.html` (new parsing work — different page/section than Dashboard's recommended jobs, needs its own markup verification) and wire navigation through `RoutePaths.publicJobDetail`, reusing Phase 4's now-proven pattern | A parser test for the new `suitable_jobs` section (valid data, missing section, malformed job entries); a widget test confirming navigation; update to the matrix's existing "see Phase 4 pattern" note | No — reproducible from a crafted HTML fixture, same as Phase 4 |

### P2 — partial functionality, fragile parsing, important UX gaps

Re-checked representatively, not exhaustively re-derived (each matches
Phase 2's original finding with no drift detected): Dashboard stats /
GD report scores / JAM profile stats / Employer dashboard counts all
still silently default to 0 on a markup-regex miss (all four re-confirmed
present, none newly broken); checkout UX gaps (no pre-payment GST
breakdown, no payment/order reference shown on a post-capture verify
failure — re-confirmed via `subscription_screen.dart:43`, still just
`AppSnackbar.showError(context, failure.message)` with no reference
number; 429/500/502 messages still not passed through); Subscription
catalog copy drift (Free plan's 2 negative restriction items still
absent); Certifications' missing content-type check on downloads and lost
400-validation message; AI Speaking's missing live transcript/elevator-
pitch cap; registration's missing optional fields (selfie, multi-language
rows, extra-education rows); **Timer exercise's missing audio playback and
"Improved Version" coaching panel — re-confirmed this phase: zero matches
for "playback"/"Improved Version"/"audio" in
`timer_exercise_result_view.dart`**; MCQ's missing previous-score card;
**Home's 5 missing lower marketing sections — re-confirmed this phase:
the only matches for their section names in `public_home_body.dart` are
inside the file's own "out of scope for this batch" doc comment, not an
implementation**; the GST invoice feature having no mobile equivalent;
Grammar's missing language switcher; the resume/activities text-based
subscription-gating brittleness (still correct against current templates,
still a standing risk, not a current defect); and generic (non-specific)
error messages on login/signup/employer-login hiding lockout/wrong-
portal/field-validation detail, with 429 messages specifically lost via
the shared exception mapper.

Session restoration never proactively validating with the server on
app relaunch is listed here, at P2, as its own item — it is the
architectural root cause behind the *now-fixed* P0 profile defects, but
with those write-path symptoms corrected (and the same page-identity
pattern available to apply to other screens as needed), the remaining
behavior is a bounded UX tradeoff (a momentarily-stale "logged in" shell
until the first real request either succeeds or correctly surfaces
`UnauthorizedFailure`), not a data-integrity defect in its own right.

### P3 — cosmetic, stale comments, low-impact cleanup

- **New this phase**: `mock_interview_html_parser.dart:49` and
  `interview_analytics.dart:30`'s doc comments both still say "this app
  has no Job Detail screen to route it to yet" — factually outdated since
  Phase 4; the underlying functional gap (P1-7 above) is unaffected, but
  the stated *reason* should be corrected whenever that gap is next
  touched, to avoid misleading a future reader into re-deriving a
  conclusion Phase 4 already settled.
- Carried forward, re-confirmed unchanged: the dead
  `DashboardDataParsing.fromJson` extension (still unused outside tests);
  stale comments at `skill_up_screen.dart:704` and
  `docs/BACKEND_CONTRACT_dashboard.md:3`; Activity list's header count
  using a filtered rather than total figure; no prev/next activity links
  for Free-plan users; logout landing on `/login` instead of Home (web's
  behavior); `RoutePaths.jobDetail`/its `ComingSoonScreen` registration now
  fully unused (left in place by Phase 4's own deliberate, documented
  choice — not an oversight to flag again).

## 4. Uncertain and blocked items — clearly separated

- **Uncertain** (evidence insufficient to classify with confidence, not
  re-resolved this phase): P1-6 (Skill-Up WebView cookie sharing);
  Employer's exact logout endpoint usage (not re-investigated this phase,
  carried forward from Phase 2 as still unresolved); Employer post/edit
  job's true field count against live production (Flutter is documented as
  targeting a ~46-field live form diverging from the 23-field committed
  repo model — still unverifiable from source alone).
- **Blocked on live/device verification**: P1-6 specifically requires a
  real device, a real account, and a real WebView session to resolve —
  it is the only item in this review that cannot be meaningfully advanced
  by more source reading. P1-2 (face detection) and P1-3 (typed answers)
  are product-decision-blocked, not verification-blocked — engineering
  work cannot meaningfully start before a product owner decides what the
  intended behavior should be.
- Every other P1/P2 item above is **reproducible and fixable from source
  and fake-HTTP-adapter tests alone**, consistent with how Phases 3 and 4
  were actually executed — no live backend or device access is required to
  implement or test them.

## 5. Mock Interview `suitable_jobs` — explicit comparison against other candidates

Per instruction, this was not automatically chosen as the next phase.
Compared directly against the other two best-scoped P1 candidates:

| | P1-1 (employer status) | P1-5 (GD/JAM language) | P1-7 (suitable_jobs) |
|---|---|---|---|
| Risk class | Latent data-integrity / wrong external communication | Pure UX/functional gap, no integrity risk | Feature-completeness gap ("Missing"), no integrity risk |
| New parsing work required | None — a validation/send-logic change only | None — the data layer already exists | **Yes** — a new HTML section on a page (`resume_analytics.html`) not previously scraped for this data, needs fresh markup verification before any code is written |
| Files touched (estimate) | 1-2 | 2-4 (two features' screens) | 3-5 (new parsing + entity + navigation wiring) |
| Backend dependency | None | None | None |
| Blocked/uncertain? | No | No | No |

**Conclusion**: P1-7 (Mock Interview job recommendations) is a reasonable
future candidate — Phase 4 did make it cheaper by proving the navigation
pattern — but it is not obviously the *best* next choice. It requires more
new parsing work than either alternative, and neither alternative carries
any backend dependency or uncertainty either. P1-1 is recommended as the
single narrowest next phase specifically because its risk class (a latent
but real data-integrity/communication-correctness issue) most closely
matches the severity bar this engagement has already prioritized in
Phase 3, and its fix is the smallest of the three candidates.

## 6. Parity matrix corrections made this phase

Four rows in `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` still described
the pre-Phase-3 broken state as current, which is now an objectively
stale classification (re-verified against current source in §2 above, not
assumed) — corrected:

1. **"Job Seeker profile — view"** row: `Partial — P0 candidate` →
   `Fully equivalent`, with the fix and its evidence cited.
2. **"Job Seeker profile — save"** row: same correction.
3. **"Employer profile — view/save"** row: same correction, plus a note
   that Phase 3 independently verified (rather than assumed) the
   employer-specific login/success redirect targets.
4. **"Password reset — confirm/complete"** row: `Partial — functionally
   broken. P0.` → `Fully equivalent`, with the fix and its 10 regression
   tests cited.

The Dashboard recommended-jobs row and the Mock Interview job-
recommendations row were already corrected during Phase 4 and were
re-checked this phase for continued accuracy — both still correct, no
further change needed (the latter's stale *reasoning*, not its
classification, is newly flagged as P3 in §3 above; the row's prose
already carries a forward-reference to "the pattern Phase 4 proved,"
which remains accurate).

No other matrix row was altered — every other classification re-checked
this phase matched current source exactly.

## 7. Recommended next remediation phase

**Primary recommendation: fix P1-1 (employer application-status silent
downgrade).**
- Scope: `lib/features/employer/data/employer_application_detail_html_parser.dart`
  and `lib/features/employer/presentation/screens/employer_application_detail_screen.dart`
  (or wherever the save payload is assembled) only.
- Change: stop implicitly defaulting an unparsed status to `'applied'`
  and silently re-sending it on every save; either omit `status` from a
  notes-only save entirely, or require a successfully-parsed status before
  allowing any save that touches it.
- Test plan: a parser-level test for a missing/unrecognized status-select
  value; a screen- or controller-level test asserting a notes-only edit
  never sends a locally-defaulted status.
- No backend, Demo Mode, signing, or unrelated-module changes required;
  no live-backend testing required — fully reproducible from a crafted
  HTML fixture, matching Phase 3/4's own demonstrated methodology.

**Secondary, equally well-scoped candidate: P1-5 (GD/JAM language picker
wiring)** — independent of P1-1, could be done in the same or a separate
narrow phase with no shared files or risk overlap.

## 8. Outstanding live-verification requirements

Unchanged from every prior phase of this engagement: no usable test
account exists (Phase 10/11's standing blocker). The one item in this
review specifically gated on live/device verification is **P1-6**
(Skill-Up WebView cookie sharing) — resolving it requires a real device,
a real account, and inspecting actual WebView network/cookie behavior,
none of which this audit attempted or claims to have performed. P1-2 and
P1-3 additionally require a product decision before any engineering
estimate is meaningful, independent of live-verification access.

## 9. Confirmations

- **Application source, tests, and the Django repository were not
  modified.** `git status --short` in both repositories, checked before
  and after this phase's work, shows the identical pre-existing
  modified/untracked file sets from Phase 4 — the only change is this new
  report plus the four corrected matrix rows documented in §6.
- `flutter analyze`: clean. `flutter test`: 1898/1898 passing — identical
  to Phase 4's own reported result, confirming no drift occurred between
  phases and nothing was altered by this audit beyond the two
  documentation files.
- No live or manual device verification is claimed anywhere in this
  report — every finding above is sourced from direct file reads and
  exhaustive greps performed this phase, cited inline.

## Status

Audit complete. Waiting for approval before implementing P1-1 (or any
other remediation) — no source change was made this phase beyond the
documented parity-matrix corrections.
