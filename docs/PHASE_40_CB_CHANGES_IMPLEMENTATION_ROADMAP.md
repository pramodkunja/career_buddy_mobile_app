# Phase 40 — CB_changes.docx Implementation Roadmap

This roadmap sequences the confirmed gaps from `PHASE_40_CB_CHANGES_COMPLETE_PARITY_MATRIX.md` into small, independently verifiable phases. No implementation has started — this is a plan only, pending explicit approval per Phase 40's own completion rule.

Priority categories are adjusted from the task's defaults where the evidence justified it: nothing found in this audit is a true P0 (login/launch/navigation blocker) — the app's critical paths (login, ATS/interview gating, job recommendations, free-plan quotas) were all found fully implemented and server-enforced. The highest real-world-impact gaps are the missing recovery-action buttons (Item 15) and two correctness bugs (wrong threshold copy, misleading always-enabled CTA), which is why Phase 41 leads with those rather than the visually larger landing-page work.

---

## Phase 41 (P1) — Resume/interview low-score recovery actions + threshold-copy fix

**Scope**: Item 15 in full, plus Item 8's lock-reason distinction (closely related — both need the same new `atsOk`/`roleFit` data).

**Expected visible result**: A user who scores below 90 on resume parsing sees "Build Resume" and, when a target role was selected, "Skill up yourself" — matching the web. A user who fails the AI interview sees a "Skill up yourself" button. The resume-result screen's "unlock" copy reads "90" instead of the current incorrect "70". The "Take Interview" CTA is disabled (not just eventually-rejected-by-the-server) when the real ATS score is below 90.

**Dependencies**: None — this is additive to existing, working screens.

**Web source references**:
- `royalStaffing_CB01/templates/resume_match_result.html:218-379,561-563` (4-way branch + role-specific skill-up CTA)
- `royalStaffing_CB01/templates/resume_analytics.html:224-245,361` (interview low-score CTA + `is_passed`-gated jobs)
- `royalStaffing_CB01/career_app/views.py:185,1134` (both `90` thresholds)

**Mobile files likely to change**:
- `lib/features/resume/domain/entities/resume_analysis.dart` — add `atsOk`/`roleFit`/`lockReason` fields
- `lib/features/resume/data/resume_html_parser.dart` — parse the two distinct disabled-CTA strings and the role-specific "Skill up yourself" link
- `lib/features/resume/presentation/screens/resume_builder_screen.dart` — add the new CTAs, fix the "70"→"90" copy, disable "Take Interview" when `!atsOk`
- `lib/features/mock_interview/presentation/widgets/mock_interview_results_view.dart` — add "Skill up yourself" CTA when `!isPassed`
- `lib/features/mock_interview/data/mock_interview_html_parser.dart` — parse the skill-up URL from the result HTML

**Regression risks**: Low. This only adds new branches/fields; existing `canInterview`-based logic is additive, not replaced. Must take care not to change the existing, already-correct no-leak behavior for `suitableJobs`.

**Test plan**: New HTML-parser fixture tests for all 4 resume-result branches (role-mismatch, below-threshold, eligible, free-plan) and both interview-result branches (pass, fail); widget tests confirming each CTA's visibility, label, and destination per branch; a regression test confirming the "Take Interview" CTA is genuinely disabled (not just styled differently) below threshold.

**Device verification plan**: Requires either the physical device used in Phases 35-38 (currently disconnected) or sufficient emulator storage (Phase 39 found the one available emulator was full — would need to be re-checked at Phase 41 time). If neither is available, this must ship as source/automated-test-verified only, stated plainly in the Phase 41 report.

**Estimated effort**: Medium.

**Acceptance criteria**: All 4 resume-result branches and both interview-result branches render the correct CTA set with correct destinations; the threshold copy reads 90 everywhere; `flutter test`/`flutter analyze` pass with no new issues beyond the existing baseline.

**Explicit exclusions**: No change to the server-side threshold logic, no change to the free-plan upgrade CTA, no change to the role-mismatch message wording itself (only its presence/absence as a Flutter field).

---

## Phase 42 (P1) — Create Resume guest-save UX fix

**Scope**: Item 4's one concrete gap only.

**Expected visible result**: A guest (not logged in) who taps "Save" in the Create Resume builder gets an immediate local acknowledgement and a clear "Sign in to save to your account" affordance — not a network round-trip followed by a confusing "session expired" message.

**Dependencies**: None.

**Web source reference**: `static/js/create_resume.js:656-660` (client-side pre-flight auth check before any network call).

**Mobile files likely to change**:
- `lib/features/resume/presentation/controllers/create_resume_builder_controller.dart` — add an auth-state check in `save()` before calling the repository
- `lib/features/resume/presentation/screens/create_resume_builder_screen.dart` — add a distinct guest-save banner/CTA with a tappable sign-in link

**Regression risks**: Low — must not change behavior for already-authenticated users' save path.

**Test plan**: Controller test asserting `save()` short-circuits (no repository call) when unauthenticated; widget test confirming the sign-in affordance renders and navigates to login.

**Device verification plan**: Same constraint as Phase 41 — state plainly if unavailable.

**Estimated effort**: Small.

**Acceptance criteria**: Guest save path never hits the network; authenticated save path is unchanged; `flutter test`/`flutter analyze` clean.

**Explicit exclusions**: Do not implement cross-app-restart local persistence (that's the separate, larger P2 item below) or guest→account draft migration (confirmed as a pre-existing web limitation, not in scope).

---

## Phase 43 (P1) — Industries → Departments → Roles home-page entry point + "Skills" wiring

**Scope**: Items 1, 3, and 7's two biggest gaps (home-page entry point; "Skills" action).

**Expected visible result**: The home screen gains a reachable "Industries"/"Choose Your Path" entry point (IT / Non-IT · Technical / Non-IT · Non-Technical), leading into a real department-browsing view, consistent with the data model that already exists in `ResumeRole`. From a role, the existing 3-action sheet's "Skills" option becomes a real, enabled destination into Skill-Up filtered by that role/department (matching the web's role-filtered deep link), replacing the current honest "Coming soon" placeholder.

**Dependencies**: Requires Skill-Up to have a role/department-filterable entry point already reachable by route (confirm current `RoutePaths.skillUpSections` supports a query-style filter, or extend it) — check before starting.

**Web source references**:
- `royalStaffing_CB01/templates/landing.html:6729-6776` (`#choose-path`), `:7900-8279` (department rendering), `:8071-8140,8311-8325` (Skills→Skill-Up handoff)
- `royalStaffing_CB01/riya_bot/skillup_views.py:60-61` (`skillup_hub`, `@login_required`, `?section=` param)

**Mobile files likely to change**:
- `lib/features/home/presentation/screens/home_screen.dart` and `widgets/` — new entry point/section
- `lib/features/resume/presentation/screens/role_picker_screen.dart` — add a department-browsing level above the current flat role list (or a lightweight department filter), and enable the "Skills" tile
- `lib/app/router/route_paths.dart`, `app_router.dart` — new route(s) for the home-page entry and/or department view

**Regression risks**: Medium — `role_picker_screen.dart` is an existing, tested, working screen reached from a different context (inside Resume Builder) with a documented Phase 22 decision explicitly ruling out the home hero as an entry point; re-opening that decision needs care not to break the existing Resume-Builder-internal usage, and its own existing tests must keep passing unmodified where behavior is unchanged.
- Enabling "Skills" requires confirming Skill-Up can actually be filtered by role/department server-side the same way the web's `?section=` param does — verify this before committing to the UI work, not after.

**Test plan**: New widget tests for the home-page entry point and department-browsing view; update (not weaken) `role_picker_screen_test.dart`'s existing "Skills honestly disabled" test to its new enabled-state equivalent; new datasource test confirming the role-filtered Skill-Up request shape.

**Device verification plan**: Standard constraint as above.

**Estimated effort**: Large — recommend splitting further into 43a (home entry point + department browsing) and 43b ("Skills" wiring) if approved, since they have different risk profiles and dependencies.

**Acceptance criteria**: A user can go Home → Industry → Department → Role → (Skills / Build Resume / Resume Parsing) without first having to open the Resume Builder tool; "Skills" opens real, role-filtered Skill-Up content.

**Explicit exclusions**: Do not change "Build Resume"'s existing (already-correct) destination or auth posture in this phase — that's Phase 46 below. Do not implement the 5-second popup here — that's Phase 44.

---

## Phase 44 (P1/P2) — Landing-page IT/Non-IT popup + missing nav entries

**Scope**: Item 1 in full; Item 2's "Top-level nav items" and "Skill Up mega-menu" sub-requirements.

**Expected visible result**: On opening the app (or landing on Home for the first time in a session — see the open question below), a non-blocking IT/Non-IT picker interstitial appears, matching the web's 2-step choice without persisting it (per the matrix's explicit recommendation to preserve the web's stateless behavior rather than inventing a "better" persisted version unasked). The nav drawer gains the 6 missing Skill Up categories and the 4 missing top-level items (About Us, Industries, Create Resume, Contact Us) as reachable entries, wired to existing or Phase 43's new destinations.

**Dependencies**: Phase 43 should land first if "Industries" is to point at its new home-page section rather than a placeholder.

**Web source references**: `royalStaffing_CB01/templates/landing.html:6781-6835,7574-7586` (popup); `templates/includes/site_nav.html:65-93,124-126` (nav entries).

**Mobile files likely to change**: `lib/features/home/presentation/screens/home_screen.dart` (interstitial trigger), a new dialog/bottom-sheet widget, `lib/shared/widgets/app_nav_drawer.dart` (new tiles).

**Regression risks**: Low for nav additions (purely additive). Medium for the popup — must not interfere with existing deep-link/splash/auth-redirect flows on cold start; needs careful placement so it doesn't show on top of or block a pending auth redirect.

**Test plan**: Widget test confirming the popup appears once per app-open (not per navigation) and is dismissible without blocking the rest of the UI; nav-drawer tests for each new entry's destination, mirroring the existing `app_nav_drawer_test.dart` pattern.

**Device verification plan**: Standard constraint.

**Estimated effort**: Medium.

**Acceptance criteria**: Popup shown once per app session, non-blocking, matches web's 2-step content; all `site_nav.html` top-level and Skill-Up-menu entries have a working Flutter destination (a route that exists today, or a clearly-labeled "coming soon" state — never a silent no-op).

**Explicit exclusions**: Do not persist the choice (confirmed non-goal, matches web). Do not build the "Resources" mega-menu or remaining landing sections here — those are Phase 45/47.

**Open question for the user before starting**: should the popup show once per app-launch (closer to "every page load" on web, which has no concept of "session" the way a mobile app does) or once-ever-per-install? Recommend once-per-app-launch as the closer mobile analogue; flag for confirmation rather than assume.

---

## Phase 45 (P2) — Non-IT Skill-Up content

**Scope**: Item 12 in full.

**Expected visible result**: The Skill-Up section gains a 4th top-level category, "Non-IT Center," with its real 2-track (Technical/Non-Technical), department, and role structure, correctly gated behind the same paid-plan restriction as Tech/Aptitude content.

**Dependencies**: None, but this is the single largest content-authoring effort in this roadmap (202 role lessons across 21 departments) and should be scoped/estimated jointly with the user before committing — see the open question below.

**Web source references**: `royalStaffing_CB01/static/001 Career Buddy/NonITCenter/` (directory tree), `static/data/nonit_departments.json`, `core/skillup_access.py:14-21` (gating).

**Mobile files likely to change**:
- `lib/features/skill_up/data/skill_up_data.dart` — likely needs restructuring from a flat 2-level model to accommodate a 3-level track→department→role structure, not just appended data
- Possibly new screens for department/role drill-down if the current `SkillUpSection`/`SkillUpSubsection`/`SkillUpLesson` model can't represent the extra level
- `lib/features/skill_up/presentation/widgets/skill_up_locked_view.dart` — extend gating to the new content

**Regression risks**: Medium — restructuring `skill_up_data.dart`'s model risks breaking the 3 existing sections if not done carefully; recommend adding the new level alongside the existing model rather than a full rewrite.

**Test plan**: New data/model tests for the 3-level structure; locked-view tests for Non-IT lessons under a Free account (mirroring Phase 38's existing Tech Center test); navigation tests for the new drill-down.

**Device verification plan**: Standard constraint; also verify via a real (non-production, authorized) Free-plan account that Non-IT lessons are genuinely locked, matching the web's own automated test.

**Estimated effort**: Large. **Recommend the user explicitly scope this down before Phase 45 starts** — e.g., a first subset of 2-3 departments to prove the pattern, rather than all 21 at once, given this is pure content transcription at a scale similar to Phase 39's own deliberate "5 of 10 sections" scoping decision.

**Acceptance criteria**: Depends on the agreed subset; whatever is built must be gated identically to existing Skill-Up content and must not regress the 3 existing sections.

**Explicit exclusions**: Do not attempt to fetch this content dynamically from a new backend API — none exists; this must be static Dart data like the existing 3 sections, authored from the same source files the web itself uses.

---

## Phase 46 (P2) — Remaining Item 7 fidelity gaps + Item 2's "Resources" menu

**Scope**: Item 7's department-browsing depth and "Build Resume" inline-vs-separate-screen/auth-posture mismatch; Item 2's "Resources" mega-menu and remaining landing sections not covered by Phase 44.

**Expected visible result**: Minor fidelity improvements — a more web-like department browsing experience if not already addressed by Phase 43; resolved discussion (see open question) on whether "Build Resume" should become unauthenticated to match the real endpoint's own posture.

**Dependencies**: Phase 43.

**Estimated effort**: Medium, likely splittable further once Phase 43/44 land and reveal how much is already covered.

**Open question for the user**: Flutter's `manualResumeBuilder` route is deliberately authenticated-only (a documented Phase 25 decision) even though the real `manual_resume_*` endpoints require no login at all. Should Phase 46 remove that restriction to match the web exactly, or is the stricter Flutter posture an intentional product choice to keep? This is a deliberate prior decision, not an oversight — needs the user's call, not an assumption either way.

---

## Phase 47 (P3) — Remaining landing-page sections, tutorial videos, and native screenshot protection

**Scope**: Item 2's remaining landing sections (feature grid, journey timeline, testimonials, final CTA — the large "basket" from the matrix); Item 6 (tutorial videos); Item 13's `FLAG_SECURE` addition and the Skill-Up WebView fullscreen-reliability check.

**Expected visible result**: Visual/polish parity with the web's full landing page; 5 real tutorial videos playable in-app; genuine OS-level screenshot blocking on the AI interview and Skill-Up assessment screens (a capability the web structurally cannot offer, so this exceeds web parity rather than merely matching it).

**Dependencies**: None blocking, but naturally lowest priority — none of this affects a core user journey, quota, or security rule.

**Web source references**: `landing.html` (sections listed in the matrix's Item 2 entry); `landing.html:7457-7562` (the 5 real tutorial `.mp4` files, Django static-served); `content-protection.js:35-39` (web's own documented screenshot-detection limitation).

**Mobile files likely to change**: new `lib/features/home/presentation/widgets/*` per landing section (one small file each, per the project's existing "fewer than 250 lines per file" convention); a new tutorial-video screen/widget using the already-present `video_player` dependency; a small native Android change (`MainActivity`/a `flutter_windowmanager`-style package) for `FLAG_SECURE` on 2 specific screens.

**Regression risks**: Low across the board — purely additive UI, and `FLAG_SECURE` only affects screenshot capability on 2 screens, nothing functional.

**Test plan**: Standard widget tests per new section; a test confirming `FLAG_SECURE` is applied (via platform-channel mock) on entry to the gated screens and cleared on exit (so it doesn't leak to unrelated screens).

**Device verification plan**: `FLAG_SECURE` specifically should be device/emulator-verified if at all possible (attempt a screenshot and confirm it's blocked) since this is exactly the kind of platform behavior that can't be confirmed from source alone with full confidence — flag clearly if this verification isn't possible when Phase 47 is executed.

**Estimated effort**: Large if done as one phase (recommend splitting per landing section, as the matrix itself notes); Small for the `FLAG_SECURE` addition alone, which could be pulled forward and done standalone at any point if the user wants the security improvement sooner without waiting for the visual-polish work.

**Acceptance criteria**: Per-section, matches the matrix's description of that section; `FLAG_SECURE` demonstrably blocks screenshots on the 2 target screens in a device test.

**Explicit exclusions**: Do not invent content for the 4 broken/missing web tutorial video references (`explorer`, `nontech`, `tracker`, `employer`) — only the 5 that genuinely exist should be reproduced.

---

## Summary ordering

| Phase | Priority | Items covered | Effort |
|---|---|---|---|
| 41 | P1 | 15, part of 8 | Medium |
| 42 | P1 | 4 (guest-save) | Small |
| 43 | P1 | 1 (entry point), 3, 7 (Skills + home entry) | Large |
| 44 | P1/P2 | 1 (popup), 2 (nav entries) | Medium |
| 45 | P2 | 12 | Large (scope down first) |
| 46 | P2 | 7 (remaining), 2 (Resources menu) | Medium |
| 47 | P3 | 2 (remaining sections), 6, 13 (FLAG_SECURE) | Large (split further) |

**Not included above — explicitly out of scope for any near-term phase, by design**: Item 5's narrow server-validation-rule mirroring (age/contact/education regex, salary ranges, contract-duration ceiling) — low value relative to effort since the server remains authoritative and already surfaces correct errors; only worth doing if the user specifically wants richer pre-submit inline feedback on the employer job form. Item 4's guest-draft cross-app-restart persistence and guest→account migration — both are either low-value (process-restart edge case) or not even present on the web itself.

**Safest first phase to actually start with**: **Phase 42** (Create Resume guest-save UX). It is the smallest, lowest-risk, most self-contained change in this roadmap — one controller method and one screen, no routing changes, no new data model, no interaction with any other in-flight feature — making it a good "prove the Phase 41 process works end to end" phase before committing to the larger Phase 41/43 work.
