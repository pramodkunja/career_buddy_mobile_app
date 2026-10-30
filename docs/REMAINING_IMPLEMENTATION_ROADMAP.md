# Remaining Implementation Roadmap — Career Buddy LMS

**Date:** 2026-10-27
**Companion to:** `docs/COMPLETE_WEB_MOBILE_PARITY_AUDIT.md`, `docs/EMULATOR_TEST_EXECUTION_REPORT.md`

This roadmap groups every verified gap from the audit into prioritized future phases. **Nothing in this document has been implemented.** It is provided so the next phase(s) of work can be scoped and approved individually, consistent with the audit task's instruction not to begin fixing anything during the audit itself.

Severity key: **Critical** = blocks a core flow or risks data/security; **High** = a real, user-visible functional gap on a major flow; **Medium** = a real gap with limited blast radius; **Low** = narrow edge case or coverage gap.

---

## Phase R1 — Live-device verification of the employer job-posting rebuild (Critical, no backend changes needed)

- **Goal:** confirm, on a real device with a real employer account, that the comprehensive validation work from Phases 52-65 (CB_changes Item 5) behaves identically to its 348 automated widget tests when actually submitted against the live/staging backend.
- **User impact:** this is the single highest-effort area of recent work and has **never been confirmed outside of widget tests** — a live confirmation (or a discovered live-only discrepancy) materially changes confidence in the whole item.
- **Included issues:** the BLOCKED note under CB_changes Item 5 in the parity audit.
- **Expected behavior:** every field-level validation message and the final submit/redirect should match `job_form.html`'s own behavior exactly.
- **Dependencies/risks:** requires an authorized employer test account (student/employer credentials were not available during this audit — this is the actual blocker, not a technical one).
- **Acceptance criteria:** at least one full happy-path submission and 3-4 representative validation-triggering submissions reproduced live, with screenshots, against a non-production or disposable test listing.
- **Completable without backend changes:** yes — this is a test-execution phase only.

## Phase R2 — Fix the "session expired" vs. "sign-in redirect" inconsistency (Medium)

- **Goal:** make "Resume Parsing & Interview" behave the same way as "Build Resume" and "Find Jobs" when the user isn't signed in.
- **User impact:** a user who was never logged in sees a confusing "your session has expired" message, which implies they were previously logged in and something went wrong, rather than a simple "please sign in."
- **Included issues:** AUDIT-01.
- **Expected behavior per updated website:** needs a first step of tracing the real web's equivalent behavior for this exact entry point (not yet done — this audit reproduced the Flutter-side inconsistency live but did not trace the triggering code path in `lib/`).
- **Dependencies/risks:** low risk; purely a client-side message/navigation fix once the triggering widget is identified.
- **Acceptance criteria:** tapping "Resume Parsing & Interview" while logged out redirects to sign-in the same way "Build Resume" does, with a widget test covering the corrected behavior.
- **Completable without backend changes:** yes.

## Phase R3 — Non-IT department list split (Medium)

- **Goal:** make Technical vs. Non-Technical department browsing show the real web's 2 distinct sets (15 vs. 6 departments) instead of one combined 21-department list.
- **User impact:** Non-IT job seekers currently see irrelevant departments mixed into both categories.
- **Included issues:** AUDIT-03 (= CB_changes Item 7's department-list sub-finding).
- **Expected behavior:** mirror `career_path()`'s own Technical/Non-Technical department partitioning.
- **Dependencies/risks:** low; a data-source split, not a new feature.
- **Acceptance criteria:** Technical and Non-Technical browsing show non-overlapping department lists matching the website's counts.
- **Completable without backend changes:** yes.

## Phase R4 — Custom IT skill validator: letter-presence check (Low)

- **Goal:** reject a purely numeric custom IT skill locally, matching Django's `custom_skill_error()`.
- **User impact:** narrow edge case (a single free-text tag field); currently only caught server-side.
- **Included issues:** AUDIT-02.
- **Expected behavior:** reuse the exact `TEXT_FIELD_RULES`-style validator pattern already established in Phases 61/65.
- **Dependencies/risks:** none.
- **Acceptance criteria:** entering a skill with zero letters (e.g. `"12345"`) shows a local error before submit; a distinct "too long" message is also considered while in this code (Django has one, Flutter currently collapses it into the generic message).
- **Completable without backend changes:** yes.

## Phase R5 — Nav-bar/drawer content-discoverability gap (High, by reach — most users touch navigation)

- **Goal:** close CB_changes Item 2's gap — only 4 of 11 Skill-Up mega-menu entries and no "Resources"/About Us/Industries/Contact Us items are currently reachable from the drawer.
- **User impact:** real content exists but can't be found through normal navigation on mobile.
- **Included issues:** CB_changes Item 2.
- **Expected behavior:** mirror the real web's nav-bar structure to the extent sensible for a mobile drawer (task explicitly does not require pixel-identical desktop layout).
- **Dependencies/risks:** needs a UX pass to decide how an 11-entry mega-menu condenses into a mobile drawer, not just a 1:1 mechanical port.
- **Acceptance criteria:** all 11 Skill-Up entries and the "Resources" grouping are reachable from the drawer in some form; product sign-off on the condensed structure.
- **Completable without backend changes:** yes.

## Phase R6 — Create Resume: signed-in draft auto-resume + remaining content sections (High)

- **Goal:** close CB_changes Item 4's two remaining gaps: auto-opening a signed-in user's most recent draft, and the 7 missing editable sections (Projects, Certifications, Achievements, Internships, Volunteering, Languages, Additional Info).
- **User impact:** signed-in users currently always start from a blank form; 7 of 12 real content sections can't be edited at all on mobile.
- **Included issues:** CB_changes Item 4.
- **Expected behavior:** match the real web's section set and most-recent-draft auto-load behavior exactly.
- **Dependencies/risks:** meaningful scope — 7 new editable sections is a substantial feature addition, not a small fix; should likely be its own multi-step phase rather than a single pass.
- **Acceptance criteria:** all 12 sections editable; a signed-in user's latest draft loads automatically, matching web.
- **Completable without backend changes:** likely yes, assuming the backend already exposes this data (not independently re-confirmed this session — recommend a quick source check as the first step of this phase).

## Phase R7 — Demo tutorial video card gating + progress persistence (Medium)

- **Goal:** close CB_changes Item 6's gap — 9 "What can you do?" cards are inert when only 4 should be; no watched/resume-position persistence.
- **User impact:** confusing inert UI elements; users can't resume a partially-watched tutorial.
- **Included issues:** CB_changes Item 6.
- **Dependencies/risks:** persistence likely needs local storage at minimum, possibly a server-side field if the web syncs across devices (needs a source check).
- **Acceptance criteria:** exactly 4 cards are interactive (matching web); watched/resume state persists across app restarts.
- **Completable without backend changes:** likely yes for local persistence; needs verification if cross-device sync is required.

## Phase R8 — Test coverage gaps (Low-Medium, ongoing/background work)

- **Goal:** add coverage for `splash` (currently zero), `home`, `subscription`, `certifications`, `mock_interview`, `grammar`, `roleplay`, `aria_chat`.
- **User impact:** indirect — reduces regression risk on features with thin automated coverage, `subscription` in particular given it gates paid functionality.
- **Included issues:** AUDIT-05.
- **Dependencies/risks:** low; this is test-writing, not behavior change.
- **Acceptance criteria:** at minimum, each listed feature has coverage for its primary happy path and one key error/edge case; `splash` has at least a smoke test.
- **Completable without backend changes:** yes.

## Not scheduled (deliberately out of scope for a near-term phase)

- **HTML-scraping architecture (AUDIT-04):** this is a standing structural characteristic of the whole app, not a discrete bug — any change here would be a major architectural migration (e.g. toward a real JSON API) requiring backend buy-in and is out of scope for incremental roadmap phases. Flagged for awareness, not scheduled.
- **Malpractice-detection gaps (CB_changes Item 13)** and the **383 unreachable Tech Center lesson pages**: both carried forward from Phase 51 as known, apparently-deliberate product-scope gaps rather than defects; recommend the product owner confirm intended scope before scheduling any work here.
- **Pro-tier "unlimited" and ATS-score 4-way branch live confirmation (Items 8, 10):** blocked on the same missing-test-account constraint as Phase R1; bundle with R1 once an account is available rather than treating as separate phases.

---

## Suggested order

1. **R1** (live employer-flow verification) — highest confidence payoff, no code change, just needs a test account.
2. **R2** (session-expired message fix) — small, clear, user-visible correctness fix.
3. **R4** (custom skill letter check) — trivial, bundle with R2 if convenient.
3. **R3** (Non-IT department split) — medium effort, real functional gap.
4. **R5** (nav discoverability) — needs a short UX decision first, then straightforward.
5. **R8** (test coverage) — ongoing, can run in parallel with anything else.
6. **R7** (tutorial gating/persistence) — medium scope.
7. **R6** (Create Resume full parity) — largest scope item; recommend scoping as its own multi-step phase rather than a single pass.

No implementation should begin on any of these until you've reviewed the audit and roadmap and explicitly approve a specific phase to start.
