# Phase 40 — CB_changes.docx Complete Parity Matrix

Source checklist: `CB_changes.docx` (15 numbered items, user-supplied). Web reference: `royalStaffing_CB01` (current/updated, read-only). Flutter reference: `Mobile_app/` (current code, as of this phase's commit `d4e8981`). All findings below are source-inspected or automated-test-inspected only — **no device verification was performed in Phase 40** per its audit-only scope; any claim beyond source/test inspection is explicitly marked.

Verbatim checklist text is quoted once per item, then broken into sub-requirements.

## Summary counts

### Top-level items (15 total)

| Status | Count | Items |
|---|---|---|
| Fully implemented and verified | 6 | 5, 8, 9, 10, 11, 14 |
| Partially implemented | 5 | 2, 3, 4, 7, 13 |
| Missing | 4 | 1, 6, 12, 15 |
| Implemented but not fully verified | 0 | — |
| Blocked or unclear | 0 | — |

### Individual sub-requirements (107 total, counted separately per the task's instruction — one checklist item may bundle several distinct features; Item 5's per-field breakdown alone accounts for 38 of the 107)

| Status | Count |
|---|---|
| Fully implemented and verified | 63 |
| Implemented but not fully verified | 13 |
| Partially implemented | 9 |
| Missing | 19 |
| Blocked or unclear | 3 |

A top-level item's status is the worst-case roll-up of its sub-requirements weighted by user visibility, not a simple majority — e.g. Item 5 is "Fully implemented and verified" overall despite 8 of 38 sub-rows being "not fully verified," because those 8 are narrow server-side business-validation rules (regex/range checks) that Flutter correctly defers to the server rather than reimplementing; no user-facing field or flow is missing. Item 15 is "Missing" overall despite having a "fully implemented" safety sub-requirement (no interview/job leak below threshold), because the item's actual subject — the two recovery buttons — doesn't exist.

---

## Item 1 — Landing page popup

> "Landing Page UI changed. Pop-up displayed within 5 seconds of opening application saying IT/Non-IT."

**Verified web behavior**: The "5 seconds" claim is accurate — `templates/landing.html:7584`: `setTimeout(() => { ...; m.showModal() }, 5000)`. The popup (`<dialog id="cpModal">`, lines 6781-6835) is a 2-step picker: Step 1 "Which path suits you?" (IT vs Non-IT), Step 2 only if Non-IT chosen ("Technical or Non-Technical?"). It shows on **every** load of `/` (no cookie/localStorage/first-visit gating found), for every visitor regardless of auth state, suppressed only if another `<dialog>` is already open. Dismissing it (native `<dialog>` close/ESC) does not prevent it reappearing next load. The choice itself is **not persisted anywhere** — `career_path()` (`activities/views.py:120-125`) only re-renders the same landing page filtered to that track; no session key, cookie, or DB field records it (confirmed: no relevant `UserProfile` field, no `request.session[...]` write).

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Trigger timing (5s) | `landing.html:7584` | Not found anywhere in `lib/features/home/` or `lib/features/splash/` | Missing | P1 | Medium |
| Display conditions (every load, no gating) | `landing.html:7575-7586`, confirmed no cookie/localStorage gate | Not found | Missing | P1 | (included above) |
| Visual/content (2-step dialog) | `landing.html:6781-6835` | Not found | Missing | P1 | (included above) |
| Dismissal behavior | Native `<dialog>` + `×` button, reappears next load | Not found | Missing | P3 | — |
| Choice persistence | None — confirmed no session/cookie/DB write | N/A (nothing to persist) | Missing | P2 | — |
| Downstream effect | Filters role panels on the same landing page render only | Not found | Missing | P1 | (included above) |

**Conflict with checklist wording**: the checklist's framing ("gave users convenient choice") implies a saved preference; the actual source is deliberately stateless, re-asking on every visit. Recommend Flutter's mobile-equivalent interaction preserve this statelessness (a non-blocking interstitial or inline picker shown once per app-open, not a persisted profile setting) rather than "improving" on the web unasked.

---

## Item 2 — Top navigation and landing-page sections

> "Modified Top nav-bar and added more features inside the top-nav bar sections in landing page/home page."

**Verified web behavior**: nav markup now lives entirely in `templates/includes/site_nav.html` (moved out of inline `base.html`). It has 2 mega-menus — "Skill Up" (11 links: English Learning, Grammar, Vocabulary & Idioms, Speaking & Presentation, Writing & Correspondence, Negotiation & Meetings, Interactive Roleplay, Aptitude, Tech, Certifications, "Browse all Skill Up") and "Resources" (Skill Up Hub, Activities, Certifications, Tutorials, Sitemap, Buddy Assistant, CareerBuddy Pro) — plus 4 flat top-level items (About Us, Industries, Create Resume, Contact Us, all in-page anchors on the landing page). The landing page itself has 10+ sections beyond what Phase 37 covered (hero/trust-strip/cards/footer): `#features` (6-tile grid), journey timeline (6-step), `#choose-path` (Item 1/3), `#skillup` (8-tile grid), `#resume` story block, `#buddy` feature grid, `#why` (8-card grid), `#create-resume` teaser, `#videos` (Item 6), testimonials, and a final CTA section. Phase 37's own report already self-acknowledged these as out of scope.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Nav markup relocated (stale Flutter source citations) | `templates/includes/site_nav.html` (new home) | `app_top_bar.dart:7-9`, `app_nav_drawer.dart:11,18` still cite old `base.html` line ranges | Blocked or unclear | P3 (doc hygiene) | Small |
| "Skill Up" mega-menu (11 entries) | `site_nav.html:67-93` | `app_nav_drawer.dart:92-101` has only 4 of 11 (English & Vocabulary, Aptitude, Tech, Browse All); Grammar exists as a separate flat tile | Partially implemented | P1 | Small–Medium |
| "Resources" mega-menu | `site_nav.html:95-114` | No "Resources" grouping; Sitemap/Resume Parsing/Activities/Pro exist as flat items; no Tutorials or Buddy Assistant nav link (Buddy is reachable via the persistent chatbot overlay, not a nav entry) | Partially implemented | P2 | Small |
| Top-level items: About Us, Industries, Create Resume, Contact Us | `site_nav.html:65,124-126` | None of the 4 exist in the nav drawer (Create Resume is reachable only via the home hero button, per Phase 39) | Missing | P1 | Small |
| Landing sections beyond Phase 37 scope (feature grid, journey, skill-up grid, testimonials, final CTA, etc.) | `landing.html` (10+ sections, line references above) | None exist as Flutter widgets (self-acknowledged gap in Phase 37's own report) | Missing | P1/P2 (split per section) | Large (as one basket; Small–Medium per individual section) |

No evidence of a language switcher on the real site — do not build one for parity.

---

## Item 3 — IT/Non-IT selection

> "Gave Users the option to choose either IT or Non-IT conveniently."

**Verified web behavior**: three surfaces offer the choice (the popup from Item 1; an inline "Choose Your Path" section on the landing page; and the IT/Non-IT split baked into every department/role card in the Item 7 flow) — all unpersisted, matching Item 1's finding. Flutter has a real, source-accurate equivalent of the underlying data model (`ResumeRole.category`/`.track` mirror the web's `it`/`tech`/`nt` semantics exactly, citing the same source lines) exposed as filter chips inside the Role Picker screen — but that screen is reached only from inside the Resume Builder tool, not from Home.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Where the choice is offered | 3 surfaces, all on/from the landing page | `role_picker_screen.dart:119-141` filter chips, reachable only from inside Resume Builder (a deliberate Phase 22 decision, documented in-code) | Implemented but not fully verified (data model accurate; entry point doesn't match "home page" framing) | P1 | Medium |
| Persistence of the choice | None (confirmed) | None (in-memory only, `role_picker_controller.dart`) | Fully implemented and verified (genuine parity — both deliberately ephemeral) | — | — |
| Downstream effect on content | Page/tool-local filter only, not a platform-wide gate | Same scope (filters the role list only) | Fully implemented and verified | — | — |

Flagged false lead: `EmployerRegisterForm.industry` (`accounts_app/forms.py:58-71`) is the **employer's company industry** at signup — unrelated to this candidate-facing feature.

---

## Item 4 — Manual resume creation from the landing page

> "Gave users to create resumes manually in the landing page."

**Verified web behavior**: hero `<a href="#create-resume">Create Resume</a>` (`landing.html:6552-6554`) scrolls to the Create Resume builder section, reachable with no login (`career_app/create_resume_views.py`, no `@login_required` on `preview_api`/`pdf_download`/`pages_api`). A guest clicking "Save" is intercepted **client-side before any network call** (`static/js/create_resume.js:656-660`): the form is written to `localStorage` and an inline "Sign in" link is shown — no server round-trip, no error framing.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Landing-page entry element | `landing.html:6552-6554` | `home_screen.dart:79,98` → `RoutePaths.createResumeBuilder` | Fully implemented and verified | — | — |
| Reachable anonymously | No auth gate on builder/preview/PDF | `createResumeBuilder`/`createResumePreview` in `universalRoutes` | Fully implemented and verified | — | — |
| "My Resumes"/drafts require login | `_json_login_required` on all draft endpoints | `createResumeDrafts` correctly omitted from public/universal routes | Fully implemented and verified | — | — |
| Entered data preserved when login is required mid-save | Pre-flight client-side auth check → local save + inline "Sign in" link, no server call | `create_resume_builder_controller.dart:236-259` has no auth-state check; always calls the server, which 401s → generic "session expired" message with no sign-in affordance | Partially implemented | **P1** | Small |
| Data durability once login is prompted | `localStorage` survives full navigation and app/browser restart | In-memory only (`NotifierProvider`, not persisted) — survives in-process nav-away, wiped on app restart | Partially implemented | P2 | Medium |
| Guest→account draft migration after login | Not implemented on web either (orphaned `localStorage` key) | N/A — no equivalent needed since web doesn't do this | Blocked or unclear (pre-existing web limitation, not a parity gap) | P3 | — |

---

## Item 5 — Employer portal job fields

> "Changed Job Fields inside Employer portal."

**Verified web behavior**: `JobPostingForm` grew from a 17-field, IT-only form (`Career_Buddy_LMS/jobs_app/forms.py`) to a ~45-field, 3-branch form (IT / Non-IT·Technical / Non-IT·Non-Technical) gated by `job_category`/`job_classification` (`royalStaffing_CB01/jobs_app/forms.py:184-960`). **Correction to an existing Flutter code comment**: `job_posting_catalog.dart`'s doc comment claims the committed Django form is "a much smaller, 17-field form" not reflecting production — this is **no longer accurate**; the current `royalStaffing_CB01` tree already has the full form, matching what Flutter built against production. Stale comment, not a functional gap.

**Verified Flutter behavior**: `Mobile_app/lib/features/employer/` is fully built (not a placeholder — see correction below) and has a named, wired field for every new/changed field, with static option lists matching the Django `*_CHOICES` constants value-for-value.

### New fields (29 checked; 25 fully verified, 4 implemented-but-not-fully-verified)

| Field | Status | Note |
|---|---|---|
| job_category, job_classification, department, designation, perks, skills, mandatory_skills, work_mode, employment_type, joining_requirement, industry_sector, industry_experience, responsibilities, certifications, working_hours, keywords, department_function, functional_skills, software_skills, language_requirements, experience_years, experience_plus, experience_years_max, salary_format, education (25 fields) | Fully implemented and verified | Named Flutter field + matching choice list confirmed for each |
| age_limit | Implemented but not fully verified | Server regex (`AGE_LIMIT_RE`) not mirrored client-side; relies on server error text |
| application_contact | Implemented but not fully verified | Same reason (`CONTACT_MESSAGE` validation) |
| contract_duration_months | Implemented but not fully verified | 12-month ceiling not mirrored client-side |
| education_other | Implemented but not fully verified | `EDUCATION_ALLOWED_RE` char rules not mirrored client-side |

### Changed fields (9 checked; 5 fully verified, 4 implemented-but-not-fully-verified)

| Field | Status | Note |
|---|---|---|
| requirements, skills_required, job_type, work_environment, notice_period | Fully implemented and verified | IT/Non-IT branch split correctly mirrored |
| title | Implemented but not fully verified | New `clean_title`/`TEXT_FIELD_RULES` server validation not mirrored client-side |
| gender_preference, interview_mode | Implemented but not fully verified | Conditional (branch-dependent) requiredness deferred to server |
| salary_min/salary_max | Implemented but not fully verified | Dual monthly/LPA range+integer rules deferred to server; widget/contract already updated to match (text input, numeric) |

`is_remote` is a pre-existing field not rendered in the real `job_form.html` at all (web silently submits it unchecked on every save) — a web-side quirk, not a Flutter gap; Flutter correctly omits it too.

### Entry-point / wiring correction

`employer_dashboard_screen.dart` → `PostNewJobScreen` is **fully built, wired, and covered by 9 widget tests + 10 datasource tests** (branch-switching, validation, per-field server-error display, edit-mode load). **4 existing docs are stale and should be corrected**: `docs/WEB_SCREEN_INVENTORY.md:162`, `docs/WEB_FLOW_MAP.md:92`, `docs/WEB_TO_MOBILE_SCREEN_MATRIX.md:350`, `docs/PRODUCTION_E2E_VERIFICATION_REPORT.md:128` all still describe this screen as a `ComingSoonScreen`/`NOT_STARTED`/"MISSING placeholder" — it is not. No device verification exists for this screen in any doc, and none is claimed here either.

**Item 5 overall: Fully implemented and verified.** The residual "not fully verified" rows are narrow server-side business-validation rules Flutter defers to the server by design (a defensible architecture, not a gap), and the HTML-error-scraping approach is flagged as a technical brittleness risk (P3) rather than a defect.

---

## Item 6 — Demo tutorial videos

> "Integrated Demo tutorial videos, so that users can learn more about the Application."

**Verified web behavior**: one tutorial hub on the public landing page (`landing.html:7183-7204,7457-7562`) — a JS array of 37 potential tutorial entries, of which only 9 reference a video id, and of those only **5 video files actually exist on disk** (`welcome.mp4`, `skillup.mp4`, `resume.mp4`, `match.mp4`, `chatbot.mp4`); the other 4 referenced ids 404 and silently fall back to a "coming soon" placeholder. Native HTML5 `<video controls playsInline>`, plain Django static files — not an iframe/YouTube embed. No login required.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Tutorial video hub exists & is reachable | `landing.html:7183-7204,7457-7562`, 5 real videos | Not found anywhere in `lib/` (confirmed `video_player` usage exists only, unrelated, in the Grammar module) | Missing | P2 | Medium |

Do not fabricate video URLs for the 4 missing/broken web-side entries if this is implemented later — reproduce only the 5 that genuinely exist.

---

## Item 7 — Industry → department → role → action popup

> "when user selects IT/Non-IT from industries section in home page, he sees departments. Inside Departments, he sees roles. If a role is selected, 'skills','build resume','resume parsing' are displayed in a pop-up. Clicking on skills redirects user to skill-up content section, clicking on build resume enables user to build resume in the popup itself, clicking on resume parsing redirects user to parse resumes."

**Verified web behavior, traced end to end**: industries live in the `#choose-path` section (home page, no login); Non-IT departments render inline, IT departments load from a static JSON; clicking a role opens `<dialog id="roleAct">` with exactly 3 options whose real labels are **"Skills" / "Build Resume" / "Resume Parsing & Interview"** (the checklist undersells the third — it bundles ATS + mock interview). "Skills" is a 2-click path (popup → in-page skills-chip view → "Start Learning" → Skill-Up Hub filtered by role), not a direct redirect. "Build Resume" genuinely renders inline in a different same-page modal, running the **older Manual Resume Builder** (`manual_resume_views.py`), confirmed distinct from Phase 39's Create Resume. "Resume Parsing" is a real navigation to `resume_builder_home?role=&dept=&track=`, login-required.

**Verified Flutter behavior**: no industries/department browsing exists on the home screen at all — the equivalent (`RolePickerScreen`) is reachable only from inside the Resume Builder flow, per an explicit, documented Phase 22 decision. Departments are shown only as list-item subtitle text, not a browsable level. The 3-action bottom sheet has the correct 3 labels; "Build Resume" correctly targets the Manual Resume Builder (resolving a long-standing "which builder" ambiguity in Flutter's favor) but as a separate pushed screen rather than inline, and is gated to authenticated users even though the real endpoint isn't. "Resume Parsing & Interview" correctly round-trips role selection to the server. "Skills" is honestly disabled ("Coming soon") rather than faked.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Industries entry point on home page | `landing.html` `#choose-path`, public | No industries/department UI in `lib/features/home/`; role picker only reachable from inside Resume Builder | Missing | P1 | Large |
| Department listing inside an industry | Inline (Non-IT) / JSON-fetched (IT) department cards | Department shown only as subtitle text in a flat role list, no browsable level | Partially implemented | P2 | Medium |
| Role → 3-action popup with correct labels | `<dialog id="roleAct">`, exact 3 labels | `_RoleActionSheet`, same 3 labels | Fully implemented and verified | — | — |
| "Skills" → Skill-Up, filtered by role | 2-click path to a role-filtered Skill-Up Hub deep link | Disabled, "Coming soon" (honest, not faked) | Missing | P1 | Medium |
| "Build Resume" rendered inline | Same-page modal, inline 5-step wizard, no login required | Separate pushed screen, login-gated (deliberate override) | Implemented but not fully verified | P3 | Small |
| "Resume Parsing" destination | Real navigation, login-required, session-threaded role | Round-trips role selection to the same server flow | Fully implemented and verified | — | — |

---

## Item 8 — Resume Parsing, ATS score, interview eligibility, and matching

> "In resume parsing, ATS score is evaluated, if score is >=90 then AI interview is accessed. if <90 then AI interview is not accessed. If resume uploaded, it's skills,experience,department must be similar to the department the user has selected, then ATS score will be 0 and tells that resume is not matched."

**Verified web behavior**: `ATS_INTERVIEW_THRESHOLD = 90` literal, `>=` comparison (`career_app/views.py:185,188-192`), enforced server-side at multiple view entry points (not merely hidden in UI), covered by automated tests asserting the exact 89/90 boundary. Department-mismatch rule (`_check_role_fit`, `role_fit.py:176-211`) force-sets `match_percentage = 0` regardless of the general ATS score, with a specific mismatch message — also covered by an automated test (`test_unmatched_resume_scores_zero`).

**Verified Flutter behavior**: Flutter duplicates none of this logic — it scrapes the server's already-decided score/summary/CTA state from the rendered HTML (`resume_html_parser.dart`) and cannot bypass the gate since the server decides.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| ATS score calculation | `resume_utils.py:391` `compute_ats_score()`, deterministic rule-based | Pure pass-through parse of server HTML | Fully implemented and verified | — | — |
| Threshold gate (literal >=90) | `views.py:185,188-192`; automated test confirms 89/90 boundary | No duplicated threshold anywhere in Flutter; defers to server | Fully implemented and verified | — | — |
| Server-side enforcement of the gate | Re-checked at render time, not just on entry (BUG-05 fix) | Inspects actual HTML/redirect outcome; cannot bypass | Fully implemented and verified | — | — |
| Department-mismatch → ATS=0 | `views.py:217-240`, automated test confirms | Score/message flow through the same already-covered fields; no special-casing needed | Fully implemented and verified | — | — |
| Mismatch message / distinct lock-reason copy | Web shows 2 distinct disabled-CTA strings (role-mismatch vs. ATS-too-low) | Flutter only models one boolean `canInterview`; no separate `lockReason` field | Partially implemented | P2 | Small |
| Role/department persistence (session-based, can go stale) | Session-only, survives across requests but never cleared without new query params | Flutter reproduces the same (possibly-stale) session-based mechanism faithfully | Fully implemented and verified | P2 (web-side design risk) | Medium (if fixed) |

---

## Item 9 — AI interview personalization

> "In AI interview, Questions asked will be asked related to fresher/experienced and related to skills user mentioned in the resume and role selected."

**Verified web behavior**: `generate_interview_questions()` (`resume_utils.py:1830+`) samples from a DB question bank calibrated by `classify_experience_level()` (years extracted from resume text), `matching_skills` (extracted at upload time), and the selected role's own topic/skill set via `_domain_inputs()`. No LLM generates the questions themselves (only `evaluate_answer()` uses an LLM, for scoring).

**Verified Flutter behavior**: Flutter never recomputes any of this — it triggers the same server-side session flow, which reads the resume/role state already established by earlier steps.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Fresher/experienced input | `resume_utils.py:663-752,1876` | No client-side years/level logic; server session is sole source | Fully implemented and verified | — | — |
| Skills input | `views.py:1044-1063`, `resume_utils.py:544-548` | Same upload flow produces this server-side | Fully implemented and verified | — | — |
| Role input | `views.py:1092-1110`, `_domain_inputs`; automated test confirms role-focused questions | `selectTargetRole()` sets the same session key before interview start | Fully implemented and verified | — | — |
| Flutter request parity (defers, doesn't duplicate) | No JSON API exists for this flow (session-stateful server-rendered pages only) | Reuses the exact same endpoints/session flow; zero duplicated business logic | Fully implemented and verified | — | — |

---

## Item 10 — Job recommendations and subscription limits

> "If user scores >=90 in AI interview, 5 job recommendations displayed for normal and unlimited job recommendations for pro users."

**Verified web behavior**: `JOB_RECOMMENDATION_LIMITS = {'normal': 5, 'pro': None}` (`views.py:151`); `pro`'s "unlimited" is a genuine `max_results=None` → no slicing at all (not a large sentinel number), confirmed by an automated test. The cap is baked into the DB query itself server-side — the HTML response never contains more than the entitled count.

**Verified Flutter behavior**: Flutter renders exactly whatever job cards the server's HTML contains; no client-side count/pagination/slicing logic exists to get out of sync.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Count for Normal plan (5) | `views.py:151,154-155` | Renders exactly the server-sent cards | Fully implemented and verified | — | — |
| Count for Pro plan (genuinely unlimited) | `_cap()`, `max_results=None` → no slicing; automated test confirms | Same | Fully implemented and verified | — | — |
| Server-side enforcement (not a UI slice) | Capped in the DB query itself | Nothing larger is ever fetched and trimmed client-side | Fully implemented and verified | — | — |
| Flutter pagination/limit handling | No pagination API for this feature | No client pagination/infinite-scroll/re-fetch-and-trim logic (nothing to paginate) | Fully implemented and verified | — | — |

---

## Item 11 — AI chatbot contextual follow-ups and language

> "AI chatbot will give follow-up questions, for the each section the user navigates to and responses will be given with respect to the language the user had selected."

**Verified web behavior**: the frontend sends `page`/`path`/`hash` on every chat request (`BOTscript.js:4263-4295`); the server merges them to identify context. **Checklist-wording caveat**: "follow-up questions" are not LLM-generated — they are a static, pre-written chip set keyed by section (`SECTION_CONTEXT`, `BOTscript.js:653-742+`) that does change per section, matching the checklist's observable behavior even though the generation mechanism is simpler than implied. 5 languages are user-selectable (english/vietnamese/hindi/arabic/russian via a `<select>`); selection is stored in `sessionStorage`. Both fixed UI strings (genuinely pre-translated) and free-form LLM replies (via an explicit system-prompt instruction to reply in the user's language) adapt to the selection — though actual LLM output quality is unverifiable from source on either platform.

**Verified Flutter behavior**: `AriaRemoteDataSource.sendMessageStream` sends the same `page`/`path`/`language` context, resolved per-screen from the router; `kAriaLanguages` is an exact 5-entry match of the web's list (confirmed automated test: "lists exactly the 5 real web languages, in order, by full name").

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Section-context sending | `BOTscript.js:4263-4295`, `riya_bot/views.py:64-78,128-146` | `aria_remote_datasource.dart:98-129`, resolved via `GoRouterState` | Fully implemented and verified | — | — |
| Follow-up "question" mechanism (static, not generated) | `SECTION_CONTEXT` dict, static chips, changes per section | Mirrors the same (actually static) web behavior exactly | Fully implemented and verified (matches what web actually does, not the checklist's idealized wording) | — | — |
| Language list / selection / storage | 5 selectable languages, `sessionStorage` | `kAriaLanguages`, exact 5-entry match; in-memory (process-scoped) storage | Fully implemented and verified | — | — |
| Response language-adaptation | Pre-translated fixed strings + LLM system-prompt instruction | Same backend, same translated-strings file ported; LLM output quality unverifiable either side | Implemented but not fully verified (not mobile-specific) | — | — |
| Flutter context-sending | — | Confirmed per-screen context resolution, no hardcoded fallback in the live code path | Fully implemented and verified | — | — |
| Flutter language support | — | Exact match + automated test coverage | Fully implemented and verified | — | — |

**Item 11 overall**: no mobile-specific gap found. The checklist's framing modestly overstates both platforms' actual sophistication (no AI-generated follow-ups exist anywhere), but Flutter faithfully matches what the web genuinely does.

---

## Item 12 — Non-IT Skill-Up content

> "Added more non-It content inside skill-up section, before only IT content is present."

**Verified web behavior**: a real, substantial "Non-IT Center" exists — 21 departments across 2 tracks (Technical: 11 departments; Non-Technical: 6 departments, with ~10 more referenced), roughly 202 role lessons total, explicitly stated on the hub page ("21 departments, 202 roles"). Gated behind paid plans via the same `SkillUpAccessMiddleware` Phase 38 already fixed cookie-delivery for — confirmed by an existing automated web-side test asserting a Non-IT lesson is locked for Free users.

**Verified Flutter behavior**: `lib/features/skill_up/data/skill_up_data.dart` is **hand-transcribed static Dart data**, not a dynamic fetch from any backend — its own doc comment states it covers only 3 sections (English & Vocabulary, Aptitude & Reasoning, Tech Center) and its own `platformStats` literally says "3 Main sections." This means Item 12 will **not** resolve itself from a backend content change alone — closing it requires new Flutter data authoring and likely new UI (the existing 2-level section/subsection model doesn't match Non-IT's 3-level track/department/role structure).

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Non-IT category existence (21 departments, ~202 roles) | `static/001 Career Buddy/NonITCenter/`, `index.html:3890-3891,4340` | `skill_up_data.dart` has 3 sections only, no Non-IT reference anywhere | Missing | P1 | Large |
| Navigation structure (track → department → role) | `initNonIt()`, `nonit_departments.json` | No equivalent screen/route/data source exists | Missing | P1 | Large |
| Free/paid gating | Same `SkillUpAccessMiddleware`/`LOCKED_PAGE`, automated test confirms | Gating logic (`skill_up_locked_view.dart`) exists for current sections but was never applied to Non-IT (nothing to gate yet) | Missing (nothing to gate) | P1 (tracks with content work) | Medium (once content/screens exist) |
| Flutter generic-rendering vs. hardcoded filtering | — | Confirmed: gap is "never transcribed," not "actively filtered out" — the architecture itself (static data, no API) is the root cause | Missing | P1 | Large |

---

## Item 13 — Assessment malpractice controls

> "added malpractise rules like (Screenshots,tab switching,exiting the fullscreen) to assessments in skillup and AI interview after resume parsing."

**Verified web behavior**: proctoring is **not centralized** — a complete engine (`static/001 Career Buddy/TechCenter/mock_test.js`) exists but is dead code, referenced by zero HTML files. Each mock-test page has its own copy-pasted engine: `english_vocab_mock_test.html`/`aptitude_mock_test.html` have full tab-switch + blur + fullscreen + PrintScreen detection; `amcat_mock_test.html`/`cocubes_mock_test.html` have **only** fullscreen-exit + PrintScreen detection (no tab-switch/blur listener at all) — a real, pre-existing inconsistency on the web side itself. The AI interview (`resume_interview.html`) has the most complete engine: tab-switch, window-blur, copy/paste, and screenshot-keyboard-shortcut detection, all server-tracked with a 2-warning/3-strike escalation. Screenshot "prevention" is honestly framed in the web's own comments as detection-only (keyboard-shortcut attempts), never true OS-level blocking — a correct, acknowledged limitation, not a bug. `FULLSCREEN_EXIT` is a dead violation type even in the AI interview (modeled, never fired).

**Verified Flutter behavior**: the AI interview screen has a genuine, OS-level equivalent — `WidgetsBindingObserver`/`didChangeAppLifecycleState` maps real app backgrounding to `tabSwitch`/`windowBlur`, posted to the **same real server endpoint** with identical warn/flag/terminate handling — arguably **more reliable** than the web's JS-only detection, since true OS backgrounding can't be spoofed the way a web tab's `document.hidden` theoretically could be. However: no `FLAG_SECURE` (Android's real, OS-enforced screenshot-blocking API) exists anywhere in the app, despite Android genuinely supporting what the web structurally cannot. Skill-Up assessments run inside a plain `WebViewController` inheriting whichever JS engine each lesson HTML embeds — same per-file inconsistency as web, plus an unverified risk that `requestFullscreen()` may not engage reliably inside `webview_flutter`'s default controller (no fullscreen delegate configured) — flagged as needing on-device verification, not assumed broken.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Screenshot detection — Skill-Up | Keyboard-shortcut detection only, inconsistent across the 4 mock-test files | Inherited via WebView JS; no native screenshot blocking | Implemented but not fully verified | P2 | Medium |
| Screenshot detection — AI interview | Keyboard-shortcut detection, server-tracked | Explicitly never reported (no keyboard shortcuts on mobile); no `FLAG_SECURE` | Partially implemented | P2 | Medium |
| Tab-switch detection — Skill-Up | Present on 2 of 4 mock-test files, absent on the other 2 (web-side inconsistency) | Inherits the same per-file inconsistency via WebView | Partially implemented | P3 (not Flutter's gap) | — |
| Tab-switch detection — AI interview | `visibilitychange`, server-tracked, 3-strike terminate | Real OS-level `AppLifecycleState` equivalent, same server endpoint/escalation | Fully implemented and verified | — | — |
| Fullscreen-exit detection — Skill-Up | Present on all 4 mock-test files | WebView fullscreen delegate not configured; reliability unverified | Blocked or unclear | P1 (verify), fix only if confirmed broken | Small (to verify) |
| Fullscreen-exit detection — AI interview | Modeled but dead code even on web (never fires) | Explicitly documented as never reported (reasonable — no Fullscreen API on mobile) | Missing (pre-existing web gap, not a parity gap) | P3 | — |
| Native `FLAG_SECURE` capability (new, mobile-only opportunity) | N/A — architecturally impossible for a website | Not implemented anywhere (confirmed via repo-wide grep) | Missing | P2 | Medium |

---

## Item 14 — Free-plan restrictions and quotas

> "for free Users, users can only access English and Vocab, grammar, 1 activity and 4 resume parses with no interview, rest of all the features will be locked out and can only be accessible if user subscribes to it."

**Verified web behavior**: all six restrictions are literal, server-enforced constants, not UI decoration — `FREE_PREFIXES`/`FREE_FILES`/`FREE_QUIZ_SUBJECTS` (`core/skillup_access.py`) for English/Vocab/Grammar; `FREE_ACTIVITY_LIMIT = 1` (`activities/views.py:387`); `FREE_RESUME_PARSE_LIMIT = 4` (`career_app/views.py:173`, a lifetime count, never reset); `_can_access_interview()` restricting AI interview to `normal`/`pro` plans only. No quota ever resets (confirmed: no cron/reset logic found for either counter).

**Verified Flutter behavior**: every one of the six is independently confirmed as a live, server-sourced check — the resume-parse quota badge is fetched live (`'${quota.left} of ${quota.limit}'`, no hardcoded "4"), the interview gate relies on detecting the server's own blocked-redirect message rather than re-implementing the rule, and Grammar correctly has zero plan-gating code (free for everyone).

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| English/Vocab + Grammar free | `core/skillup_access.py:18-21`, 403 via middleware | Same session cookie now correctly forwarded (Phase 38 fix) | Fully implemented and verified | — | — |
| 1 activity | `activities/views.py:387-447`, server 403/redirect | Mirrors server's `is_locked` field exactly | Fully implemented and verified | — | — |
| 4 resume parses | `career_app/views.py:173`, lifetime count | Live-fetched quota badge, never hardcoded | Fully implemented and verified | — | — |
| No AI interview for free | `career_app/views.py:143-146`, server redirect+flash | Detects the real server block, can't be bypassed | Fully implemented and verified | — | — |
| Rest of features locked | Composite of the above 3 mechanisms | Composite, each independently confirmed | Fully implemented and verified | — | — |
| Quota reset behavior (never) | Lifetime counts, confirmed no reset logic | No local caching that could drift (always fetches fresh) | Fully implemented and verified | — | — |

---

## Item 15 — Recovery actions after low scores

> "In resume parsing, if user fails to score >=90, then he will see skill-up yourself and build resume button, which will redirect to build resume and skillup content, if user fails to score >=90 in ai interview, user will be asked to skillup himself via skillup button."

**Verified web behavior**: `PASSING_SCORE = 90` and `ATS_INTERVIEW_THRESHOLD = 90` are consistent with each other (no drift). The resume-parsing result page has a real 4-way branch, not a simple 2-button state: role-mismatch shows "Build Resume" + "Upload Another"; below-ATS-threshold (paid plan) shows "Build Resume" + "Analyse Again"; a separate "Skill up yourself" button appears only inside the AI-suggestions card, and only when a specific target role was picked. The AI-interview result page has a single "Skill up yourself" button when `not is_passed`, and `suitable_jobs` is confirmed gated to `is_passed` only — no leak on web.

**Verified Flutter behavior — this is a genuine, user-visible gap**: `ResumeAnalysisResult` has **no `atsOk`/`roleFit` field at all** — the result screen only branches on plan-level `canInterview`, so neither "Build Resume" nor "Skill up yourself" appears anywhere on the resume-result screen. A **stale threshold is displayed**: `resume_builder_screen.dart:731,748` hardcode "Score 70 or above out of 100" against the real server threshold of 90. The AI-interview result screen has no "Skill up yourself" button at all for failed candidates. On the safety side, no actual leak exists: because the server still enforces `_ats_unlocks_interview()` and the interview-result parser only ever reflects jobs the server itself gated by `is_passed`, a below-threshold user cannot actually reach the interview or see jobs even though the resume-screen's CTA is misleadingly always-enabled.

| Sub-requirement | Web evidence | Flutter evidence | Status | Priority | Effort |
|---|---|---|---|---|---|
| Resume-parsing low-score buttons (Build Resume / Skill up yourself) | `resume_match_result.html:308-379,561-563` | No `atsOk`/`roleFit` field; neither CTA exists anywhere on the screen | Missing | P1 | Medium |
| AI-interview low-score button (Skill up yourself) | `resume_analytics.html:224-245` | No such button anywhere | Missing | P1 | Small–Medium |
| Threshold consistency (reused from Item 8) | 90/90, no drift | Flutter displays "70" in result-screen copy; `canInterview` doesn't encode the 90 threshold client-side at all | Partially implemented | P1 | Small (copy) + Medium (real field) |
| No leak of interview access/jobs below threshold | Server-gated at both points, confirmed | Functionally safe (server-blocked, correctly surfaced); CTA is misleadingly enabled below threshold | Implemented but not fully verified | P2 | Small (disable button once `atsOk` field exists) |

---

## Prior-phase reconciliation (see also the Audit Report's §Prior-phase section)

Phase 35, 37, 38, and 39's reports were re-checked against current code during this audit (not merely re-cited):
- Phase 35 (login/env fix): unaffected by this audit's findings, not re-verified live this phase (no device available — see roadmap doc).
- Phase 37 (landing rebuild): accurate — its own report already explicitly listed the Journey/Feature-grid/testimonials/Final-CTA sections as out of scope, which this audit independently confirmed are still absent.
- Phase 38 (Skill-Up cookie fix): still correct and still in effect; Item 12 found it does not extend to content that was never transcribed into Flutter at all (a different, larger gap).
- Phase 39 (Create Resume): accurate for everything it claimed; this audit found one new gap Phase 39 did not flag — the guest-save UX (Item 4) — which is in scope, not a Phase 39 regression (Phase 39 never tested the guest-save path against the web's actual client-side pre-flight behavior).

Two categories of stale documentation (not functional bugs) were found and should be corrected independently of any Phase 41 implementation work: (1) `job_posting_catalog.dart`'s doc comment describing an outdated 17-field web form; (2) four `docs/*.md` files still describing Post New Job as unbuilt.
