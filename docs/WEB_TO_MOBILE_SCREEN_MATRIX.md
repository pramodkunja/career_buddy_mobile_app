# Web → Mobile Screen Conversion Matrix

**This is an audit document only. No code was changed to produce it.**

Source of truth: `/Users/kunjapramodmahajan/Flutter Projects/CAREER BUDDY LMS/Career_Buddy_LMS/`
Note: as established in prior sessions, that exact path no longer exists on
disk — the live, git-tracked backend is at
`/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Career_Buddy_LMS/`
(no `CAREER BUDDY LMS` wrapper). All findings below are against that tree,
cross-checked against the live running server where noted.

Flutter project: `/Users/kunjapramodmahajan/Flutter Projects/Career_Buddy_LMS/Mobile_app/`.
**Confirmed by direct file listing:** exactly 7 Flutter screens exist today —
`SplashScreen`, `LoginScreen`, `DashboardScreen`, `ActivityListScreen`,
`ActivityDetailScreen`, `SubActivityDetailScreen`, `McqExerciseScreen`. No
other screen files exist anywhere under `lib/`.

Status legend (exactly one per row): `NOT_STARTED` `PARTIAL`
`FUNCTIONAL_ONLY` `UI_MISMATCH` `DATA_MISMATCH` `COMPLETE` `NOT_APPLICABLE`.

---

## Master Screen Inventory

### Module: Authentication

| ID | Module | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|---|
| W001 | Auth | Student Login | `/users/login/` | `templates/users/login.html` | `LoginScreen` | PARTIAL |

**W001 — Student Login**
- **Purpose:** session-cookie login for the student/job-seeker portal.
- **Visible components (web):** left branding banner (logo, headline, 4-item feature checklist), right form card (title "Job Seeker Sign In", subtitle), username/email field, password field, inline server-rendered error banner, "Forgot password?" link, primary submit button, divider, "Create Free Candidate Account" outline button, "Employer Portal Sign In" link.
- **Data fields:** username/email, password. No other fields.
- **Actions:** Sign In, Forgot Password (link), Create Account (link), Employer Portal Sign In (link).
- **States (web):** validation error (Django form errors, one generic message for both "wrong credentials" and "employer account used here" — see `users/forms.py` `LoginForm.clean()`), loading (browser-native form submit, no JS spinner), success (302 redirect to `next`/`home`).
- **Backend data source:** `EXISTING_HTML_ONLY`, but the mobile client doesn't need JSON here — it POSTs the same form-encoded endpoint directly (`FORM_POST`, verified working end-to-end in an earlier session: CSRF handshake, invalid-credentials path, and the 200-vs-302 success signal were all confirmed against the live server).
- **Flutter file:** `lib/features/auth/presentation/screens/login_screen.dart`.
- **Matching quality:** `UI_PARTIAL`. Flutter has: username/email field, password field (with visibility toggle — an improvement over the web, not a regression), primary Sign In button, loading state, error snackbar on failure. **Missing UI:** the branding/feature-checklist banner (acceptable simplification for mobile, not a functional gap); "Forgot password?" is present as a link but wired to a no-op (`onPressed: () {}`) since the password-reset flow has no Flutter screen yet; "Create Free Candidate Account" and "Employer Portal Sign In" are both rendered but also wired to no-ops for the same reason.
- **Missing functionality:** registration flow, password reset flow, employer login flow — none exist in Flutter (see W-series below, all `NOT_STARTED`).
- **Missing data:** none for the login screen itself.
- **Why `PARTIAL` not `COMPLETE`:** the screen's own core function (submit credentials, see the real error, land on the dashboard) is real and verified, but two of its four visible actions (Forgot Password, Create Account) are inert placeholders, and Employer Portal Sign In has no destination.

---

### Module: Dashboard

| ID | Module | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|---|
| W002 | Dashboard | Student Dashboard | `/dashboard/` | `templates/dashboard.html` | `DashboardScreen` | PARTIAL |

**W002 — Student Dashboard**
- **Purpose:** post-login landing page — progress overview, recent activity, job recommendations, payment history.
- **Visible components (web):** cosmetic language-switcher dropdown (not real i18n, not worth porting — documented, not a gap), welcome banner, 4-tile stats row (Total Activities/Completed/In Progress/Total Score), "Recommended Job Opportunities" card (conditional), activity-progress list with per-activity progress bars, "Payment History" table (conditional), "Recent Results" sidebar, static "Quick Start" category shortcut links, a site-wide subscription-expiry popup banner (injected via context processor on every page, not dashboard-specific).
- **Data fields:** exact list documented in `docs/BACKEND_CONTRACT_dashboard.md` (stats, per-activity completion_rate/completed_sub_activities/total_sub_activities, recent_results with score/max_score/percentage, recommended_jobs with title/company/skills/location/job_type/experience/salary, payment_history with date/amount/status/transaction_id, interview_score).
- **Actions:** Continue/Start/Review per activity (navigates), "View All" (web has no such link — the web page's activity list has no separate "browse all" affordance, it's the same list as `/activities/`'s "All" tab), job "View & Apply" (navigates into `employer_portal`, out of Flutter's scope), payment rows are read-only.
- **States (web):** each section (jobs, activities, payments, recent results) has its own conditional visibility/empty rule (documented exhaustively in `BACKEND_CONTRACT_dashboard.md`); no page-level loading/error state on the web (full-page server render).
- **Backend data source:** `EXISTING_API` — `GET /dashboard/api/`, fully implemented, tested (`activities/tests_dashboard_api.py`, 9/9 passing), documented in `BACKEND_CONTRACT_dashboard.md`.
- **Flutter file:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`.
- **Matching quality:** `UI_MATCH` for the sections it implements. Flutter has: welcome banner, stats row, recommended-jobs section, activity-progress list (tappable → `ActivityDetailScreen`, an improvement the web doesn't have per-card navigation depth for since it's already the endpoint), payment history section, recent-results list, loading/error/retry states (which the web doesn't need but a mobile API client does), responsive phone/tablet layout, sign-out action in the app bar.
- **Missing UI:** the "Quick Start" static category-shortcut links (minor — same destination as the Activities tab's category filters, arguably redundant on mobile, not a real gap); the language switcher (correctly, deliberately not ported).
- **Missing functionality:** none of the dashboard's OWN functionality — every section's data is real and live-verified against the actual backend contract.
- **Why `PARTIAL` not `COMPLETE`:** the "Quick Start" shortcuts are a real (if minor) web component with no Flutter equivalent, and job cards' "View & Apply" has no Flutter destination (Jobs module is `NOT_STARTED`, see below) — so the screen is functionally excellent but not 1:1 complete against every web element.

---

### Module: Activities

| ID | Module | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|---|
| W003 | Activities | Activity List | `/activities/` | `templates/activities/list.html` | `ActivityListScreen` | PARTIAL |
| W004 | Activities | Activity Detail | `/activities/<pk>/` | `templates/activities/detail.html` | `ActivityDetailScreen` | PARTIAL |
| W005 | Activities | Sub-Activity Detail | `/activities/<activity_pk>/sub/<sub_pk>/` | `templates/activities/sub_activity.html` | `SubActivityDetailScreen` | PARTIAL |
| W006 | Activities | Exercise — MCQ | `/activities/exercise/<pk>/` (mcq type) | `templates/activities/exercise.html` (mcq branch) | `McqExerciseScreen` | PARTIAL |
| W007 | Activities | Exercise — Fill in the Blank | same URL, `fill_blank` type | same template, fill_blank branch | *(none)* | NOT_STARTED |
| W008 | Activities | Exercise — Matching | same URL, `matching` type | same template, matching branch | *(none)* | NOT_STARTED |
| W009 | Activities | Exercise — Bingo | same URL, `bingo` type | same template, bingo branch | *(none)* | NOT_STARTED |
| W010 | Activities | Exercise — Ordering | same URL, `ordering` type | **dead on web too** — no template branch exists | *(none)* | NOT_APPLICABLE |
| W011 | Activities | Exercise — Writing | same URL, `writing` type | same template, writing branch | *(none)* | NOT_STARTED |
| W012 | Activities | Exercise — Timer | same URL, `timer` type | same template, timer branch | *(none)* | NOT_STARTED |
| W013 | Activities | Workshop Dashboard | `/activities/workshop/` | `templates/activities/workshop_dashboard.html` | *(none)* | NOT_STARTED |
| W014 | Activities | AI Module — Speaking | `/activities/exercise/<pk>/` (module-routed) | `templates/activities/modules/speaking.html` | *(none)* | NOT_STARTED |
| W015 | Activities | AI Module — Writing | same, module-routed | `templates/activities/modules/writing.html` | *(none)* | NOT_STARTED |
| W016 | Activities | AI Module — Listening | same, module-routed | `templates/activities/modules/listening.html` | *(none)* | NOT_STARTED |
| W017 | Activities | AI Module — Reading | same, module-routed | `templates/activities/modules/reading.html` | *(none)* | NOT_STARTED |
| W018 | Activities | Roleplay Home | `/roleplay/` | `templates/activities/modules/roleplay_home.html` | *(none)* | NOT_STARTED |
| W019 | Activities | Roleplay Practice | `/roleplay/<feature>/` | `templates/activities/modules/roleplay.html` | *(none)* | NOT_STARTED |
| W020 | Activities | Mock Test — OOP Mastery | consumed via `static/001 Career Buddy/TechCenter/*.html` (standalone JS SPA, not a Django template) | n/a (static HTML + `mock_test.js`) | *(none)* | NOT_STARTED |
| W021 | Activities | Mock Test — Subject Quiz | same static SPA layer, per-subject | n/a | *(none)* | NOT_STARTED |
| W022 | Activities | Mock Test — AMCAT | same static SPA layer | n/a | *(none)* | NOT_STARTED |
| W023 | Activities | Mock Test — CoCubes | same static SPA layer | n/a | *(none)* | NOT_STARTED |

**W003 — Activity List**
- **Purpose:** browse all learning activities, filtered by category.
- **Visible components (web):** page header, category tab bar (hidden entirely for Free-plan users), Free-plan banner (conditional, shows claimed-activity state), activity card grid (number badge, icon, done-badge overlay, level badge, category badge+icon+tooltip, title, description [`objective` field], progress bar [only when `rate>0`], 3-state CTA button, locked state with an "Upgrade Required" modal), empty state ("No activities found for this category." + Show All button).
- **Data fields:** id, title, `objective` (as description), category (+ display label), level, duration, is_locked, completion_rate, is_completed.
- **Actions:** category filter tap, card tap (Start/Continue/Review), locked-card tap (opens upgrade modal on web; Flutter instead just shows a lock icon + "Locked" label with no modal — see mismatch below).
- **States:** loading (browser-native), empty (per-category), locked (modal), progress (0%/partial/100%).
- **Backend data source:** `EXISTING_API` — `GET /activities/api/`, documented in `BACKEND_CONTRACT_activities.md` §A, tested (`activities/tests_activities_api.py`).
- **Flutter file:** `lib/features/activities/presentation/screens/activity_list_screen.dart`.
- **Matching quality:** `UI_PARTIAL`. Flutter has: category filter chips, activity cards (level/category badges, progress bar, 3-state CTA label, lock icon), empty-state copy (exact web text), phone/tablet responsive layout (verified overflow-free at 320px and tablet width), pull-to-refresh, retry-on-error.
- **Missing UI:** the "Upgrade Required" modal for a locked card tap — Flutter's locked cards currently have no distinct tap behavior documented (the card is still generically tappable via `ActivityCard`'s `onTap`, which would push into `ActivityDetailScreen`, which THEN shows the 403/locked message — so the web's "explain the lock immediately on the list page" UX is currently deferred one screen later in Flutter, not missing entirely, but not a 1:1 match); the Free-plan claimed-activity banner text ("You have used your one free activity on X...") has no Flutter equivalent — Flutter shows `is_free_preview` as a boolean the UI doesn't currently surface any messaging for.
- **Missing functionality:** none of the list/filter/navigate functionality itself.
- **Missing data:** none — every field the web shows is present in the API contract and rendered.

**W004 — Activity Detail**
- **Purpose:** activity overview + its sub-activities.
- **Visible components (web):** hero (breadcrumb, title, `objective` subtitle, level/duration/sub-activity-count meta, progress ring), sub-activity cards (numbered badge, status badge [Completed/In Progress/Not Started], exercise count, 3-state CTA, started/completed timestamps), prev/next activity nav buttons, sidebar "Materials" card, static "Assessment" info card (hardcoded copy, not per-activity data), anonymous-user "Login to Track Progress" prompt.
- **Data fields:** matches `BACKEND_CONTRACT_activities.md` §B exactly.
- **Actions:** sub-activity card tap, prev/next activity nav.
- **States:** progress ring at 0/partial/100%, per-sub-activity status badge states, workshop/module activities redirect elsewhere on web (Flutter shows an inline message instead — see below).
- **Backend data source:** `EXISTING_API` — `GET /activities/api/<id>/`, §B.
- **Flutter file:** `lib/features/activities/presentation/screens/activity_detail_screen.dart`.
- **Matching quality:** `UI_PARTIAL`. Flutter has: title/description/level/duration/sub-activity-count meta, progress bar (linear, not a ring — a deliberate, reasonable mobile adaptation, not a defect), sub-activity tiles with status badge, tap-through navigation, locked-state screen (distinct copy + icon, better than the list page's current gap), loading/error/retry.
- **Missing UI:** prev/next activity navigation buttons (no Flutter equivalent at all); the "Materials" sidebar card and the static "Assessment" info card (both omitted — for Materials this is a real content gap, for the static Assessment card it's arguably fine to omit since it's identical boilerplate text on every activity, not real per-activity data).
- **Missing functionality:** prev/next navigation.
- **Missing data:** `activity.materials` (a text field the web shows, first-6-items-split, that the API contract doesn't currently expose at all — confirmed absent from `BACKEND_CONTRACT_activities.md` §B's field table).

**W005 — Sub-Activity Detail**
- **Purpose:** sub-activity overview + its exercise list + "Mark Complete" action.
- **Visible components (web):** status badge, Overview card (description), Instructions card, exercise cards (type icon+label, title, truncated instructions, last-score+percentage-badge if attempted, Start CTA), "Mark Complete" form (disabled with tooltip until all exercises done, else a real button), completed-banner, sidebar in-activity sub-nav list, static 4-item "Learning Tips" list.
- **Data fields:** matches `BACKEND_CONTRACT_activities.md` §C.
- **Actions:** exercise card tap (Start), Mark Complete submit.
- **States:** per-exercise last-score badge (color-coded by percentage threshold, ≥80/≥50/<50 — Flutter replicates this exact threshold), "all exercises done" gating on the Mark Complete button.
- **Backend data source:** `EXISTING_API` — `GET /activities/api/sub/<id>/`, §C.
- **Flutter file:** `lib/features/activities/presentation/screens/sub_activity_detail_screen.dart`.
- **Matching quality:** `UI_PARTIAL`. Flutter has: status badge, description, instructions, exercise tiles (type label, last-score, color-coded percentage badge), "complete all exercises" hint text, tap-through to `McqExerciseScreen` for `mcq`-type exercises only.
- **Missing UI:** the sub-activity's own truncated-instructions-on-card-only style (Flutter shows full instructions on its own card instead — arguably better, not worse, but not identical); prev/next sub-activity navigation; sidebar sub-nav list; "Learning Tips" static list.
- **Missing functionality:** **the "Mark Complete" button itself does not exist in Flutter at all** — there is no way for a mobile user to explicitly mark a sub-activity complete the way the web's real `<form>`-POST-to-`mark_sub_complete` button does. This is a genuine functional gap, not a cosmetic one — a mobile user's only path to "completed" status is submitting every exercise (which auto-completes it server-side, per `SubActivity.all_exercises_done()`), matching the web's *automatic* completion path but not its *explicit manual* one.
- **Missing data:** none of the exercise-summary fields.

**W006 — Exercise (MCQ)**
- **Purpose:** take an MCQ exercise, see a server-graded result.
- **Visible components (web):** breadcrumb, type icon+label, per-question progress bar + live score counter, one-question-at-a-time paging, 4 option buttons per question with immediate client-side correct/wrong coloring + inline explanation, Next/Submit button, result panel (6-tier qualitative score message, score line, per-question breakdown, "Try Again" = page reload, "Back to Sub-Activity" link), sidebar "Previous Score" card.
- **Data fields:** question text, 4 options, (web only, pre-submission) correct answer + explanation baked into the page.
- **Actions:** select option, Next, Submit, Try Again.
- **States:** per-question answered/unanswered, submitting, submitted/result.
- **Backend data source:** `EXISTING_API` for the mobile flow specifically — `GET /activities/api/exercise/<id>/` + `POST .../submit/`, a **new, mobile-only, server-authoritative pair** built this project (documented exhaustively in `PHASE_3_EXERCISE_ARCHITECTURE.md` and `BACKEND_CONTRACT_activities.md` §D) — the web's own `submit_exercise` endpoint is untouched and remains client-graded (a documented, deliberate divergence, not an oversight).
- **Flutter file:** `lib/features/activities/presentation/screens/mcq_exercise_screen.dart`.
- **Matching quality:** `UI_PARTIAL` (and, uniquely among all screens audited, **functionally superior to the web in one specific respect**: server-authoritative grading vs. the web's client-trusted score). Flutter has: progress bar, question paging (one at a time, matching web), option selection with visual state, Next/Submit gating (disabled until answered/all-answered, matching web), submitting state, result view (score/max/percentage/attempt number, per-question correct/incorrect + explanation).
- **Missing UI:** the web's 6-tier qualitative score message ("Perfect Score!"/"Excellent!"/etc.) — Flutter shows the raw percentage only, no qualitative tier; "Try Again" (web reloads the page; Flutter has no retry-the-exercise action at all from the result screen — a real navigation gap, not just cosmetic); sidebar "Previous Score" card (no Flutter equivalent, though the sub-activity screen already surfaces last-score per exercise one level up).
- **Missing functionality:** retry from the result screen; only `mcq` type is converted (see W007-W012 — 5 of 7 default-flow exercise types, plus the AI modules and roleplay, remain `NOT_STARTED`, and `ordering` is dead on the web itself so correctly excluded).
- **Missing data:** none for the MCQ type itself.

**W007-W012 — remaining default-flow exercise types.** `fill_blank`, `matching`, `bingo`, `writing`, `timer` are all live, working, distinct UI flows on the web (documented field-by-field in the Phase 1 inspection report earlier this project) with **zero Flutter equivalent** — not even a placeholder. `ordering` (W010) has JS wired up but no template branch on the web itself (confirmed dead code), so it's correctly `NOT_APPLICABLE` rather than a real gap.

**W013 — Workshop Dashboard.** A real, distinct screen (`/activities/workshop/`, its own template, a small card grid linking to GD/JAM/Roleplay) — confirmed by direct read just now (`templates/activities/workshop_dashboard.html`, 61 lines). Zero Flutter equivalent.

**W014-W017 — AI Modules (Speaking/Writing/Listening/Reading).** Each is a substantial, distinct screen (mic recording, live transcript, AI-graded scoring, a genuine server-side word-count validator for one specific writing exercise, and — for Listening — the only real anti-replay/attempt-token protection anywhere in the exercise system). All fully documented in the Phase 1 inspection. Zero Flutter equivalent; would require audio recording, `MediaRecorder`-equivalent Flutter packages, and multipart upload — a materially larger undertaking than MCQ was.

**W018-W019 — Roleplay.** GD/JAM-style AI conversation practice, its own app-level flow (`/roleplay/`), persists to `ScoreRecord` not `UserExerciseResult`. Zero Flutter equivalent.

**W020-W023 — Mock Tests (OOP/Subject/AMCAT/CoCubes).** These are real, substantial user-facing screens (question-by-question quiz UI with a countdown timer, section navigation for AMCAT/CoCubes) but are **not Django-templated at all** — they're a standalone static-HTML + vanilla-JS mini-SPA under `static/001 Career Buddy/TechCenter/`, consuming the `oop-quiz`/`quiz`/`amcat`/`cocubes` JSON endpoints directly. This is architecturally the closest thing to a "mobile-ready" screen already (real JSON in, real JSON out, answers withheld until grading, fully server-side graded) — but it's also the most disconnected from the rest of the site's navigation (no link to it found in `templates/activities/` — reachable only via the redirect at `path('static/001 Career Buddy/', RedirectView.as_view(url='/skill-up/', ...))`, which itself just forwards to skill-up, suggesting this TechCenter SPA may be a legacy or side feature rather than a primary flow — **flagging this as uncertain, not asserting it confidently**, since I did not trace how a real user actually discovers this page from the main navigation).

---

### Module: Registration, Profile & Password Recovery

| ID | Module | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|---|
| W024 | Profile | Student Registration | `/users/register/` | `templates/users/register.html` | *(none)* | NOT_STARTED |
| W025 | Profile | Student Profile (View + Edit) | `/users/profile/` | `templates/users/profile.html` | *(none)* | NOT_STARTED |
| W026 | Profile | Password Reset Request | `/users/password-reset/` | `templates/registration/password_reset_form.html` | *(none)* | NOT_STARTED |
| W027 | Profile | Password Reset Done | `/users/password-reset/done/` | `templates/registration/password_reset_done.html` | *(none)* | NOT_STARTED |
| W028 | Profile | Password Reset Confirm | `/users/reset/<uidb64>/<token>/` | `templates/registration/password_reset_confirm.html` | *(none)* | NOT_STARTED |
| W029 | Profile | Password Reset Complete | `/users/reset/done/` | `templates/registration/password_reset_complete.html` | *(none)* | NOT_STARTED |

**W024 — Student Registration**
- **Purpose:** self-registration collecting a full candidate profile (personal, ID docs, education, experience, resume) plus email-OTP verification, then auto-login.
- **Visible components:** header; 7 section cards — Personal Information, Identity Documents, Education (+ dynamic "Additional Education" repeater), Experience & Skills (+ conditional contact-person sub-block), Location, Abroad Experience (conditional), Account Setup; inline email-OTP widget (Verify/Confirm/Resend + 60s cooldown); dynamic "Add Language" repeater; submit "Create My Account"; "Already have an account?" link.
- **Data fields:** first/last name, email, gender, mobile, alternate_mobile, blood_group, languages_known (dynamic), selfie, aadhar/pan/passport numbers, education_level(+2), passed_out_year(+2), iti_diploma_specialization, higher_education_degree, additional_educations_json (dynamic), has_experience, experience_years, company_name, contact_person_role/mobile/email, industry, skills, current_ctc, expected_ctc, certification, resume (required upload), current_location, preferred_location, has_abroad_experience(+years/country/industry/skills), username, password1, password2.
- **Actions:** Verify/Resend/Confirm email OTP (AJAX), Add Language, Add Another Education (client-side), Create My Account (submit), Sign In link.
- **States:** per-field validation errors, non-field-errors block, email-exists alert popup, real-time PAN/Aadhar/Passport format validation (✔/✘), OTP send cooldown.
- **Backend data source:** `EXISTING_HTML_ONLY` for the form submit itself. The two OTP sub-actions (`send_email_otp`, `verify_email_otp`) ARE JSON (`EXISTING_API`, but they're actions, not screens) — a mobile registration screen could reuse them as-is.
- **Flutter:** none. Confirmed by direct grep — `lib/features/` has exactly 4 folders (`activities`, `auth`, `dashboard`, `splash`); `auth/` contains only login-related files.

**W025 — Student Profile (View + Edit)**
- **Purpose:** the user's own profile — a read-only "Profile Details" tab and an "Edit Details" tab (same field set as registration, minus password) on one URL, client-side tab-switched.
- **Visible components:** left sidebar (avatar/selfie, name, `@username`, English-level badge, 3-stat grid [Started/Done/Score], "Recent Exercise Results" list [conditional], "Joined" date); right card with Profile Details / Edit Details tabs; Overview tab (grouped read-only sections: Account, Personal & Contact, Government ID [masked], Education, Work Experience & Skills, Location, Abroad Experience); Edit tab (full form mirroring registration's fields, masked-reveal ID fields, resume upload showing the current file link).
- **Data fields:** every `UserProfile` field from W024, plus `completed_subs`, `total_score`, `activities_started`, `recent_results` (last 10 `UserExerciseResult`).
- **Actions:** switch tabs, Save Changes (submit), "Change" on masked ID fields (reveal blank input), replace selfie/avatar/resume, view current resume link.
- **States:** per-field errors on Edit tab, "Profile updated successfully!" success message, "Not Provided" empty-value fallback throughout Overview, conditional Recent Results section.
- **Backend data source:** `EXISTING_HTML_ONLY` — no `JsonResponse` sibling exists for this screen at all (confirmed by grep of `users/views.py`).
- **Flutter:** none.

**W026-W029 — Password Reset (4-screen flow: Request → Done → Confirm → Complete).** All four are Django's built-in `auth_views.PasswordReset*View`s with custom templates — standard, well-understood flow (email input → confirmation → new-password form [with a `validlink` true/false branch] → success). All `EXISTING_HTML_ONLY`, all `NOT_STARTED` in Flutter. Referenced from W001 (Login)'s "Forgot password?" link, currently wired to a no-op in Flutter.

**Explicitly confirmed absent (checked against the actual code, not assumed):** there is no in-app "change my password while logged in" screen anywhere — only the forgot-password email-link flow exists. There is no subscription/plan display on the profile page itself (that's a separate `career_app` screen, W-series TBD). There is no "My certificates"/"My documents" listing screen — only the single resume-upload control embedded in the profile Edit tab.

**Non-screens in this module (confirmed via view code, not templates of their own):** `register/send-otp/`, `register/verify-otp/` (JSON-only OTP actions), `/users/logout/` (POST-only, always redirects, no template), `/employer/accounts/logout/` (same, plus no `registration/logged_out.html` exists in the templates tree at all).

---

### Module: Employer Authentication

| ID | Module | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|---|
| W030 | Employer Auth | Employer Login | `/employer/accounts/employer/login/` | `templates/employer_login/login.html` | *(none)* | NOT_STARTED |
| W031 | Employer Auth | Employer Registration | `/employer/accounts/employer/register/` | `templates/employer_login/signup.html` | *(none)* | NOT_STARTED |
| W032 | Employer Auth | Employer Login (legacy) | `/employer/accounts/login/` | `templates/accounts/login.html` | *(none)* | NOT_APPLICABLE |
| W033 | Employer Auth | Employer Registration (legacy) | `/employer/accounts/register/` | `templates/accounts/register.html` | *(none)* | NOT_APPLICABLE |

**W030 — Employer Login**
- **Purpose:** HR/recruiter sign-in, distinct from student login — server-side rejects any account without an `employer_profile` ("Student accounts cannot log in through the employer portal.").
- **Visible components:** lock icon, "Employer Login" heading, username + password inputs, error alert, Sign In submit, "Create Employer Account" button, "Job Seeker Login" cross-portal link.
- **Actions:** Sign In, Create Employer Account link, Job Seeker Login link.
- **Backend data source:** `EXISTING_HTML_ONLY` — zero `JsonResponse` anywhere in `accounts_app/views.py`.
- **Reachability confirmed real:** linked from `base.html`, `home.html`, the student login page's own "Employer Portal Sign In" link (currently a no-op in Flutter's `LoginScreen`), and two employer-portal pages.
- **Flutter:** none.

**W031 — Employer Registration**
- **Purpose:** new company self-registration — company profile, tax IDs (GST/PAN), HR contact, with **two independent email-OTP verifications** (account email and HR email).
- **Visible components:** 4 section cards (Company Profile, Tax & Registrations, HR/Contact Person, Account Credentials), two separate OTP widgets, Create Employer Account submit.
- **Data fields:** first/last name, username, email, company_name, company_logo, company_gst, company_pan_tin, company_address, industry, hr_contact, hr_mail, password1, password2.
- **Actions:** two OTP verify flows, submit (client- AND server-side blocked until both emails verified), Sign In link.
- **Backend data source:** `EXISTING_HTML_ONLY` for the submit; OTP actions reuse the same `users` app JSON endpoints as W024.
- **Reachability confirmed real:** linked from `home.html` (×2), the employer login page, and two employer-portal pages.
- **Flutter:** none.

**W032/W033 — legacy/orphaned employer login+registration.** Same `EmployerLoginView` class rendering a different template (W032), and a `# Keep for compatibility`-commented plain `UserCreationForm` view that never creates an `EmployerProfile` (W033, meaning an account created here would fail login's employer-profile check — evidence this path is broken/abandoned, not just unused). Verified by exhaustive grep that **nothing else in the site links to either URL** — they only link to each other, and `base.html` explicitly excludes these route names from a nav conditional. Marked `NOT_APPLICABLE`: dead code, not a real user-facing entry point, not worth converting. (Verified via static grep only — not 100% certain no external/email-template reference exists, flagged as a minor residual uncertainty.)

---

### Module: Pro / Membership & Payments (`career_app`)

All screens here are `@login_required`; no public pricing page exists. A site-wide subscription-expiry modal (`context_processors.subscription_notice`) overlays any page — not inventoried as a screen.

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W034 | Pro / Membership Plans | `/pro/` | `templates/pro.html` | *(none)* | NOT_STARTED |
| W035 | GST Tax Invoice | `/pro/invoice/<int:pk>/` | `templates/career_app/gst_invoice.html` | *(none)* | NOT_STARTED |

**W034 — Pro / Membership Plans**
- **Purpose:** Free/Normal(₹499)/Pro(₹999) plan comparison + upgrade/renew/downgrade entry point; payment via a Razorpay Checkout popup, not a form on this page.
- **Visible components:** 3 plan cards (feature checklist, price, CTA); a "Payment Preparation" modal (loading spinner → order summary [base/GST 18%/total] → Pay button); external Razorpay checkout iframe.
- **Data fields:** `current_plan`, `subscription_active`, `subscription_expiry`, `renewal_window`, `days_left` (card content itself is hardcoded, not context-driven).
- **Actions:** downgrade-to-free (POST, blocked while a paid plan is active), start-payment → `create_razorpay_order` (JSON) → Razorpay Checkout → `verify_razorpay_payment` (JSON) → reload; "Renew for another year" (shown only in the last-7-days renewal window).
- **States:** current-plan-disabled, paid-plan-active-on-free-card, renewal-window, checkout-loading, order-summary, payment-pending (webhook will finish activation), payment-error, network-error, payment-failed.
- **Backend data source:** `EXISTING_HTML_ONLY` for plan state; `create_razorpay_order`/`verify_razorpay_payment`/`razorpay_webhook` are write/transaction JSON actions, not a read API for "which plan am I on."
- **Flutter:** none.

**W035 — GST Tax Invoice**
- **Purpose:** Print-ready GST invoice for a payment (plain HTML, not a PDF binary — user prints-to-PDF from the browser). Owner-or-staff only, else 404.
- **Visible components:** standalone document (no site nav), seller/buyer blocks, payment-reference block, line-items table (SAC code, taxable value, CGST/SGST, amount), totals, Back link, Download/Print button (`window.print()`).
- **Data fields:** invoice_number, created_at, status, razorpay_payment_id/order_id, currency, taxable_value/cgst_rupees/sgst_rupees/total_rupees, plan_label, seller.{name,gstin,address,state,state_code,email,sac_code}, buyer.{name,email}.
- **Actions:** Back → Pro page; Download/Print (client-side only).
- **States:** missing-GSTIN warning banner; non-"captured" status badge (refunded/partially_refunded/refund_required).
- **Backend data source:** `EXISTING_HTML_ONLY`, single-record page, no JSON sibling.
- **Flutter:** none.

---

### Module: Resume Builder & AI Interview (`career_app`)

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W036 | Resume Builder Home (upload) | `/resume-builder/` | `templates/resume_builder.html` | *(none)* | NOT_STARTED |
| W037 | Resume Match / ATS Result | `/resume-builder/match/` | `templates/resume_match_result.html` | *(none)* | NOT_STARTED |
| W038 | Resume History | `/resume-builder/history/` | `templates/resume_history.html` | *(none)* | NOT_STARTED |
| W039 | AI Mock Interview (single screen, many states) | `/resume-builder/interview/chat/` | `templates/resume_interview.html` | *(none)* | NOT_STARTED |
| W040 | Interview Analytics / Results | `/resume-builder/analytics/` | `templates/resume_analytics.html` | *(none)* | NOT_STARTED |

**W036 — Resume Builder Home (upload)**
- **Purpose:** Resume upload form — not the score display itself (that's W037).
- **Visible components:** hero banner with stat chips, error box, drag-and-drop upload zone (.pdf/.docx), filename chip, "Analyze Resume with AI" submit, full-screen "Analyzing…" overlay on submit, 3 static feature cards.
- **Data fields:** `error` (set on a failed prior attempt, re-rendered into this same template).
- **Actions:** POST multipart upload → `resume_job_match` (success renders W037 directly, no redirect; failure re-renders this screen with an error). "Resume History" link → W038.
- **States:** default/empty, file-selected, drag-over, submitting/loading-overlay, error (invalid file / unreadable-scanned PDF / AI-analysis failure — 3 distinct messages).
- **Dead state found (documented, not fixed):** `resume_locked.html` is rendered when `_can_access_resume()` is false, but that function is literally `return user.is_authenticated` and the view itself is `@login_required` — this branch can never actually trigger.
- **Backend data source:** `EXISTING_HTML_ONLY`.
- **Flutter:** none.

**W037 — Resume Match / ATS Result**
- **Purpose:** AI analysis result — ATS score, and job-match if a JD was supplied. Reached only via a POST-success render or a session-fallback GET, or via re-analysis from W038; no dedicated screen of its own.
- **Visible components:** animated SVG score ring, "Matching Skills"/"Missing Skills" chip lists, a conditional banner (green "Complete the Interview to Unlock…" if allowed, amber "Upgrade to Unlock…" if not), a "Recommended ATS Resume Templates" section with 3 downloadable `.docx` templates + preview lightbox, a conditional "AI Suggestions"/career-advice card.
- **Data fields:** analysis text, matching_skills, missing_skills, match_percentage, career_advice, years_exp ("Fresher" if <1yr), is_ats_only (changes ring label), resume_valid/validation_msg, can_interview (paywall flag).
- **Actions:** "Try Interview" (if allowed & resume valid) → W039; "Upgrade for AI Interview" → W034; "Analyze Another Resume" → W036; "Resume History" → W038; template-preview modals (client-side only); static `.docx` downloads.
- **States:** ATS-only vs JD-match mode; resume-invalid-sections warning; can-interview vs paywalled banner; empty-skills states ("No exact matches found." / "No significant gaps found!"); score ring animates from 0.
- **Backend data source:** `EXISTING_HTML_ONLY`.
- **Flutter:** none.

**W038 — Resume History**
- **Purpose:** Lists every resume the user has uploaded.
- **Visible components:** hero banner, Django messages alerts, resume card list (file icon, filename, upload timestamp, "Current" badge, "View File", "View ATS Analysis"), empty state.
- **Data fields:** resumes (queryset, newest first), current_resume_id (from session).
- **Actions:** "Upload Another Resume" → W036; "View File" (protected media link); "View ATS Analysis" (POST → re-analyze → W037, only shown if extracted_text is non-empty).
- **States:** populated, empty ("No resumes uploaded yet"), current-highlighted, messages alert.
- **Backend data source:** `EXISTING_HTML_ONLY` — no JSON listing endpoint.
- **Flutter:** none.

**W039 — AI Mock Interview (single URL/template, many in-page states — NOT separate screens)**
- **Purpose:** The full camera-monitored, timed, voice-driven mock interview flow. Gated to Normal/Pro plans with a parsed resume; the largest/most stateful screen in the entire app (1869-line template).
- **In-page states (confirmed, not invented):** (1) camera-consent gate (live preview, Enable Camera → Start Interview); (2) camera-permission-denied/no-device error; (3) interview-in-progress main Q&A UI (chat-style bubbles, 30s per-question countdown, progress bar "Question X of 20", live Score Tracker panel, voice-answer flow [mic → transcript preview → re-record/submit] or a plain textarea for coding questions); (4) camera-lost overlay mid-interview; (5) anti-malpractice non-blocking toast + blocking warning modal (8 violation types: face-not-detected, multiple-faces, tab-switch, window-blur, camera-interrupted, fullscreen-exit, copy-paste, screenshot-attempt — each requires explicit "I Understand, Continue"); (6) interview-terminated overlay (after 5 total violations or >3 tab-switches, saves recording, redirects to W040); (7) interview-completed/saving state → "Analyze My Performance" → W040.
- **Data fields:** question text/topic/difficulty/progress, per-answer score/feedback, violation count/status, transcribed text — all populated client-side from JSON action calls (`resume_camera_verified`, `resume_upload_interview_video`, `resume_transcribe_answer`, `resume_get_next_question`, `resume_submit_answer`, `resume_record_violation`, `resume_violation_state`), not server-rendered context.
- **Actions:** enumerated above per state.
- **Backend data source:** `EXISTING_HTML_ONLY` for the page shell; `EXISTING_API` (JSON) for every live interaction during the interview — these already exist and could be reused as-is by a mobile client, though camera/mic/anti-malpractice monitoring would need native equivalents.
- **Flutter:** none.

**W040 — Interview Analytics / Results**
- **Purpose:** Post-interview results — pass/fail, per-question breakdown, topic chart, and (if passed) matched job recommendations. Re-checks plan access at render time so an expired/downgraded user can't view stale results.
- **Visible components:** hero banner with avg-score/completed stat chips; large pass/fail banner (≥70 "Recommended for Jobs" vs <70 "You should upgrade your skill"); 4 stat cards; if failed — "Recommended Skill Upgradation Courses" card linking to Activities by category; if passed with matches — "Recommended Job Opportunities" grid (skill tags, location, salary, "View & Apply" → Job Detail W042); a Chart.js bar chart of avg score per topic; "Session Summary" panel + Retry/Analyze-Another buttons; full "Detailed Breakdown" table (topic, Q+A, score chip, AI feedback).
- **Data fields:** session, per-question data (topic/difficulty/question/answer/score/feedback), total_integer_score, avg_score, is_passed, years_exp, suitable_jobs (plan-capped: 5 for Normal, unlimited for Pro), total_questions, answered_count.
- **Actions:** Retry Interview → W039; Analyze Another Resume → W036; skill-upgrade links → Activities; job cards → W042.
- **States:** pass vs fail (two full visual variants); jobs-recommended-but-empty (no jobs section renders at all if passed with zero matches — no distinct empty message); detailed-breakdown-empty ("No answered questions found in this session.").
- **Backend data source:** `EXISTING_HTML_ONLY` — chart data is embedded inline, not a fetchable JSON endpoint.
- **Flutter:** none.

**Confirmed not part of this audit's scope:** `ResumeBuilder_module/` is an unwired reference/vendor package (not in `INSTALLED_APPS`, not imported anywhere) with an earlier, materially simpler snapshot of these same 4 templates — it has zero active screens and is excluded from this inventory. One orphaned dead template (`resume_userguide.html`, referenced by a link with no matching URL) was also found and is not tracked as a real screen.

---

### Module: Jobs (`jobs_app`)

**Structural findings carried into this audit (documented, not fixed):** `jobs_app/urls.py` is never included anywhere — its `job_list` view/template is completely dead/unreachable code. Two URL names (`job_detail`, `download_candidates_csv`) are registered twice under the same `employer_portal` namespace (once in `employer_portal/urls.py`, once in `jobs_app/employer_urls.py`) — Django's `reverse()` resolves to the first-registered match, a known latent bug class in this codebase (an inline code comment already documents a prior break from the same cause). There is **no "My Applications" list screen anywhere on the web** — `my_application_detail` is reachable only via an emailed deep-link when an employer changes an application's status, never from a dashboard or nav.

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W041 | Student Application Detail | `/applications/<int:pk>/` | `templates/jobs/my_application.html` | *(none)* | NOT_STARTED |
| W042 | Job Detail + Apply | `/employer/jobs/<int:pk>/` | `templates/jobs/job_detail.html` | *(none)* | NOT_STARTED |

**W041 — Student Application Detail**
- **Purpose:** A student's read-only view of one of their own job applications. Scoped to the logged-in user's own applications; a foreign application id 404s (not 403, to avoid disclosing other candidates' applications).
- **Visible components:** application ID badge, job title, company name (or fallback), location, color-coded status pill, a 2×2 info grid (Applied on / Last updated / Applied-as name+email / Job type+experience), optional cover-letter block, conditional "View job posting" button (only if the job is still active).
- **Data fields:** pk, job.title, employer.company_name, job.location, status, applied_at, updated_at, applicant_name, applicant_email, job type/experience, cover_letter.
- **Actions:** Back to dashboard; conditional View job posting → W042. **No edit/withdraw action exists.**
- **States:** 6 status states (applied/reviewing/shortlisted/interview/offered/rejected), no-cover-letter, job-closed (button hidden).
- **Backend data source:** `EXISTING_HTML_ONLY` — no JSON endpoint for a single application or its status.
- **Flutter:** none.

**W042 — Job Detail + Apply**
- **Purpose:** Public job posting + embedded application form — one screen serving two audiences differently: the apply form is hidden entirely for a logged-in employer viewing their own posting (session-driven), shown for everyone else (anonymous or student).
- **Visible components:** job header card (title, company, type/experience/location/salary/openings badges), description, requirements, skills badges, optional deadline, full "Apply for this Position" form (non-employer viewers only).
- **Data fields:** title, company_name, job type/experience display, location, salary_display (personalized: interpolated from the user's most recent resume text if authenticated), openings, description, requirements, skills list, deadline.
- **Apply form fields:** applicant_name, applicant_email, applicant_phone, resume upload (.pdf/.doc/.docx), cover_letter, applicant_skills, years_experience, current_company, current_salary, expected_salary.
- **Actions:** Submit application (POST to same URL; success sends a thank-you email + employer notification; duplicate email+job → "You have already applied for this job.").
- **States:** duplicate-application error, generic save-failure, per-field validation errors, apply form hidden for employer viewers, deadline shown only if set, 404 if job isn't active.
- **Backend data source:** `EXISTING_HTML_ONLY`.
- **Flutter:** none.

---

### Module: Employer Portal (`employer_portal` + `jobs_app` employer views)

Every screen here (except the landing page and Job Detail's employer-viewer branch) is `EMPLOYER`-only, gated by `EmployerProfile` ownership and/or a `request.session['portal']=='employer'` check. All are `EXISTING_HTML_ONLY` — a full grep found zero `JsonResponse` calls anywhere in this scope.

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W043 | Employer Portal Landing | `/employer/` | `templates/jobs/employer_home.html` | *(none)* | NOT_STARTED |
| W044 | Employer Dashboard | `/employer/employer/dashboard/` | `templates/employer/dashboard.html` | *(none)* | NOT_STARTED |
| W045 | Post New Job / Edit Job | `/employer/employer/jobs/new/`, `/employer/employer/jobs/<pk>/edit/` | `templates/employer/job_form.html` | *(none)* | NOT_STARTED |
| W046 | Applicants List (per job) | `/employer/employer/jobs/<pk>/applications/` | `templates/employer/applications.html` | *(none)* | NOT_STARTED |
| W047 | Application Detail / Review | `/employer/employer/applications/<pk>/` | `templates/employer/application_detail.html` | *(none)* | NOT_STARTED |
| W048 | All Applications (employer-wide) | `/employer/employer/applications/` | `templates/employer/all_applications.html` | *(none)* | NOT_STARTED |
| W049 | Employer Profile Create / Edit | `/employer/employer/profile/create\|edit/` | `templates/employer/profile_form.html` | *(none)* | NOT_STARTED |
| W050 | Candidate / Resume Search | `/employer/employer/candidates/search/` | `templates/jobs/candidate_search.html` | *(none)* | NOT_STARTED |
| W051 | "Job Openings" (ambiguous audience — see note) | `/employer/employer/job-openings/` | `templates/employer/job_openings.html` | *(none)* | NOT_STARTED |

**W043 — Employer Portal Landing**
- **Purpose:** Public marketing/landing page for the recruiter side of the platform (despite the code comment calling it "job-seeker facing," the actual rendered copy/CTAs are 100% employer-oriented).
- **Visible components:** two hero image cards, auth-state-dependent hero buttons, "How It Works" 3-step section.
- **Data fields:** `total_jobs`/`total_companies` are computed by the view but never actually rendered anywhere in the template — dead context data.
- **Actions:** anonymous — Join as Recruiter, Employer Login; authenticated — Manage Dashboard, Find Candidates.
- **States:** authenticated vs anonymous CTA set.
- **Flutter:** none.

**W044 — Employer Dashboard**
- **Purpose:** Employer home after login — stats + their job postings table. Requires a completed profile (GST+PAN) or redirects to W049.
- **Visible components:** welcome header, "Post New Job Listing" CTA, 3 stat cards (Total Jobs, Active Listings, Applications), "My Job Postings" table.
- **Data fields:** total_jobs_count, active_jobs, total_apps; per row: title, job type, status badge, applications count (clickable → W046), created_at.
- **Notable behavior (document, don't fix):** if the employer owns zero jobs, the table silently falls back to showing **every job on the platform**, not just their own.
- **Actions:** Post New Job → W045; per-row Edit → W045; Delete (POST + JS confirm); click app count → W046.
- **States:** empty jobs table, profile-incomplete redirect, all-platform-jobs fallback.
- **Flutter:** none.

**W045 — Post New Job / Edit Job**
- **Purpose:** Create/edit form for a job posting (same template for both).
- **Visible components:** sectioned form — Job Overview & Type, Compensation & Vacancies, Description & Technical Skills, Timeline & Publish, Work Environment (radio pills), Interview Mode (radio pills + "specify other"), Notice Period (radio pills + "specify other"), Gender Preference (radio pills); a "You have no active jobs" modal notice on create-mode only.
- **Data fields:** title, job_type, experience, location, salary_min/max, openings, description, requirements, skills_required, deadline, status, work_environment, interview_mode(+other), notice_period(+other), gender_preference.
- **Notable behavior:** editing a seeded job silently transfers its ownership to the editing employer.
- **Actions:** Save Job Posting; Cancel → W044.
- **States:** create vs edit copy, first-time no-active-jobs notice, per-field validation, conditional "other" text inputs.
- **Flutter:** none.

**W046 — Applicants List (per job)**
- **Purpose:** All applications to one specific job, with a status filter.
- **Visible components:** header (job title + applicant count), status filter pill row (All + 6 statuses), candidate list cards (name+avatar-initial, email, years_experience, status badge).
- **Actions:** filter by status; "Review Submission" → W047.
- **States:** empty ("No applications found for this status."), per-status filter.
- **Flutter:** none.

**W047 — Application Detail / Review**
- **Purpose:** Full candidate detail + status-update/notes form for one application.
- **Visible components:** candidate header (photo if linked account, else initials); "Candidate Background" card (experience, current company, current/expected salary, skills, resume link, optional AI mock-interview video player with score, cover letter); "Recruitment Decision" status-update form.
- **Data fields:** applicant_name/email/phone, job.title, years_experience, current_company, current/expected salary, resume, cover_letter, applied_at, status, employer_notes.
- **Bug found (documented, not fixed):** the template references `app.parsed_skills`, a field that does not exist on the `JobApplication` model (the real field is `applicant_skills`) — Django silently renders this as empty, so candidate skills entered at apply time never actually display on this screen.
- **Actions:** Update Status (select from 6, + notes textarea) — triggers an automatic, deduped candidate email notification.
- **States:** no-resume (button hidden), no-interview-session (video hidden), no-cover-letter (hidden), no-photo (initials fallback), status-changed vs status-unchanged success message.
- **Flutter:** none.

**W048 — All Applications (employer-wide)**
- **Purpose:** Application pipeline across all of an employer's jobs, with search + status + source filters.
- **Visible components:** header, filter bar (text search, status dropdown, source dropdown), application card list (source-colored left border: Direct Apply vs Resume Parsed).
- **Same `parsed_skills` display bug as W047** (never renders).
- **Actions:** search (by name/email), filter by status/source, "Review Submission" → W047.
- **States:** empty ("No applications found").
- **Flutter:** none.

**W049 — Employer Profile Create / Edit (Company Settings)**
- **Purpose:** Company profile form, required (GST+PAN) before dashboard access.
- **Visible components:** view-then-edit toggle UI (fields start disabled until "Edit Profile"); sectioned form — Company Identity, Web Presence & Branding (logo upload), About the Organization, Headquarters Location, Tax & Legal Registration (GST/PAN with live regex validation + masked-PAN reveal), HR & Contact Details.
- **Data fields:** company_name, company_website, company_logo, industry, company_size, location, description, company_address, company_gst, company_pan_tin (masked on edit, real value never re-sent to the browser), hr_contact, hr_mail.
- **Actions:** Edit Profile (toggle), Save Company Profile, Cancel.
- **States:** create vs edit mode, live GST/PAN validation feedback, server-side validation errors.
- **Flutter:** none.

**W050 — Candidate / Resume Search (Employer)**
- **Purpose:** Employer-side search over registered students + parsed resumes by skills/location/experience, with a fallback scan of on-disk resume PDFs not yet linked to a registered account.
- **Visible components:** hero header, search form (skills/keywords, location, experience dropdown), result-count alert, candidate result cards, a sort-by dropdown that is **UI-only/non-functional** ("Experience"/"Location" links are `href="#"`), a sign-up CTA banner for non-employer visitors.
- **Data fields per card:** name, skill_count match badge, location, experience, industry, education, matched skills (highlighted), email/phone (mailto/tel links), resume_url or "No resume uploaded" badge.
- **Actions:** Search, View Resume (new tab), email/phone links, "Clear Filters" (empty state).
- **States:** no-query-yet, zero-results, N-results. Export via **`download_candidates_csv`** — a pure CSV `HttpResponse`, not a screen.
- **Flutter:** none.

**W051 — "Job Openings" (ambiguous audience, flagged for product clarification)**
- **Purpose:** Conflicting signals — the view's docstring and generic `@login_required` (not employer-scoped) suggest a student-facing job browse, but the template extends the employer sidebar shell and uses employer-oriented copy/filter labels. Critically, the view fully implements a `JobApplicationForm` POST handler, but the template contains **no `<form>` element anywhere** — that entire apply branch is dead/unreachable from the UI. Each job card's only action links to W042.
- **Visible components:** job card grid (title, company, job-type badge, location, experience, skills[first 2], salary, is_seeded pill), filter tabs "All Jobs / My Postings / Career Buddy Listed" (the "My Postings" tab is JS-driven off `is_seeded` only, not actual per-employer ownership — so the label doesn't match its own behavior for any audience).
- **Recommendation:** track as low-priority / needs product clarification before mapping to a mobile screen; do not build a mobile equivalent against its half-wired apply flow.
- **Flutter:** none.

---

### Module: Group Discussion Workshop (`GD_app`)

Access note: every entry view checks workshop-plan access; failure redirects to the Activities page's upgrade paywall (out of this module's scope).

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W052 | GD Home / Topic Entry | `/gd/` | `templates/GD_app/home.html` | *(none)* | NOT_STARTED |
| W053 | GD Room (live discussion) | `/gd/room/<int:session_id>/` | `templates/GD_app/room.html` | *(none)* | NOT_STARTED |
| W054 | GD Performance Report | `/gd/report/<int:session_id>/` | `templates/GD_app/report.html` | *(none)* | NOT_STARTED |

**W052 — GD Home / Topic Entry**
- **Visible components:** hero banner; topic-entry form (free text, 499-char limit with live counter); 5 suggested-topic chips; "Recent Sessions" list (last 5, each with Open or Report link); right rail with 3 static AI-partner cards (Alex/Maya/Rishi).
- **Data fields:** session topic, created_at, is_active, performance_report.overall_score.
- **Actions:** Start GD (POST, creates session, redirects to W053); click a suggested topic; Open (resume); Report (view past).
- **States:** empty/over-limit topic input, no-recent-sessions vs list, active vs ended-with-report.
- **Backend data source:** `EXISTING_HTML_ONLY` for the page; a JSON sibling `api_sessions` exists for a "history" use case.
- **Flutter:** none.

**W053 — GD Room (live discussion)**
- **Purpose:** The real-time group discussion room — establishes a WebSocket and renders the running transcript.
- **Visible components:** left sidebar — topic box + 4 agent rows (Alex/Maya/Rishi/You) each with an animated sound-wave + status dot; header — live pulsing dot, title, timer element, language dropdown, End Session; center — scrollable chat feed (empty-state illustration when no messages); footer — Start/Speak Now/Done Speaking/Resume/End controls (JS-toggled visibility); a full-screen "Analyzing your performance…" overlay while the report generates.
- **Actions (client→server over WS):** start, user_speaking, user_message, end. **(server→client):** status, message, typing, report.
- **States:** not-started, in-progress (agents cycling ~2.5s apart), user-speaking (agents paused), analyzing, ended (footer swaps to "View Performance Report").
- **Backend data source:** `WEBSOCKET` — no JSON polling alternative exists; this is expected, not a gap.
- **Flutter:** none.

**W054 — GD Performance Report**
- **Visible components:** animated SVG score ring (/100); 4 dimension cards with score bars (Fluency/Grammar/Relevance/Confidence, each /25) + feedback; "Key Strengths"/"Areas for Growth" lists; "Coach's Final Verdict" card; "No analysis yet" empty state.
- **Data fields:** overall_score, per-dimension score+feedback, strengths[], improvements[], summary — persisted `GDSession.performance_report` JSON field.
- **Actions:** Start New Discussion; Back to Activities; (if no report) Go to Room.
- **States:** report present vs absent.
- **Backend data source:** `EXISTING_HTML_ONLY`.
- **Flutter:** none.

---

### Module: JAM — Just A Minute Workshop (`jam_app`)

Unlike GD_app, jam_app has no Channels/consumers — the live session screen is ordinary HTTP + browser `MediaRecorder`/`SpeechRecognition` + an async save-audio POST.

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W055 | JAM Dashboard | `/jam/dashboard/` | `templates/jam/dashboard.html` | *(none)* | NOT_STARTED |
| W056 | JAM Practice Topics | `/jam/topics/` | `templates/jam/topics.html` | *(none)* | NOT_STARTED |
| W057 | JAM Session (live recording) | `/jam/session/start/...` | `templates/jam/session.html` | *(none)* | NOT_STARTED |
| W058 | JAM Session Result | `/jam/session/<int:session_id>/` | `templates/jam/session_detail.html` | *(none)* | NOT_STARTED |
| W059 | JAM Assessment Diagnostic Report | `/jam/assessment/result/<int:assessment_id>/` | `templates/jam/assessment_result.html` | *(none)* | NOT_STARTED |
| W060 | JAM Practice History | `/jam/history/` | `templates/jam/history.html` | *(none)* | NOT_STARTED |
| W061 | JAM Profile | `/jam/profile/` | `templates/jam/profile.html` | *(none)* | NOT_STARTED |

**W055 — JAM Dashboard**
- **Visible components:** hero CTAs (Start Session/Browse Topics); 3 stat tiles (Total Sessions, Recent Score /25, Fluency Rank ★ avg); Recent Sessions grid (empty state); "Assessment Journey" card (3 pill badges Simple/Intermediate/Hard, toggled done/not-done, gated Start Assessment button, locked-explanation note); "Danger Zone" Reset All Progress (POST + confirm).
- **Actions:** Start Session → W057; Browse Topics → W056; delete a session; Start Assessment (only once all 3 difficulties done); Reset All Progress.
- **States:** assessment locked vs unlocked; has/has-not recent sessions.
- **Flutter:** none.

**W056 — JAM Practice Topics**
- **Visible components:** 3 anchor sections (Easy/Medium/Hard), card grid per topic (title, description, "Practice Session" button).
- **Actions:** Practice Session → creates a session, goes straight to W057.
- **Flutter:** none.

**W057 — JAM Session (live 60-second speaking session)**
- **Purpose:** The recording screen — for practice, or one stage of a 3-stage assessment (same template both ways).
- **Visible components:** instructions modal ("I'm Ready — Start Session"); header (topic, difficulty badge, assessment 3-dot stage indicator if applicable); circular SVG 60s countdown ring + digital display; recording indicator (pulsing dot "Recording Live"); Start/Stop buttons; post-stop audio playback + live word-count; "Recording too short" (<2s) retry panel; submit panel whose CTA differs by context (practice: "Get AI Feedback"; assessment stage 1/2: "Next Stage"; stage 3: "Generate Diagnostic Report").
- **Actions:** Start (getUserMedia + MediaRecorder + SpeechRecognition), Stop, POST save-audio (JSON), navigate onward.
- **States:** instructions-shown → mic-permission-request (denial shows inline "Mic Access Denied") → recording (ring color amber>30s/red>45s) → stopped-too-short → stopped-valid. Tab-switch auto-stops recording with an alert.
- **Backend data source:** `EXISTING_HTML_ONLY` page + a JSON POST action (`save_audio`) — not a WebSocket, unlike GD_app.
- **Flutter:** none.

**W058 — JAM Session Result**
- **Visible components:** topic/difficulty/duration pills; 5 score bars (Confidence/Fluency/Language/Pronunciation/Time Management, each /5); overall score ring (/25) with a quote; "Detailed Feedback" prose + raw transcript panel; "Growth Roadmap" sidebar card; Next Session button; "Listen to Recording" link (if audio exists).
- **Data fields:** 5 sub-scores, overall_score_display, ai_feedback, transcript, improvement_tips, duration_display.
- **Backend data source:** `EXISTING_HTML_ONLY` — scores/feedback computed server-side (Sarvam AI with a rule-based fallback), then simply rendered.
- **Flutter:** none.

**W059 — JAM Assessment Diagnostic Report**
- **Visible components:** averaged 5-category score bars (/15), total score ring (/75), per-stage summary strip (Easy/Medium/Hard), "Diagnostic Feedback" prose + collapsible per-stage transcript accordion, per-stage color-coded Growth Roadmap tips, Start Practice / View History buttons.
- **Data fields:** easy/medium/hard session results, final_report (avg duration/fluency, assigned level Beginner/Intermediate/Advanced).
- **Backend data source:** `EXISTING_HTML_ONLY`.
- **Flutter:** none.

**W060 — JAM Practice History**
- **Visible components:** tabbed list (Regular Sessions / Assessments), each row → delete (POST) or open detail.
- **Flutter:** none.

**W061 — JAM Profile**
- **Visible components:** editable first/last name, email, bio; stats sidebar (total sessions, minutes, and a decorative "practice streak" bar row with no real data binding — confirmed cosmetic-only, not a real progress indicator).
- **Flutter:** none.

**Dead/unreachable found (documented, not fixed):** `jam_app.views.signup_view` and its template `jam/signup.html` exist in code but are not wired into `jam_app/urls.py` — unreachable.

---

### Module: Skill Up (`skillup_hub` + `skillup_assessment`)

**Confirmed structural finding:** actual lesson content and mock-test-taking live in a large legacy static HTML/JS bundle (`static/001 Career Buddy/`), wrapped by one Django view purely so the Riya widget can be injected onto it. `skillup_assessment` is a **separate, certificate-issuance-only** system — quiz grading itself happens in `activities/views.py` JSON endpoints, which write `skillup_assessment.QuizAttempt` rows.

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W062 | Skill Up Hub (SPA host) | `/skill-up/` | `templates/skillup/skillup_hub.html` | *(none)* | NOT_STARTED |
| W063 | Certifications Hub | `/skill-up/assessment/` | `skillup_assessment/templates/.../hub.html` | *(none)* | NOT_STARTED |
| W064 | Subject Certification Detail | `/skill-up/assessment/<module>/` | `.../result.html` | *(none)* | NOT_STARTED |
| W065 | Edit Certificate Name | `/skill-up/assessment/<module>/certificate/edit/` | `.../edit_name.html` | *(none)* | NOT_STARTED |

**W062 — Skill Up Hub (SPA host)**
- **Purpose:** A Django wrapper that injects an entire legacy static HTML bundle (lessons, category browsing, mock tests — hash-routed via `location.hash`, never leaving this one URL) so the Riya widget can be included on it.
- **Scope note:** the SPA's internal structure (Sections → Subsections → Lessons, plus standalone Mock Test pages) is large and not Django-templated; its internal screens were **not individually enumerated** — flagged as a likely separate, larger follow-up audit rather than covered at this depth. Confirmed content directories: TechCenter, AptitudeReasoning, Vocabulary, GrammerActivities, "001 CEFR", HP.
- **Backend data source:** mock-test grading (when reached from inside the SPA) posts to the existing `activities` JSON quiz endpoints (`quiz_submit`, `oop_quiz_submit`, `amcat_submit`, `cocubes_submit`).
- **Flutter:** none.

**W063 — Certifications Hub**
- **Purpose:** Lists ~27 certification subjects grouped by category, each in one of 4 states.
- **Visible components:** header with 3 counters (total/attempted/earned); per-category counts; card grid, each card in one of: **certified** (score, "CERTIFICATE EARNED" pill, View/Download), **eligible** (score, "ELIGIBLE" pill, Generate Certificate), **locked** (score below 70% threshold, "LOCKED" pill, View Details), **not_attempted** ("NOT ATTEMPTED" pill, View Details).
- **Data fields:** per subject — label, category, state, best-ever score/total, pass_threshold (70%).
- **Backend data source:** `EXISTING_HTML_ONLY`; a JSON twin `api_certifications_status` exists for an in-page widget embedded inside the SPA.
- **Flutter:** none.

**W064 — Subject Certification Detail**
- **Purpose:** Per-subject certificate flow, 4 mutually exclusive states in one template.
- **States:** not_completed (link back to Skill Up SPA); locked (score vs required threshold + Retake link); eligible (congrats card + certificate-name form → POST, server re-derives eligibility, never trusts the client); certified (issued-to name, score, certificate number, issued date, View/Download + Edit Name & Regenerate).
- **Backend data source:** `EXISTING_HTML_ONLY`; JSON twins exist for the SPA-embedded widget (`api_certificate_generate`/`api_certificate_regenerate`).
- **Flutter:** none.

**W065 — Edit Certificate Name**
- **Visible components:** single-field form (prefilled certificate name), Regenerate/Cancel, inline validation error.
- **Notable behavior:** does not re-check live quiz eligibility on regeneration — ownership + existing-certificate check only.
- **Flutter:** none.

**Not a screen:** `certificate_download` serves the generated PDF as a binary `FileResponse` — not HTML.

---

### Module: Grammar (`subject_views.py`)

| ID | Web Screen | Web URL | Template | Flutter Screen | Status |
|---|---|---|---|---|---|
| W066 | Grammar Subject Library | `/subject/` | `templates/subject/home.html` | *(none)* | NOT_STARTED |
| W067 | Grammar Topic Lesson Page | `/subject/<slug>.html` | `templates/subject/detail.html` | *(none)* | NOT_STARTED |

**W066 — Grammar Subject Library**
- **Visible components:** header; a language dropdown (client-side Google-Translate-driven, a separate implementation from the shared dropdown used elsewhere — noted inconsistency); responsive topic card grid (9 topics: Nouns, Pronouns, Verbs, Adjectives, Adverbs, Conjunctions, Tenses, Sentence Structure, Types of Sentences); a "How it works" 3-item strip.
- **Data fields:** per topic — title, description, badge, emoji, accent_color, href.
- **Actions:** click a card → W067.
- **Flutter:** none.

**W067 — Grammar Topic Lesson Page**
- **Purpose:** Real lesson-content page for one grammar topic — slides, video, audio recap, rules/examples/exercises.
- **Visible components:** header (title + definition); "Interactive Media Section" with 3 expandable media cards — Visual Guide (real slide-deck images if present, else generated SVG illustrations), Video Lesson (locally hosted range-seekable `.mp4`, else a YouTube-embed fallback), Audio Recap (Sarvam neural TTS with a `speechSynthesis` browser fallback); authored lesson-slide text beside each illustration (selectable/accessible, not locked in an image); a "why this matters" editorial box; a summary table; repeating per-topic sections (data table, bullet list, rule boxes, "Examples in Context," static Practice-Exercises with revealed answers — not interactively graded); the same ad-hoc language dropdown as W066.
- **Data fields:** title, subtitle, definition, role_items, summary_rows, slides, slide_cards, video URLs, audio_text, sections[] — a large hand-authored content dict per topic (~9 topics).
- **Actions:** expand/collapse each media card, slideshow prev/next, audio play/pause/restart, language switch.
- **States:** media-collapsed vs expanded per card; audio idle/loading/playing/paused; video local-file vs YouTube-fallback (depends on whether the local file exists on disk).
- **Backend data source:** `EXISTING_HTML_ONLY` for lesson content; TTS calls a JSON endpoint (`riya_bot`, out of scope) but content itself is server-rendered.
- **Flutter:** none.

---

### Riya Chatbot Widget (reusable UI component, not a standalone screen)

Included globally via `base.html` (and explicitly re-included on the Skill Up hub, which bypasses `base.html`) — present on effectively every screen across the site, not tracked with a W-number.

- **Structure:** floating launcher button with an auto-updating greeting bubble; opens a chat panel (header, 5-language selector persisted to `localStorage`, mic button for voice input, speaker button with 3 visual states [idle/speaking/paused], close button); scrollable response feed alternating user/assistant bubbles; a text composer as an alternative to voice; a TTS-playback audio-bars animation.
- **Context carried:** current page name/path, employer-vs-student role, username — re-synced on every hash change while inside the Skill Up SPA so it tracks internal navigation.
- **Backend data source:** backed by a JSON chat-streaming API (`riya_bot`), not re-derived in this audit per the task's scope boundary — documented only as the component's backing contract.
- **Recommendation for the tracker:** convert as one reusable overlay widget/component embedded across mobile screens, not as an individual screen entry.

---

## Module Coverage

67 real, user-facing web screens were inventoried across 13 modules (the Skill Up legacy SPA's internal lesson/mock-test pages are not individually counted — see W062). "Missing" = `NOT_STARTED`; `NOT_APPLICABLE` rows (dead/unreachable code, e.g. legacy employer auth duplicates, the dead `ordering` exercise type) are excluded from both Partial and Missing and noted separately so the table isn't inflated by screens nobody needs to convert.

| Module | Web Screens | Complete | Partial | Missing | Not Applicable (dead code) |
|---|---|---|---|---|---|
| Authentication | 1 | 0 | 1 | 0 | 0 |
| Dashboard | 1 | 0 | 1 | 0 | 0 |
| Activities | 21 | 0 | 4 | 16 | 1 |
| Registration, Profile & Password Recovery | 6 | 0 | 0 | 6 | 0 |
| Employer Authentication | 4 | 0 | 0 | 2 | 2 |
| Pro / Membership & Payments | 2 | 0 | 0 | 2 | 0 |
| Resume Builder & AI Interview | 5 | 0 | 0 | 5 | 0 |
| Jobs | 2 | 0 | 0 | 2 | 0 |
| Employer Portal | 9 | 0 | 0 | 9 | 0 |
| Group Discussion Workshop | 3 | 0 | 0 | 3 | 0 |
| JAM Workshop | 7 | 0 | 0 | 7 | 0 |
| Skill Up | 4 | 0 | 0 | 4 | 0 |
| Grammar | 2 | 0 | 0 | 2 | 0 |
| **Total** | **67** | **0** | **6** | **58** | **3** |

No screen anywhere is `COMPLETE`. The 6 `PARTIAL` screens (Login, Dashboard, Activity List, Activity Detail, Sub-Activity Detail, MCQ Exercise) are all real, working, backed by live data — but each has specific documented gaps (see their write-ups above), not just polish items.

---

## Flutter Screens Requiring Rework

**Finding: none.** All 6 non-splash Flutter screens (`LoginScreen`, `DashboardScreen`, `ActivityListScreen`, `ActivityDetailScreen`, `SubActivityDetailScreen`, `McqExerciseScreen`) map 1:1 to a real web screen with **reduced**, not invented, scope — every gap documented against them above is a *missing* web element (a no-op link, an unconverted exercise type), never an element that doesn't exist on the web. No Flutter screen introduces functionality, navigation, or data the web app doesn't already have.

`SplashScreen` has no web equivalent, but this is expected, standard native-app bootstrap chrome (a launch screen while the session is restored), not invented product functionality — it isn't tracked as a rework item.

---

## Missing Backend Support

Classification legend: `EXISTING_API` (real JSON endpoint already exists), `EXISTING_HTML_ONLY` (only a server-rendered HTML view exists), `WEBSOCKET`, `FORM_POST` (plain form-encoded POST, no JSON needed), `MISSING_API` (no backend support of any kind exists), `UNKNOWN` (not verified to this level of depth in this pass). No APIs were created to produce this table — it is a classification of what already exists.

| Screen(s) | Classification | Note |
|---|---|---|
| W001 Student Login | `FORM_POST` | Verified working end-to-end against the live server in a prior phase. |
| W002 Student Dashboard | `EXISTING_API` | `GET /dashboard/api/`, implemented and tested. |
| W003 Activity List | `EXISTING_API` | `GET /activities/api/`. |
| W004 Activity Detail | `EXISTING_API` | `GET /activities/api/<id>/`. |
| W005 Sub-Activity Detail | `EXISTING_API` | `GET /activities/api/sub/<id>/`. |
| W006 Exercise — MCQ | `EXISTING_API` | New mobile-only, server-authoritative pair (`GET`/`POST .../submit/`); the web's own `submit_exercise` is untouched and remains client-graded. |
| W007-W009, W011-W012 (fill_blank, matching, bingo, writing, timer) | `EXISTING_API` (client-trusted) | Share the web's existing `submit_exercise` endpoint, which trusts the client-submitted score for these types — a known, separately-documented security gap (`SECURITY_RECOMMENDATION_activities.md`), not something to silently replicate without a decision. |
| W010 Ordering | `NOT_APPLICABLE` | Dead code on the web itself. |
| W013 Workshop Dashboard | `EXISTING_HTML_ONLY` | Simple static card-grid template, trivial to mirror without a new API. |
| W014-W017 AI Modules (Speaking/Writing/Listening/Reading) | `EXISTING_API` | Use the same AI-graded submission path as other exercise types; Listening additionally has real anti-replay/attempt-token protection server-side. Exact multipart/audio-upload contract not re-verified in this pass. |
| W018-W019 Roleplay | `UNKNOWN` | Persists to `ScoreRecord`, not `UserExerciseResult`; JSON vs HTML backing not verified to the same depth as other modules in this pass. |
| W020-W023 Mock Tests (OOP/Subject/AMCAT/CoCubes) | `EXISTING_API` | Real JSON in/out already, server-side graded, answers withheld until grading — architecturally the closest to mobile-ready of anything in scope. Reachability from primary nav is itself uncertain (see W020-W023 write-up). |
| W024 Student Registration | `EXISTING_HTML_ONLY` (form) + `EXISTING_API` (OTP actions) | The two email-OTP actions are already JSON and reusable as-is; the account-creation submit itself is not. |
| W025 Student Profile | `EXISTING_HTML_ONLY` | No `JsonResponse` sibling exists anywhere in `users/views.py`. |
| W026-W029 Password Reset (4 screens) | `EXISTING_HTML_ONLY` | Django's built-in auth views, not JSON. |
| W030 Employer Login | `EXISTING_HTML_ONLY` | Zero `JsonResponse` anywhere in `accounts_app/views.py`. |
| W031 Employer Registration | `EXISTING_HTML_ONLY` (form) + `EXISTING_API` (OTP actions, shared with W024) | |
| W032-W033 legacy employer auth | `NOT_APPLICABLE` | Confirmed dead/orphaned code. |
| W034 Pro / Membership Plans | `EXISTING_HTML_ONLY` (state) + `EXISTING_API` (payment actions) | `create_razorpay_order`/`verify_razorpay_payment` are real JSON, but they're write/transaction actions, not a read API for current-plan state. |
| W035 GST Tax Invoice | `EXISTING_HTML_ONLY` | Single-record page, no JSON sibling. |
| W036 Resume Builder Home | `EXISTING_HTML_ONLY` | |
| W037 Resume Match / ATS Result | `EXISTING_HTML_ONLY` | |
| W038 Resume History | `EXISTING_HTML_ONLY` | No JSON listing endpoint. |
| W039 AI Mock Interview | `EXISTING_HTML_ONLY` (shell) + `EXISTING_API` (every live interaction) | Camera/mic/anti-malpractice monitoring itself would need native equivalents regardless of the API's existence. |
| W040 Interview Analytics | `EXISTING_HTML_ONLY` | Chart data is embedded inline, not a fetchable JSON endpoint. |
| W041 Student Application Detail | `EXISTING_HTML_ONLY` | No JSON endpoint for a single application. |
| W042 Job Detail + Apply | `EXISTING_HTML_ONLY` | |
| W043-W050 Employer Portal screens (8) | `EXISTING_HTML_ONLY` | Full grep of `jobs_app/` + `employer_portal/` found exactly one unused `JsonResponse` import — zero real JSON usage anywhere in this scope. |
| W051 "Job Openings" | `EXISTING_HTML_ONLY` | Also has an ambiguous/half-wired audience — see its write-up before building against it. |
| W052 GD Home | `EXISTING_HTML_ONLY` (page) + `EXISTING_API` (`api_sessions`, history) | |
| W053 GD Room | `WEBSOCKET` | No JSON polling alternative exists — expected, not a gap. |
| W054 GD Performance Report | `EXISTING_HTML_ONLY` | |
| W055-W056, W058-W061 JAM (Dashboard/Topics/Result/Assessment Report/History/Profile) | `EXISTING_HTML_ONLY` | |
| W057 JAM Session (live recording) | `EXISTING_HTML_ONLY` (page) + `FORM_POST`-style JSON action (`save_audio`) | Not a WebSocket, unlike GD_app. |
| W062 Skill Up Hub (SPA host) | `EXISTING_HTML_ONLY` (shell) + `EXISTING_API` (quiz grading via `activities` endpoints) | Internal SPA screens not individually classified — out of depth for this pass. |
| W063 Certifications Hub | `EXISTING_HTML_ONLY` (page) + `EXISTING_API` (`api_certifications_status`, SPA-widget twin) | |
| W064 Subject Certification Detail | `EXISTING_HTML_ONLY` (page) + `EXISTING_API` (`api_certificate_generate`/`regenerate`, SPA-widget twins) | |
| W065 Edit Certificate Name | `EXISTING_HTML_ONLY` | |
| W066 Grammar Subject Library | `EXISTING_HTML_ONLY` | |
| W067 Grammar Topic Lesson Page | `EXISTING_HTML_ONLY` (content) + `EXISTING_API` (TTS only, `riya_bot`, out of scope) | |
| Riya Chatbot widget | `EXISTING_API` (streaming) | Backing contract not re-derived in this audit per the task's scope boundary. |

**Summary: no screen in this entire audit requires a genuinely `MISSING_API`** — every screen is backed by either a working JSON endpoint, a working HTML/form flow, or (for the two live-workshop screens) a working WebSocket/HTTP-action pair. The real backend work for mobile conversion is **adding JSON siblings to `EXISTING_HTML_ONLY` screens** (the large majority — 43 of 67), not building new business logic from scratch.

---

## 20-Day Priority Plan

Tiers are by scope/dependency for a coherent, usable mobile app — not by which screens happen to look easiest. Effort is a rough order-of-magnitude estimate in engineer-hours, explicitly approximate (marked `~`) since no UI has been designed and no backend JSON-sibling work has been scoped in detail; do not treat these as committed estimates.

### Tier 1 — Must Convert (core student flow: sign up → learn → practice → get hired)

| Screen | Complexity | Dependencies | API ready? | UI exists in Flutter? | Est. hours (~) |
|---|---|---|---|---|---|
| W024 Student Registration | HIGH | OTP actions (ready), selfie/document upload, dynamic repeaters | Partial (OTP only) | No | ~40 |
| W025 Student Profile (view+edit) | MEDIUM | Same field set as registration | No | No | ~24 |
| W026-W029 Password Reset (4 screens) | LOW | Django built-in views, standard flow | No (HTML only) | No (link is a no-op today) | ~16 total |
| W007-W009 remaining default exercises (fill_blank, matching, bingo) | MEDIUM each | Mirrors W006's architecture | Yes (client-trusted) | No | ~16 each (~48 total) |
| W011-W012 writing, timer exercises | MEDIUM-HIGH | Timer/word-count logic | Yes (client-trusted) | No | ~20 each (~40 total) |
| W013 Workshop Dashboard | LOW | None | No (trivial to add) | No | ~6 |
| W041 Student Application Detail | LOW | None | No | No | ~8 |
| W042 Job Detail + Apply | MEDIUM | File upload for resume | No | No | ~16 |
| **Tier 1 subtotal** | | | | | **~198 hours (~25 eng-days)** |

### Tier 2 — Important (career tools, the app's stated differentiator)

| Screen | Complexity | Dependencies | API ready? | UI exists? | Est. hours (~) |
|---|---|---|---|---|---|
| W036 Resume Builder Home | MEDIUM | File upload | No | No | ~14 |
| W037 Resume Match / ATS Result | MEDIUM | Depends on W036 | No | No | ~16 |
| W038 Resume History | LOW | None | No | No | ~8 |
| W034 Pro / Membership Plans | HIGH | Razorpay mobile SDK integration (not just a webview) | Partial (payment actions ready) | No | ~32 |
| W035 GST Tax Invoice | LOW | Depends on W034 | No | No | ~8 |
| W014-W017 AI Modules | VERY HIGH | Native audio recording, multipart upload, live playback | Yes (uncertain contract) | No | ~30 each (~120 total) |
| **Tier 2 subtotal** | | | | | **~198 hours (~25 eng-days)** |

### Tier 3 — Secondary (workshops, employer portal, ancillary content)

| Screen(s) | Complexity | Notes | Est. hours (~) |
|---|---|---|---|
| W039 AI Mock Interview | VERY HIGH | Native camera monitoring, anti-malpractice detection — the single largest undertaking in the whole app | ~80+ |
| W040 Interview Analytics | MEDIUM | Depends on W039 | ~16 |
| W052-W054 GD Workshop (3 screens) | VERY HIGH | Requires a Flutter WebSocket client + real-time agent-turn UI | ~60 |
| W055-W061 JAM Workshop (7 screens) | HIGH | Native audio recording + speech recognition, no socket | ~90 |
| W043-W051 Employer Portal (9 screens) | HIGH | Separate persona/flow; only relevant if employer mobile use is in scope at all | ~120 |
| W062-W065 Skill Up (4 screens, hub SPA excluded) | HIGH | Certificate flow straightforward; the hub SPA itself is a much larger, unscoped undertaking | ~40 |
| W066-W067 Grammar (2 screens) | MEDIUM | Rich media (video/audio/slides) | ~24 |
| W018-W023 Roleplay + Mock Tests | HIGH | Least-understood backend contracts in this audit | ~60 |
| Riya Chatbot widget | MEDIUM | One reusable overlay component, not a screen | ~24 |
| **Tier 3 subtotal** | | | | **~514 hours (~64 eng-days)** |

---

## 20-Day Feasibility

**A. Total web screens found:** 67 (across 13 modules), plus one reusable chatbot widget documented separately.

**B. How many have a Flutter equivalent today:** 6 of 67 (9%) — Login, Dashboard, Activity List, Activity Detail, Sub-Activity Detail, MCQ Exercise.

**C. How many are close to complete:** 6 — the same 6, all `PARTIAL`, all with a small, enumerated, bounded gap list (a few no-op links, one missing retry action, one missing qualitative-score tier). None require architectural rework to finish — only finishing the already-started work.

**D. How many are partial vs. completely missing:** 6 `PARTIAL`, 58 `NOT_STARTED` (completely missing, zero Flutter code), 3 `NOT_APPLICABLE` (dead code on the web itself, not worth converting).

**E. How many need new backend APIs to be built:** Zero require APIs that don't already exist in some form (see Missing Backend Support) — but **43 of 67 screens (64%)** currently have only `EXISTING_HTML_ONLY` backing and would need a new JSON sibling endpoint written (following the exact pattern already established for `dashboard/api/` and `activities/api/`) before a Flutter screen could consume them. That JSON-sibling work is not counted separately in the Tier hour estimates above — it's folded into each screen's estimate, but it is real, non-trivial backend work, not just a mobile-side task.

**F. Which major user flow is most incomplete:** The **student career-outcome flow** (Resume Builder → ATS analysis → AI Mock Interview → Job matching → Apply) is 0% converted end-to-end — none of W036-W042 exist in Flutter, despite this being the app's core differentiator per its own marketing copy on W043. The **onboarding flow** is also 0% converted (Registration W024, all 4 password-reset screens) — meaning a brand-new user cannot currently create an account on mobile at all; only an existing web-registered user can log in.

**G. What's realistically completable in 20 engineer-days (≈160 hours) at this team's demonstrated pace:** Roughly **half of Tier 1** — based on the ~40-50 hours/week actually delivered per phase in this project so far (Activities Phase 2+3 together, the most comparable prior scope, took multiple sessions for ~6 screens' worth of read+write API and UI work). A realistic 20-day scope: Student Registration (W024, the single highest-leverage missing screen — nothing else works for a new user without it), Student Profile (W025), Password Reset (W026-W029, low effort/high completeness value), and 1-2 of the remaining default exercise types (W007 fill_blank, W008 matching) to broaden Activities beyond MCQ-only. That is **~120-140 of the ~198 Tier-1 hours** — the full Tier 1 list above is optimistic for 20 days, not a straight fit.

**H. Biggest risks/blockers to the 20-day plan:** (1) Registration's dynamic repeaters (education entries, languages) and document/selfie upload have no Flutter precedent in this codebase yet — first-of-kind UI work, likely to run over estimate. (2) Every `EXISTING_HTML_ONLY` screen needs a *new* backend endpoint designed and reviewed before mobile work can start — that's backend design time, not pure Flutter time, and isn't currently scheduled as a separate lead-in step. (3) The AI Modules, AI Mock Interview, and GD/JAM workshops (Tiers 2-3) all depend on native audio/video/WebSocket capabilities never yet exercised in this Flutter codebase — the very first screen built on each of those primitives should be expected to take materially longer than its estimate while the pattern is established, the same way MCQ (the first exercise-submission pattern) anchored the ones that will follow it faster.

---

## Visual QA Checklist (template — not performed in this audit; no screenshots were taken)

For each screen, before marking it `COMPLETE`:

**Layout parity**
- [ ] Header/title matches the web screen's heading text and hierarchy
- [ ] Every visible section from the web write-up above is present (no silently dropped sections)
- [ ] Every card/tile/list-item field from the "Data fields" list is rendered, not a subset
- [ ] Every button/link from the "Actions" list is present and wired to its real destination (no no-ops)
- [ ] Icons/badges match in meaning (color-coded status, pills) even if restyled for mobile conventions

**States**
- [ ] Empty state matches the web's actual empty-state copy/behavior (not a generic placeholder)
- [ ] Loading state exists (even where the web has none, since mobile is API-driven)
- [ ] Error state exists with a working retry, not a dead end
- [ ] Every conditional section's show/hide rule from the web is replicated (not always-shown or always-hidden)

**Responsiveness**
- [ ] No horizontal overflow at 320px width (smallest common phone)
- [ ] No overflow/clipping at tablet width (≥700px, per the project's existing breakpoint)
- [ ] Long text (names, titles, company names) truncates with ellipsis rather than overflowing, per the `Expanded`+`TextOverflow.ellipsis` pattern already established in this codebase

**Data correctness**
- [ ] Every field pulled from the real API/data source, not a placeholder or hardcoded value
- [ ] Numeric formatting matches (percentages, currency, dates) the web's actual display convention
- [ ] Server-authoritative data is never recomputed client-side (mirrors the MCQ precedent — never trust a client-computed score where the web/backend already computes one)

**Navigation**
- [ ] Every navigation target from the web screen exists and is reachable
- [ ] Back/cancel behavior matches (returns to the expected prior screen, not a generic pop)
- [ ] Deep-link-only web screens (e.g. W041) get an equivalent reachable path on mobile, not an orphaned route

**Sign-off**
- [ ] Status updated in this matrix from `PARTIAL`/`NOT_STARTED` to `COMPLETE` only once every box above is checked against the actual web screen, not from memory
