# Complete Web ↔ Mobile Parity Audit — Career Buddy LMS

**Audit date:** 2026-10-27
**Auditor:** Claude (automated, read-only audit + live emulator testing)
**Scope:** Entire Flutter app vs. the updated Django website. Audit and testing only — no application code, test code, dependency, configuration, or Django-tree changes were made in this task. The only repository changes are this report and its two companion reports in `docs/`, plus screenshots captured for this task.

---

## 1. Audit scope and environment

- **Flutter app under audit:** `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Mobile_app/`
- **Authoritative updated Django reference (read-only):** `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/royalStaffing_CB01`
- **Original Django reference (read-only):** `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Career_Buddy_LMS`
- **Live site:** `https://careerbuddy4u.com` — used only as a passive reference point; no state-changing request was made against it. (The test build described in §6 does, by the app's own default configuration, point at this live host for any network call — see §6's safety note.)
- **Change checklist:** `~/Downloads/CB_changes.docx` — read in full this session (15 numbered items).
- **Method:** (a) direct source inspection of both the Flutter app and the updated Django reference, (b) three parallel research passes (screen inventory, 15-item change-list comparison, API/runtime-stability + regression-test execution), each producing a detailed evidence file now folded into this report, and (c) live, hands-on testing of the compiled debug app on a running Android 14 emulator (screenshots in `docs/screenshots/` — see Report 2 for the index).
- This is a **sampled, evidence-based** audit, not an exhaustive click-through of all 75 screens. Every verdict below states its evidence basis (source-only, source-plus-live, or live-only) so you can see exactly how far each claim was actually checked.

## 2. Project and Git baseline

- Branch: `main`. Working tree at audit start: 5 files modified under `lib/features/employer/`+`test/features/employer/` (Phases 52-65's own uncommitted work, preserved exactly as found), 6 unrelated pre-existing modified files under `test/features/resume/` (an external unused-parameter fix from before this session, also preserved untouched), and 13 untracked `docs/PHASE_52...` through `docs/PHASE_65...` reports. **Identical at audit end** except for the 3 new report files this task adds.
- Flutter `3.44.8` (stable channel), Dart `3.12.2`.
- Key dependencies: `flutter_riverpod ^3.4.3`, `dio ^5.11.1`, `go_router ^17.3.0`, `flutter_secure_storage ^11.1.1`, `webview_flutter ^4.13.0`.
- Android `applicationId = com.sriainfotech.career_buddy_lms` (a stale `com.example.career_buddy_lms` package from an older build is also installed on the shared test emulator — harmless, but can be confusing in the app drawer).
- `flutter analyze`: **0 issues**. `flutter test`: **2,710 passing, 0 failing** — both commands actually executed this session (not assumed from a prior report), matching the figure already reported in `docs/PHASE_65_REMAINING_TEXT_VALIDATION_REPORT.md`.
- No `integration_test/` directory exists anywhere in the repo — the entire 307-file test suite is Flutter widget/unit tests; **no automated test in this repository has ever launched the compiled app on a device before this audit.**

## 3. Complete screen and feature inventory

**75 screens across 26 feature modules, 307 test files.** Full per-screen table (feature → screen → route → auth requirement → source file → test coverage) is in the companion research file referenced below; the summary here is what matters for this report.

| Feature | Screens | Test files | Auth model |
|---|---|---|---|
| splash | 1 | **0** | none |
| auth | 9 (Login, Register, Forgot/Reset Password ×3, Employer Login/Register, Profile) | 10 | public |
| home | 1 | 2 | reachable either way |
| dashboard | 1 | 13 | student-only |
| employer | 11 | 31 | mixed (see §6) |
| activities + 9 exercise-type sub-features (ai_speaking/writing/listening/reading, matching, bingo, fill_blank, generic_writing, timer_exercise) | 15 | 90 | student-only |
| mock_tests | 5 | 22 | student-only |
| mock_interview | 1 | 5 | student-only |
| resume | 11 | 36 | mixed (see below) |
| skill_up | 4 screen classes / 5 routes | 6 | student-only |
| grammar | 2 | 5 | student-only |
| group_discussion | 4 | 10 | student-only |
| jam | 8 | 17 | student-only |
| roleplay | 2 | 5 | student-only |
| subscription | 1 | 5 | student-only |
| certifications, aria_chat | 0 routed screens (supporting modules) | 8 | n/a |

**Important correction found during this audit:** `lib/app/router/route_paths.dart`'s own doc comments are **stale in the optimistic-sounding-but-wrong direction** — they claim `register`, `profile`, `pro`, and `resumeInterviewPlaceholder` still render a `ComingSoonScreen`, but `lib/app/router/app_router.dart` has already wired all four to real, substantial screens (`RegisterScreen` 659 lines, `ProfileScreen` 654 lines, `SubscriptionScreen` 108 lines, `MockInterviewScreen` 222 lines). **Do not trust that file's comments for implementation status** — only one route in the whole router, `jobDetail` (`/jobs/detail`, a deliberately-dead legacy no-id fallback, explicitly documented as such), actually renders `ComingSoonScreen`. There are **zero confirmed stub/placeholder screens** in the current app.

**Unreachable-but-built routes**: `publicJobDetailPattern` (`/jobs/:id`) and `myApplicationDetailPattern` (`/my-applications/:id`) are fully implemented, registered routes with no current in-app entry point — nothing constructs the `context.push` that would reach them.

**Resume feature's auth model is mixed by deliberate design, not inconsistency**: `createResumeBuilder`/`createResumePreview`/`careerDepartments`/`careerRoles` require no login (matching the real backend's own no-login endpoints); `manualResumeBuilder`/`manualResumePreview`/`resumeHistory`/`createResumeDrafts` are student-authenticated-only **by deliberate Flutter-side restriction even though the real backend endpoint itself has no login requirement** — documented as a product decision in the route file's own comments, not something this audit can independently judge as right or wrong without the product owner's intent, but worth knowing it's intentional, not an oversight.

*(Full inventory table with every screen, route, and test-file reference: see the research evidence retained for this audit at the path noted in Report 2, §"Evidence sources.")*

## 4. Website-vs-mobile parity matrix — the 15 `CB_changes.docx` items

Read the full docx text this session. All 15 items were previously derived with direct file/line evidence in `docs/PHASE_51_FINAL_AUDIT_REPORT.md`. Since then, `git diff` shows the **only** files touched by any later phase (52-65) are inside `lib/features/employer/`/`test/features/employer/`, so items unrelated to the employer form (1-4, 6-15) have not changed and are reported below as **re-validated as still current via that diff check**, not re-walked from scratch (which would duplicate Phase 51's own already-thorough pass for zero new information). Item 5 is fully re-derived, since it is exactly what Phases 52-65 rebuilt.

| # | Item (paraphrased) | Status | Evidence basis | Key finding |
|---|---|---|---|---|
| 1 | Landing popup within 5s, IT/Non-IT choice | **PASS** | Source + **live-confirmed this session** | 5s auto-trigger, 2-step popup — reproduced live on the emulator (screenshot `01_initial_launch.png`). Minor PARTIAL sub-note: a logged-in student gets no equivalent nudge. |
| 2 | Modified top nav-bar, more sections | **PARTIAL** | Source only | All 10 landing sections exist as widgets, but the nav drawer only exposes 4 of 11 Skill-Up mega-menu entries and no "Resources"/About Us/Industries/Contact Us flat items — content exists, discoverability doesn't match. |
| 3 | IT/Non-IT choice convenience | **PASS** | Source + **live-confirmed** | Reproduced live: popup + a "Choose Your Path" section both route to the real department browser (screenshots `01`-`03`). |
| 4 | Create resumes manually from landing page | **PARTIAL** | Source + **live-confirmed (guest access)** | **Live-confirmed this session**: tapping "Create Resume" on the landing page opens a full guest resume builder with no login prompt (screenshot `13_create_resume_tap.png`) — this specific sub-behavior is a genuine PASS. Remaining gaps: web auto-opens a signed-in user's most recent draft, Flutter always starts blank; only 5 of 12 real web content sections are editable in Flutter. |
| 5 | Changed Job Fields inside Employer portal | **PASS at code/test level; live-device confirmation still BLOCKED** | Source (very thorough — Phases 52-65) | See §5 below — this is the one item that materially changed since Phase 51. |
| 6 | Demo tutorial videos | **PARTIAL** | Source only | Tutorial hub + all 5 real videos match; 9 "What can you do?" cards are inert when only 4 should be; no watched/resume-position persistence. |
| 7 | Department → role → skills/build-resume/resume-parsing popup | **PARTIAL** | Source + **live-confirmed, including a new reproduction** | **Live-confirmed this session** (screenshots `02`-`04`, `06`-`11`): the 3-action popup exists and matches the described structure exactly. But **live-reproduced a specific, previously source-identified gap**: from this popup, "Build Resume" and "Resume Parsing & Interview" both require login on mobile, while "Skills" does not — and the real web's equivalent "Build Resume" is guest-accessible (confirmed from source). Also: Technical vs. Non-Technical browsing resolves to the same combined 21-department list on mobile vs. 2 genuinely different 15-vs-6 sets on the real web. See the new UX-inconsistency finding in §7, Issue AUDIT-01. |
| 8 | ATS score ≥90, role-mismatch forces 0 | **PASS** (architecture) | Source only | Threshold, role-mismatch-forces-zero, 4-way outcome branching all match `views.py`. Live rendering of all 4 branches is BLOCKED — no authorized test account was available this session. |
| 9 | AI interview questions from résumé/role | **PASS** | Source only | Server-side sampling; Flutter is a pass-through. |
| 10 | 5 job recommendations (unlimited for Pro) | **PASS** (architecture) | Source only | Server-rendered/scraped, not re-implemented client-side. Pro-tier "genuinely unlimited" behavior needs a live Pro account to confirm — BLOCKED. |
| 11 | AI chatbot follow-ups, per-language responses | **PASS** | Source + **live-confirmed (UI only)** | **Live-confirmed this session**: the chatbot overlay opened with a greeting, language selector, mic, and contextual action chips (screenshot `16_chatbot_tap.png`). Actual LLM response-language fidelity needs a live round trip not attempted (no message was sent, to avoid any state-changing production call). |
| 12 | More Non-IT Skill-Up content | **PASS** (content) | Source only | Flutter's Non-IT asset JSON is byte-identical to the real web JSON (21 departments, 202 roles). Live WebView rendering unconfirmed — BLOCKED, no device test performed for this specific sub-flow. |
| 13 | Malpractice detection (screenshots/tab-switch/fullscreen) | **PARTIAL** | Source only | Mock Interview tab-switch/blur/strike-escalation are solid and well tested. Confirmed-absent: copy/paste detection, screenshot-block (`FLAG_SECURE`), face detection — by design, not silently skipped. Of 585 web lesson pages using this engine, only 202 are even reachable from current Flutter navigation. |
| 14 | Free-tier gating (English/Vocab/Grammar, 1 activity, 4 parses, no interview) | **PASS** | Source only | No hardcoded client-side limits found; every quota is server-scraped/enforced. The Razorpay pay→verify round trip has never been exercised end-to-end by any phase — not attempted this session either (would be a real payment action). |
| 15 | Low-score recovery (Skill Up Yourself / Build Resume CTAs) | **PASS** | Source only | All 3 resume-side CTAs and the interview-side recovery card match the real web's own conditions and literal copy. |

**Totals: 9 PASS, 6 PARTIAL, 0 MISSING.** Every PARTIAL/BLOCKED sub-facet is a previously-documented, honestly-carried-forward gap except for the new UX-inconsistency finding in §7 (Issue AUDIT-01) and the custom-IT-skill letter-check gap in §5.

## 5. Employer job-posting flow (Item 5) — detailed re-verification

This was Phase 51's single worst finding (a likely submission-blocking defect for every new Non-IT posting, 2 fully-missing fields, 11 "verification incomplete" fields). Re-read current `post_new_job_screen.dart` and its 348-test companion file directly this session (not trusted from the prior phase reports' narrative alone):

- Category-specific requiredness, the duplicate job-type dropdown, gender/interview-mode/notice-period gating — **Phase 52**.
- Education requiredness (**53**) + category-specific education option lists and custom-qualification character/length rules (**54**).
- `experience_plus` ("10+") / `experience_years_max` — fully built, were 100% missing before — **Phase 55**.
- Contract Duration — was always-visible and unvalidated; now conditional on the effective job type, full 1-12 range, 5 exact messages — **Phase 57**.
- Application Contact — was unvalidated; now full email/phone/name + multi-separator rule — **Phase 58**.
- Age Limit — was unvalidated with no error slot; now full `N`/`N+`/`N-M`/`N-M+` rule plus the error slot — **Phase 59**.
- The 7 remaining Non-IT sheet-required fields that had no local check at all — **Phase 60**.
- All 10 `TEXT_FIELD_RULES` fields (`industry_sector`, `industry_experience`, `department_function`, `functional_skills`, `keywords`, `title`, `location`, `certifications`, `software_skills`, `language_requirements`) — **Phases 61 + 65**.
- Salary format/min/max/decimal/cross-field validation — was fully unvalidated; now complete — **Phase 63**.
- Openings 0/negative — **Phase 64** (this phase also discovered, by actually executing the installed Django version, that negative input and zero produce two genuinely different server messages, not one).

**Every one of these is now fixed and covered by automated tests** (348 tests in `post_new_job_screen_test.dart` alone, all re-confirmed passing this session as part of the full 2,710-test run).

**One new finding from this audit, not previously flagged** (see Issue AUDIT-02 in §7): the employer-typed **custom IT skill** validator correctly mirrors the server's character-class and 40-character length rule, but is missing the server's "must contain at least 1 letter" check — a purely numeric custom skill like `"12345"` would be accepted locally and only rejected by the server on submit.

**Still BLOCKED for this item**: no live-device confirmation of the actual employer job-posting flow has been performed by any phase through 65, or by this audit — all 348 tests are `flutter test` widget-level simulations, not a running app with a real employer account. This audit did not attempt to log in as an employer (no authorized test account was available — see §6).

## 6. Emulator-tested flows

**The app was actually built, installed, and launched on a real, already-running Android 14 (API 34) emulator this session** — full detail, screenshots, and exact commands are in `docs/EMULATOR_TEST_EXECUTION_REPORT.md`. Summary:

- Build: `flutter run -d emulator-5554 --debug` — Gradle assembled in 41.4s, installed in 3.1s, launched with **no exceptions, no crash**, reaching the landing page.
- **Safety-critical finding**: this debug build was launched with no `--dart-define=ENV=...` flag, and the app's own `environment.dart` defaults to **`Environment.production`** (`https://careerbuddy4u.com`) when no flag is set (changed from a `dev` default in an earlier phase, specifically because debug builds used to silently hang against an unreachable local address). **This means every screen interacted with in this session was talking to the real, live production backend**, not a sandbox. Accordingly, testing in this session was strictly **read-only navigation**: no login was attempted with any credential (none was available, and none was invented, per the task's own explicit restriction), no form was submitted, no resume was saved/downloaded, no chatbot message was sent, and no job posting, payment, or any other state-changing action was performed.
- Live-tested, read-only: landing page + popup, IT career-path browsing (department list → role list → 3-action popup), the Skills view for a role, the guest Create Resume builder (opened, not submitted), the "Find Jobs" entry point, the logged-out nav drawer, and the AI chatbot overlay (opened, no message sent).
- **New finding from live testing** (Issue AUDIT-01, detailed in §7): three different "this needs an account" entry points behave inconsistently — "Build Resume" (inside a role's popup) cleanly redirects to the Job Seeker Sign In screen; "Find Jobs" does the same; but "Resume Parsing & Interview" (in the same popup as "Build Resume") instead shows a red **"Your session has expired. Please sign in again."** message inline, without navigating anywhere — a misleading message for a user who was never signed in to begin with.
- A peer Claude Code session was found to be using the same shared emulator for a different, unrelated app ("Royal HRMS") — this was identified early and avoided; this audit's testing only touched the Career Buddy LMS package.

## 7. Detailed findings and evidence

### AUDIT-01 — Inconsistent "requires sign-in" handling across 3 entry points in the same popup
- **Feature/screen**: IT Career Paths → [Department] → [Role] popup ("What would you like to do next?")
- **Severity**: Medium
- **Expected website behavior**: not fully confirmed from source in this pass (needs a Django-side trace of the equivalent "Build Resume"/"Resume parsing" links' guest-vs-login behavior); the real web's "Build Resume" is confirmed guest-accessible per Phase 51/this audit's own Item 7 finding.
- **Actual Flutter behavior**: tapping "Build Resume" navigates cleanly to the Job Seeker Sign In screen. Tapping "Resume Parsing & Interview" instead leaves the popup open and shows red text "Your session has expired. Please sign in again." — a confusing message since the user was never signed in.
- **Reproduction**: IT Job Seeker → Development → any role → tap "Resume Parsing & Interview" (screenshots `09`-`11` in Report 2).
- **Verified on**: real emulator, this session (live).
- **Verified through code only**: no — this was live-reproduced, and the specific `_fieldError`/session-check code path producing the message was not independently traced in `lib/` this session (recommended as the first step of any fix).
- **Affects**: functionality (confusing error messaging), not reliability or security.
- **Recommended direction**: trace which widget emits "Your session has expired" for this action and align it with the same clean sign-in redirect "Build Resume" already uses, so every "this needs an account" action behaves the same way.
- **Dependency/limitation**: none to reproduce further; a source trace is the next step.

### AUDIT-02 — Custom IT skill text accepts a purely numeric value locally
- **Feature/screen**: Employer job posting → IT skills picker → "add a custom skill" text entry
- **Severity**: Low
- **Expected website behavior**: Django's `custom_skill_error()` rejects a skill with fewer than 1 letter (`len(re.findall(r'[A-Za-z]', skill)) < 1`).
- **Actual Flutter behavior**: `_addCustomItSkill()` (`post_new_job_screen.dart:424-444`) correctly mirrors the character-class and 40-character-length rule but has no letter-count check — a value like `"12345"` is accepted locally and would only be rejected on the server round trip.
- **Reproduction**: not live-reproduced this session (would require an authorized employer account); confirmed by direct source reading of both `post_new_job_screen.dart` and `jobs_app/forms.py`'s `custom_skill_error()`.
- **Verified through code only**: yes.
- **Affects**: functionality (a minor, narrow-edge-case local-validation gap), not security or reliability.
- **Recommended direction**: add the same `len(re.findall(...))  < 1` -equivalent check already used elsewhere in this codebase's validators (Phase 61/65 established the exact pattern to reuse).
- **Dependency/limitation**: none.

### AUDIT-03 — Non-IT department browsing shows one combined list instead of 2 distinct sets
- **Feature/screen**: Non-IT Job Seeker → Technical / Non-Technical department browsing
- **Severity**: Medium
- **Expected website behavior**: the real web shows 2 genuinely different, non-overlapping department sets for Technical (15) vs. Non-Technical (6).
- **Actual Flutter behavior**: both resolve to the same combined 21-department list.
- **Verified through code only**: yes (carried from Phase 51, re-confirmed unchanged by this session's git-diff check).
- **Affects**: functional parity (a real content/behavior mismatch, not a crash).
- **Recommended direction**: split the Non-IT department data source the same way the real web's `career_path()` view does.

### AUDIT-04 — HTML-scraping integration architecture is a standing structural risk
- **Feature/screen**: entire app's backend integration layer
- **Severity**: Medium (architectural, not a specific bug)
- **Expected/actual**: the app has no JSON REST API; it authenticates via a Django session cookie and parses server-rendered HTML for almost every data source (confirmed in `auth_remote_datasource.dart`'s own doc comment: "there is no JSON login API"). This is clearly a deliberate, heavily-documented choice (extensive "confirmed live against production" comments throughout), not an oversight.
- **Risk**: any server-side template/markup change is one step away from silently breaking a data source, with no compile-time protection.
- **Verified through code only**: yes.
- **Recommended direction**: no immediate fix implied — this is a standing architectural characteristic to monitor, best mitigated by the project's own existing practice of pinning parsers to specific, documented markup and testing against it.

### AUDIT-05 — Several feature areas have thin automated test coverage
- **Feature/screen**: `splash` (0 test files), `home` (2 tests vs. 22 source files), `certifications`, `subscription`, `mock_interview`, `grammar`, `roleplay`, `aria_chat` (each 4-5 tests against 12-19 source files).
- **Severity**: Low-Medium (subscription gates paid functionality, so a gap there is higher-impact than its raw ratio suggests).
- **Verified through code only**: yes (file-count ratios) — this is a coverage-breadth signal, not a confirmed defect; a feature could have few-but-thorough tests.
- **Recommended direction**: prioritize `subscription` and `home` for new coverage given their traffic/impact.

### Carried-forward findings (not new, already documented in Phase 51 and re-confirmed unchanged this session)
Items 2, 4, 6, 7 (department-list split, dead-link-precision on deep links), 13 (malpractice-detection gaps, 383 unreachable Tech-Center lesson pages) — see §4's table for each item's specific carried-forward gap; not repeated here to avoid duplication.

## 8. Existing behavior that already matches the website

Landing popup timing/structure, IT/Non-IT convenience toggle, guest Create Resume (save/restore/PDF), department→role→3-action popup structure, skills display, AI interview question sourcing, job-recommendation threshold architecture, AI chatbot section-awareness and language list, Non-IT Skill-Up content data parity, free-tier gating architecture, and low-score recovery CTAs — all confirmed PASS per §4's table, each with its own evidence basis noted.

## 9. Regressions or inconsistencies found

**No regression** was found in Phases 52-65's own employer job-posting work — re-confirmed via the full, actually-executed 2,710-test run (0 failures) and `flutter analyze` (0 issues). The 2 new findings (AUDIT-01, AUDIT-02) are **gaps**, not regressions — AUDIT-01 pre-dates this session's work and was only newly *reproduced live*; AUDIT-02 is a previously-unflagged gap in long-standing (pre-Phase-52) code, not something any recent phase broke.

## 10. Limitations and remaining uncertainties

- **No authorized test account was available or used.** Every flow requiring student, employer, or Pro-tier login is marked BLOCKED for live confirmation in §4, consistent with the task's explicit instruction not to invent credentials.
- This audit sampled roughly 16 live interactions out of 75 screens; the remaining screens' live behavior is assessed from source only, clearly marked as such throughout.
- The complete `flutter test` suite verifies application logic, not the actual rendered/interactive experience — a passing test is not proof of visual or live-network parity, per the task's own stated principle.
- Payment (Razorpay), OTP delivery, and any flow requiring a real inbox/phone were not exercised, live or otherwise.
- The Non-IT department-list split (AUDIT-03) and the malpractice-detection gaps (Item 13) were not re-walked file-by-file this session — they are carried forward from Phase 51's own thorough, file-cited pass, confirmed still current only via the git-diff check described in §4.

---

**See also:** `docs/EMULATOR_TEST_EXECUTION_REPORT.md` (full emulator session detail) and `docs/REMAINING_IMPLEMENTATION_ROADMAP.md` (prioritized next steps). No implementation was started or should be started until these are reviewed and explicitly approved.
