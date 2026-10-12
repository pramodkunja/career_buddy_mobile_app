# Phase 11 — Remaining Feature Parity Review & Prioritized Roadmap

Audit-only phase. No Flutter application source, test, dependency, or
platform-configuration file was modified. No Django/web file was modified
(read-only throughout). Only `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`
(one row reclassified, evidence-supported — see §3) and this new report
were touched.

## 1. Executive summary

Re-verified every previously-addressed gap from Phases 3/4/6/7/8/10 against
**current** source: all six remain correctly fixed, no regressions.

Re-investigated the previously-unresolved items from Phase 5 plus several
new areas, using five parallel read-only research passes (Skill-Up/quiz
proctoring; Timer/Grammar/MCQ/Generic-Writing exercises;
registration/home/GST; subscription UX/employer workflows; a fresh sweep
for undocumented parser-fallback defects), each independently verified
against current source rather than trusted at face value. Two **new**,
previously-unflagged findings emerged from the parser-fallback sweep that
materially matter:

- **`ProfileRemoteDataSource._extractEnglishLevel`** silently defaults to
  `'intermediate'` on a parse miss for a field that has **no edit-tab UI at
  all** (invisible to the user) yet is unconditionally re-POSTed on every
  profile save — the exact same "false success" shape as the Phase 6
  employer-status bug, just not yet publicly flagged.
- **`JobPostingRemoteDataSource`'s `openings` field** silently defaults to
  `1` on a parse miss and is likewise re-POSTed on every job edit.

One previously-"Uncertain" item (Skill-Up WebView cookie sharing) is now
**resolved** by fresh evidence: the lesson pages are static, unauthenticated
content with nothing gradeable in them, so cookie-sharing was never
actually relevant — see §3 and the matrix correction in §7.

**Recommended next phase (Phase 12)**: fix the two new silent-fallback
defects above, using the exact remediation pattern Phase 6 already
established and proved (nullable field, fail loudly, never resubmit a
guessed value). Full scope in §6.

## 2. Source and prior-report review performed

Read in full or re-grepped fresh this phase: `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`
(all ~91 rows), `docs/PHASE_5_REMAINING_PARITY_REVIEW.md`,
`docs/PHASE_9_MOCK_INTERVIEW_PROCTORING_DECISION_AUDIT.md`,
`docs/PHASE_10_POLICY_ALIGNMENT_AND_DOCUMENTATION_REPORT.md`. Phases 3/4/6/7/8's
own reports were not re-read in full this phase (their claims were instead
re-verified directly against current source — see §3 — which is strictly
stronger evidence than re-reading a prior report's prose).

Five parallel, independent research passes were run (each a fresh read of
current source, not a re-statement of old findings), covering: (a) Skill-Up
WebView cookie sharing + Mock Tests/AMCAT/CoCubes proctoring; (b) Timer,
Grammar, MCQ, Generic Writing exercise parity; (c) registration
fields/validation, Home marketing content, GST invoice; (d) subscription
payment UX + employer Job Create/Edit + employer logout; (e) a targeted
sweep across every `*_html_parser.dart`/`*_remote_datasource.dart` for the
specific "silent fallback that could be resubmitted as real data" defect
class. Every claim below that originated from one of these passes was
either independently re-confirmed by direct file reads performed personally
this phase (for the two new high-value findings and the Skill-Up
reclassification — see §3) or is reported with its exact citation so it can
be re-checked.

No live device, emulator, browser, or production account was used anywhere
in this phase.

## 3. Reconciled status of previously known gaps

### 3a. Previously addressed — re-verified still correct, not reopened

| Area | Phase | Re-verification this phase |
|---|---|---|
| Password-reset confirm + expired-session profile handling | 3 | `grep -c passwordResetSetPassword` → 4 occurrences still present; `isProfileHtml`/`isEmployerProfileFormHtml` both still present and wired |
| Dashboard recommended-job detail navigation | 4 | `recommended_jobs_section.dart`'s `job.id == null ? null : () => context.push(...)` guard still present |
| Employer application-status parsing/resend risk | 6 | `EmployerApplicationDetail.status` confirmed still `String?` with no default (`employer_application_detail.dart:73`), doc comment explaining why intact |
| GD/JAM language selection | 7 | `setLanguage` call sites confirmed present in both `gd_topic_screen.dart` and `jam_topics_screen.dart` |
| Mock Interview suitable-job recommendations | 8 | `InterviewAnalyticsResult.suitableJobs` field and its parsing confirmed present |
| Mock Interview typed-answer policy / deferred face detection / `cameraInterrupted` doc | 10 | `MockInterviewQuestionView`'s unconditional `TextField` confirmed present; `MockInterviewController`'s updated scope-note doc comment and `malpractice.dart`'s corrected `cameraInterrupted` doc comment both confirmed present, matching Phase 10's own report exactly |

**No regression found in any of the six.** None are reopened.

### 3b. Previously unresolved — current status

| # | Item | Phase 5 status | Current status (this phase) | Evidence |
|---|---|---|---|---|
| 1 | Skill-Up WebView cookie sharing | Uncertain, blocked on device test | **Resolved — not a real gap.** The 48 lesson pages are Django's plain `static()`-served HTML, no `@login_required`, confirmed live unauthenticated — nothing gradeable renders inside them. Certificate eligibility is derived entirely server-side from the persisted `QuizAttempt` table (`skillup_assessment/views.py:57-65`), populated only by the separate, normally-authenticated Mock Tests quiz-submit flow (which already shares cookies correctly via the real `ApiClient`). | `skill_up_lesson_screen.dart:8-19` (doc comment, personally re-read this phase); `skillup_assessment/views.py:57-65` (personally re-read this phase); `mock_quiz_remote_datasource.dart:16-24` |
| 2 | Mock Tests/AMCAT/CoCubes proctoring asymmetry | Confirmed, product-decision-blocked | **Confirmed, unchanged.** `mock_test_intro_view.dart:13-21` and `amcat_instructions_view.dart:16-19` both still explicitly document the deliberate omission. Django's own fullscreen+`visibilitychange`+3-strike-auto-submit logic re-confirmed real in `static/.../oop-mastery.html:2538-2624`, `amcat-guide.html:2379-2384`, `cocubes-guide.html:1907-1954`, and the shared `mock_test.js:22-27`. | See agent citations above |
| 3 | Timer exercise missing audio playback + "Improved Version" panel | Confirmed | **Confirmed, unchanged.** `timer_exercise_result_view.dart` still has no audio/improved-version UI; no `AudioRecorderService` used anywhere in `lib/features/timer_exercise/`. Web logic re-confirmed 100% client-side (`exercises.js:1436-1546`), no backend dependency. | `timer_exercise_result_view.dart`; `exercises.js:1436-1546` |
| 4 | Grammar missing language switcher | Confirmed | **Confirmed, unchanged.** No picker anywhere under `lib/features/grammar/`. Web's switcher (`subject/detail.html:425-454`) only retranslates static text (TTS stays hardcoded English even on web) — so a mobile fix would match real web behavior exactly, not over-deliver. | `subject/detail.html:425-454,926-931` |
| 5 | MCQ missing "previous score" card | Confirmed (already in matrix row 72) | **Confirmed, unchanged.** Every other exercise type's detail screen forwards `previousAttempt`; the MCQ branch (`sub_activity_detail_screen.dart:142-143`) doesn't. `McqExercise` entity already carries `lastAttempt` — just not threaded through. | `sub_activity_detail_screen.dart:142-143` |
| 6 | Generic Writing — sanity re-check | Fully equivalent | **No regression** — still fully equivalent, re-confirmed against `exercises.js:93,295,1639` (`initWriting()` dispatch). | — |
| 7 | Registration fields (selfie, repeatable language rows, repeatable extra-education rows) | Confirmed | **Confirmed, unchanged** — and a **new sub-finding**: the identical 3-field gap repeats on **profile edit** too (`ProfileUpdateForm` has the same 3 fields with no Flutter editor), not just initial registration. Django's `RegisterForm`/`ProfileUpdateForm` both accept these via plain `required=False` multipart fields — no backend change needed either way. | `users/forms.py:209,487-501,619,905-926` |
| 8 | Home/dashboard marketing content | Confirmed (Partial, in matrix) | **Confirmed, unchanged.** 4 of the 5 missing sections (Seven Core Skill Areas, How It Works, Testimonials, closing CTA) are static marketing copy — Flutter-only feasible. The 5th (Featured Activities) is explicitly blocked on a data source mobile doesn't fetch today. | `public_home_body.dart:11-15`; `home.html:1340-1927` |
| 9 | GST invoice | Missing (in matrix) | **Confirmed, unchanged** — and a **new, more actionable finding**: the server-rendered invoice page already exists and works (`career_app/views.py:386-421`, `pro/invoice/<int:pk>/`, owner/staff-gated). It's only ever linked from the receipt **email**, never from the dashboard. A mobile fix doesn't need a new backend endpoint — it can open the same authenticated URL (session cookie already shared via the app's own `ApiClient`/cookie jar) in an in-app WebView, the same pattern already used for Skill-Up/Grammar media. | `career_app/views.py:386-421`; `templates/emails/payment_receipt.html:62` |
| 10 | Subscription/payment UX (no pre-payment GST breakdown; no reference number on verify failure; 429/500/502 collapsed) | Confirmed (in matrix) | **Confirmed, unchanged**, all three. The reference-number gap is especially cheap to fix: `subscription_checkout_controller.dart:134-153` already has `orderId`/`paymentId` in scope at the failure site, they're just not threaded into `CheckoutFailed`. The status-code collapse is a structural, app-wide mapper simplification (`exception_mapper.dart:17`, `failures.dart:16-18`), not payment-specific. | See agent citations above |
| 11 | Employer Job Create/Edit field-count mismatch (46 vs. committed-repo fields) | "Unverifiable from source alone" | **Confirmed, still a genuine cross-repo discrepancy** — freshly recounted: Flutter's `JobPostingSubmission` constructor has 46 named fields; the committed Django `JobPosting` model has 23, and `JobPostingForm` exposes ~19 of those. None of Flutter's extra field names appear anywhere in the committed `templates/employer/job_form.html`. This is **not** a misunderstanding to resolve by re-reading source — it's a real discrepancy between this committed Django snapshot and whatever Flutter's own comments assert was verified live against production. Not Flutter-fixable; needs the backend/production source of truth reconciled. | `job_posting_submission.dart:17-65`; `jobs_app/models.py:27-73`; `jobs_app/forms.py:96-128` |
| 12 | Employer logout reusing the student endpoint | "Not investigated" | **Investigated, confirmed benign.** Flutter's employer logout calls the student `/users/logout/` endpoint, not Django's distinct `job_logout` route — but both views call the same site-wide `django.contrib.auth.logout(request)` (no per-portal session scoping exists in Django itself), and Flutter unconditionally clears local cookies regardless of server response. Functionally correct; only a URL-contract tidiness gap, not a bug. | `auth_remote_datasource.dart:67-91`; `users/views.py:248-251`; `accounts_app/urls.py:8` |

### 3c. New findings not in any prior report

1. **`ProfileRemoteDataSource._extractEnglishLevel`** (`lib/features/auth/data/datasources/profile_remote_datasource.dart:131-135`) — personally re-read and confirmed this phase:
   ```dart
   String _extractEnglishLevel(String html) {
     final block = _englishLevelSelectPattern.firstMatch(html)?.group(1);
     if (block == null) return 'intermediate';
     return _selectedOptionValuePattern.firstMatch(block)?.group(1) ?? 'intermediate';
   }
   ```
   `englishLevel` has **no edit-tab UI anywhere in this app** (confirmed via `profile_data.dart:36-40`'s own doc comment — it exists purely so `updateProfile` can echo it back unchanged, because the real Django field is `required=True` with no value this app ever lets the user set). If the `<select name="english_level">` block or its `selected` option ever fails to match (a markup change, an unexpected server-rendered variant), this silently substitutes `'intermediate'` — a plausible, real-looking value — which then gets POSTed back as the user's actual English level on **every subsequent profile save**, with no error surfaced anywhere. This is the identical "false success" shape to the already-fixed Phase 6 employer-status bug: a value invisible to the user, defaulted to something indistinguishable from a real answer, then resubmitted as fact. The sibling function for the equivalent employer field, `employer_profile_html_parser.dart`'s `_selectedOption`, already correctly falls back to `''` instead of a fake choice — this file is the one inconsistent outlier.

2. **`JobPostingRemoteDataSource`'s `openings` field** (`lib/features/employer/data/job_posting_remote_datasource.dart:256`):
   ```dart
   openings: int.tryParse(_textValue(html, 'openings')) ?? 1,
   ```
   Scraped from the live job-edit form, seeded directly into the Edit screen's text field (`post_new_job_screen.dart:191`), and re-POSTed verbatim on save (same file, line 78). Every other field this function scrapes correctly defaults to `''`/`[]` (visibly empty) on a parse miss; `openings` is the one exception that defaults to a plausible real count instead. Lower severity than #1 because the wrong value is at least visible in a text field an employer *could* notice before saving — but it is the same defect shape, with no comment acknowledging the risk (unlike the rest of this otherwise carefully-reasoned file).

   **Ruled out, not flagged** (checked and confirmed safe): the three `_statusValueForLabel` functions across the employer-applications parsers fall back to an empty label (never a fake status) and feed only display badges, never a status-update POST; `mock_interview_remote_datasource.dart`'s JSON-sourced `topic`/`difficulty`/etc. defaults are display-only and never resubmitted; `employer_application_detail_html_parser.dart`'s `currentCompany`/`currentSalary`/`yearsExperience` defaults are display-only info tiles. No `TODO`/`FIXME`/`HACK` markers exist anywhere in `lib/`.

3. **Employer dashboard job-status badge defaulting to `'draft'`** on a parse miss (already flagged in the current matrix, row "Employer dashboard (stats + job table)," `employer_dashboard_html_parser.dart:17-19,43`) — re-confirmed present, same risk family as #1/#2 above (a real, live job could be mislabeled as a draft), carried forward at its existing Medium severity rather than re-derived from scratch.

## 4. Ranked findings

Severity scale matches this engagement's own established bar (Phase 2/5):
**P0** — a *currently manifesting* false-success/critical defect; **P1** —
important, feasible, justified; **P2** — meaningful but schedulable later;
**P3** — polish/low-impact/intentional.

**No P0 found.** Both new silent-fallback defects (§3c #1, #2) are, like
Phase 5's P1-1 before them, confirmed **correct against current markup** —
the risk is latent (what happens *if* the regex ever misses), not
currently manifesting. That is the same reasoning this engagement has
consistently used to keep this class of defect at P1, not P0.

### P1 — High

| # | Finding | Status | Flutter-only? | Impact/rationale | Disposition |
|---|---|---|---|---|---|
| P1-A | `ProfileRemoteDataSource._extractEnglishLevel` fake default (`'intermediate'`), resubmitted on every save, field has zero edit UI | New, confirmed, latent | Yes | A silent, undetectable-by-the-user profile-data corruption risk, identical shape to the already-fixed Phase 6 bug | **Fix next** |
| P1-B | `JobPostingRemoteDataSource.openings` fake default (`1`), resubmitted on every job edit save | New, confirmed, latent | Yes | Same shape as P1-A, lower severity (visible in a text field) | **Fix next** (bundle with P1-A — same remediation pattern, same review) |
| P1-C | Mock Tests/AMCAT/CoCubes proctoring asymmetry vs. Mock Interview | Confirmed, unchanged | No (needs a product decision; partial app-lifecycle measures are Flutter-only but wouldn't match web's rigor) | Real certificate-integrity asymmetry — mobile is weaker than web for cert-granting quizzes specifically | Obtain a product decision |
| P1-D | GST invoice unreachable from mobile | Confirmed, unchanged, more actionable than before | Yes (link out to the existing authenticated HTML invoice URL — no new backend endpoint needed) | Compliance-adjacent for any paying mobile subscriber; web itself only links it from email, so impact is bounded but real | Fix next (strong runner-up candidate — see §6) |
| P1-E | Login/registration errors collapse to one generic message (lockout, wrong-portal, field-specific, 429 all lost) | Confirmed, unchanged (already in matrix) | Yes | Users can't tell *why* a login/registration failed; this is the kind of silent-information-loss class this engagement has repeatedly prioritized | Fix next (viable alternative candidate) |
| P1-F | Checkout: no payment/order reference shown on post-capture verify failure | Confirmed, unchanged | Yes, and cheap (`orderId`/`paymentId` already in scope at the failure site) | Support-diagnosability gap — a user with a real captured payment has no reference to quote | Fix next (small, bundleable with P1-D or standalone) |
| P1-G | Employer Job Create/Edit 46-vs-23-field mismatch | Confirmed, unchanged | No | Cannot be resolved by reading source alone — needs the real production field contract reconciled with this repo | Needs production/backend-owner verification, not a Flutter fix |

### P2 — Medium

- Timer exercise missing audio playback + "Improved Version" coaching panel (Flutter-only, moderate effort, coaching/completeness value, not correctness).
- Grammar missing language switcher (Flutter-only, small effort, reuses the existing Phase-7 `_LanguageSelector` pattern).
- MCQ missing "previous score" card (Flutter-only, very small — `lastAttempt` already exists on the entity, just not threaded through).
- Subscription non-400 status codes (429/500/502) collapsed to one generic message app-wide (Flutter-only, low effort — interpolate the already-captured `statusCode` into `ServerFailure`).
- Registration + profile-edit missing optional fields (selfie, repeatable language rows, repeatable extra-education rows) — Flutter-only but moderate UI effort (image picker, repeatable-row widgets); safe server-side fallbacks mean no functional breakage today.
- Home marketing content, 4 of 5 sections (Flutter-only, static content, cosmetic).
- Employer dashboard job-status badge defaulting to `'draft'` on a parse miss (standing risk, carried forward, Flutter-only, same remediation shape as P1-A/B — could be bundled into the same future phase).
- No pre-payment GST breakdown shown on the subscription screen (cosmetic/trust, Flutter-only).
- Renewal-window-aware purchase button (already in matrix; low-medium, cosmetic).

### P3 — Low / intentional / resolved

- **Skill-Up WebView cookie sharing — resolved, not a gap** (see §3b-1; matrix corrected, §7).
- Employer logout reusing the student endpoint — confirmed benign, cosmetic URL-contract tidiness only.
- "Switch to Free Plan" missing (already Low in matrix).
- `allExercisesDone` fail-open phrase-match fragility (already in matrix, standing risk, currently correct).
- Employer `job_detail` stale comment, etc. — no new items found in this class this phase.

**Deliberately not re-flagged as defects**: "Current plan/expiry visibility"
(matrix already correctly classifies this as **Blocked for a JSON
approach but resolvable via scraping**, Medium-high impact) was reviewed
this phase and found unchanged — it remains a legitimate, larger-scope
candidate (not a one-file fix like P1-A/B) and is called out explicitly in
§6 as a runner-up, not folded into the ranked table above since its matrix
entry already accurately reflects its status.

## 5. Confirmed blockers and standing product decisions (not reopened)

Per Task 4, the following remain binding and were **not** proposed for
reversal anywhere above:
1. Mock Interview typed theory answers stay available (Phase 10) — untouched.
2. No new minimum answer-length restriction (Phase 10) — untouched.
3. Face detection remains deferred, no new dependency (Phase 9/10) — untouched; P1-C above explicitly does **not** propose reopening Mock Interview's own face-detection decision — it concerns a *different* feature (Mock Tests/AMCAT/CoCubes), whose own proctoring gap was already independently tracked since Phase 5 and is reported here only as "still open," not as a call to reverse any Mock Interview decision.
4. Face-detection disclosure deferred until implementation is reconsidered — untouched.
5. `cameraInterrupted` documentation correction (Phase 10) — re-confirmed intact, not reopened.
6. Job Create/Edit blocked on the missing production API contract — re-confirmed still blocked (§3b-11); this phase does **not** propose a Flutter-side fix, only documents the discrepancy for the project owner.
7. No invented backend APIs — every recommendation above that is "Flutter-only feasible" was checked against this constraint explicitly (P1-D's GST fix reuses an *existing* URL; P1-A/B need no new endpoint at all).
8. Payments/subscription implementation remains deferred — P1-D/P1-F/the 429-500-502 item are all framed as **UX/display fixes against the existing contract**, not new payment functionality, consistent with this constraint.

## 6. Recommended next phase (Phase 12) — proposed, not implemented

**Recommendation: fix the two new silent-fallback defects (P1-A, P1-B),
using the exact remediation pattern already proven in Phase 6.**

### Why this one, over the other P1 candidates

| | P1-A/B (silent fallbacks) | P1-D (GST invoice link-out) | P1-E (generic login errors) |
|---|---|---|---|
| Risk class | Latent data-integrity ("false success"), this engagement's historically highest-priority class | Feature-completeness gap, no integrity risk | UX/information-loss, no integrity risk |
| Scope | 2 files, 2 isolated functions, already-proven remediation pattern | 1-2 files (a link/button + WebView route) | 4 call sites (2 logins, 2 registrations) sharing one root cause |
| Backend dependency | None | None (reuses existing authenticated URL) | None |
| Ambiguity/product decision needed | None — unambiguous defect | None | None |
| Precedent in this engagement | Identical to Phase 6, which is the engagement's own template for "how to fix this class of bug" | New pattern (first WebView-for-an-authenticated-page use) | New pattern (first cross-cutting error-surfacing change) |

All three are legitimate, approvable candidates. P1-A/B is recommended as
**the single narrowest, most precedented, and highest-priority-class** of
the three — it exactly matches this engagement's own established practice
of treating latent false-success defects as the top remediation priority
(Phase 3, Phase 6), and carries the least ambiguity about scope or
approach. P1-D (GST) and P1-E (generic errors) are both strong, ready
candidates for a **subsequent** phase and are deliberately not bundled in
here, per the task's instruction to avoid combining unrelated features.

### Proposed Phase 12 scope

- **Files**: `lib/features/auth/data/datasources/profile_remote_datasource.dart`
  (`_extractEnglishLevel`), `lib/features/auth/domain/entities/profile_data.dart`
  (make `englishLevel` nullable if the remediation requires it, mirroring
  `EmployerApplicationDetail.status`'s own precedent), `lib/features/employer/data/job_posting_remote_datasource.dart`
  (`openings` parsing), and whatever minimal call-site changes in
  `profile_remote_datasource.dart`'s `updateProfile`/`post_new_job_screen.dart`'s
  save flow are needed so a `null`/unparseable value is never silently
  resubmitted as real data.
- **Out of scope**: GST invoice, login error messages, every P2/P3 item
  above, any Django/backend change, any new dependency, any UI redesign
  beyond what's strictly needed to handle the newly-nullable state (e.g. a
  small notice analogous to `EmployerApplicationDetail`'s existing
  `_UnknownStatusNotice`, if the chosen fix makes the field user-visible at
  all — to be decided during that phase's own investigation, not assumed
  here).
- **Completion criteria**: a crafted-HTML regression test proving a parse
  miss on `english_level`/`openings` no longer silently defaults to a
  plausible value; `flutter analyze` clean; full suite passing with a net
  increase in test count matching the new tests added; no behavior change
  for the (today, confirmed-correct) happy path.
- **Device/production verification that would still be needed later**:
  none to *implement* the fix (fully reproducible from a crafted HTML
  fixture, exactly like Phase 6) — only a live profile-save/job-edit
  smoke test would ever be needed to confirm the *current, happy-path*
  markup still matches what the regression tests assume, which is routine
  ongoing maintenance, not a blocker to approval.

**This phase (11) does not implement any of the above.** Waiting for
explicit approval of this scope before Phase 12 begins.

## 7. Parity matrix correction made this phase

One row in `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` was reclassified,
supported by current evidence (not assumed): **"Skill-Up WebView-embedded
lesson pages"** (previously "Skill-Up WebView-embedded mock-test lessons")
— changed from **Uncertain** (blocked on a device test) to **Resolved —
not a gap**, because fresh evidence shows the premise of the original row
was itself mistaken: the lesson pages were assumed to be gradeable,
same-origin-iframe quiz content requiring cookie-sharing, but they are
actually static, unauthenticated, non-gradeable HTML with no
certificate linkage at all (see §3b-1 for full citations). The row's
header, web-behavior, mobile-behavior, gap/impact, and next-step columns
were all updated accordingly; the summary count at the bottom of the
matrix was updated from "Uncertain: 3" to "Uncertain: 2. Resolved — not a
gap: 1."

No other row was changed. Every other classification re-checked this
phase (§3) matched current source exactly, including items whose severity
or framing I might otherwise have been tempted to adjust — e.g. "Current
plan/expiry visibility" was left exactly as the matrix already has it,
since nothing this phase found contradicts that entry.

## 8. Verification performed and limitations

- **Source inspection**: every finding above is cited to a specific file
  and (where stable) line number, re-read this phase — not carried forward
  from an old report's claimed line numbers without re-checking.
- **Direct personal verification** (not merely trusting a research pass):
  I personally re-read and confirmed `profile_remote_datasource.dart:1-139`
  (the English-level bug), `job_posting_remote_datasource.dart`'s `openings`
  line and its two call sites, `skill_up_lesson_screen.dart:1-25`'s doc
  comment, and `skillup_assessment/views.py:50-68` — the four claims this
  report leans on most heavily for its P1 ranking and matrix correction.
- **Commands run** (read-only; exact):
  ```
  grep -c passwordResetSetPassword / isProfileHtml / isEmployerProfileFormHtml / ...
    (re-verifying all 6 previously-addressed areas, §3a)
  grep -n "englishLevel|english_level" profile_remote_datasource.dart profile_data.dart
  grep -n "openings" job_posting_remote_datasource.dart
  grep -n "WebView|webview" docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md
  git status --short (both repos, before and after this phase's edits)
  ```
  All returned the results cited inline above.
- **No live device, emulator, browser, or production account was used.**
  No claim in this report describes behavior as observed live. "Confirmed"
  below always means "re-read in current source this phase," never "ran
  and watched happen."
- **This is not a claim of a complete audit of every feature** — it
  reconciles the specific areas Task 1 named plus whatever the targeted
  parser-fallback sweep surfaced; broad areas not named in Task 1 (e.g. the
  full ARIA chatbot, full Grammar/Skill-Up content-accuracy, full Exercise
  scoring-heuristic parity) were not re-audited this phase beyond what the
  existing matrix already documents, and that matrix itself is explicit
  about which of its own entries are source-only vs. device-confirmed.
- **Outstanding, unresolved-by-this-phase items requiring something this
  audit cannot provide**: P1-C (product decision on quiz proctoring
  parity), P1-G (production/backend-owner reconciliation of the job-form
  field contract), and the longstanding "current plan/expiry visibility"
  item (a larger-scope build, not reviewed for implementation readiness
  beyond confirming its existing matrix classification still holds).

## Confirmations

- No Flutter application source, test, dependency, or platform-configuration
  file was created, edited, or deleted this phase.
- No Django/web file was modified — read-only access only, confirmed via
  `git status --short` showing the identical pre-existing modified/untracked
  set present since early in this engagement.
- No production system, production data, authentication/OTP/subscription
  restriction, or payment flow was touched, bypassed, or exercised.
- No endpoint, API contract, test account, or verification result was
  invented; every "Flutter-only feasible" claim above was checked against
  the existing, already-deployed backend contract, not a hypothetical one.
- Only `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` (one row + the summary
  line, both evidence-supported) and this new report were written this
  phase.

---

Audit complete. **No implementation was attempted.** Top priority: fix the
two new silent-fallback defects (P1-A/B) in a narrowly-scoped Phase 12,
exactly as proposed in §6. Waiting for explicit approval of that scope (or
a different phase selection) before proceeding.
