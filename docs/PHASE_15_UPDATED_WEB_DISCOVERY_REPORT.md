# Phase 15 — Updated Website Discovery Report

Audit-only phase. **No Flutter application code was changed. Neither
Django codebase was modified. No parity matrix row was touched this
phase.** The only files created are this report and the three other
documents listed in §7.

## 1. Executive summary

A new ZIP extraction of the Career Buddy LMS Django backend
(`royalStaffing_CB01/`) was compared against the engagement's existing
reference repo (`Career_Buddy_LMS/`) and the current Flutter app
(`Mobile_app/`). The update represents substantial, real change — not a
cosmetic refresh. The single most important finding is a **confirmed
scoring regression**: the server now re-grades MCQ and Matching exercise
submissions server-side, and Flutter's current submission payloads for
both exercise types no longer match the required shape — **every MCQ and
Matching submission from the mobile app would score 0, regardless of
correctness**, the moment this backend ships. This is the clear top
priority for the next implementation phase (see §6).

Beyond that, the update adds a large, entirely new resume-building feature
(two independent builders with PDF export and draft persistence), replaces
the site's home page template completely, adds new Mock Interview gates
(ATS score, optional role-fit), adds a new Skill-Up free-plan content
restriction alongside a major Skill-Up content expansion, and adds a new
centralized student/employer portal-separation check. It also **resolves
a long-standing open question** from an earlier phase of this engagement:
Flutter's 46-field job-posting contract, previously unexplained against
the old reference repo's ~23-field model, is now explained field-for-field
by this update's 22 new migrations plus 3 form-only alias fields — no
Flutter change is needed there.

Several claims from a third-party audit document bundled in the ZIP
(`CareerBuddy_FSD_Audit.html`) were checked and found to be **unreliable**
for this engagement's purposes — it compared against an old external
specification document, not our actual reference repo, and at least three
of its "new since spec" claims (Riya bot Telugu/Tamil support, the GST
invoice feature, the Razorpay webhook) were independently confirmed to
already exist, unchanged, in our own baseline. Every finding in the four
deliverables below was independently verified by direct source comparison,
not taken from that document.

## 2. Actual paths inspected

- Updated Django: `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/royalStaffing_CB01/`
  — confirmed to be the Django project root itself (contains `manage.py`,
  the `business_english_lms/` settings package, and every app directory
  the original repo has, plus several new ones). No nested wrapper
  directory existed; the ZIP root was already correct.
- Original Django: `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Career_Buddy_LMS/`
  (git HEAD `3d4a1ba` at the time of this audit).
- Flutter app: `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Mobile_app/`.
- No path was missing, ambiguous, or required guessing — all three
  resolved cleanly on first inspection.

## 3. Methodology

1. `git status`/`git log` confirmed the original repo's clean baseline
   state; the updated folder was confirmed to have **no git history**
   (`fatal: not a git repository`) — version-history comparison was not
   possible, so a full file-tree + content diff was used instead, exactly
   as this phase's own instructions anticipated.
2. A `diff -rq` (excluding caches, media, logs, build artifacts) produced
   the raw file-level change counts in §4. **This raw count was found to
   overstate real change substantially** — direct content comparison
   (stripping CRLF line endings, which the ZIP tool introduced into files
   the update never actually touched) showed that entire app directories
   `diff -rq` flagged as heavily changed (`GD_app/`, `jam_app/`,
   `ResumeBuilder_module/`, `users/`) were functionally **byte-identical**
   once line-ending noise was removed. Every finding in this report's
   companion documents reflects **content-level verification**, not the
   raw file-diff count.
3. For every substantive lead (whether self-identified from the file diff
   or sourced from the third-party audit document as a lead only), the
   actual source in both Django repos was read directly, and the
   corresponding Flutter code was checked for current behavior before any
   status was assigned.
4. Five parallel research passes were used to cover breadth efficiently
   (mock interview/resume; the new resume-builder feature; activities/
   skill-up/quiz-rotation; GD/JAM/core infrastructure; Riya bot/users/
   auth); the jobs/employer field-contract resolution and several
   cross-checks (GST invoice, Razorpay webhook, FAQ field, landing-page
   discovery) were performed directly, personally, not delegated. Two
   initial research passes failed to complete due to a transient
   account-level rate limit and were successfully retried; no finding in
   this report rests on an incomplete or failed pass.

## 4. Raw file-level change counts (for context only — see §3's caveat)

`diff -rq` between the two Django trees (excluding caches/media/logs/build
artifacts): **447 files differing, 144 new, 11 removed.** As established
in §3, a large fraction of the "differing" count is line-ending noise, not
functional change — do not use this raw count as a proxy for implementation
effort; the item-level counts below are the ones that matter.

## 5. Confirmed-item counts (counting method stated explicitly)

Counted at the level of one distinct **finding** (a single confirmed
behavior/contract change), not at the file level, and not double-counted
across the three other documents — each finding below appears once in
`UPDATED_WEB_CHANGE_INVENTORY.md`, is mapped once in
`UPDATED_WEB_MOBILE_GAP_ANALYSIS.md`, and (if it needs mobile work) is
scoped once in the roadmap.

- **Confirmed new functionality**: 13 (Create Resume + Manual Resume
  builders counted as one feature-area finding; ATS-90 gate; role-fit
  gate; free-résumé-analysis cap; TechCenter/NonITCenter content
  expansion; Skill-Up free-plan gating middleware; portal-separation
  middleware; Riya guest mode; Riya's 5 new action keys counted as one
  finding; content-protection middleware; gzip-compression middleware;
  FAQ industry field; the job-posting 22-migration field expansion).
- **Confirmed modified functionality**: 6 (landing-page replacing the home
  page; interview question-generation reverted to upfront generation;
  `evaluate_answer`'s resume-consistency check; activity progress
  percentage semantics; Riya's `want_audio` default flip; the MinIO
  URL fix/interview-video Range support, counted together as one
  infrastructure finding).
- **Confirmed validation/business-rule changes**: 4 (MCQ scoring
  regression; Matching scoring regression; interview pass threshold
  70→90; malpractice thresholds 3/5→2/3).
- **Confirmed removed functionality**: 1 finding, covering 3 endpoints
  (`dashboard_api`/`activities_api`/`mcq_exercise_api` — already-undeployed
  JSON APIs Flutter never depended on).
- **Confirmed configuration/tooling-only changes**: 1 finding, covering 3
  items (Excel question-bank import tool, TTS cache-warming command, one
  data-fix migration).
- **Uncertain** (investigated but not resolvable from source alone this
  phase): 3 (Mock Tests/AMCAT/CoCubes rotation-path compatibility;
  activity progress-semantics real display impact; the portal-separation
  middleware's dual-role-account edge case).
- **Explicitly confirmed NOT changed** (a meaningful category in its own
  right, since several were plausible leads that turned out false): 7
  (GST invoice; Razorpay webhook; Riya bot's language list; `users/`
  auth/registration/profile/OTP/lockout contract; `GD_app/`; `jam_app/`;
  `ResumeBuilder_module/`).

**Total distinct findings this audit produced a verdict on: 35.**

## 6. API/integration findings summary

See `UPDATED_WEB_CHANGE_INVENTORY.md` §B1 for the full 11-route table for
the new resume-builder feature (the largest new API surface in this
update) — every route is JSON/form-postable or returns a PDF/PNG, with no
browser-only session-state dependency; fully mobile-consumable as
specified. All other confirmed backend changes are either (a) inert for
any JSON-consuming client (the two new middleware classes, both
explicitly skip non-HTML responses), (b) already correctly handled by
Flutter's existing generic flashed-message-scraping mechanism (the two new
Mock Interview gates), or (c) the scoring-contract break detailed in §1,
which is the one genuine, confirmed, client-breaking API/contract change
this audit found.

## 7. Flutter impact summary and highest-priority remaining work

**Highest priority**: Phase 16 in the roadmap (fix the MCQ/Matching
scoring payload shapes) — this is the only finding in the entire audit
with active, silent, currently-shipping-risk user-facing harm once the
updated backend deploys. Everything else in the roadmap is either a new
feature opportunity, a cosmetic/UI-copy fix, or an investigation step.

**Second priority**: the Home/landing-page re-audit (roadmap Phase 19) —
not because it's urgent in the same way, but because it is a genuine
blocker for correctly scoping two other phases (the new Create-Resume
builder and the role-fit picker, both of which are UI sections embedded in
the redesigned page) and because several existing parity-matrix rows about
the Home screen are now stale and should not be trusted without
re-verification.

## 8. Key blockers and limitations

- No live device, emulator, or production account was used anywhere in
  this phase — every finding is sourced from direct file reads performed
  this phase. No claim of manual QA or live-endpoint verification is made
  anywhere in the four deliverables.
- Two of seven initial parallel research passes failed on first attempt
  due to a transient account-level rate limit; both were successfully
  retried and completed. No finding in the final deliverables rests on an
  incomplete pass — where a pass's scope could not be fully covered even
  after retry, that specific sub-item is explicitly marked **Uncertain**
  in the gap analysis rather than asserted.
- The role-fit picker, the free-analysis-cap proactive counter, and the
  Skill-Up "one self-selected free activity" rule each have an open
  **product decision** flagged in the roadmap — none were resolved
  unilaterally by this audit, consistent with this phase's scope.
- The Home/landing-page re-audit (roadmap Phase 19) is intentionally left
  **unsized** — committing to an effort estimate before reading the
  redesigned page's actual content in full would have been a guess, which
  this phase's own instructions direct against.

## 9. Confirmation that this phase was audit-only

- No Flutter application source, test, or dependency file was created,
  edited, or deleted.
- Neither Django codebase (`Career_Buddy_LMS/` or `royalStaffing_CB01/`)
  was modified — both were read-only throughout.
- `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` was not opened or modified
  this phase, per this phase's explicit instruction.
- No git branch, commit, stash, reset, or working-tree state was changed
  in either repository.
- No dependency was installed, upgraded, or removed.
- No database migration, seed script, or destructive command was run.
- No request was sent to any production endpoint; no production form was
  submitted; no production data was read or modified. No `.env`/secret
  file content was printed anywhere in these deliverables (their presence
  was noted only where relevant, e.g. `.env.example` existing in the
  updated folder, never their contents).
- No build, release artifact, signing step, or store upload occurred.

## 10. The four deliverables

1. `docs/UPDATED_WEB_CHANGE_INVENTORY.md` — full comparison, evidence,
   classifications.
2. `docs/UPDATED_WEB_MOBILE_GAP_ANALYSIS.md` — per-feature Flutter
   alignment status.
3. `docs/PHASE_15_UPDATED_WEB_CONVERSION_ROADMAP.md` — the phase-wise
   implementation plan (Phases 16-23).
4. This file.

---

**Stopping here, as instructed.** No Phase 16 (or any other roadmap phase)
work has begun. Awaiting explicit project-owner direction on which phase
to approve next — most likely Phase 16, given its severity, but that
remains the project owner's call, not a decision this audit makes for
them.
