# Updated Website ↔ Mobile Gap Analysis (Phase 15)

Maps every change in `docs/UPDATED_WEB_CHANGE_INVENTORY.md` to Flutter's
current state. Status values: **Aligned**, **Modification required**,
**Partial**, **Missing**, **Backend blocked**, **Uncertain**. This phase
did not modify any Flutter file — every "required work" note below is a
forward-looking description for the roadmap, not something done.

## 1. MCQ exercise scoring — **Modification required** (Critical)

- Updated web feature: §A1 — server now re-grades MCQ submissions,
  rejecting any non-dict `answers` entry.
- Existing mobile behavior: `mcq_exercise_remote_datasource.dart:85` POSTs
  `answers: {questionId: letter}` (flat string).
- Difference: payload shape incompatible with the new required shape
  (`{"1": {"chosen": "b"}, ...}`, dict keyed by 1-based question-order
  position, not database id).
- Affected screen/route: the MCQ exercise screen(s) under
  `lib/features/activities/` (or wherever the current MCQ feature folder
  is — confirm exact path during implementation, not assumed here).
- Affected model/entity: `McqExercise`/`McqQuestion` (or equivalent).
- Data source/repository: `mcq_exercise_remote_datasource.dart`.
- Controller/state: `mcq_exercise_controller.dart` (per research-agent
  citation — doc comment explicitly assumes client-trusted scoring,
  confirmed stale once this fix ships).
- Validation/error handling: none currently needed beyond the payload
  reshape.
- Tests covering this today: existing MCQ datasource/controller tests
  assert the *old* flat-string shape — these will need updating alongside
  the fix, not just new tests added.
- Required work: change the POST body builder to send
  `{"<position>": {"chosen": "<letter>"}}` keyed by the question's 1-based
  position in server order (requires confirming the server's question
  order is already known to Flutter, e.g. via the existing question list's
  index — verify during implementation, don't assume array order is
  already correct).
- Backend dependency: none — this is a client-side payload fix against an
  already-shipped (in the update) server contract.
- Risks: if the position-vs-id mapping is got wrong, scores could still be
  silently wrong rather than obviously broken — needs a crafted-fixture
  regression test asserting the exact JSON body sent, mirroring this
  engagement's established "assert the actual outgoing payload" test
  convention.
- Acceptance criteria: a regression test POSTs a known-correct and a
  known-incorrect answer set and asserts the resulting score matches what
  `grading.py`'s logic would compute for that same input (reproduced in
  the test, not against a live server).

## 2. Matching exercise scoring — **Modification required** (Critical)

- Updated web feature: §A1 — same re-grading change, `matching` type
  requires a `paired` key equal to the match-number string.
- Existing mobile behavior:
  `matching_exercise_repository_impl.dart:32-43` POSTs `{'result':
  'correct'}` on a correct pair — no `paired` key.
- Required work: include `paired: "<number>"` in the POST body for a
  correct pair (and the actual submitted pairing for an incorrect one, if
  the UI tracks it — confirm during implementation).
- Same acceptance-criteria pattern as item 1: a payload-assertion
  regression test reproducing `grading.py`'s matching logic.
- Backend dependency: none.

## 3. Fill-blank / bingo / timer / writing scoring — **Aligned**

- Verified (by the research pass covering quiz rotation, cross-checked by
  reading `grading.py` directly myself for the MCQ/matching cases) that
  these four exercise types' existing Flutter payload shapes already match
  the new server contract (`given`/`correct`, `target`/`chosen`, etc.). No
  action needed.

## 4. Mock Interview pass threshold (70→90) — **Aligned**

- `mock_interview_html_parser.dart` derives `isPassed` by scraping the
  literal substring `"Qualified Candidate (Score"` from the server's
  rendered HTML, never a hardcoded numeric comparison — the threshold
  change requires zero Flutter code change.
- One stale doc comment found: `interview_analytics.dart`'s doc comment
  still says ">= 70" — cosmetic, zero functional risk, worth a one-line
  fix for accuracy (P3, bundle with any other doc-only change).

## 5. Mock Interview violation thresholds (3/5→2/3) — **Modification required** (small, concrete)

- `mock_interview_remote_datasource.dart` already reads
  `flag_threshold`/`terminate_threshold` dynamically from the server's
  `resume_violation_state` JSON into `ViolationState` — the hardcoded
  `3`/`5` in that file are unreachable Dart-side fallback defaults only,
  never hit in practice. **No change needed there.**
- `mock_interview_question_view.dart`'s blocking warning dialog hardcodes
  the denominator: `'Warning ${warning.count}/3'`. `warning` is typed
  `ViolationRecordResult`, which does not itself carry the flag threshold
  (only `count`/`status`/`action`/`typeOccurrenceNumber`) — the threshold
  needs to be plumbed in from the separately-held `ViolationState` (or the
  controller needs to pass it alongside the warning) so the dialog always
  shows the real, current threshold rather than a baked-in "3".
- Required work: thread the flag threshold into the warning-dialog UI; add
  a widget test asserting the dialog shows the server-provided threshold,
  not a hardcoded one.
- Backend dependency: none (server already sends this value).

## 6. New ATS-90 interview gate — **Aligned** (no change needed)

- `mock_interview_remote_datasource.dart`'s `startInterview()` plus
  `mock_interview_html_parser.dart`'s `parseMockInterviewFlashedMessage`
  generically scrape any `class="alert alert-*" ... role="alert"` block —
  the exact same mechanism already correctly surfaces the pre-existing
  Premium-plan and no-parsed-resume blocks. This new message uses the
  identical `messages.info()` + redirect pattern, so it surfaces correctly
  with **zero Flutter code change**. Verified, not assumed, by reading both
  the new gate's server code and the existing generic parser together.

## 7. New role-fit / target-role picker — **Missing** (optional feature, not a regression)

- No role-picker screen, no `rb_role`/`rb_role_fit` equivalent anywhere in
  `lib/features/resume/` or `lib/features/mock_interview/`.
- Because the gate is inert unless a role was explicitly picked via
  landing-page query params (§B3 of the inventory), **the core upload →
  analyze → interview funnel keeps working exactly as before** without
  this feature — this is a feature gap (an optional enhancement web users
  get and mobile users don't), not a parity-breaking defect.
- Required work (if pursued): a new "pick a target role" step in the
  resume flow, a request to `manual_resume_roles`-equivalent role data (the
  same role library §B1's builders already expose via `manual/roles/`),
  and surfacing the role-fit blocked message (already handled generically
  by the existing flash-message scraper, same as item 6).

## 8. New free-résumé-analysis cap (4 total) — **Partial**

- The hard-block message itself (*"You have used all 4 Resume Parsing
  analyses..."*) would likely already surface correctly via the existing
  generic error-box scraper — not independently re-verified this phase,
  flagged as **Probable**, not Confirmed.
- No proactive "3 of 4 used" counter concept exists anywhere in
  `lib/features/resume/` — the web shows this before the limit is hit;
  Flutter currently cannot, since nothing scrapes/tracks a remaining-count
  value. **Missing** for the proactive UX; the hard block itself is
  Probable-Aligned.

## 9. New Create Resume / Manual Resume builders — **Missing** (large, new feature)

- No existing Flutter code references drafts, manual resume building, or
  role templates anywhere (confirmed via broad grep).
- This is the single largest net-new feature area in the update. See
  roadmap for scope sizing — this is explicitly **not** a "fix existing
  code" item, it is new feature construction from a clean, well-specified,
  already-mobile-consumable JSON/PDF contract (§B1 of the inventory).

## 10. Home/landing page complete redesign — **Modification required** (large)

- Flutter's `lib/features/home/` (`public_home_body.dart`,
  `authenticated_home_body.dart`, `home_screen.dart`) mirrors the **old**
  `home.html` structure, which the updated web no longer serves to anyone
  at all (confirmed: the view that used to render it now unconditionally
  renders `landing.html`).
- Every prior Home-screen parity finding in
  `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` (hero cards, the 5 "missing
  lower marketing sections," etc.) was written against `home.html` and
  must be **re-derived against `landing.html`**, not assumed still
  accurate — this is a re-audit, not an extension of old findings.
- This single change is also the delivery vehicle for the new
  Create-Resume builder (item 9) and the role-fit picker's entry point
  (item 7) — they are UI sections embedded inside this same template, not
  separate pages.
- Required work: a full Home-screen content/structure re-audit against
  `landing.html`'s actual sections (`features`, `choose-path`, `resume`,
  `skillup` preview, `stories`, `employer`, `job-seeker`, `contact`) before
  any implementation is sized — flagged here as the necessary *first step*
  of a Home-area phase, not a known, pre-sized gap list yet.

## 11. Skill-Up free-plan content gating — **Missing**

- No Flutter-side plan-gating logic exists for Skill-Up lesson access
  (confirmed via a research pass; not scoped to verify exhaustively this
  phase). If this middleware is live in production, a Free-plan user
  tapping into an Aptitude/Tech-Center/Non-IT-Center lesson in the current
  Flutter app would hit an unexpected 403/locked-page response the app has
  no specific handling for.
- Required work: add a plan-aware gate in Flutter's Skill-Up navigation
  mirroring the server's rule (Free = English/Vocabulary/Grammar + one
  self-chosen activity), and a graceful "upgrade to unlock" state for a
  gated attempt instead of an unhandled error.
- **Backend blocked for exact parity**: the "one self-selected activity"
  rule needs the server's own selection-tracking state to mirror exactly;
  until that's confirmed reachable from a client, a close approximation
  (always honor the fixed free set, show a locked state for everything
  else) is the safe interim behavior.

## 12. TechCenter/NonITCenter content expansion (~585 new lesson pages) — **Missing**

- `lib/features/skill_up/data/skill_up_data.dart` (729 lines) currently
  references exactly one of the new TechCenter files and zero NonITCenter
  content.
- This is large in raw volume but mechanical in nature (the existing
  WebView-lesson-loading pattern this engagement already established for
  Skill-Up already handles arbitrary static lesson pages — this is mostly
  data entry: new department/lesson metadata entries, not new mechanism).

## 13. Portal-separation middleware edge case — **Uncertain** (low real-world incidence)

- Confirmed new server-side enforcement; the only plausible Flutter impact
  is a dual-role account (one user with both a student and an employer
  profile) hitting a path that now 302-redirects to an HTML login page
  where Flutter expected JSON/scraped HTML. Normal single-role accounts
  are unaffected. Worth one manual/QA check with a dual-role test account
  if one exists; not large enough to warrant a dedicated phase on its own.

## 14. Riya/Buddy guest-mode destinations — **Partial** (safe, not urgent)

- `aria_action_routes.dart`'s route-string switch already has safe
  fallback behavior (re-sends the label as a chat message rather than
  crashing) for an unmapped destination.
- 4 of the 5 new/guest-relevant destinations are either already mapped
  (`LOGIN`, `EMPLOYER_LOGIN`) or map to features Flutter already has no
  equivalent screen for (`/#why`, `/#choose-path`, `/#create-resume`,
  `/#contact` — all landing-page anchors; Flutter has no marketing-page
  route at all). Fixing this is really a sub-concern of item 10 (the
  Home/landing re-audit), not an independent task.
- The 5 new backend `ACTION_DEFINITIONS` keys: `listen_learn` and
  `job_recommendations` are already correctly mapped in Flutter
  (**Aligned**); `resources`/`industries` already fall through to an
  existing, correct catch-all case (**Aligned**); only `contact_us` is
  unmapped (**Missing**, same low-priority landing-page-anchor class as
  above).

## 15. Jobs/Employer 46-field contract — **Aligned** (mystery resolved, no action)

- Fully, field-by-field confirmed match (see inventory §C). No Flutter
  change required anywhere in `lib/features/employer/`.

## 16. GD, JAM, ResumeBuilder (standalone module), auth/registration/profile fields, GST invoice, Razorpay webhook, Riya languages — **Aligned** (confirmed unchanged)

- All verified functionally identical to what Flutter already correctly
  implements. No action required for any of these areas. This closes out
  several previously-open uncertainties from earlier phases with direct,
  current evidence (e.g. the Phase 13 GST-invoice blocker is now confirmed
  still exactly as documented, not stale).

## 17. Quiz-option-rotation / AMCAT-CoCubes submission path — **Uncertain**

- The mock-test/subject-quiz bank grading system (a different code path
  from the MCQ exercise type in items 1/3) grades by comparing option
  *text*, not position, so rotation itself is not inherently a contract
  break for that system. Whether Flutter's own Mock Tests/AMCAT/CoCubes
  submission code (`lib/features/mock_tests/` — confirmed to exist from an
  earlier phase of this engagement, not re-read in full this phase)
  already submits a value compatible with text-based grading, or a
  positional index that could be affected by option shuffling, was **not**
  independently re-confirmed this phase. Flagged as a required
  investigation step for whichever future phase touches Mock Tests, not
  asserted either way without evidence.

## 18. Activity progress-percentage semantics — **Uncertain**

- Mechanism change confirmed (coverage-based → score-based
  `completion_rate` under the same field name); real-world display impact
  on Flutter's activity-list screens (which read this value, expecting the
  old meaning) not independently re-verified this phase — needs a UI-copy
  and behavior check (does the label still say "completion," now showing a
  score-based number?) before sizing any fix.

---

Nothing in this document was implemented. Every "required work" note above
feeds directly into `docs/PHASE_15_UPDATED_WEB_CONVERSION_ROADMAP.md`'s
phase scoping.
