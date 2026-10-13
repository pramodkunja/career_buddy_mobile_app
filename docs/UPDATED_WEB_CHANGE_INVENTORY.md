# Updated Website Change Inventory (Phase 15)

Audit-only. Compares the ORIGINAL Django repo
(`Career_Buddy_LMS/`, git HEAD `3d4a1ba`) against the UPDATED Django
snapshot received as a ZIP extraction (`royalStaffing_CB01/`, no git
history). Flutter (`Mobile_app/`) is referenced only to note current usage,
not modified. See `PHASE_15_UPDATED_WEB_DISCOVERY_REPORT.md` for paths
inspected, methodology, and counts; see `UPDATED_WEB_MOBILE_GAP_ANALYSIS.md`
for the full Flutter-alignment verdict per item.

## Methodology note (read first)

A raw `diff -rq` between the two Django trees reports 447 files as
"differing," 144 as new, and 11 as removed. **This overstates real change
substantially**: a large fraction of the "differing" files (confirmed
directly in `GD_app/`, `jam_app/`, `ResumeBuilder_module/`, `users/`) are
byte-identical in content once CRLF line endings are stripped — the ZIP
tool re-encoded line endings on files the update never touched. Every
finding below was verified by reading actual diffed content, not by
trusting the raw file-level diff count. A separate, previously-unverified
third-party document bundled in the update
(`royalStaffing_CB01/CareerBuddy_FSD_Audit.html`) compares the code against
an external "functional specification" dated Aug 2025, **not** against our
ORIGINAL repo — several of its "new" claims were independently checked and
found **false** relative to our actual baseline (e.g. it called Riya bot's
Telugu/Tamil language support "new"; both are byte-identical in ORIGINAL).
That document was used only as a lead generator, never as evidence; every
claim below was re-verified directly against both real repos.

## A. Critical: scoring-contract changes (business-rule change)

### A1. MCQ exercise submissions are now server re-graded, and Flutter's payload shape no longer matches

- **Original behavior**: `submit_exercise` (`activities/views.py`) stored
  whatever `score`/`max_score` the client POSTed, for every exercise type.
  This was a known, shared, accepted web+mobile trust model (the client
  self-grades; the server never re-verifies) — not a parity gap, a
  documented architectural choice both platforms made identically.
- **Updated behavior**: new `activities/grading.py` (not in ORIGINAL at
  all). `submit_exercise` (`activities/views.py`, ~line 1003) now calls
  `grade_submission(exercise, score, max_score, answers)` for every
  exercise type except `writing`/`timer` (which get AI-scored), with an
  explicit comment: *"the browser's own number is never taken on trust."*
  For `mcq`, `grade_submission` requires `answers` keyed `"1"`, `"2"`, ...
  (1-based position in `exercise.questions.all()` order), each value a
  **dict** with a `chosen` key (`grading.py:41-61`, read directly). For
  `matching`, each entry must be a dict with a `paired` key equal to the
  matching number as a string (`grading.py:71-78`, read directly).
  `_answer()` (`grading.py:41-45`) returns `{}` for any non-dict value —
  silently, with no error.
- **Flutter's current payload**: `mcq_exercise_remote_datasource.dart:85`
  POSTs `answers: {questionId: letter}` — a flat string keyed by the
  database question id, not a dict keyed by 1-based position.
  `matching_exercise_repository_impl.dart:32-43` POSTs `{'result':
  'correct'}` on a correct pair — no `paired` key at all.
- **Consequence**: `_answer()` silently returns `{}` for every Flutter
  submission of either type; `.get('chosen')`/`.get('paired')` is always
  `None`; the comparison against the real correct answer always fails.
  **Every MCQ and Matching exercise submitted from the Flutter app would
  score 0, regardless of correctness**, the moment this backend ships to
  production.
- Fill-blank (`given`/`correct` keys), bingo, timer, and writing payload
  shapes were checked and already match the new server contract — **not**
  affected.
- **Classification**: Validation/business-rule change. **Confidence:
  Confirmed** — read `activities/grading.py` directly myself (not only via
  research-agent report), confirmed the docstring, the `_answer()`
  fallback-to-`{}` behavior, and the `submit_exercise` call site's own
  "never taken on trust" comment.

### A2. Mock Interview pass threshold: 70 → 90

- `career_app/views.py:974` `PASSING_SCORE = 70` (ORIGINAL) →
  `career_app/views.py:1134` `PASSING_SCORE = 90` (UPDATED). **Confirmed**
  by direct diff.
- The pass/fail UI text itself (`"Qualified Candidate (Score ≥ X/100)"`)
  changes with it server-side; Flutter never hardcodes the number (see Gap
  Analysis).

### A3. Mock Interview anti-malpractice thresholds: flag at 3/terminate at 5 → flag at 2/terminate at 3

- `career_app/views.py:1041-1042` (ORIGINAL) `MALPRACTICE_FLAG_THRESHOLD =
  3`, `MALPRACTICE_TERMINATE_THRESHOLD = 5` → `career_app/views.py:1212-
  1213` (UPDATED) `= 2`, `= 3`. **Confirmed** by direct diff. The server
  already returns both thresholds in `resume_violation_state`'s JSON
  response in both versions (`"flag_threshold"`/`"terminate_threshold"`) —
  this was always meant to be read dynamically, not hardcoded.

## B. New functionality — large, net-new feature areas

### B1. "Create Resume" and "Manual Resume" builders (entirely new, no ORIGINAL equivalent)

Two independent, from-scratch, browser-based resume builders, both
embedded in the new landing page (§C1), neither existing anywhere in
ORIGINAL (confirmed: `grep -rli` across all of ORIGINAL for
`create_resume|manual_resume|resume_draft|ResumeRoleTemplate|ResumeDraft`
returns zero matches).

- **"Manual" Resume Builder** (`career_app/manual_resume_views.py`,
  `resume_document.py`, `resume_pdf.py`, `resume_roles.py`) — a role-driven
  5-step wizard opened from a career-path "role card" on the landing page.
  Picking a role seeds per-role, per-experience-level suggestions (skills,
  summary templates, responsibilities) from a built-in role library plus an
  admin-overridable `ResumeRoleTemplate` model (migration `0016`). No
  login, no save/draft capability — stateless, nothing stored server-side.
- **"Create Resume" builder** (`career_app/create_resume_views.py`,
  `create_resume.py`, `create_resume_pdf.py`) — a free-form, single-page,
  multi-section form (personal/summary/experience/education/skills/
  projects/certifications/achievements/internships/languages/volunteering)
  with a template switcher, live preview, print/PDF download, and
  **signed-in draft persistence** (`ResumeDraft` model, migration `0017`,
  max 20 per user).
- **Full endpoint table** (routes confirmed in `business_english_lms/urls.py:92-104`):

  | Route | Method | Auth | Contract |
  |---|---|---|---|
  | `manual/roles/` | GET | None | `?slug=`/`?spec=` → role JSON |
  | `manual/preview/` | POST | None | full wizard state JSON → `{ok, document, warnings, completeness, filename}` |
  | `manual/pdf/` | POST | None | same state → `application/pdf` |
  | `manual/pages/` | POST | None | same state → JSON page images (base64 PNGs rendered from the real PDF) |
  | `create/preview/` | POST | None | full builder state JSON → `{ok, document, errors, status, filename}` (always returns a document, even with errors — true live preview) |
  | `create/pdf/` | POST | None | same state → `application/pdf` |
  | `create/pages/` | POST | None | same state → JSON page images |
  | `create/drafts/` | GET | **Login required** | `{ok, drafts:[{id,title,template,updated}]}` |
  | `create/drafts/save/` | POST | **Login required** | `{id?, data}` → create/update, 400 over 20-per-user cap |
  | `create/drafts/<pk>/` | GET | **Login required**, owner-scoped | full draft data |
  | `create/drafts/<pk>/delete/` | POST | **Login required**, owner-scoped | `{ok:true}` |

- All POST endpoints are CSRF-protected, size-limited (200-300KB), and
  per-IP rate-limited. No subscription/plan gating on either builder.
- **Mobile feasibility** (verified, not assumed): the JSON/PDF contract is
  fully mobile-consumable as-is — `pdf`/`pages`/draft-CRUD endpoints need
  no prior "preview" call; a client can assemble the same JSON shape fresh
  and POST directly. The genuinely browser-only piece is the **live
  on-screen document preview**, currently rendered by hand-rolled
  client-side JS (`static/js/create_resume.js`, 835 lines) turning the
  `document` JSON into styled HTML — this has no portable code to reuse; a
  Flutter port would need a native widget-tree renderer for the same
  `document` JSON shape, built from scratch.
- **Classification**: New functionality. **Confidence: Confirmed**
  (migrations, view code, and templates all read directly).

### B2. Home/landing page — complete replacement, not an addition

- `activities/views.py`'s `home()` view (the site's root `/` URL, used by
  **every** visitor — not just guests) now renders `templates/landing.html`
  (9054 lines) instead of the original `home.html`. The updated code's own
  comment is explicit: *"The previous home.html is left in place, unused by
  this view."* **Confirmed** by direct read of the current `home()` view.
- `landing.html`'s real content sections (by `id`, not icon spans):
  `features`, `choose-path` (career-track/role picker), `resume` (ATS
  upload CTA), `create-resume` (§B1), `rm` (the manual-resume role modal,
  §B1), `skillup`, `stories` (testimonials), `employer`, `job-seeker`,
  `contact`, `buddy` (chat widget anchor).
- This is the same page the new role-fit/target-role flow (§B3) and the
  new "Create Resume" builder (§B1) are embedded in — i.e. this one
  template change is the delivery vehicle for several of the other new
  features in this inventory, not an isolated UI change.
- **Classification**: Modified functionality (full replacement).
  **Confidence: Confirmed.**

### B3. Mock Interview: two new pre-interview gates, both via the existing flashed-message mechanism

- **ATS-90 gate** (new): `ATS_INTERVIEW_THRESHOLD = 90`
  (`career_app/views.py:185`, absent from ORIGINAL entirely).
  `resume_start_interview` now blocks unless
  `analysis['match_percentage'] >= 90`
  (`_ats_unlocks_interview`), flashing *"The AI Interview unlocks when your
  resume's ATS score is 90% or higher. Improve your resume and analyse it
  again."* and redirecting to `resume_job_match` — same `messages.info()` +
  redirect pattern as the pre-existing Premium-plan/no-parsed-resume
  blocks. **Confirmed**, read the surrounding view code directly.
- **Role-fit gate** (new, optional): new files `career_app/resume_roles.py`,
  `career_app/role_fit.py`, migration `0018_interview_target_role.py`.
  `rb_role`/`rb_role_fit` session keys are populated **only** when the
  request carries `?role=&dept=&track=` query params (set by role-card
  links on the new landing page). If a target role was picked and the
  resume's skill-word coverage against that role is below ~25%, the
  interview is blocked with *"This resume does not match the {role} role
  you picked..."*. **Skipping the picker entirely leaves the gate inert —
  the funnel works exactly as before.** **Confirmed**, read `role_fit.py`
  and the gate's call site directly.
- **Free résumé-analysis cap** (new): `FREE_RESUME_PARSE_LIMIT = 4`
  (`career_app/views.py:173`, absent from ORIGINAL). Free-plan users are
  capped at 4 total resume analyses (fresh uploads + re-analyses combined);
  blocked with a counted message ("You have used all 4..."). **Confirmed**
  by direct diff.

### B4. Skill-Up: new free-plan content gating + large content expansion

- `core/skillup_access.py` + `core/test_skillup_access.py` (new, no
  ORIGINAL equivalent of any kind — confirmed no inline gating logic
  existed in ORIGINAL either). Free plan is now restricted to English,
  Vocabulary, and Grammar plus one self-selected activity; Normal/Pro
  unlock Aptitude, the Tech Center, the new Non-IT Center, and
  certificates. Enforced in middleware ahead of static-file serving, so a
  direct URL cannot bypass it. **Classification**: New functionality.
  **Confidence: Confirmed.**
- Content expansion under `static/001 Career Buddy/`: 10 new TechCenter
  department subdirectories (business-analysis, customer-success-
  technical-support, design-ux-ui, development, devops-infrastructure,
  product-management, project-management-agile-delivery, quality-
  assurance-qa-testing, sales-and-marketing, technical-writing — 383 new
  HTML files) plus an entirely new `NonITCenter/` (technical +
  non-technical, 202 new HTML files). **Classification**: New
  functionality/content. **Confidence: Confirmed** (file counts from
  direct listing).
- `skillup_assessment/services.py` (new) consolidates certificate
  bookkeeping that, per its own test file
  (`activities/tests_option_rotation.py`'s `CertificateBookkeepingTests`),
  previously only ran for AMCAT/CoCubes submissions and never for the 25
  subject quizzes — a genuine bug fix, not a contract change a client
  would need to adapt to.

### B5. Portal separation now enforced centrally (new middleware)

- `core/portal_access.py` (`PortalSeparationMiddleware`, new — confirmed no
  equivalent existed in ORIGINAL beyond scattered template-level nav-item
  visibility checks, which never blocked access). Employer accounts
  hitting any of `/dashboard/`, `/careers/`, `/applications/`,
  `/activities/`, `/skill-up/`, `/users/profile/`, `/pro/`,
  `/resume-builder/`, `/gd/`, `/jam/`, `/roleplay/`, `/subject/`, `/go/`
  now get redirected (302) to the student login; student accounts hitting
  `/employer/*` get redirected to the employer login. **Classification**:
  New functionality (access control). **Confidence: Confirmed.**

### B6. Riya bot ("Buddy") guest mode and new action keys

- `riya_bot/guest.py` (new): unauthenticated visitors on the new landing
  page can now use Buddy — a rule-based (regex, no AI) response set that
  either names a real feature and routes the visitor to the correct login
  page, or allows exactly four truly-public destinations: `/#why`,
  `/#choose-path`, `/#create-resume`, `/#contact`. **Confirmed new** (no
  prior guest/anonymous chat handling existed in ORIGINAL).
- 5 new action keys added to `riya_assistant.py`'s `ACTION_DEFINITIONS`
  (34 → 39 total, confirmed by diff): `listen_learn`, `job_recommendations`,
  `contact_us`, `resources`, `industries`.
- `riya_chat`'s (non-streaming) `want_audio` default flipped `True` →
  `False` (`riya_bot/views.py`, confirmed) — the server-generated `audio`
  field is now `null` unless explicitly requested.

## C. Confirmed changes with no (or already-mitigated) Flutter relevance

- **`dashboard_api`/`activities_api`/`mcq_exercise_api` JSON endpoints
  removed entirely** (confirmed: zero references anywhere in the updated
  repo). These were already documented in Flutter's own code as "confirmed
  not deployed to production" — Flutter already uses HTML scraping as its
  real data source for these, so this removal changes nothing Flutter
  depends on.
- **`ContentProtectionMiddleware`** (new) injects an anti-copy/anti-print
  `<script>` tag into full HTML responses only — explicitly skips all
  non-`text/html` responses (every JSON API) and AJAX fragments. No effect
  on Flutter's JSON calls; the HTML pages Flutter scrapes gain one extra
  inert `<script>` tag that existing parsers (which key off other DOM
  elements) are unaffected by.
- **`PageGZipMiddleware`** (new) gzips normal responses, explicitly skips
  `text/event-stream` (chatbot streaming) — transparent to any standard
  HTTP client; no action needed.
- **GST tax invoice** (`career_app/views.py`'s `payment_invoice`) —
  confirmed **byte-identical** between ORIGINAL and UPDATED. The external
  audit document's "new" claim for this feature is **false**; it already
  existed, unchanged, and the Phase 13 blocker (no payment `pk` exposed
  anywhere a mobile client could read it) is unaffected by this update.
- **Razorpay webhook** (`pro/webhook/razorpay/`) — confirmed **already
  present, unchanged**, in ORIGINAL too (identical route, identical "BUG-03
  fix" comment). The external audit document's "new" claim is **false**.
  Server-to-server only; zero Flutter relevance either way.
- **Riya bot language list** (english/hindi/vietnam/arabic/russian/telugu/
  tamil) — confirmed **byte-identical** between ORIGINAL and UPDATED. The
  external audit document's "new" (Telugu/Tamil) claim is **false**.
- **`users/` auth, registration, profile, OTP, lockout** — `forms.py`,
  `models.py`, `urls.py` confirmed **byte-identical** (CRLF-only diff).
  `LOGIN_FAILURE_LIMIT = 5`/`LOGIN_LOCKOUT_SECONDS = 900` and every error
  message string this engagement's recent auth-error-message work
  (Phase 14) depends on are unchanged. `views.py` gained a new open-redirect
  guard (`_safe_next()`) and portal-separation redirect targets — neither
  affects Flutter, which only checks HTTP status codes, never redirect
  targets, for its own login/logout handshake.
- **`GD_app/`, `jam_app/`, `ResumeBuilder_module/`** — confirmed
  functionally **unchanged** (the files `diff -rq` flagged are CRLF line-
  ending noise only; content diffs after stripping `\r` are empty except
  for 5 cosmetic `<title>` tag changes in `ResumeBuilder_module`'s
  templates). The only real change found was a client-side neural-TTS
  fallback added to GD's own JS (`gd.js`), layered in front of the existing
  browser speech synthesis — does not touch the WebSocket message contract.
- **Jobs/Employer field contract — the Phase 11 mystery is resolved.**
  Flutter's `JobPostingSubmission` (46 fields) was previously flagged as
  unexplained against ORIGINAL's committed `JobPosting` model (~23 fields).
  The UPDATED repo's `jobs_app/models.py` now has 48 model fields (22 new
  migrations, `0011`-`0032`), and `JobPostingForm` excludes exactly 5
  non-form fields (`employer`, `created_at`, `updated_at`, `is_seeded`,
  `skills_required`) while adding back 3 form-only Non-IT alias fields
  (`work_mode`, `employment_type`, `joining_requirement`, each copied into
  a real model field — `work_environment`, `job_type`, `notice_period`
  respectively — in `JobPostingForm`'s own `clean()`). **43 real fields + 3
  aliases = 46 — an exact match to Flutter's field list, confirmed
  field-by-field by me directly**, with the real template
  (`templates/employer/job_form.html`) confirmed to render a genuine
  `{{ form.X }}` control for every one of the 46. **Flutter's job-posting
  implementation needs no changes for this area — it was already built
  correctly against this (or an equivalent) contract; the OLD reference
  repo was simply stale.**

## D. Lower-priority / informational

- **Interview question generation**: reverted from live performance-
  adaptive domain-question selection (`domain_count=0` in ORIGINAL) to
  upfront generation of all 20 questions (`domain_count=10,
  focus=session.target_role` in UPDATED) — the adaptive-difficulty code
  path in `resume_get_next_question` becomes dead code once a session is
  created this way. Backend-only; Flutter's polling contract is unchanged.
- **`evaluate_answer`** gained a resume-consistency cross-check (answer
  must be supported by the candidate's own resume skills/experience) and
  optional server-side spoken-answer transcription support
  (`spoken`/`audio` POST fields `resume_submit_answer` now accepts).
  Flutter already does on-device speech-to-text and never sends
  `spoken`/`audio` — it gets the scoring upgrade automatically and is
  unaffected by the new optional transcription path.
- **Activity progress semantics**: new `activities/progress.py` +
  `ACTIVITY_PROGRESS_SCORING` setting (default `'latest'`, absent from
  ORIGINAL). `Activity.get_completion_rate()` changed from a
  coverage-based percentage (ORIGINAL) to a score-performance-based
  percentage (UPDATED) under the same method/field name — a semantic
  change to an existing value, not purely additive. **Confidence:
  Confirmed** mechanism; **Probable** (not fully verified) real-world
  display impact.
- **MinIO public-URL fix**: a previously-malformed `https//host` URL bug
  is fixed (would have 404'd video links) — a net-positive backend bug fix,
  no Flutter action needed.
- **Interview video streaming**: HTTP Range support (206 partial content)
  added to the protected media view — improves seekability, backward
  compatible.
- **FAQ industry scoping** (migrations `0014`/`0015`) — Flutter has no FAQ
  feature at all; not applicable to mobile.
- **Excel-based interview-question import tool**, **`warm_tts_cache.py`**,
  **migration `0008_fix_listen_learn_category.py`** (a data-only fix) — all
  confirmed pure admin/ops tooling with no runtime contract change.
- **Quiz option rotation**: three independent subsystems found
  (mock-test/subject-quiz banks; the DB-backed Exercise/Question `mcq`
  type covered in §A1 — **not** rotated at all; and 2 static in-lesson
  quiz pages). The mock-test/subject-quiz bank system grades by comparing
  option **text**, not position, so rotation itself does not break that
  system's contract. **Whether Flutter's own Mock Tests/AMCAT/CoCubes
  submission path (a different code path from the §A1 MCQ exercise type)
  already submits by text/correct-answer rather than a positional index was
  not independently re-confirmed this phase — flagged as Uncertain, not
  assumed Aligned.**

---

Every classification and confidence level above reflects direct source
reads performed this phase (by me directly, or by a research pass whose
specific file:line citations I either re-verified myself or am reporting
as that pass's own Confirmed/Probable finding, never as unverified
third-party claims).
