# Phase 67 — Complete Website-to-Mobile UI Parity Audit

**Date:** 2026-10-27
**Scope:** component-level visual and functional UI comparison, building on the prior feature-level audit (`docs/COMPLETE_WEB_MOBILE_PARITY_AUDIT.md`) and Phase 66's fixes. This report does not repeat work already done in those documents in detail — it cites them and goes deeper where this phase found new ground to cover.

## 1. Sources and evidence inspected

- **Flutter**: `Mobile_app/lib/` — route configuration (`app/router/route_paths.dart`, `app_router.dart`, `route_guards.dart`), design tokens (`app/theme/`), shared widgets (`shared/widgets/`), and every feature module referenced below.
- **Django reference (updated)**: `royalStaffing_CB01/templates/`, `career_app/`, `jobs_app/`, `activities/`, `accounts_app/`, `users/` — templates, views, and static JS/CSS read directly for each area audited.
- **Django reference (original)**: consulted only where the updated repo was ambiguous; not separately re-walked in this phase.
- **Production** (`https://careerbuddy4u.com`): read-only GET requests only (no WebFetch/curl was used inside the research forks, per their scope; direct production requests were made personally by the coordinator only for the Phase 66 resume-sign-in conflict, already documented there — not repeated here).
- **Prior reports read before starting**: `COMPLETE_WEB_MOBILE_PARITY_AUDIT.md`, `EMULATOR_TEST_EXECUTION_REPORT.md`, `REMAINING_IMPLEMENTATION_ROADMAP.md`, `PHASE_66_WEB_MOBILE_PARITY_FIXES_REPORT.md`, `PHASE_51_FINAL_AUDIT_REPORT.md`/`PHASE_51_FINAL_PARITY_MATRIX.md`, `PHASE_62_EMPLOYER_VALIDATION_PARITY_AUDIT.md` through `PHASE_65_REMAINING_TEXT_VALIDATION_REPORT.md`, `PHASE_42`/`PHASE_45`/`PHASE_46`/`PHASE_47`/`PHASE_48`/`PHASE_49` reports.
- `~/Downloads/CB_changes.docx` was already read in full during the prior audit session (its 15-item numbering is preserved in `COMPLETE_WEB_MOBILE_PARITY_AUDIT.md` §4) — not re-extracted in this phase, since nothing in this phase's findings concerns a `CB_changes.docx` item not already covered there.
- **Git baseline at phase start**: identical to Phase 66's end state (5 modified employer files + 6 unrelated pre-existing modified test files, all preceding this project's involvement; 19 untracked `docs/` reports). Confirmed via `git status --short` before any edit in this phase.

## 2. Method

Four parallel, read-only research passes (each is recorded as its own evidence trail, retained in the session's scratch files) covered:
- **Fork A**: Splash, Auth (login/register/OTP/password-reset), Navigation (top nav/drawer/footer), Landing/Home.
- **Fork B**: Career Paths (IT/Non-IT browsing + role popups) and the entire Resume feature.
- **Fork C**: Student Dashboard, Employer screens, Subscription/Payment, AI chatbot overlay.
- **Fork D**: Skill-Up, all Activities/exercise types, Mock Tests, Mock Interview, Grammar, Group Discussion, JAM, Roleplay, Certifications.

Each fork read the actual Django template/view/form source and the actual Flutter screen/widget source side by side, rather than relying on prior reports' narrative conclusions. The coordinator separately drove live, read-only emulator interaction (screenshots captured) for the areas easiest to verify without an authenticated account, and independently confirmed one additional finding (the nav drawer gap, §5 UI-N-001) by directly reading the website's shared nav template after observing the gap live.

**Coverage was not uniform.** Given the scope, some areas received a full line-by-line diff (e.g., Subscription, Login, Register, Employer Login, Career Paths, Resume) while others received only a structural/inventory check (e.g., JAM, Roleplay, Group Discussion, Certifications, the 4 AI exercise modules' visual layer, Employer Dashboard/Company Profile/Applications screens). Every "not verified" area is listed explicitly in §9 — none are silently treated as matched.

## 3. Status legend

- `MATCHED` — supported by adequate comparison evidence (source-level or live).
- `PARTIAL` — some confirmed differences remain.
- `MISSING` — a source-backed page or feature has no corresponding implementation.
- `BLOCKED` — cannot be verified with available access (no test account, or out of time budget this phase).
- `CONFLICT` — website sources disagree with each other (production vs. reference repo).

## 4. Screen inventory and website→Flutter mapping (summary)

The full 75-screen/26-module inventory from the prior audit (`COMPLETE_WEB_MOBILE_PARITY_AUDIT.md` §3) is reused here as the structural baseline — it was re-confirmed still accurate by this phase's forks (no new screens or routes were found to exist that weren't already catalogued, and no catalogued screen was found to have been removed). This phase adds component-level detail on top of that structural map, area by area, in §5.

## 5. Findings

Severity: Critical / High / Medium / Low. Confidence: Confirmed from source / Confirmed live / Inferred / Blocked.

### 5.1 Auth, Navigation, Landing (Fork A)

| ID | Screen/area | Flutter | Django | Discrepancy | Severity | Status |
|---|---|---|---|---|---|---|
| UI-A-001 | Login branding pane | `login_screen.dart:218-246` | `templates/users/login.html:9-14` | Generic `Icons.school_outlined` instead of the real bundled `assets/images/logo-mark-light.png` (already used correctly elsewhere, `app_top_bar.dart:36-43`); missing "Since 2026" tagline; "CareerBuddy" not split bold like the web's "Career**Buddy**". | Medium | PARTIAL (confirmed from source, deferred) |
| UI-A-002 | Login subtitle wording | `login_screen.dart:258` | `templates/users/login.html:17` | Flutter: "Continue your journey to Business English mastery and career growth." / Web: "Continue your journey to career growth." — wording has drifted. | Low-Medium | PARTIAL (confirmed from source, deferred) |
| UI-A-003 | Login feature list spacing | `login_screen.dart:189` | `templates/users/login.html:19` | "20+" vs web's "20 +" (space before +) — cosmetic. | Very Low | PARTIAL (deferred) |
| UI-A-004 | Register header | `register_screen.dart:219` | `templates/users/register.html:132-135` | Flutter: bare AppBar "Create Account". Web: "Candidate Registration" + subtitle + 72px gradient icon box. | Medium | PARTIAL (confirmed from source, deferred) |
| UI-A-005 | Login screen doc comment | `login_screen.dart:35-38` | n/a | Stale comment falsely claims register/password-reset/employer screens don't exist yet — internal-only, not user-facing. | Low (internal) | Confirmed from source |
| UI-A-006 | Employer Login banner | `employer_login_screen.dart` (whole file) | `templates/employer_login/login.html:17-34`; view `accounts_app/views.py:86-88` | Real page has the same two-pane branding banner as student login ("Welcome Back!" + 4 employer feature bullets). Flutter has a single centered card only — its own doc comment incorrectly claims the real template is single-card. | High | MISSING (confirmed from source, deferred) |
| UI-A-007 | Password-reset flow (3 screens) | `forgot_password_screen.dart`, `reset_password_screen.dart`, `password_reset_complete_screen.dart` | `templates/registration/password_reset_*.html` | Headings match; Flutter's extra "paste your reset link" step is a deliberate, sensible mobile adaptation (no deep-link-through-email-client), not a defect. | — | MATCHED |
| UI-A-008 | Employer Login/Register form-pane copy | `employer_login_screen.dart:113-177` | `templates/employer_login/login.html:39-86` | Titles/CTAs/"student portal" link all match exactly. | — | MATCHED (form pane only; banner is UI-A-006) |
| UI-A-009 | Nav drawer `_goComingSoon` helper name | `app_nav_drawer.dart:180-183` | n/a | Misleadingly named (legacy from when these really were placeholders) — it's just a generic pop-then-push now; no functional bug. | Very Low (internal) | Confirmed from source |
| UI-A-010 | Nav drawer Skill-Up sub-items (authenticated) | `app_nav_drawer.dart:97-100` | n/a | "English & Vocabulary"/"Aptitude"/"Tech"/"Browse All" all route to the same destination — carried forward from the prior audit's Item 2, not new. | Medium (carried forward) | PARTIAL |
| UI-A-011 | Splash screen | `splash_screen.dart` | n/a — no web equivalent | Plain navy + spinner, no logo. Not a parity gap (no website page to compare), flagged only as a polish note. | Low (not parity) | N/A |
| UI-A-012 | Footer | `app_footer.dart:73-113` | not fully re-verified | Brand/copyright line checked and correct; full link list not diffed this pass. | — | BLOCKED (not verified this pass) |
| **UI-N-001** (coordinator's own finding) | **Guest nav drawer** | `app_nav_drawer.dart` (guest branch, pre-fix: lines 156-173) | `templates/includes/site_nav.html:192-258` (`cbMobileMenu`) | **Confirmed live on the emulator** and from source: the real site's mobile menu shows a signed-out visitor 8 top-level items — Home, About Us, Skill Up (10-item submenu), Resources (6-item submenu), Industries, Create Resume, Contact Us, plus the 2 logins. Flutter's guest drawer showed only Home + the 2 logins — nothing else at all. | **High** | **MISSING → PARTIALLY FIXED this phase** (see §6) |

### 5.2 Career Paths and Resume (Fork B)

| ID | Screen/area | Flutter | Django | Discrepancy | Severity | Status |
|---|---|---|---|---|---|---|
| UI-R-001 | Create Resume Builder — content sections | `create_resume_builder_controller.dart:13-18` (5 steps: Personal, Summary, Skills, Experience, Education) | `career_app/create_resume.py:32-35` — real `SECTIONS` has 10 entries (adds Projects, Certifications, Achievements, Internships, Languages) plus `REPEATABLE`'s `volunteering` and 6 `ADDITIONAL_FIELDS` sub-fields | Refines the prior audit's "5 of 12 sections" finding with exact backend tuple evidence. Large, multi-step content gap — not attempted this phase (too large for this batch). | High (large scope) | PARTIAL — roadmap item |
| **UI-R-002** | Role Picker → role action sheet → "Skills" | `role_picker_screen.dart:310-314` (pre-fix: hardcoded `enabled: false`, "Coming soon") | `templates/landing.html:7589-7622`, `8729-8749` — the single generic `#roleAct` dialog's "Skills" card is always a real, enabled action for every role (`pickRole()`'s own comment: "Skills uses the role modal when the role has skills data, otherwise Skill Up") | Flutter's catalog-role sheet was the only one of the app's two near-identical role-action sheets that still disabled Skills — the sibling `CareerRoleActionSheet` (department-tree roles) already did this correctly. The data (`ResumeRole.fields`) already existed. | Medium | **MISSING → FIXED this phase** (see §6) |
| UI-R-003 | Non-IT Career Paths screen title (Technical/Non-Technical tracks) | `career_departments_screen.dart:32` | n/a (no single destination-page title to compare) | Both single-group tracks (new in Phase 66) still show the generic "Non-IT Career Paths" title, not a more specific one — cosmetic only, correct content renders either way. | Low | PARTIAL (deferred) |
| UI-R-004 | Create Resume — auto-load signed-in user's most recent draft | `create_resume_builder_controller.dart` | `static/js/create_resume.js:819-823` | Carried forward from the prior audit (Item 4) — Phase 45 only restores a guest's local draft, never an authenticated user's server-saved one. Not independently re-walked this pass. | Medium (carried forward) | PARTIAL |
| UI-R-005 | Resume History screen | `resume_history_screen.dart` | `templates/resume_history.html` | No new discrepancy found; screen's own doc comments show careful, specific parity work. Not re-verified line-by-line this pass. | — | BLOCKED (not deeply re-verified) |

### 5.3 Dashboard, Employer, Subscription, Chatbot (Fork C)

| ID | Screen/area | Flutter | Django | Discrepancy | Severity | Status |
|---|---|---|---|---|---|---|
| **UI-E-001** | Subscription — Free plan resume-parse limit | `subscription_plan.dart:57` (pre-fix: "Unlimited Resume Parsing & ATS Score Analysis") | `templates/pro.html:173` ("4 Resume Parsing & ATS Score Analyses") | Free tier is actually capped at 4, matching `CB_changes.docx` Item 14's already-confirmed free-tier limit elsewhere in this project. Factually wrong, user-facing pricing claim. | **High** | **PARTIAL → FIXED this phase** (see §6) |
| **UI-E-002** | Subscription — Normal & Pro mock-interview threshold | `subscription_plan.dart:72,86` (pre-fix: "70 or above", both plans) | `templates/pro.html:252-253,328-329` ("90 or above", both places) | Duplicated numeric error affecting both paid plans' job-recommendation unlock condition. | **High** | **PARTIAL → FIXED this phase** (see §6) |
| UI-E-003 | Subscription — Free plan "not included" bullets | `plan_card.dart:81-93` | `templates/pro.html:159-178` | Real Free card has 2 explicit "not included" bullets (red X icon, `feature-item disabled` class). `PlanCard` has no disabled/excluded visual treatment at all — only ever renders a green check-circle. Adding the 2 facts without that treatment would be more misleading (implying they ARE included), so deliberately left for a future phase alongside that UI work. | Medium | MISSING — roadmap item |
| **UI-E-004** | Subscription — Normal plan feature list | `subscription_plan.dart:66-73` (pre-fix) | `templates/pro.html:226-254` | Missing the real "Full Skill Up access ... with certificates for scoring 70 or above" bullet; had a fabricated "Grammar & Vocabulary Practice Exercises" bullet that doesn't exist on the real card; bullet order also differed. | Medium | **PARTIAL → FIXED this phase** (see §6) |
| UI-E-005 | Subscription — Free plan tagline | `subscription_plan.dart:52` | `templates/pro.html:145` | "Essential access to begin learning Business English." vs. real "Essential access to English, grammar and resume scoring." | Low | PARTIAL (deferred) |
| UI-E-006 | Subscription — plan badges | `plan_card.dart` | `templates/pro.html:143,211,291-292` | Real page shows a small pill badge per plan ("Starter"/"Basic Plan"/"Full Suite"); Flutter only ever shows "Recommended" on Pro. Decorative. | Low | MISSING (deferred) |
| UI-E-007 | Subscription — Normal plan AI Mock Interview wording | `subscription_plan.dart:71` (pre-fix: "AI Technical Mock Interviews") | `templates/pro.html:245-249` ("AI Mock Interviews (open when your resume scores 90% or above in ATS)") | Dropped the unlock condition, added "Technical" which isn't in the real Normal-tier wording. | Medium | **PARTIAL → FIXED this phase** (folded into UI-E-004's fix, see §6) |
| UI-E-008 | Subscription — resume-parsing bullet detail | `subscription_plan.dart:70,84` (pre-fix) | `templates/pro.html:242-243,314-315` | Both Normal and Pro dropped "(Extract text, density & format check)". Cosmetic. | Low | **PARTIAL → FIXED this phase** (folded into the same edit, see §6) |
| UI-E-009 | Subscription — current-plan/renewal state | `subscription_screen.dart:16-20,74-88` | `templates/pro.html:182-201,258-281,338-...` | No backend endpoint exists for current-plan status (documented, accepted limitation per `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md`) — not a new finding. | N/A | Already documented/accepted |
| UI-D-001 | Student Dashboard section order | `dashboard_screen.dart:103-169` | `templates/dashboard.html` | Spot-checked only: section order (stats → recommended jobs → activity progress → payment history) matches. Field-level card content not compared. | — | BLOCKED (needs deeper follow-up) |
| UI-D-002 | Student Dashboard stat cards | not inspected in depth | `dashboard.html:66-90` (4 cards: Total Activities/Completed/In Progress/Total Score, distinct colors/icons) | Not compared against `DashboardStatsRow` this pass. | — | BLOCKED |
| UI-M-001 | Employer Dashboard / Company Profile / Applications — visual layout | `employer_dashboard_screen.dart` (479 lines) and siblings | `templates/employer/dashboard.html` and siblings | **Not compared in this pass** — a real coverage gap, explicitly flagged by the fork rather than assumed fine. | — | BLOCKED (recommend dedicated follow-up) |
| UI-M-002 | AI chatbot overlay | `buddy_chatbot_overlay.dart` | not located in Django source this pass | Not compared beyond the prior audit's live screenshot confirming it opens correctly. | — | BLOCKED |

### 5.4 Skill-Up, Activities, Mock Interview, JAM, Roleplay, GD, Certifications (Fork D)

| ID | Screen/area | Flutter | Django | Discrepancy | Severity | Status |
|---|---|---|---|---|---|---|
| UI-S-001 | Skill-Up lesson WebView fullscreen quiz | `skill_up_lesson_screen.dart` (plain `WebViewController()`, no `onShowCustomView` wiring) | 585 lesson HTML pages' own `requestFullscreen()`/`fullscreenchange` proctor engine (confirmed present per Phase 48) | The real page's assessment likely never actually goes fullscreen inside Flutter's WebView. Functionally harmless (the page's own JS wraps every call in `.catch(()=>{})` and only warns on an actual fullscreen *exit*) — a visual/UX gap, not a functional break. | Medium | BLOCKED — needs live verification on a paid-plan account |
| UI-S-002 | Skill-Up hub tabs | `skill_up_screen.dart:26-40` | real page's 4 anchor sections | No discrepancy — labels and structure match exactly. | — | MATCHED |
| UI-S-003 | Mock Interview camera gate | `mock_interview_camera_gate_view.dart` | `templates/resume_interview.html:414-428` | No discrepancy — copy matches verbatim. | — | MATCHED |
| UI-S-004 | Mock Tests (AMCAT/Cocubes) data contract | `amcat_remote_datasource.dart` etc. | `activities/views.py:1890-2068` | Architecture confirms match (server-authoritative JSON); rendered palette/timer/result UI not compared pixel-for-pixel (out of time budget). | — | MATCHED (data) / BLOCKED (rendered visuals) |
| UI-S-005 | Grammar index | `grammar_index_screen.dart:18-20` | not independently re-read this pass | Accepted on the strength of the screen's own specific doc comment; not independently re-confirmed. | Low | BLOCKED (inferred only) |
| UI-S-006 | JAM / Roleplay / Group Discussion screen inventories | various | not independently re-read this pass | Structural/name-level check only — screen names map plausibly to expected flows. | — | BLOCKED (structural only) |
| UI-S-007 | AI Speaking/Writing/Listening/Reading visual layer | `ai_speaking/`, `ai_writing/`, `ai_listening/`, `ai_reading/` | `templates/activities/modules/*.html` | Functional/data-contract layer already exhaustively covered by `docs/W014`-`W017`; visual/layout layer not independently re-verified this pass. | — | BLOCKED |
| UI-S-008 | Certifications | 17 Flutter files, no dedicated routed screen (embedded in Skill-Up) | `skillup_assessment/views.py` | Structural naming match only; not read line-by-line. | — | BLOCKED |

## 6. Correction batch implemented this phase

Per Step E's priority order (broken/misleading behavior → missing/incorrect navigation → major layout differences → missing functionality → minor cosmetic), the following **5 findings** were selected, implemented, and verified this phase. Everything else in §5 is left for a future phase.

1. **UI-E-001** — Subscription Free plan: "Unlimited Resume Parsing & ATS Score Analysis" → "4 Resume Parsing & ATS Score Analyses".
2. **UI-E-002** — Subscription Normal & Pro plans: "70 or above" → "90 or above" for the job-recommendation unlock condition (both places).
3. **UI-E-004** (+ UI-E-007, UI-E-008, folded in as the same fix) — Subscription Normal plan: removed the fabricated "Grammar & Vocabulary Practice Exercises" bullet, added the real missing "Full Skill Up access..." bullet, corrected the AI Mock Interview wording, added the "(Extract text, density & format check)" detail to Normal/Pro's resume-parsing bullets, and matched the real bullet order.
4. **UI-R-002** — Role Picker's "Skills" action: enabled it for every role (was permanently "Coming soon"), reusing the existing `fields`-based skill-group data and the sibling sheet's already-correct UI pattern.
5. **UI-N-001** — Guest nav drawer: added a "Create Resume" entry (previously the drawer had only Home + the 2 login tiles for a guest). The full nav gap (About Us, Skill Up submenu, Resources submenu, Industries, Contact Us) is much larger and requires either new anchor-scroll plumbing or new destinations — deliberately deferred as a roadmap item (see `docs/PHASE_67_UI_PARITY_IMPLEMENTATION_REPORT.md` for the exact scoping rationale).

Full implementation detail, exact diffs, tests, and verification are in `docs/PHASE_67_UI_PARITY_IMPLEMENTATION_REPORT.md`.

## 7. Conflicts between production and reference source

No new production-vs-reference-repo conflict was found in this phase's scope. The one known conflict remains the Phase 66 finding: the reference repo's `resume_builder_home` has no login gate, while live production redirects a guest to `/users/login/...` — already documented in `docs/PHASE_66_WEB_MOBILE_PARITY_FIXES_REPORT.md` and not re-investigated here, per this phase's instruction to keep it as-is.

## 8. Blocked flows / missing authorized test accounts

No authorized student, employer, or Pro-tier test account exists. Every finding above marked `BLOCKED` for live verification is blocked specifically for this reason (not time/laziness) when it requires an authenticated session: Student Dashboard content, Employer Dashboard/Company Profile/Applications, Skill-Up lesson fullscreen behavior, JAM/Roleplay/Group Discussion content, Mock Tests rendered UI, AI exercise modules' visual layer.

## 9. What was NOT verified (explicit)

- Employer Dashboard, Company Profile, Job Openings/Applications list and detail screens — visual layout not compared in any depth (a real, acknowledged coverage gap).
- AI chatbot overlay — not compared beyond the prior audit's single live screenshot.
- Student Dashboard — section order spot-checked only, not field-level.
- JAM, Roleplay, Group Discussion, Certifications — structural/name-level inventory only.
- AI Speaking/Writing/Listening/Reading — visual layer not compared (functional layer already covered elsewhere).
- Footer's full link list — only the brand/copyright line checked.
- Grammar index's exact content — accepted from the screen's own doc comment, not independently re-read.
- Mock Tests' rendered UI (palette/timer/result visuals) — not compared pixel-for-pixel.
- No live/authenticated emulator interaction was attempted for anything requiring a sign-in — every live check this phase was guest/read-only navigation.
- Production was not re-queried for anything in this phase beyond what Phase 66 already covered.

## 10. Proposed correction order for future phases

1. **UI-A-006** (Employer Login banner) — high severity, well-evidenced, reuses the existing `LoginScreen` branding-pane pattern.
2. **UI-R-001** (Create Resume's 5-of-10 sections) — high-value but large; scope as its own multi-step phase.
3. **UI-E-003** (Subscription Free plan "not included" bullets) — needs a small `PlanCard` extension (a disabled/excluded bullet style) before the content can be added faithfully.
4. **UI-N-001 remainder** (full guest/authenticated nav parity — Skill-Up submenu, Resources submenu, Industries, About Us, Contact Us) — needs either anchor-scroll plumbing on the Home screen or dedicated destination screens; larger scope, own phase.
5. **UI-A-001/002/004** (Login/Register cosmetic polish) — low risk, quick wins, bundle together.
6. **UI-M-001** (Employer screens visual layout) — needs a dedicated audit pass first (this phase's fork ran out of budget before reaching it).
7. **UI-S-001** (Skill-Up lesson WebView fullscreen) — needs a live, authenticated verification step before any fix is attempted, since the actual on-device behavior is only inferred, not confirmed.
8. Everything else in §5 marked `BLOCKED` — schedule once a test account becomes available, or as a source-only deep-dive otherwise.
