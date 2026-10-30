# Document 1 — Application Functionality and Modules

This is a read-only, source-code-based audit. No application, backend, or
database file was modified to produce this document. Evidence is cited as
`file:line` wherever practical. Items that could not be verified from source
are explicitly marked **Unverified** or **Requires business/backend
confirmation** rather than assumed.

Primary backend reference: `royalStaffing_CB01` (updated Django project).
Secondary reference (comparison only): `Career_Buddy_LMS` (original Django
project). Flutter app: `Mobile_app/`.

---

## 1. Application overview

**Purpose**: Career Buddy LMS is a combined career-development platform for
job seekers and a hiring platform for employers. For job seekers it bundles
English/communication-skill learning (Grammar, Vocabulary, AI-graded
speaking/writing/listening/reading practice), technical upskilling (Skill
Up hub, Tech Center, Non-IT Center, Certifications), resume tooling (AI
resume parsing/ATS matching, two different resume builders), and an AI mock
interview with camera-based verification. For employers it provides job
posting, applicant tracking, and candidate search over the same pool of
registered job seekers.

**Intended audience**: (1) Job seekers / students ("candidates") — the
primary learning + resume + job-application audience; (2) Employers /
recruiters — a separate portal for posting jobs and managing applicants.

**Problems solved**:
- For candidates: closing English/communication skill gaps, closing
  technical skill gaps, improving resume quality against a target job
  description, interview readiness, and a path from learning straight
  through to applying for real job postings.
- For employers: sourcing candidates from the registered user base, posting
  and managing job listings, and reviewing applicants in one portal.

**Guest (no-login) access** — confirmed directly from
`lib/app/router/route_paths.dart` (`publicRoutes`/`universalRoutes`) and
`lib/app/router/route_guards.dart`'s `computeRedirect`:
reachable with **no account at all**: the combined Home landing page
(`/home`), the Employer Home landing page (`/employer-home`), the public job
detail/apply page (`/jobs/:id` — the real `jobs_app.views.job_detail` has no
`@login_required`), the Career Paths department/role browser (`/careers`,
`/careers/roles` — confirmed `activities.views.career_path` has no
`@login_required`), the free-form Create Resume builder's build/preview
screens (saving a *named* draft requires login; building and previewing one
does not), and the entire login/registration/password-reset flow. Every
other module (Activities, Grammar, Skill Up, Dashboard, Resume
Parsing/ATS, Manual Resume Builder, Mock Interview, JAM, Group Discussion,
Roleplay, Certifications, every Employer-portal screen) requires an
authenticated session.

**Free vs. paid**: yes. A 3-tier plan system exists — Free / Normal (₹499,
1 year) / Pro (₹999, 1 year), plus 18% GST at checkout (`career_app/
views.py:314-320`, `PLAN_PRICING`/`GST_RATE`). Checkout is a real Razorpay
integration with server-side signature verification (see §13 of Document 2
for full detail). Free-plan content gating is enforced **server-side** in
several places (Skill Up's `has_full_skillup()`, Mock Interview's
`_can_access_interview()`, Activities' free-plan subset substitution) — this
is a real backend restriction, not only a UI label.

**Relationship to careerbuddy4u.com**: the Flutter app is a native mobile
client of the **same Django backend** that serves careerbuddy4u.com. It
consumes a mix of a few genuine JSON APIs and, more commonly, the website's
own server-rendered HTML pages (parsed client-side) — confirmed repeatedly
across `lib/core/network/api_endpoints.dart` (e.g., Dashboard, Activities,
Resume Builder, and JAM are all HTML-only in production; a documented JSON
sibling exists in source for some of these but is confirmed **not deployed**
to production). The app and the website are two front ends over one shared
account/data system, not independent products.

**Website-team implication**: the production website already exists at
`careerbuddy4u.com` and may already carry some of the legal/support pages
this audit recommends. Neither local Django checkout contains a Privacy
Policy, Terms, Refund, Cookie, or Account-Deletion template (confirmed by a
direct search of both `templates/` trees) — but the **live** site was not
checked by this filesystem-only audit. **The website team should check
careerbuddy4u.com directly before assuming a blank slate.**

**Technology stack** (`Mobile_app/pubspec.yaml`):
- State management: `flutter_riverpod`. Routing: `go_router` with
  centralized auth-redirect guards.
- Networking: `dio` + `cookie_jar`/`dio_cookie_manager` — a **Django
  session-cookie**-based HTTP client, not a token/JWT API.
- Storage: `flutter_secure_storage` (OS Keychain/Keystore) for a small set
  of cached auth values; `path_provider` to persist the cookie jar across
  app restarts.
- Media/device: `camera`, `record` (audio), `speech_to_text` (on-device),
  `flutter_tts`, `audioplayers`, `video_player`, `webview_flutter`
  (first-party static content only), `image_picker`, `file_picker`,
  `open_file`, `url_launcher`.
- Real-time: `web_socket_channel` (Group Discussion's live session over
  Django Channels).
- Payments: `razorpay_flutter` (official Razorpay SDK wrapper).

See Document 2 for the full third-party/SDK-to-data mapping.

---

## 2. Complete route inventory (all 77 `GoRoute`s)

Guard legend (from `route_guards.dart`'s actual `computeRedirect` logic, not
assumption): **Public** = reachable logged out only, bounces an
authenticated user away; **Universal** = reachable either way, no bounce;
**Auth (student)** = any authenticated session, bounced to `/login` if
logged out; **Auth (employer)** = authenticated employer session only,
bounced to `/employer-login` if logged out, to `/dashboard` if a
non-employer tries it; **Mixed** = one specific route reachable by any
authenticated session (candidate or employer) but not guests.

| # | Route | Path | Guard | Real Django view (evidence) |
|---|---|---|---|---|
| 1 | `splash` | `/` | n/a | pure client bootstrap, no backend call |
| 2 | `login` | `/login` | Public | `users/login/` |
| 3 | `demoEntry` | `/demo` | Public, debug-only | none — refuses to act outside `kDebugMode` |
| 4 | `register` | `/register` | Public | `users.views.register_view`, `/users/register/` |
| 5 | `passwordReset` | `/password-reset` | Public | Django `PasswordResetView` |
| 6 | `checkEmail` | `/password-reset/check-email` | Public | `password_reset_done.html` |
| 7 | `resetPasswordConfirm` | `/password-reset/confirm` | Public | `PasswordResetConfirmView` (link pasted manually, not an app-link) |
| 8 | `passwordResetComplete` | `/password-reset/complete` | Public | `password_reset_complete.html` |
| 9 | `employerLogin` | `/employer-login` | Public | `accounts_app.views.EmployerLoginView` |
| 10 | `employerRegister` | `/employer-register` | Public | `accounts_app.views.employer_register` |
| 11 | `home` | `/home` | Universal | `activities.views.home` |
| 12 | `employerHome` | `/employer-home` | Universal | `jobs_app.views.home` |
| 13-14 | `createResumeBuilder`, `createResumePreview` | `/resume-builder/create...` | Universal | `create_resume_views` (saving a named draft requires login) |
| 15-16 | `careerDepartments`, `careerRoles` | `/careers...` | Universal | `activities.views.career_path` |
| 17 | `dashboard` | `/dashboard` | Auth (student) | `activities.views.dashboard` (HTML; documented JSON sibling not deployed) |
| 18 | `employerDashboard` | `/employer-dashboard` | Auth (employer) | `jobs_app.views.employer_dashboard` |
| 19-20 | `employerJobCreate`, `employerJobEditPattern` | `/employer-jobs/...` | Auth (employer) | `jobs_app.views.job_create`/`job_edit` — real production form, ~45 fields |
| 21-22 | `employerAllApplications`, `employerJobApplicationsPattern` | `/employer-applications...` | Auth (employer) | `jobs_app.views.all_applications`/`job_applications` |
| 23 | `publicJobDetailPattern` | `/jobs/:id` | reachable by anyone per the real view; no Flutter nav entry point wired yet | `jobs_app.views.job_detail` |
| 24 | `myApplicationDetailPattern` | `/my-applications/:id` | Auth (student) | `jobs_app.views.my_application_detail` |
| 25-26 | `employerCompanyProfile`, `...Create` | `/employer-company-profile...` | Auth (employer) | `jobs_app.views.employer_profile_edit`/`_create` |
| 27 | `employerJobOpenings` | `/employer-job-openings` | **Mixed** | `jobs_app.views.job_openings` — plain `@login_required`, no portal check |
| 28 | `employerSearchCandidates` | `/employer-candidates` | Auth (employer) | `jobs_app.views.search_candidates` — searches registered students' profiles |
| 29 | `employerApplicationDetailPattern` | `/employer-applications/:id` | Auth (employer), not yet wired to a nav entry point | `jobs_app.views.application_detail` |
| 30-45 | Activities + every exercise type (`activities`, `aiSpeakingPattern`, `aiWritingPattern`, `aiListeningPattern`, `aiReadingPattern`, `matchingExercisePattern`, `bingoExercisePattern`, `fillBlankExercisePattern`, `genericWritingExercisePattern`, `timerExercisePattern`, `workshopDashboard`, etc.) | `/activities...` | Auth (student) | `activities.views.*` — HTML-only in production |
| 46-49 | `mockTestsHub`, `oopMasteryMockTest`, `subjectQuizPattern`, `amcatMockTest`, `cocubesMockTest` | `/mock-tests...` | Auth (student) *in this app's own navigation*, though the real endpoints require no auth | genuine JSON APIs, scored either way; only persisted if logged in |
| 50 | `profile` | `/profile` | Auth (student) | `ComingSoonScreen` placeholder — **not yet built** (`app_router.dart:442`) despite `users.views.profile_view` existing server-side |
| 51-57 | `skillUp`, `sitemap`, `skillUpSections`, `skillUpCertifications`, `skillUpLesson`, `skillUpNonIt`, `skillUpNonItRoles` | `/skill-up...` | Auth (student) | `riya_bot.skillup_views.skillup_hub` — plain `@login_required`, no employer branch |
| 58-59 | `techCenterDepartments`, `techCenterRoles` | `/skill-up/tech-center...` | Auth (student) | same `skillup_hub` view |
| 60-61 | `grammar`, `grammarTopicPattern` | `/grammar...` | Auth (student) | `subject_views.subject_home`/`subject_topic` |
| 62-70 | Resume Builder family (`resumeBuilder`, `resumeHistory`, `resumeRolePicker`, `manualResumeBuilder`, `manualResumePreview`, `manualResumePagePreview`, `createResumeDrafts`, `mockInterview`) | `/resume-builder...` | Auth (student), except the Universal Create-Resume routes above | `career_app.views.*`, `manual_resume_views.*`, `create_resume_views.*` |
| 71-74 | JAM (`jamTopics`, `jamHistory`, `jamProfile`, session/assessment detail) | `/jam...` | Auth (student) (gated one layer up via the Activity entry point) | `jam_app.views.*` |
| 75 | `roleplayHome` | `/roleplay` | Auth (student) | `activities.roleplay_urls` |
| 76 | `groupDiscussion` | `/group-discussion` | Auth (student) | `GD_app` + a live WebSocket |
| 77 | `mockInterview` | `/resume-builder/mock-interview` | Auth (student), reached from the ATS result screen | `career_app.views.resume_start_interview` + camera-verification pipeline |

Certifications has no separate top-level route — it is a tab inside
`SkillUpScreen` (`skillUpCertifications`).

---

## 3. Module-wise inventory

### Home / Landing (`lib/features/home/`)
- **Purpose**: combined marketing + entry landing page for both candidate
  and employer tracks; also the authenticated dashboard entry surface.
- **Features**: "Which path suits you?" IT/Non-IT path picker popup
  (confirmed live on an Android emulator during unrelated prior work in
  this project), Career Paths browsing, a guest-reachable entry into Create
  Resume.
- **Inputs collected**: none directly — navigation only.
- **Login required**: No. **Free/Paid**: Free.
- **Backend**: `activities.views.home` (HTML).
- **Status**: Complete.

### Auth — Login / Registration / Password reset (`lib/features/auth/`)
- **Purpose**: candidate and employer account creation, sign-in, password
  recovery.
- **Candidate registration fields**: first/last name, email, username,
  password+confirm, gender, mobile, alternate mobile, blood group,
  languages known, **Aadhaar number (required), PAN number, passport
  number** (both optional), two education-history sets, experience
  flag/years, current employer/company, HR-contact role/mobile/email,
  industry, skills (free text), current/expected CTC, certification,
  **required resume file upload**, current/preferred location,
  abroad-experience fields. Server-side, a `selfie` field also exists but is
  deliberately not implemented in this app (documented scope decision).
- **Employer registration fields**: username, password+confirm, email,
  first/last name, company name, industry, HR contact phone+email, optional
  company logo upload, GST number, company PAN/TIN, company address. Both
  the account email and the HR email must each be independently verified
  via OTP before the account can be created.
- **OTP verification**: real, 6-digit, server-validated for both roles
  (`/users/register/send-otp/`, `.../verify-otp/`).
- **Password reset**: real 4-step Django email flow; the user manually
  pastes the reset-link text into the app rather than following a
  deep/universal link (a documented workaround, not a bug — no app-link
  verification is configured against the production host).
- **Session/cookie storage**: a real Django session cookie, persisted via a
  plain file-backed cookie jar (`cookie_jar`/`dio_cookie_manager`) in the
  app's private storage — **not** OS Keychain/Keystore. Separately, only
  two small cached values (username, employer flag) use real OS-secure
  storage (`flutter_secure_storage`). See Document 2 for the full detail.
- **Profile screen**: `/profile` is still a `ComingSoonScreen` placeholder —
  **not built** — despite a fully-modeled `ProfileData`/`ProfileEditData`
  domain entity already existing with the complete real field set. This is
  a genuine implementation gap: users cannot currently view or edit their
  own profile data inside the app.
- **Login required**: No for the auth screens themselves (they are the
  pre-login flow). **Free/Paid**: Free.
- **Backend**: `users` app, `accounts_app` (employer auth).
- **Status**: Login/registration/password-reset — Complete. Profile
  viewing/editing — **Unavailable** (placeholder only). **No in-app
  account-deletion option exists** (see Document 3).

### Employer (`lib/features/employer/`, 81 files)
- **Purpose**: the full recruiter portal — job posting lifecycle, applicant
  tracking, candidate sourcing, company profile.
- **Features**: job posting create/edit (a ~45-field real production form
  across 3 job-category branches, 13 skill-category checkbox groups/124
  skills, perk checkboxes, work-environment/interview-mode/notice-period/
  gender-preference radio groups), job applications (per-job and
  all-applications list + review-with-notes), Company Profile (GST, PAN,
  address, logo), Job Openings (shared with candidates), Candidate Search
  (query/location/experience filters over registered students' profile
  data, plus a CSV export).
- **Inputs collected**: all job-posting fields; application review
  notes/status; company profile fields; search query terms.
- **Output**: job listings, applicant lists/details, a downloadable CSV of
  searched candidates.
- **Login required**: Yes, employer session specifically for most of this
  module; `employerJobOpenings` is reachable by any authenticated session.
- **Free/Paid**: Unverified whether any employer-side feature is
  plan-gated — no subscription-plan reference found in the employer entity
  files; `Requires confirmation`.
- **Backend**: `jobs_app`.
- **Status**: Complete for job CRUD, applications, candidate search,
  company profile.

### Resume (`lib/features/resume/`, 85 files — actually 4 sub-features)
1. **Resume Parsing / ATS matching** — upload a resume + optional job
   description, get an ATS-style match result. `@login_required`. History
   lists every resume ever uploaded and supports re-analysis.
2. **Manual Resume Builder** — AI-assisted, role-suggestion-driven
   structured resume builder with server-rendered page-image/PDF preview
   (capped at 6 pages). Authenticated-only in this app **by deliberate
   product decision**, even though the real backend endpoint itself has no
   login requirement.
3. **Create Resume Builder** — a free-form builder backed by a
   `ResumeDraft` model scoped to the user. Build/preview/PDF require no
   login; only named-draft save/list/delete requires login (surfaced as a
   "sign in to save" prompt).
4. **Career Departments/Roles browser** — the "Choose Your Path" IT/Non-IT
   explorer, no login required.
- **Inputs collected**: uploaded resume files, job-description text,
  structured resume content (name, contact, education, experience, skills,
  projects, certifications — exact field list not independently
  re-enumerated in this document; see Document 2's data inventory),
  selected role/template choices.
- **Output**: ATS match score/analysis, generated resume PDF, page-image
  previews (Manual: up to 6 pages; Create: up to 10 pages, both capped).
- **Free/Paid**: the Free plan caps Resume Parsing at 4 analyses (plan
  copy); whether this limit is enforced server-side or only displayed is
  `Unverified — requires confirmation`.
- **Backend**: `career_app` (parsing + create-resume), `manual_resume_views`
  (manual builder).
- **Status**: Complete for all 4 sub-features per endpoint evidence.

### Mock Interview (`lib/features/mock_interview/`)
- **Purpose**: an AI-driven mock interview with camera-based identity
  verification and anti-malpractice monitoring, reached from the Resume
  ATS result screen's "Try Interview" CTA.
- **Features/inputs**: camera-verified session start, sequential
  AI-generated questions, spoken or typed answers (transcribed **on-device**
  via `speech_to_text`, not sent as raw audio to the server for this
  specific feature), violation recording during the session (confirms
  anti-cheating monitoring is server-tracked, not only a UI warning), a
  **genuine continuous video+audio recording of the entire interview**,
  uploaded to the backend at the end (see Document 2 §Camera for the
  resolved, verified detail — the backend persists this file only when the
  session passes; otherwise it is discarded, unpersisted), and a
  post-interview analytics/score breakdown.
- **Login required**: Yes. **Free/Paid**: unlocked only at ATS ≥90% and
  restricted to Normal/Pro plans (`_can_access_interview`, confirmed
  server-side).
- **Backend**: `career_app.views.resume_start_interview` + the
  camera/question/answer/violation/video-upload/analytics endpoints.
- **Status**: Complete. **Uses the device camera and microphone for a real,
  continuous recording — this is the single most significant data-capture
  fact in the app and must be prominently disclosed** (see Documents 2, 3,
  and 5).

### Activities / AI Speaking / AI Writing / AI Listening / AI Reading /
Matching / Bingo / Fill-in-the-Blank / Generic Writing / Timer Exercise
- **Purpose**: the core English/communication learning content — Activities
  is the catalog/hub; each type is a distinct AI-graded or self-graded
  practice format.
- **Inputs per AI module**: AI Speaking — recorded audio (multipart upload)
  + duration/pause-count/client transcript/language/reference text. AI
  Writing — typed text + language/reference text (plus a copy-paste
  anti-cheat check server-side). AI Listening — similar, plus a single-use
  anti-replay token. AI Reading — recorded audio, no replay token.
  Matching/Bingo/Fill-blank/Generic-Writing/Timer — client- or
  server-regraded submissions.
- **Login required**: Yes, uniformly. **Free/Paid**: Free-plan users see a
  fixed, smaller subset of Activities, substituted server-side.
- **Backend**: `activities` app, HTML-only in production.
- **Status**: Complete.

### Mock Tests (`lib/features/mock_tests/`)
- **Purpose**: fixed-bank technical/aptitude mock tests — OOP Mastery, 24
  subject quizzes, AMCAT and CoCubes full mocks.
- **Inputs**: quiz answers only.
- **Login required**: the real endpoints themselves require no auth (an
  attempt is simply not persisted unless logged in), but this app's own
  navigation places these screens behind its authenticated-only route set.
- **Backend**: `activities` app, genuine JSON APIs.
- **Status**: Complete.

### Skill Up / Tech Center / Non-IT Center / Certifications
- **Purpose**: a hub of static HTML learning content (English, Vocabulary,
  Aptitude, Tech, Non-IT) plus a certifications/assessment subsystem.
  Individual lesson pages (48 static HTML files) render inside a real
  `WebView` pointed only at the app's own backend — never an external site.
- **Certifications**: a genuine `@login_required` JSON API —
  status-per-subject, PDF certificate generate/regenerate/download with the
  printed name read from a `certificate_name` form field. This **generates
  a PDF document containing the user's name**.
- **Login required**: Yes, uniformly (no employer-specific branch).
- **Free/Paid**: Free plan is English & Vocabulary (plus one Tech Center
  mock test) only; everything else requires Normal/Pro.
- **Status**: Complete. (This sub-area has its own exhaustive, independent
  audit trail already in this repository — see `docs/PHASE_76_*` through
  `docs/PHASE_79_*` — not re-derived here.)

### Grammar (`lib/features/grammar/`)
- **Purpose**: 9-topic grammar lesson content plus per-topic slide-deck
  images, a generated SVG illustration, and a session-cookie-gated lesson
  video (HTTP Range–streamed).
- **Login required**: Yes. **Backend**: `subject_views.py`.
- **Status**: Complete.

### JAM — "Just A Minute" (`lib/features/jam/`)
- **Purpose**: timed impromptu-speaking practice with AI feedback (Sarvam,
  falling back to rule-based scoring).
- **Inputs**: recorded audio + duration/transcript/language.
- **Assessment flow**: a 3-stage (easy/medium/hard) assessment gated on
  having completed one practice session at each difficulty.
- **Login required**: Yes in practice (gated via the Activity entry point).
- **Backend**: `jam_app`, HTML throughout except one JSON endpoint.
- **Status**: Complete. Note: a **feature-level "reset my progress"**
  capability already exists for this module on the real website
  (`jam:reset_progress` — permanently deletes JAM session history on
  request) but is not currently exposed in the Flutter app; see Document 3
  for why this is relevant to account-deletion planning.

### Roleplay Workshop (`lib/features/roleplay/`)
- **Purpose**: 3 sub-features (Storytelling / Situations / Roleplay) — AI-
  generated practice scenarios.
- **Login required**: Yes. **Status**: Complete for the 2 confirmed
  endpoints.

### Group Discussion (`lib/features/group_discussion/`)
- **Purpose**: a live, real-time AI-moderated group discussion session over
  a genuine Django Channels **WebSocket** (not polling), using on-device
  speech-to-text for live transcription.
- **Login required**: Yes (via the Activity entry point). **Status**:
  Complete.

### Dashboard (`lib/features/dashboard/`)
- **Purpose**: the authenticated candidate's summary screen — activity
  progress, recommended jobs, subscription status, and **payment/
  transaction history** (date, amount, transaction ID, active/inactive).
- **Backend**: `activities.views.dashboard` (HTML, scraped client-side).
- **Login required**: Yes. **Status**: Complete.

### Subscription / Pro (`lib/features/subscription/`)
- A static, hand-transcribed copy of the real pricing page drives the plan
  display; checkout (order creation + verification) is real (see Document
  2 §13 for the full payment-flow detail). **No in-app subscription
  cancellation or plan-change screen was found** — flagged for business
  confirmation, since no backend cancellation endpoint exists either (see
  Document 2).
- **Status**: Complete for display + checkout. Cancellation/management:
  **Unavailable**.

### ARIA chat / "Riya"/"Buddy" AI assistant (`lib/features/aria_chat/`,
`lib/shared/widgets/buddy_chatbot_overlay.dart`)
- **Purpose**: an AI chatbot assistant that can converse, answer questions,
  and trigger in-app navigation.
- **Inputs**: typed or voice chat messages, selected language.
- **AI provider**: **Sarvam AI** (confirmed for chat replies, speech-to-
  text, and most text-to-speech); **Google** is a second, confirmed
  provider for some TTS language/voice paths. See Document 2 for the full
  data-flow detail.
- **Login required**: No — the chat/voice endpoints are explicitly
  CSRF-exempt and carry no `@login_required`, though a logged-in employer
  session does get slightly different assistant behavior.
- **Status**: Complete. This is a significant, independently-documented
  data flow for the Privacy Policy (chat/voice content leaves the device to
  a Django view, which forwards it to an external AI/voice vendor) — see
  Document 2.

---

## 4. Biggest open questions carried forward

1. **Account deletion**: no deletion option exists anywhere, in-app or
   backend (full detail in Document 3).
2. **Profile screen is unbuilt** (`ComingSoonScreen`) despite a complete
   domain model already existing.
3. **Candidate registration collects Aadhaar, PAN, and passport numbers** —
   a sensitive-data category requiring explicit Privacy Policy/Data Safety
   disclosure (full detail in Document 2).
4. **Riya/ARIA's underlying chat-completion AI provider**: confirmed to be
   Sarvam AI (resolved during synthesis of this audit — see Document 2);
   voice features additionally use Google for some languages.
5. **Employer-side subscription/plan-gating**: unconfirmed — no plan-tier
   reference found in the employer entity files.
6. **In-app subscription cancellation**: not found — `Requires business
   confirmation` on the intended policy (see Documents 2 and 5).
7. **The live production website was not checked** by this filesystem-only
   audit for an existing Privacy Policy/Terms/Account-Deletion page — check
   `careerbuddy4u.com` directly before assuming none exists.

## Coverage note

This document is a structural/contract-level inventory — all 77 routes and
all 26 `lib/features/*` directories were addressed at module level, cross-
referenced against the real Django views/decorators wherever a direct
mapping exists. It is not an exhaustive screen-by-screen UI walkthrough
(e.g., the full 124-skill/45-field employer job-posting form and the
complete resume-builder field list are summarized by count/category here,
not transcribed field-by-field — see Document 2 for the data-focused
breakdown and Document 6 for exactly which files were and weren't read in
full).
