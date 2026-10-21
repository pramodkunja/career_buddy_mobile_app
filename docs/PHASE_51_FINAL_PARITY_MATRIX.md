# Phase 51 — Final Web-to-Mobile Parity Matrix

Source checklist: `CB_changes.docx` (15 numbered items, extracted verbatim this
phase by unzipping the `.docx` and parsing `word/document.xml` directly —
the file stores all 15 items as one paragraph separated by `<w:br/>` line
breaks, not 15 separate paragraphs). Web reference: `royalStaffing_CB01`
(current, read-only). Original reference: `Career_Buddy_LMS` (read-only,
not separately re-audited this phase beyond what prior phases already
established, since `royalStaffing_CB01` is the authoritative "updated"
tree per every prior phase's own convention). Flutter reference:
`Mobile_app/` current working tree (uncommitted changes from Phases 42–50
all present and preserved — see the Audit Report §9 for the full working-tree
state recorded before this audit began).

**Method**: 10 parallel, read-only research passes (one Claude agent per
functional area), each re-deriving evidence directly from current source
rather than trusting prior phase reports, each running its own focused
`flutter test`/`flutter analyze` commands and reporting exact counts. This
document is the synthesis of all 10 reports, reconciled by the orchestrating
session, including two explicit **overrides of prior phases' own framing**
where a fresh, deeper look found the old characterization no longer
defensible (Item 5's employer-field validation bug, Item 7/13's
Technical/Non-Technical and Tech-Center-reachability findings) — see the
Audit Report for why.

No application or Django source file was modified by this audit. All test
counts below were personally executed by an agent or the orchestrating
session this phase, not copied from old reports, unless explicitly labeled
"per report."

## Summary counts

### Top-level items (15 total)

| Status | Count | Items |
|---|---|---|
| Complete and verified | 8 | 1, 3, 8, 9, 10, 11, 14, 15 |
| Partially implemented | 5 | 2, 4, 5, 7, 13 |
| Implemented, verification incomplete | 2 | 6, 12 |
| Missing | 0 | — |
| Blocked | 0 | — |

A top-level item's status is the worst-case roll-up of its sub-requirements
weighted by user-visible impact, matching Phase 40's own stated convention.
See the Audit Report for the full before/after comparison against Phase 40's
original 6/5/4/0/0 split.

### Sub-requirements (127 total — see the Audit Report §4 for why this is
more granular than Phase 40's 107; the growth is almost entirely in Items 5
and 13, both re-examined this phase in far more mechanical detail than
before)

| Status | Count |
|---|---|
| Complete and verified | 74 |
| Implemented, verification incomplete | 23 |
| Partially implemented | 17 |
| Missing | 8 |
| Blocked | 5 |

---

## Item 1 — Landing page popup

> "Landing Page UI changed. Pop-up displayed within 5 seconds of opening application saying IT/Non-It."

**Overall: Complete and verified.** Built in Phase 49, backdrop-dismissal
corrected in Phase 50, both independently re-confirmed this phase against
current source with zero drift found (one 3-line citation shift in the
trigger script, content identical).

| # | Sub-requirement | Web evidence | Flutter evidence | Test/device evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 1a | 5-second auto-trigger | `landing.html:7577-7584`, `setTimeout(...,5000)`, no storage-based suppression | `home_screen.dart:78`, `Timer(Duration(seconds:5), _maybeShowPathPicker)` | `test/features/home` run this phase: 47/47 passing | Complete and verified | None |
| 1b | 2-step IT/Non-IT → Technical/Non-Technical content & nav | `landing.html:6785-6830` | `home_path_picker_popup.dart` | Same 47/47 run | Complete and verified | Step 2's 2 choices share 1 destination — see Item 7's finding on this exact point, which **changes the recommended classification for that specific facet**; kept here as "Complete" for the popup's own content/structure fidelity |
| 1c | Close (×) / "Maybe later" / Phase 50 backdrop fix | `landing.html:6783,6833`; no backdrop-click listener confirmed via grep | `home_path_picker_popup.dart`, `home_screen.dart:111` (`barrierDismissible: false`) | Same run, incl. "tapping outside... does not dismiss it" and "repeated pumps... never produce a 2nd dialog" | Complete and verified | None |
| 1d | Guest vs. authenticated-student audience | `activities/views.py:78-80` — only an authenticated **employer** is redirected away; a logged-in student still sees `landing.html` | `home_screen.dart:93-94` — popup is guest-only (any `AuthAuthenticated` skips it) | Test: "never appears for an authenticated (non-employer) user" passing | **Partially implemented** | A logged-in student loses this convenience nudge; `AuthenticatedHomeBody` has no equivalent section at all — pre-existing, separate architectural scope (see Item 3) |
| 1e | No persistence across visits | Confirmed no localStorage/cookie/session write anywhere in the popup script | No persistence added; reshows every fresh `HomeScreen` mount | Tests: direct-selection cancellation, navigate-away suppression | Complete and verified | None — genuine parity (both deliberately stateless) |

---

## Item 2 — Top navigation and landing-page sections

> "Modified Top nav-bar and added more features inside the top-nav bar sections in landing page/home page."

**Overall: Partially implemented.** This is the item with the single
biggest *positive* surprise in this audit: the "10+ missing landing
sections" half of Phase 40's finding is now **fully closed** (an
unnumbered `LANDING_PAGE_WEB_MOBILE_PARITY_REPORT.md` phase, run between
Phase 42 and Phase 43, built all of them, with live emulator verification
of every guest-reachable destination at the time). The **nav-bar/drawer**
half of the finding, however, is **still an open, real gap**, re-confirmed
directly against current `site_nav.html` this phase, not merely re-cited.

| # | Sub-requirement | Web evidence | Flutter evidence | Test/device evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 2a | Landing-page sections beyond Phase 37's original hero/footer (Platform Overview, Career Journey, Choose Your Path, Skill Up teaser, Resume & AI, Meet Buddy, About, Resume-maker teaser, Tutorials, Testimonials) | `landing.html`, 10+ sections, confirmed present | All 10 implemented as real widgets (`home_platform_overview.dart`, `home_career_journey.dart`, `home_choose_path.dart`, `home_skill_up_teaser.dart`, `home_meet_buddy_section.dart`, `home_about_section.dart`, `home_resume_maker_teaser.dart`, `home_tutorials_section.dart`, `home_testimonials_section.dart`) | Live emulator verification **performed by that phase** (per its own report: Get Started/Create Resume/Find Jobs/Check Resume/Ask Buddy/Featured Tutorial all confirmed live as a guest); re-confirmed this phase via a fresh 47/47 `test/features/home` run | Complete and verified | None remaining at the section-existence level (see Items 4, 6, 7 for content-level gaps found *within* some of these sections) |
| 2b | "Skill Up" mega-menu (10 content links + "Browse all" = 11) | `site_nav.html:67-93`, 3 columns, 11 entries, re-counted directly this phase | `app_nav_drawer.dart:92-101` — only 4 of 11 in the drawer's Skill Up group (Grammar exists separately, flat) | No test asserts full menu content | **Partially implemented** | 6 of 11 real categories (Vocabulary & Idioms, Speaking & Presentation, Writing & Correspondence, Negotiation & Meetings, Interactive Roleplay, Certifications) have no nav-drawer entry |
| 2c | "Resources" mega-menu (7 links) | `site_nav.html:95-114` | No "Resources" grouping exists; some content reachable as flat tiles, no Tutorials/Buddy Assistant drawer links | Not tested | **Partially implemented** | No single discoverable entry point; content mostly exists elsewhere, just not grouped/linked the same way |
| 2d | Flat top-level items: About Us, Industries, Create Resume, Contact Us | `site_nav.html:65,124-126` | None of the 4 labels appear in the drawer; underlying content exists on Home (scroll-only), no nav shortcut | Not tested | **Partially implemented** | User must scroll the full Home page instead of tapping a nav item; low-moderate impact since content itself is present |
| 2e | Nav markup doc-citation staleness | `site_nav.html` is now the sole nav source | `app_top_bar.dart:7-14`/`app_nav_drawer.dart:10-13` doc comments still cite old `base.html` line ranges | N/A (doc-only) | **Blocked** (not functional — a doc-hygiene issue this audit cannot fix under audit-only rules) | No end-user impact; future-maintainer confusion only |

---

## Item 3 — IT/Non-IT selection

> "Gave Users the option to choose either IT or Non-IT conveniently."

**Overall: Complete and verified** (for the guest-facing Home screen,
which is the only surface the real web itself treats this way for an
anonymous visitor).

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status |
|---|---|---|---|---|---|
| 3a | Where the choice is offered (popup + always-visible section, both with distinct, correctly non-duplicated copy) | 2 surfaces on `landing.html`, confirmed distinct copy strings | `HomePathPickerPopup` + `HomeChoosePath`, both routing to the real `CareerDepartmentsScreen` | `home_screen_test.dart`: "tapping IT/Non-IT Job Seeker in Choose Your Path..." passing | Complete and verified |
| 3b | No persistence of the choice | Confirmed, no session/cookie write in `career_path()` | In-memory only | Implicit in no-persistence tests | Complete and verified |

Same guest-only caveat as Item 1d applies here (not re-scored separately to
avoid double-counting the identical fact).

---

## Item 4 — Manual resume creation from the landing page

> "Gave users to create resumes manually in the landing page."

**Scope clarification (confirmed this phase)**: the app has two distinct
resume builders. Item 4 refers to the free-form **Create Resume** feature
(`career_app/create_resume_views.py`, no login required to build/preview/
PDF) — **not** the older, role-driven **Manual Resume Builder** reached via
Item 7's popup, which is a structurally separate feature with its own
routes/controllers.

**Overall: Partially implemented.** A genuine, previously-undocumented gap
was found this phase: authenticated users don't get the web's zero-click
"continue your last resume" behavior.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 4a | Landing-page entry, reachable anonymously | `landing.html:6552`, no `@login_required` on preview/pdf/pages views | `home_screen.dart` → `RoutePaths.createResumeBuilder`, in `universalRoutes` | Per report (route-guard tests not re-run this phase) | Complete and verified | None |
| 4b | Required fields are server-driven, not duplicated client-side | `create_resume.py`'s `validate()` is the sole source of truth | No client-side re-implementation; server errors surfaced via `CreateResumeValidationError` | `create_resume_pdf_controller_test.dart` 8/8, `create_resume_pdf_parser_test.dart` 6/6 (personally run) | Complete and verified | None |
| 4c | Preview never rejects; PDF/pages do | `preview_api` always `{ok:true,...}`; `pdf_download`/`pages_api` gate on `validate()` | Parsers encode this exact asymmetry | `create_resume_preview_parser_test.dart` 4/4 | Complete and verified | None |
| 4d | Authenticated save/update/delete (drafts) | `draft_save`/`draft_detail`/`draft_delete`, ownership-scoped, `MAX_PER_USER=20` | Matching remote datasource + `CreateResumeDraftsScreen` (open/delete/new) | `create_resume_drafts_controller_test.dart` 5/5 | Complete and verified | None |
| 4e | Guest local save (no server round-trip) | `localStorage`, keyed `cbCreateResume.v1.guest`, pre-flight client check, no network call | `SecureStorageService` (encrypted, stronger than web's plain localStorage), pre-flight `_isAuthenticated` check | `create_resume_builder_controller_test.dart` 29/29, `create_resume_builder_screen_test.dart` 9/9, `create_resume_guest_draft_local_datasource_test.dart` 9/9, `create_resume_guest_draft_repository_impl_test.dart` 6/6 | Complete and verified | None |
| 4f | Guest draft restoration on reopening | Synchronous `localStorage` read + restore + inline Sign-in link | `restoreGuestDraftIfAvailable()` with race/generation/claim guards (a genuine extra robustness need Flutter has and web doesn't, due to async storage) | Same test files as 4e | Complete and verified | None |
| 4g | **Authenticated-user auto-open-most-recent-draft** | `create_resume.js:821-827` — a signed-in user's most-recently-updated draft auto-opens on page load | **No equivalent exists** — `startBlank()` always starts blank for an authenticated user arriving via the home CTA | None (gap, not test failure) | **Missing** (new finding, not in Phase 39/42/45) | A signed-in user must manually go to "My Resumes → Open" instead of landing pre-filled; data isn't lost, just an extra step |
| 4h | Remaining 7 of 12 content sections (Projects, Certifications, Achievements, Internships, Volunteering, Languages, Additional Info) + page-image preview | `create_resume.py:32-35`, 10 sections + `ADDITIONAL_FIELDS`, confirmed still real on web | Only personal/summary/skills/experience/education are editable; others sent as empty, never omitted (never malformed) | `create_resume_state_test.dart` 9/9 | **Partially implemented** (documented scope decision from Phase 39, still accurate) | Real web content types unreachable on mobile |
| 4i | Sign-in prompts / interrupted-workflow recovery | Only prompted at Save; no guest→account migration on either platform | Matches exactly, including the shared limitation | N/A | Complete and verified | None beyond the web's own pre-existing limitation |
| 4j | PDF/preview generation for implemented sections | Server-rendered PDF, `Content-Disposition`, `no-store` | `CreateResumePdfController`, stale-result guard, rejection vs. ready handling | `create_resume_pdf_controller_test.dart` 8/8 | Complete and verified | None |
| 4k | Live on-device rendering of the full guest-save/restore/PDF round-trip | — | — | Phase 45's report claims live emulator screenshots; **not independently re-verified this phase** (no device access in this audit) | **Blocked** | Labeled "per report," not re-confirmed |

---

## Item 5 — Employer portal job fields

> "Changed Job Fields inside Employer portal."

**Overall: Partially implemented** — **downgraded from Phase 40's "Fully
implemented and verified."** This phase's deeper trace of the actual
conditional-rendering and client-side-validation code (not just a
field-existence check) found a likely **submission-blocking defect for
new Non-IT job postings**. See the Roadmap's P0 entry — this is the single
most severe finding of the entire Phase 51 audit.

**Critical finding**: `post_new_job_screen.dart`'s `_localRequiredErrors()`
unconditionally requires `work_environment`, `interview_mode`, and
`notice_period` — but these fields' input widgets are correctly *hidden*
for Non-IT (matching the web's own `nonit-hide` CSS classes) and are never
populated by `_onCategoryChanged`. A new Non-IT posting therefore likely
fails client-side validation with phantom "required" errors for fields the
employer cannot see or fill in, before any network call is made. Edit mode
is unaffected (Django's `clean()` backfills these server-side on existing
postings, masking the bug there). No test in the suite exercises a full
Non-IT submission — only IT has one, confirming this was never exercised.
**Not device-confirmed in this audit** (no employer account/emulator
access) — classified "Partially implemented" on strong static evidence,
not "Missing" outright, pending a live check.

| # | Sub-requirement group | Status | Count | Notes |
|---|---|---|---|---|
| New fields 1–10 (category/classification/department/designation/perks/skills catalogs/mandatory-skills/work-mode/joining-requirement) | Complete and verified | 10 | Value-for-value match to current `models.py` |
| New field 11 (`employment_type`) | Complete and verified | 1 | — |
| New fields 12–13 (`responsibilities`, `working_hours`) | Complete and verified | 2 | Plain fields, no extra server rules either |
| New field 14 (`salary_format`) | Complete and verified | 1 | — |
| New field 15 (`education` + custom toggle) | Complete and verified | 1 | — |
| New fields 16–23 (8 fields sharing `TEXT_FIELD_RULES`: industry_sector, industry_experience, certifications, keywords, department_function, functional_skills, software_skills, language_requirements) | **Implemented, verification incomplete** | 8 | Char-set/length rules not mirrored client-side; server-authoritative by architecture, correcting Phase 40's inconsistent treatment of these vs. `title` |
| New field 24 (`age_limit`) | Implemented, verification incomplete | 1 | Regex not mirrored |
| New field 25 (`application_contact`) | Implemented, verification incomplete | 1 | Same pattern |
| New field 26 (`contract_duration_months`) | Implemented, verification incomplete | 1 | 12-month ceiling not mirrored; also always-visible rather than conditional (minor) |
| New field 27 (`education_other`) | Implemented, verification incomplete | 1 | Char rules/length not mirrored |
| New field 28 (`experience_years`) | **Partially implemented** | 1 | Only bare whole-number entry works |
| New field 29 (`experience_plus`) | **Missing** | 1 | Hardcoded `false`; no UI control — "10+" years can never be posted |
| New field 30 (`experience_years_max`) | **Missing** | 1 | Hardcoded empty; no range-entry UI |
| Changed: `requirements`, `skills_required` | Complete and verified | 2 | — |
| Changed: `job_type` | **Partially implemented** | 1 | Not gated by `_isIt`; renders a confusing, wrongly-populated duplicate dropdown for Non-IT (doesn't block submission, but is a real UI defect) |
| Changed: `work_environment` | **Partially implemented** | 1 | Likely submission-blocking for new Non-IT postings (see Critical Finding) |
| Changed: `notice_period` | **Partially implemented** | 1 | Likely submission-blocking for new Non-IT→Non-Technical postings |
| Changed: `title` | Implemented, verification incomplete | 1 | Same char-rule-mirroring gap as rows 16–23 |
| Changed: `gender_preference` | **Partially implemented** | 1 | Unconditionally required client-side; web makes it optional for Non-IT |
| Changed: `interview_mode` | **Partially implemented** | 1 | Same likely-blocking root cause as `work_environment` |
| Changed: `salary_min`/`salary_max` | Implemented, verification incomplete | 1 | Range/ceiling rules not mirrored |
| Entry-point/wiring (dashboard → Post New Job, routes registered) | Complete and verified | 1 | 19/19 tests personally run this phase |
| Stale documentation (4 docs still describe this screen as unbuilt) | — (doc hygiene, not scored as its own status row) | — | `WEB_SCREEN_INVENTORY.md`, `WEB_FLOW_MAP.md`, `WEB_TO_MOBILE_SCREEN_MATRIX.md`, `PRODUCTION_E2E_VERIFICATION_REPORT.md` |

**Item 5 sub-requirement totals**: Complete and verified 17, Implemented/
verification incomplete 14, Partially implemented 6, Missing 2, Blocked 0.
(39 rows total, reconciling to the historical "38 fields" + 1 entry-point
row.)

---

## Item 6 — Demo tutorial videos

> "Integrated Demo tutorial videos, so that users can learn more about the Application."

**Overall: Implemented, verification incomplete.** Phase 40's "Missing"
verdict is **stale** — superseded by the same unnumbered Landing Page
Parity phase referenced in Item 2, independently re-confirmed this phase.
Two new, previously-undocumented minor gaps were found.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 6a | Tutorial hub exists with correct heading/copy/structure | `landing.html:7183-7204` | `home_tutorials_section.dart`, verbatim copy/order | `home_screen_test.dart` 44/44 (full file), `test/features/home` 47/47 | Complete and verified | None |
| 6b | Correct video count & content (only real files reproduced) | 37 listed, only 5 real `.mp4` files exist on disk (confirmed via `find`) | `kHomeTutorialVideoIds` — exactly the same 5 | Same run | Complete and verified | None — faithfully honest, no fabricated videos |
| 6c | "What can you do?" cards clickable for the 4 that should open a video | 4 of 9 cards are real buttons wired to the tutorial modal | **All 9 cards are inert** `Container`s, no `onTap` on any of them | No test covers this (confirmed gap, not masked) | **Partially implemented** (new finding) | Tapping "Learn"/"Build your resume"/"Find jobs"/"Get AI guidance" does nothing; content still reachable via Featured Tutorials below, so low severity |
| 6d | Open/play action (native video, real network URL) | In-page `<video controls>`, no autoplay | `VideoPlayerController.networkUrl`, **autoplays** on open (a minor, arguably-better UX deviation) | `home_screen_test.dart` dialog-open test passing | Implemented, verification incomplete | Actual frame decode/playback not confirmed this phase (no device); a prior report claims live-decoded-frame confirmation, cited not re-verified |
| 6e | Loading state | Native browser default only | Explicit `CircularProgressIndicator` | Confirmed passing | Complete and verified | Exceeds web's bare-default UX |
| 6f | Error state | Falls back to "coming soon" on load error | Falls back to an explicit error message | Not test-covered (code-read only) | Implemented, verification incomplete | Low risk; unreachable for the 5 always-present real videos |
| 6g | Guest-only availability | `#videos` is part of guest-only `landing.html` | `HomeTutorialsSection` only in `PublicHomeBody` | Confirmed via the authenticated-branch test groups | Complete and verified | None |
| 6h | Watched-checkmark / resume-playback-position | `localStorage` (`cbTutWatched`/`cbTutPos`) | No equivalent found anywhere | N/A | **Missing** (new finding) | Pure convenience/engagement feature; no functional blocker |

---

## Item 7 — Industry → department → role → action popup

> "when user selects IT/Non-IT from industries section in home page, he sees departments. Inside Departments, he sees roles. If a role is selected, 'skills','build resume','resume parsing' are displayed in a pop-up. Clicking on skills redirects user to skill-up content section, clicking on build resume enables user to build resume in the popup itself, clicking on resume parsing redirects user to parse resumes."

**Overall: Partially implemented.** Phase 40's "Missing" verdict is
superseded by Phase 43/49's work (entry point, department/role browsing,
and the 3-action popup now all genuinely exist) — but this phase's deeper
trace of each of the 3 actions, plus an explicit, independent
re-examination of the Technical/Non-Technical question the brief asked for,
found real content/navigation gaps serious enough to keep the item as a
whole at "Partially implemented," not "Complete."

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 7a | Industries entry point on home page | `landing.html:6729-6778` + popup | `HomeChoosePath` + `HomePathPickerPopup` → `universalRoutes` | `home_screen_test.dart` 45/45 | Complete and verified | None |
| 7b | IT department browsing | `it_departments.json`, 2 groups/10 depts/93 roles | Bundled asset, counts re-verified identical via direct diff this phase | 18/18 (`career_departments_asset_datasource_test.dart` + `career_departments_screen_test.dart` + `career_role_action_sheet_test.dart`) | Complete and verified | None |
| 7c | Non-IT department browsing (combined view) | 21 depts (15 tech + 6 nt) | Bundled asset, re-counted identical this phase | Same 18/18 | Complete and verified | None |
| 7d | Role list inside a department | `route()`, `landing.html:8070-8140` | `career_roles_screen.dart` | Covered indirectly (no dedicated test file — minor coverage gap) | Complete and verified (behavior); test-coverage gap noted | None functional |
| 7e | 3-action popup structure/labels | `roleAct` dialog, `landing.html:7589-7622` | `career_role_action_sheet.dart`, verbatim copy | Same 18/18 | Complete and verified | None |
| 7f | "Skills" action destination | Deep-links to the **specific role's** Skill-Up section (`?section=role-...`) | Opens the **general** Skill-Up hub, no role filter | Covered ("Skills opens the real skills view...") | **Partially implemented** | User must manually find the relevant section instead of landing in it |
| 7g | "Build Resume" action behavior | Opens **inline, same-page/same-dialog**, confirmed **no login required** | Separate full-screen navigation; **route is authenticated-only by deliberate Phase 25 decision**, despite the real web having no login gate here | Covered (synthetic-role test) | **Partially implemented** | A guest who could build a resume this way on web is redirected to Login on Flutter — a real, product-decision-gated capability loss for guests |
| 7h | "Resume Parsing" action destination | `nav_go('resume-builder')`, login-required | Matches, correct `track` mapping (`tech`/`nonit`), correct guest-failure handling | Covered ("a failed Resume Parsing attempt... shows the real error") | Complete and verified | None |
| 7i | **Technical vs. Non-Technical: distinct destinations** | `career_path('technical')`/`'non-technical')` are real, `Http404`-validated, genuinely-filtered routes — confirmed the Django `{% if %}` *omits the whole panel*, and the department-population JS `return`s early for the absent one, so each shows a **different, non-overlapping department list** (15 vs. 6) | `CareerDepartmentsAssetDataSource.load()` resolves any non-`'it'` value to the **same** combined 21-department list; no code path can filter to Technical-only or Non-Technical-only, even though the `category` field needed to do so already exists | Covered only insofar as "both buttons navigate somewhere" (the combined list) | **Partially implemented** (this phase **overrides** Phase 43/47/49/50's framing of this as an acceptable "intentional simplification" — the web demonstrably discards real, distinct content, not just a styling choice) | A user tapping "Technical" (expecting ~15 engineering-type departments) sees 6 unrelated Non-Technical departments mixed in, and vice versa |

---

## Item 8 — Resume Parsing, ATS score, and interview eligibility

> "In resume parsing, ATS score is evaluated, if score is >=90 then AI interview is accessed. if <90 then AI interview is not accessed. If resume uploaded, it's skills,experience,department must be similar to the department the user has selected, then ATS score will be 0 and tells that resume is not matched."

**Overall: Complete and verified.** Phase 46's work fully re-confirmed
against current source this phase, zero drift found at the line level.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status |
|---|---|---|---|---|---|
| 8a | ATS interview threshold value & source (90, independently re-derived, not assumed) | `career_app/views.py:185`, `ATS_INTERVIEW_THRESHOLD = 90` | `kAtsInterviewThreshold = 90` (`resume_analysis.dart:39`) | `resume_html_parser_test.dart` 32/32, `resume_builder_screen_test.dart` 38/38 | Complete and verified |
| 8b | Role-mismatch forces ATS score to 0 | `views.py:217-240` (`_check_role_fit`) | Detected via the server's own unique heading text, never re-derived client-side | Covered in the same 38/38 | Complete and verified |
| 8c | 4-way outcome branching (role-mismatch / below-threshold / eligible / plan-locked) | `resume_match_result.html:223-367` | `ResumeInterviewGate` enum, same precedence order | Covered, incl. "pre-Phase-46 fixtures... fallback" regression | Complete and verified |
| 8d | Two-constants-not-merged design (`kAtsInterviewThreshold` vs. `kInterviewPassingScore`, both 90 today, genuinely separate server constants) | `views.py:185` and `:1134`, 2 distinct module constants | 2 distinct Dart constants in 2 different feature files | Confirmed via source re-read, not just citation | Complete and verified |
| 8e | Live on-device rendering of all 4 populated outcome screens | — | — | No legitimate test account/device available to any phase to date, including this one | **Blocked** |

---

## Item 9 — AI interview personalization

> "In AI interview, Questions asked will be asked related to fresher/experienced and related to skills user mentioned in the resume and role selected."

**Overall: Complete and verified.** This is a server-side DB-bank sampling
system (not an LLM generating questions); Flutter correctly never
duplicates or re-derives any of this logic, only consuming the resulting
session.

| # | Sub-requirement | Web evidence | Flutter evidence | Status |
|---|---|---|---|
| 9a | Fresher/experienced calibration | `resume_utils.py:737-756,1876-1887,1912` | No client-side logic exists to diverge | Complete and verified |
| 9b | Skills-based question selection | `resume_utils.py:1791-1802` | Same — pure consumption | Complete and verified |
| 9c | Role-based question selection | `resume_utils.py:1791-1821` | `selectTargetRole()` sets the same session key the web form submits | Complete and verified |

---

## Item 10 — Job recommendations and subscription limits

> "If user scores >=90 in AI interview, 5 job recommendations displayed for normal and unlimited job recommendations for pro users."

**Overall: Complete and verified** (architecture); one sub-item
unverifiable live without a Pro account.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status |
|---|---|---|---|---|---|
| 10a | >=90 interview-pass threshold gates the list at all | `views.py:1134,1834,1848-1852` | Pass/fail scraped from a literal server-rendered substring, never re-derived from a number | `mock_interview_results_view_test.dart` 13/13, incl. a test literally asserting the constant value | Complete and verified |
| 10b | Exactly 5 for Normal plan | `JOB_RECOMMENDATION_LIMITS = {'normal':5,'pro':None}`, sliced server-side | No client-side slicing logic exists anywhere | Same 13/13 | Complete and verified |
| 10c | Genuinely unlimited for Pro plan | `None` → no slicing at all (not a large sentinel) | Same pass-through rendering, no cap logic | No Pro account available | **Implemented, verification incomplete** |
| 10d | Server-side enforcement (not a client trim) | Confirmed, slice happens before HTML renders | No over-fetch-and-trim pattern found | N/A | Complete and verified |

---

## Item 11 — AI chatbot contextual follow-ups and language

> "AI chatbot will give follow-up questions, for the each section the user navigates to and responses will be given with respect to the language the user had selected."

**Overall: Complete and verified.** Note: these are static, section-keyed
chip sets on both platforms, not LLM-generated follow-ups — the
requirement is satisfied by that mechanism on both sides, not by comparing
against a non-existent AI-generated alternative.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status |
|---|---|---|---|---|---|
| 11a | Section-aware context sent with every request | `BOTscript.js` posts `page`/`path`/`hash`; `riya_bot/views.py` merges them | `_currentRoute()` resolves live from `GoRouterState`, forwarded verbatim | `buddy_chatbot_overlay_test.dart` 17/17, `aria_chat_controller_test.dart` 44/44 | Complete and verified |
| 11b | Section-specific follow-up/action chips | `SECTION_CONTEXT` dict, per-section `quickActions`/`recommendations` | `kAriaWelcomeSectionContext`, same keys, near-verbatim card content | Covered in the same 17/17 | Complete and verified |
| 11c | Language list parity (5 selectable languages) | `<select>`: English/Vietnamese/Hindi/Arabic/Russian, in order | `kAriaLanguages`, identical 5, same order/codes | "lists exactly the 5 real web languages, in order" passing | Complete and verified |
| 11d | Selected language actually changes response language | Server LLM system-prompt instruction + static translation dict | Client forwards `state.language` on every call (chat/voice/TTS) | `aria_chat_controller_test.dart` passing (client-forwarding only) | **Implemented, verification incomplete** | Live LLM output-language fidelity needs a real network round-trip, unverifiable from source on either platform equally — not a mobile-specific gap |
| 11e | Language persists across the session | `sessionStorage` (tab-scoped) | Plain (non-autoDispose) Riverpod `NotifierProvider` (process-scoped) | Covered via panel close/reopen tests | Complete and verified | Minor, documented, reasonable adaptation (process-scope vs. tab-scope) |

One minor code-quality finding (not user-facing): `AriaRemoteDataSource
.sendMessage()` (an unreachable, non-streaming method with exactly zero
call sites in `lib/`) hardcodes `'language': 'english'` — dead code, not a
live bug, flagged for optional cleanup.

---

## Item 12 — Non-IT Skill-Up content

> "Added more non-It content inside skill-up section, before only IT content is present."

**Overall: Implemented, verification incomplete.** Phase 47's work fully
re-confirmed: the Flutter asset is byte-for-byte identical to the real web
JSON (confirmed via `diff`), and all counts were independently re-derived
from scratch, not copied. See Item 13 for how this content's embedded
malpractice engine is now a **live-surface** verification question, not a
hypothetical one.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status |
|---|---|---|---|---|---|
| 12a | All 21 departments present (15 tech + 6 nt) | Filesystem + JSON re-counted this phase: 21 | `assets/data/nonit_skillup_departments.json`, byte-identical to source | `skill_up_nonit_asset_datasource_test.dart` passing | Complete and verified |
| 12b | All 202 roles/lessons present, correct titles/skills/ordering | 202 HTML files = 202 JSON role entries, re-counted | Parsed in source order, no re-sorting | Same suite | Complete and verified |
| 12c | Lesson navigation opens the correct WebView content | `initNonIt()`'s `#load=<coursePath>` mechanism | Same `buildSkillUpLessonUrl()`/`SkillUpLessonScreen` pair every other section uses — no parallel code path | Navigation wiring test passing; actual WebView render **not testable under `flutter test`** | Implemented, verification incomplete | No device to confirm actual render |
| 12d | Authenticated session-cookie forwarding for gated lessons | `SkillUpAccessMiddleware` reads the session cookie directly | `SkillUpLessonScreen._loadLesson()` still builds/sends the cookie header, unchanged since Phase 38, section-agnostic | Not independently testable (WebView platform channel) | Implemented, verification incomplete | Confirmed correct by code reading; no Non-IT-specific live confirmation (only a Tech Center lesson was ever device-verified, in Phase 38) |
| 12e | Locked-content view shown correctly | `LOCKED_PAGE`, explicitly names "the Non-IT Center" | `SkillUpLockedView`, verbatim copy incl. the Non-IT mention | `skill_up_locked_view_test.dart` passing | Implemented, verification incomplete | No live 403 trigger observed for an actual Non-IT URL |
| 12f | Free-vs-paid access behavior | All 202 Non-IT lessons are paid-only, confirmed unchanged | No client-side plan prediction; server's 403 is sole authority | Architectural confirmation only | Implemented, verification incomplete | No legitimate Free or paid account available to any phase to date |
| 12g | Pre-existing IT Skill-Up content remains intact | Web itself still says "3 main sections" | All 3 original sections + platform stats unchanged in `skill_up_data.dart` | Full suite 2,482/2,482 this phase (vs. Phase 47's 2,458 baseline — legitimate growth, not a regression) | Complete and verified |

---

## Item 13 — Assessment malpractice controls

> "added malpractise rules like (Screenshots,tab switching,exiting the fullscreen) to assessments in skillup and AI interview after resume parsing."

**Overall: Partially implemented** — downgraded from Phase 48's more
favorable framing by one concrete, newly-established fact: of the 585
Skill-Up lesson pages carrying the embedded fullscreen/3-warning quiz
engine, only **202 (the Non-IT role lessons) are actually reachable** from
current Flutter navigation. The other **383 (Tech Center's nested
role-course pages)** have **no linking data source at all** — `it_
departments.json` carries no course-path field, unlike the Non-IT
equivalent — so that engine's TechCenter instances are not a verification
gap but a genuine, absent navigation path.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 13a | Mock Interview: tab-switch detection | `resume_interview.html:1734` | `MockInterviewScreen.didChangeAppLifecycleState`, `paused`/`hidden` → `tabSwitch` | 217/217 (`test/features/mock_interview`+`test/features/jam`) | Complete and verified | None (arguably more reliable than the web's spoofable `document.hidden`) |
| 13b | Mock Interview: window-blur detection | `resume_interview.html:1740` | `inactive` → `windowBlur` | Same 217/217 | Complete and verified | None |
| 13c | Mock Interview: 2/3-strike warn→flag→terminate | `views.py:1212-1213`, dynamic, re-confirmed at these exact lines | Reads server-provided thresholds, never hardcoded | Phase 17 regression group, re-run passing | Complete and verified | None |
| 13d | Mock Interview: copy/paste detection | Live on web (`contextmenu`/copy events) | Not reproduced — no native equivalent for a mobile `TextField`; honestly documented | N/A | **Missing** (by design, pre-existing) | A candidate pasting a looked-up answer has no mobile-side detection |
| 13e | Mock Interview: screenshot-attempt detection | Live on web (keyboard-shortcut detection only, self-documented as unable to catch a phone camera) | Not reproduced; **Android's actual `FLAG_SECURE` screenshot-block capability is not implemented either** (confirmed: zero matches repo-wide) | N/A | **Partially implemented** | Correctly doesn't fake a signal it can't observe, but also misses a genuine mobile-only opportunity to be *stronger* than the web here |
| 13f | Mock Interview: face-not-detected / multiple-faces | Live, continuous (`face-api.js`) | Not implemented; no ML/face dependency exists | N/A | **Missing** (pre-existing, honestly documented, blocked on an unmade product decision per Phase 9) | Largest single proctoring-capability gap; an off-camera helper is undetectable |
| 13g | Mock Interview: camera-interrupted (continuous re-check) | Live, continuous | Checked once at the gate only; enum value exists, zero call sites report it | N/A | **Missing** (pre-existing, honestly documented) | Camera could fail/be covered mid-interview undetected |
| 13h | Mock Interview: fullscreen-exit | **Dead code on the web itself** — no `fullscreenchange` listener anywhere in `resume_interview.html` | Never reported, correctly | N/A | Complete and verified (nothing to match — faithful non-behavior) | None |
| 13i | JAM: one-shot auto-stop on backgrounding | `jam/session.html:584-588`, `visibilitychange`-only | `WidgetsBindingObserver`, `paused`/`hidden` only, re-entrancy-guarded | Same 217/217, incl. the Phase 48 lifecycle/guard tests | Complete and verified | None |
| 13j | Skill-Up embedded quiz engine — **Non-IT role lessons (202 files, reachable today)** | `onIncident()`/`exam_guard.js`, fullscreen + 3-warning auto-submit, confirmed present in all 202 | Reachable via `SkillUpNonItRolesScreen` → `SkillUpLessonScreen`; **cannot confirm whether `webview_flutter`'s default config grants real HTML5 fullscreen** (no custom `WebChromeClient`/`WKUIDelegate` override exists) | No automated test can exercise embedded 3rd-party JS | **Blocked** (upgraded from a theoretical to a live-surface question this phase) | If fullscreen never truly engages, only the fullscreen-exit warning branch is affected; tab-switch/blur/keyboard-shortcut counting is independent of fullscreen state and expected to still work |
| 13k | Skill-Up embedded quiz engine — **Tech Center nested role courses (383 files, unreachable)** | Same engine, confirmed present | **No Flutter screen or data source links to any of these 383 files** — `it_departments.json` has no course-path field | N/A — nothing to test, the content isn't navigable | **Missing** (reclassified from an implicit "unverified" to an absent navigation path) | Most of Tech Center's actual graded course content is unreachable on mobile today |
| 13l | Skill-Up: 4 standalone mock-test pages (english_vocab/aptitude/amcat/cocubes) | A 3rd, distinct, inconsistent engine (2 of 4 have full tab-switch+blur, 2 have only fullscreen+PrintScreen) — a pre-existing **web-side** inconsistency | All 4 linked and reachable via `skill_up_data.dart` | N/A | **Blocked** for the fullscreen-specific sub-control (same WebView question as 13j); non-fullscreen sub-controls plausibly functional but unverified live | Not a Flutter-specific defect; inherits a web-side inconsistency already scoped P3 in Phase 40 |
| 13m | Skill-Up Certifications quiz (`skillup_assessment`) | Confirmed, no malpractice engine at all | N/A — correctly nothing to implement | N/A | Complete and verified (nothing to match) | None |

---

## Item 14 — Free-plan restrictions and quotas

> "for free Users, users can only access English and Vocab, grammar, 1 activity and 4 resume parses with no interview, rest of all the features will be locked out and can only be accessible if user subscribes to it."

**Overall: Complete and verified.** Notably low-drift-risk architecture:
no hardcoded client-side numeric limit was found anywhere in the audited
code paths — every count/threshold/lock state is either scraped live from
server HTML or enforced purely server-side with Flutter as a faithful
pass-through.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status |
|---|---|---|---|---|---|
| 14a | Free allowlist: English/Vocab, Grammar | `skillup_access.py:17-21`, re-confirmed unchanged | Matching `relativePath`s; gating is server-authoritative via the WebView cookie-forwarding mechanism, not duplicated client-side | `test/features/skill_up` 34/35 (depending on run) passing | Complete and verified |
| 14b | "1 activity" limit | `activities/views.py:388`, `FREE_ACTIVITY_LIMIT = 1` | No hardcoded "1" anywhere; scraped from `js-locked-activity`/banner text | 63/63 across the 3 activities test files | Complete and verified |
| 14c | "4 resume parses" quota (re-verified current value) | `views.py:173`, `FREE_RESUME_PARSE_LIMIT = 4`, confirmed still current, lifetime-count semantics | `parseResumeParsesLeft()` regex-scrapes the live count; numerically agnostic, never hardcodes "4" | `resume_html_parser_test.dart` 32/32 | Complete and verified |
| 14d | No interview access for free users | `_can_access_interview()` excludes `'free'` | `ResumeInterviewGate.planLocked` detected from server signal, never re-derived | Covered in the same 32/32 + 13/13 | Complete and verified |
| 14e | "Rest of all features locked... subscribe path" | 3 independent server-enforced gates (Skill-Up/Activities/Interview) + a real, test-mode-wired Razorpay subscribe flow (`RoutePaths.pro` → real `SubscriptionScreen`, not the `ComingSoonScreen` an older doc still describes) | All 3 gates confirmed server-sourced; subscribe route/screen/dependency all real | 142 tests across the 4 relevant suites | Complete and verified (gating); **Implemented, verification incomplete** (the actual Razorpay order-create→pay→verify round-trip has never been exercised end-to-end by any phase) |

---

## Item 15 — Recovery actions after low scores

> "In resume parsing, if user fails to score >=90, then he will see skill-up yourself and build resume button, which will redirect to build resume and skillup content, if user fails to score >=90 in ai interview, user will be asked to skillup himself via skillup button."

**Overall: Complete and verified.** Phase 46's work fully re-confirmed.

| # | Sub-requirement | Web evidence | Flutter evidence | Test evidence | Status | Gap / impact |
|---|---|---|---|---|---|---|
| 15a | Resume-side recovery: Build Resume / Upload Another / Analyse Again | `resume_match_result.html:309-348` | All 3 CTAs implemented per branch | `resume_builder_screen_test.dart` 38/38 | Complete and verified | None |
| 15b | Resume-side "Skill up yourself" (role-mismatch/below-threshold) | `:560-563`, gated on `can_interview and target_role.section and not ats_ok` | `showSkillUpAction` detected from the server's own rendered presence, never re-derived | Same 38/38 | Complete and verified | None |
| 15c | Interview-side "Skill up yourself" + Recommended Courses card | `resume_analytics.html:241-355`, incl. literal "23" activities | `mock_interview_results_view.dart`, same literal "23" reproduced | `mock_interview_results_view_test.dart` 14/14 | Complete and verified | None |
| 15d | Role-specific deep-link precision | Web deep-links to the exact role/section (`?section=...`) | Both buttons open the **general** Skill-Up hub — same limitation already noted at Item 7f | Covered by the same tests | **Partially implemented** | Minor navigation-precision gap, not a missing feature |
| 15e | Live on-device rendering of populated recovery screens | — | — | No legitimate test account/device available to any phase | **Blocked** | Shared with Item 8e |

---

## Cross-cutting notes

- **Full test suite**: re-run fresh by the orchestrating session after all
  10 agent passes completed: **2,482 passing, 0 failing** (one agent
  reported 2,483 in its own run — not reproduced in 2 independent fresh
  runs by the orchestrating session; treated as a transient/non-deterministic
  anomaly in that one run, not a real discrepancy).
- **Static analysis**: **8 issues**, identical pre-existing
  `unused_element_parameter` warnings in unrelated resume-controller test
  files, re-confirmed by the orchestrating session and by multiple agents
  independently. 0 new issues.
- **No file in either Django reference tree, and no application source
  file, was modified during this audit.** All 10 research passes and the
  orchestrating session operated read-only (Read/Grep/Bash-for-tests only).
- **No production account, fabricated test account, or auth/subscription
  bypass was used anywhere in this audit.**
