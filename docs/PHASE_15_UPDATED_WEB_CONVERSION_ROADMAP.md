# Updated-Web Conversion Roadmap (Phase 15)

Derived entirely from `docs/UPDATED_WEB_CHANGE_INVENTORY.md` and
`docs/UPDATED_WEB_MOBILE_GAP_ANALYSIS.md`. **Planning only — nothing in
this document has been implemented.** Phase numbers continue this
engagement's existing sequence (the last completed implementation work was
Phase 14; this is new-work planning, not yet approved for Phase 16+).

## How these phases were sized

Grouped by shared root cause/dependency, not by feature area alone — e.g.
the two scoring-contract fixes are bundled (same root cause: new
server-side re-grading) rather than split by exercise type. Each phase is
independently testable and deployable; none depends on a phase later in
the sequence. The roadmap stops sizing beyond what the audit actually
found — it does not invent additional phases for areas with no confirmed
gap.

## Phase 16 — Fix MCQ and Matching scoring payloads (CRITICAL)

- **Priority**: Critical.
- **Website changes covered**: Inventory §A1 (server-side re-grading via
  new `activities/grading.py`).
- **Source evidence**: `activities/grading.py:41-78`, `activities/views.py`
  `submit_exercise` (~line 1003), confirmed directly by reading the
  updated repo.
- **Current mobile behavior**: `mcq_exercise_remote_datasource.dart:85`
  sends a flat-string answer map; `matching_exercise_repository_impl.dart:
  32-43` omits the required `paired` key on a correct match. Both would
  silently score 0 against the updated backend.
- **Flutter areas likely to change**: `mcq_exercise_remote_datasource.dart`
  (and whatever request-model type it builds the payload from),
  `matching_exercise_repository_impl.dart`. Likely also the existing
  question-order/id mapping used to build the MCQ payload — needs
  confirming during implementation, not assumed.
- **Dependencies/prerequisites**: none — self-contained.
- **Implementation scope**: reshape both POST bodies to the server's
  actual required shape; verify against a crafted-fixture test that
  reproduces `grading.py`'s own grading logic (not a live server call).
- **Explicit exclusions**: no change to fill-blank/bingo/timer/writing
  (already confirmed Aligned); no change to the Mock Tests/AMCAT/CoCubes
  bank-quiz submission path (tracked separately, Phase 15's gap analysis
  item 17 — Uncertain, needs its own investigation first).
- **Backend/product-owner decisions required**: none — this is a
  client-side fix against an already-shipped server contract.
- **Acceptance criteria**: a correct MCQ/Matching submission's POST body,
  when run through a reproduction of `grading.py`'s own logic in a test,
  yields a full-credit score; an incorrect submission yields a correctly
  partial/zero score; existing fill-blank/bingo/timer/writing tests remain
  green, unmodified.
- **Required automated tests**: new payload-assertion unit tests for both
  exercise types (mirroring this engagement's established "assert the
  actual outgoing request body" convention); update any existing test that
  currently asserts the old (now-wrong) payload shape.
- **Required manual verification**: none strictly required to ship the
  fix (fully reproducible from source), but a live-account smoke test of
  one real MCQ and one real Matching submission against the updated
  backend, once deployed, would be the only way to confirm end-to-end —
  explicitly not claimed as done by this phase.
- **Relative effort**: Small.
- **Risks**: getting the question-order-vs-id mapping wrong could produce
  a *different* wrong score rather than an obviously broken one — mitigate
  with the fixture-based acceptance test above, not a live spot-check
  alone.

## Phase 17 — Mock Interview threshold/UI alignment (HIGH)

- **Priority**: High (user-visible incorrect copy, but not a scoring
  break — the underlying data is already read correctly in most places).
- **Website changes covered**: Inventory §A2 (pass threshold 70→90), §A3
  (violation thresholds 3/5→2/3).
- **Current mobile behavior**: pass-threshold detection already works via
  generic HTML scraping (no change needed); violation-warning dialog
  hardcodes `/3` instead of reading the real, already-available
  `flagThreshold`.
- **Flutter areas likely to change**:
  `mock_interview_question_view.dart` (thread the real threshold into the
  warning dialog text); `interview_analytics.dart` (correct the stale
  ">=70" doc comment, no functional change).
- **Dependencies**: none.
- **Implementation scope**: small, targeted — no new data model needed
  (`ViolationState` already carries the right values); just wire the
  already-available number into the one UI string that hardcodes it.
- **Explicit exclusions**: no change to the ATS-90 gate or role-fit gate
  handling (already Aligned/inert — see Phase 18 for the role-fit
  *feature*, which is a separate, optional addition, not a fix).
- **Backend/product-owner decisions required**: none.
- **Acceptance criteria**: the warning dialog shows the server's actual
  flag threshold, not a hardcoded number; a widget test proves this with a
  non-3 threshold fixture.
- **Required automated tests**: one widget test overriding `ViolationState`
  with a non-default threshold and asserting the dialog text reflects it.
- **Required manual verification**: none required.
- **Relative effort**: Small.
- **Risks**: minimal — isolated UI string change.

## Phase 18 — Resume flow: free-analysis-cap UX and role-fit picker (MEDIUM)

- **Priority**: Medium (neither blocks the core funnel; both are
  visible, real feature gaps).
- **Website changes covered**: Inventory §B3 (free-analysis cap, role-fit
  gate).
- **Current mobile behavior**: hard-block message likely already surfaces
  (Probable, not Confirmed — verify first); no proactive usage counter; no
  role-picker step anywhere.
- **Flutter areas likely to change**: `lib/features/resume/` (datasource,
  screen) for the usage-counter display; a new role-picker screen/step
  feeding `?role=&dept=&track=`-equivalent state into the existing
  interview-start call, if the role-fit feature is approved for porting.
- **Dependencies**: should start with a verification sub-step (confirm the
  hard-block message actually surfaces today) before any new UI is built.
- **Implementation scope**: (a) small — surface a "X of 4 used" counter if
  the server exposes it anywhere scrapeable (needs its own quick
  verification, not assumed available); (b) medium — a full role-picker
  step, reusing the same role-library data the web's `manual/roles/`
  endpoint already serves as JSON.
- **Explicit exclusions**: no change to the interview scoring/timer/
  question logic.
- **Backend/product-owner decisions required**: **product decision** —
  is porting the optional role-fit picker worth the effort given it's
  inert if skipped on web too, or should mobile simply continue skipping
  it (current behavior, already safe)?
- **Acceptance criteria**: (a) a Free-plan user sees their real remaining
  analysis count before hitting the hard cap, if a product decision
  approves building it; (b) if the role picker is built, picking a role
  and then an unrelated resume correctly blocks the interview with the
  real role-fit message, and skipping the picker behaves exactly as today.
- **Required automated tests**: fixture-based tests for the counter
  display and (if built) the role-fit blocked-message case.
- **Required manual verification**: none strictly required; a live check
  of the exact free-plan remaining-count data source would reduce risk
  before committing to (a)'s scope.
- **Relative effort**: Medium.
- **Risks**: scope creep if the role-picker UI tries to match the web's
  full 5-step wizard rather than the minimal query-param equivalent mobile
  actually needs.

## Phase 19 — Home/landing screen re-audit and rebuild (HIGH, large)

- **Priority**: High (affects every user's first screen; several
  previously-tracked parity findings are now stale and could mislead
  future work if not corrected first).
- **Website changes covered**: Inventory §B2 (complete `landing.html`
  replacement of `home.html`).
- **Current mobile behavior**: mirrors the now-retired `home.html`
  structure.
- **Flutter areas likely to change**: `lib/features/home/` entirely
  (`public_home_body.dart`, `authenticated_home_body.dart`,
  `home_screen.dart`), and `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`'s
  Home-related rows (re-derive, don't assume still accurate).
- **Dependencies**: should run **before** Phase 20 (Create Resume) and
  before any role-fit-picker work in Phase 18(b), since both are UI
  sections embedded inside this same redesigned page and their exact
  placement/framing depends on this audit's findings.
- **Implementation scope**: **Step 1 is itself a dedicated re-audit** (not
  sized yet) — read `landing.html`'s actual rendered sections
  (`features`, `choose-path`, `resume`, `skillup` preview, `stories`,
  `employer`, `job-seeker`, `contact`) in full and produce a fresh,
  accurate gap list before estimating implementation size. Only after that
  re-audit should a concrete UI-build scope be committed to.
- **Explicit exclusions**: the Create-Resume builder's own internals
  (Phase 20) and the role-fit picker's own internals (Phase 18) — this
  phase covers the surrounding Home-screen structure/navigation only.
- **Backend/product-owner decisions required**: **product decision** on
  how much of a from-scratch marketing redesign belongs in a learning-app
  mobile client at all (some `landing.html` sections, e.g. testimonials or
  marketing copy, may not be a product priority for mobile even though
  they exist on web — flag for an explicit decision, don't assume "port
  everything").
- **Acceptance criteria**: to be defined once the re-audit sub-step
  completes; premature to state now.
- **Required automated tests**: to be defined post-re-audit.
- **Required manual verification**: a visual comparison against the live
  web page would materially de-risk this phase, given its size — flagged
  as valuable, not claimed as done.
- **Relative effort**: Large (re-audit) + Unknown (implementation, pending
  the re-audit's own findings — stating a size before that audit would be
  a guess, which this roadmap's own instructions say not to do).
- **Risks**: the largest single risk in this whole roadmap is under-
  scoping this phase by treating it as "update a few sections" when the
  underlying web page has been fully rebuilt — hence splitting the
  re-audit out as its own explicit first step rather than bundling it into
  a single implementation estimate.

## Phase 20 — New feature: Resume builders (Create Resume / Manual Resume) (MEDIUM priority, Large effort)

- **Priority**: Medium (genuinely new value, but not a regression or a
  blocker for any existing feature — can be scheduled after the
  correctness-critical phases above).
- **Website changes covered**: Inventory §B1.
- **Source evidence/endpoints**: the 11-route table in the inventory
  (`manual/roles/`, `manual/preview/`, `manual/pdf/`, `manual/pages/`,
  `create/preview/`, `create/pdf/`, `create/pages/`, `create/drafts/` ×4).
- **Current mobile behavior**: none — confirmed no existing code
  references this feature anywhere.
- **Flutter areas likely to change**: two new feature modules (role-based
  wizard; free-form builder), each with: domain entities mirroring the
  server's `document`/draft JSON shape exactly, a datasource/repository
  pair per the established architecture, a native preview-rendering widget
  tree (the one piece with no portable web code to reuse — see below), a
  PDF download/view integration, and (Create Resume only) a login-gated
  drafts list/detail/save/delete screen set.
- **Dependencies**: should follow Phase 19 (both builders are entry points
  reached from the redesigned landing/home page).
- **Implementation scope**: (a) JSON state models + repository/datasource
  for both builders — direct, low-risk, the contract is already fully
  specified and mobile-consumable as-is; (b) native document-preview
  renderer consuming the same `document` JSON the PDF/HTML renderers
  consume — the single largest, least-precedented piece of new UI work in
  this whole roadmap, since the web's own preview logic is hand-rolled
  client JS with nothing to port; (c) PDF download/view (straightforward —
  direct POST, standard PDF viewer integration); (d) drafts CRUD screens
  (straightforward CRUD, login-gated, matching the `ResumeDraft` contract
  exactly).
- **Explicit exclusions**: no AI/suggestion generation (the web feature
  itself is explicitly rule-based/non-AI — do not add AI here either); no
  attempt to reproduce the wizard's exact 5-step web UX pixel-for-pixel —
  the UI should be native-appropriate, following the same data/validation
  contract, not a literal UI port.
- **Backend/product-owner decisions required**: **product decision** on
  whether to build both builders or just one first (e.g. Create Resume,
  since it has draft persistence and a simpler, non-wizard UI, might be
  the more natural first slice); confirm whether a native PDF-preview
  widget (rendering the downloaded PDF) is an acceptable substitute for a
  pixel-perfect live-HTML-style preview, or whether true live-preview
  parity is a hard requirement.
- **Acceptance criteria**: a user can build a resume via the chosen
  builder, preview it, download a real PDF matching the server-rendered
  one, and (Create Resume) save/reload/delete a draft — all against the
  real, unmodified backend contract, with every validation rule the server
  enforces also enforced (or at minimum surfaced) client-side.
- **Required automated tests**: unit tests for every state-normalization
  rule mirrored from `resume_document.py`/`create_resume.py`; payload
  round-trip tests against crafted fixtures of the server's actual JSON
  shapes; widget tests for the drafts CRUD flow.
- **Required manual verification**: a real PDF download/open on a device,
  compared against the server-rendered equivalent, would be the only way
  to confirm visual fidelity — not claimed as done by this planning phase.
- **Relative effort**: Large.
- **Risks**: scope creep from trying to match the web's exact visual
  design rather than its data contract; the live-preview rendering piece
  in particular could balloon if treated as "port the JS" rather than "a
  from-scratch native renderer for the same JSON."

## Phase 21 — Skill-Up: free-plan gating + new department content (MEDIUM)

- **Priority**: Medium.
- **Website changes covered**: Inventory §B4 (gating middleware,
  TechCenter/NonITCenter content expansion).
- **Current mobile behavior**: no plan-aware gating logic; only 1 of the
  new TechCenter files and zero NonITCenter content referenced in
  `skill_up_data.dart`.
- **Flutter areas likely to change**: `lib/features/skill_up/` (gating
  logic + a locked-state UI for the existing lesson-WebView screen;
  `skill_up_data.dart`'s lesson/department metadata entries).
- **Dependencies**: the gating sub-task should land before or alongside
  the content-expansion sub-task, so new lessons aren't added without the
  access rule that's supposed to guard some of them.
- **Implementation scope**: (a) small — add a plan check + locked-state UI
  before opening a gated lesson; (b) large-but-mechanical — add metadata
  entries for ~585 new lesson pages across 12 departments, following the
  exact existing pattern already used for the one TechCenter file
  Flutter already has.
- **Explicit exclusions**: no attempt to replicate the server's "one
  self-selected activity" free-tier rule exactly without first confirming
  that selection state is readable from a client at all (see Backend
  blocked note in the gap analysis) — ship the safe approximation (fixed
  free set only) first if the exact rule isn't confirmable.
- **Backend/product-owner decisions required**: confirm whether the
  "one self-selected free activity" rule needs exact mobile parity or
  whether the safer, simpler fixed-set approximation is acceptable.
- **Acceptance criteria**: a Free-plan user sees a clear locked state
  (not a raw error) when attempting a gated lesson; all newly-added lesson
  entries open correctly via the existing WebView mechanism.
- **Required automated tests**: a gating-logic unit test per plan tier; a
  smoke test confirming a sample of the new lesson entries resolve to a
  real, loadable URL.
- **Required manual verification**: spot-checking a handful of the ~585
  new lesson URLs on a real device/emulator would catch any data-entry
  typos before a full rollout — not claimed as done here.
- **Relative effort**: Medium (gating) + Large (content volume, but low
  complexity per entry).
- **Risks**: data-entry errors across hundreds of new lesson entries;
  mitigate with a scripted/semi-automated metadata-generation step rather
  than fully manual entry, if feasible.

## Phase 22 — Investigate and resolve remaining Uncertain items (MEDIUM, verification-first)

- **Priority**: Medium — these are open questions, not yet sized
  implementation work.
- **Website changes covered**: Inventory items flagged Uncertain in the
  gap analysis: (a) Mock Tests/AMCAT/CoCubes submission-path compatibility
  with quiz-option rotation; (b) activity progress-percentage semantic
  change's real display impact; (c) the dual-role-account
  `PortalSeparationMiddleware` edge case.
- **Implementation scope**: this phase is itself investigation, not a
  fix — each item needs its own direct-source + Flutter-code check before
  any code change is proposed. Do not pre-commit to a fix for any of these
  before that investigation completes, consistent with this whole
  engagement's established practice of verifying before changing.
- **Dependencies**: none blocking; can run in parallel with any of the
  above.
- **Backend/product-owner decisions required**: none yet — decisions, if
  any, follow from what the investigation finds.
- **Acceptance criteria**: each item resolved to a concrete status
  (Confirmed-fine / Confirmed-needs-fix / Confirmed-no-mobile-equivalent-
  needed), with a follow-up phase proposed only for whichever turn out to
  need one.
- **Relative effort**: Small (per item, investigation only).

## Phase 23 — Full regression pass and final verification (ALL, final gate)

- **Priority**: Critical (as a gate, not as new functionality) — this is
  the completion check, not a feature phase.
- **Scope**: run the complete Flutter test suite, `flutter analyze`, and a
  fresh pass of `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` reconciliation
  against everything above once Phases 16-22 (whichever are approved and
  completed) land, updating the matrix with evidence-backed corrections
  only, per this engagement's established practice.
- **Acceptance criteria**: full suite green; `flutter analyze` clean;
  parity matrix accurately reflects the post-update state, with every
  updated row citing current evidence, not carried-forward assumptions.

---

## Overall conversion-completion criteria

The mobile conversion for this website update is complete when:

1. Phase 16 (scoring-contract fix) has shipped and is verified — this is
   the only item in this roadmap with active, silent user-facing harm if
   left unfixed, so it alone is the hard gate for calling "parity restored
   to its pre-update baseline."
2. Every other phase above has either shipped, or been explicitly deferred
   by the project owner with a documented reason (e.g. "Create Resume
   deferred to a later quarter") — completion does not require every
   phase to ship, only that each has a known, owner-approved disposition.
3. The parity matrix (Phase 23) has been refreshed to reflect whichever
   phases actually shipped, so the next audit starts from accurate ground
   truth rather than this roadmap's own forward-looking estimates.

No phase in this roadmap has been started. All require explicit approval
before implementation begins, per this phase's own scope boundary.
