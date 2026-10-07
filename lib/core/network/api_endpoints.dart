/// Backend paths, verified against `users/urls.py` and `users/views.py` in
/// the Django project. Do not add a path here without confirming it exists
/// in the backend first.
///
/// `users.urls` is mounted under the `/users/` prefix in the project's root
/// `business_english_lms/urls.py` (`path('users/', include('users.urls'))`)
/// — verified by hitting the live dev server, where `/login/` 404s but
/// `/users/login/` returns 200.
abstract final class ApiEndpoints {
  static const String login = '/users/login/';
  static const String logout = '/users/logout/';

  /// Employer Portal auth — a genuinely separate Django form/view from the
  /// student [login] above (`accounts_app.views.EmployerLoginView`, backed
  /// by an `AuthenticationForm` subclass that additionally rejects any user
  /// without an `employer_profile`). Verified live: `employer_portal`
  /// (`business_english_lms/urls.py:50`, mounted at `/employer/`) includes
  /// `accounts_app.urls` at `accounts/`, which itself nests the employer
  /// paths one level deeper under `employer/` — giving the URLs below,
  /// confirmed by hitting the dev server directly (both return 200).
  static const String employerLogin = '/employer/accounts/employer/login/';
  static const String employerRegister = '/employer/accounts/employer/register/';

  /// The real post-login/-registration redirect target
  /// (`accounts_app/views.py` `EmployerLoginView.get_success_url`/
  /// `employer_register`, both `redirect('job_home')`) — `jobs_app.views.
  /// home`, the Recruiter Portal landing page (`templates/jobs/
  /// employer_home.html`), reachable whether or not a session is logged
  /// in. Confirmed live (200) at this exact path, distinct from
  /// `employer_portal:home` (`/employer/`, same view, different URL).
  static const String employerHome = '/employer-home/';

  /// `jobs_app.views.employer_dashboard` (`@login_required`, plus a
  /// second, in-view check that the session's `portal == 'employer'`) —
  /// server-rendered HTML only, no JSON sibling. Note the doubled
  /// `employer/employer/` segment: `employer_portal.urls` (mounted at
  /// `/employer/`) itself nests `jobs_app.employer_urls` at a second
  /// `employer/` prefix (`employer_portal/urls.py`) — confirmed live
  /// (302 when logged out, redirecting to [employerLogin]).
  static const String employerDashboard = '/employer/employer/dashboard/';

  /// `jobs_app.views.application_detail` (`employer_portal:
  /// application_detail`) — same doubled `employer/employer/` mount as
  /// [employerDashboard]. GET renders the review page; POST (same URL)
  /// submits a status/notes update and 302s back to itself on success. The
  /// view scopes `JobApplication.objects.filter(job__employer=profile)`
  /// before the `pk` lookup, so a 404 (not 403) is the real server's
  /// answer for another employer's application id — confirmed directly
  /// against `jobs_app/views.py:684-691`.
  static String employerApplicationDetail(int pk) => '/employer/employer/applications/$pk/';

  /// `jobs_app.views.employer_profile_edit` — same doubled
  /// `employer/employer/` mount as [employerDashboard]. GET renders
  /// `employer/profile_form.html` pre-filled from the caller's own
  /// `EmployerProfile` row (masked PAN); POST (same URL) updates it and
  /// 302s to [employerDashboard] on success, re-renders the form (200) on
  /// validation failure — verified live against a real, complete profile
  /// (`jobs_app/views.py:558-572`).
  static const String employerProfileEdit = '/employer/employer/profile/edit/';

  /// `jobs_app.views.employer_profile_create` — same template/form as
  /// [employerProfileEdit], reached instead of it specifically when
  /// `employer_dashboard` finds the caller's profile missing GST/PAN
  /// (`_employer_profile_complete`, `jobs_app/views.py:482-493`). Every
  /// self-registered employer already has an `EmployerProfile` row (created
  /// at signup), so this updates that row rather than inserting a second
  /// one (`jobs_app/views.py:544-551`).
  static const String employerProfileCreate = '/employer/employer/profile/create/';

  /// `jobs_app.views.job_create` — same doubled `employer/employer/` mount.
  ///
  /// **The live production form diverges completely from this repository's
  /// committed `JobPostingForm`/`templates/employer/job_form.html` (a
  /// 17-field form with one plain `skills_required` text input and no
  /// department/mandatory-skill system) — confirmed by fetching and parsing
  /// the real rendered page directly.** The live page instead has ~45
  /// fields across 3 branches (`job_category`: IT / Non-IT×Technical /
  /// Non-IT×Non-Technical, each showing a different field set), a
  /// `department` selector driving which of 13 skill categories' checkbox
  /// groups show (124 skills total plus IT's free-typed custom-skill
  /// addition, `name="skills"`), a star-to-mark-3–4-mandatory interaction
  /// per skill (`mandatory_skills`, one comma-joined hidden field), 18 perk
  /// checkboxes, and 4 radio groups (`work_environment`/`interview_mode`/
  /// `notice_period`/`gender_preference`). This divergence is real and
  /// permanent, not a stale-cache artifact — the repo's `JobPostingForm`
  /// contract is NOT the one used here. See `job_posting_catalog.dart` for
  /// every option/skill value (copied verbatim from the live page) and
  /// `JobPostingSubmission` for the full field list — both are the
  /// authoritative, live-verified contract this app now builds against,
  /// per this task's explicit instruction to follow production over stale
  /// repository code. Per-field validation errors come back as
  /// `<div id="err_<field>">message</div>` (not Django's default
  /// `errorlist` rendering — see `JobPostingRemoteDataSource`).
  static const String employerJobCreate = '/employer/employer/jobs/new/';

  /// `jobs_app.views.job_edit` — presumed same live-vs-repo form-contract
  /// divergence as [employerJobCreate] (not independently re-verified this
  /// task, which only covered *creating* a job); not wired to a Flutter
  /// screen. Scoped to the caller's own jobs **or** any `is_seeded=True`
  /// platform job — editing a seeded job transfers its ownership to the
  /// caller (`jobs_app/views.py:606-620`, intentional, not
  /// reproduced-around).
  static String employerJobEdit(int pk) => '/employer/employer/jobs/$pk/edit/';

  /// `jobs_app.views.job_delete` — POST-only (a GET just redirects back to
  /// [employerDashboard] without deleting anything); same ownership/seeded
  /// scoping as [employerJobEdit]. No JSON body, no confirmation page — the
  /// web's only confirmation is a client-side `confirm('Delete this job?')`
  /// before the POST fires.
  static String employerJobDelete(int pk) => '/employer/employer/jobs/$pk/delete/';

  /// `jobs_app.views.job_applications` — GET only, this job's own
  /// `JobApplication` list, optionally filtered server-side with
  /// `?status=<value>` (one of `JobApplication.STATUS_CHOICES`).
  static String employerJobApplications(int pk) => '/employer/employer/jobs/$pk/applications/';

  /// `jobs_app.views.all_applications` — GET only, every application across
  /// all of the caller's own job postings, optionally filtered
  /// server-side with `?q=` (name/email), `?status=`, and `?source=`
  /// (`JobApplication.SOURCE_CHOICES`).
  static const String employerAllApplications = '/employer/employer/applications/';

  /// `jobs_app.views.search_candidates` (`templates/jobs/
  /// candidate_search.html`) — GET only, searches REGISTERED STUDENTS
  /// (`search_registered_candidates`), optionally filtered with `?q=`
  /// (skills/keywords), `?location=`, `?experience=`. Note: this screen's
  /// own `experience` choices (`fresher`/`1-3`/`3-5`/`5+`) are a genuinely
  /// different set from `JobPosting.EXPERIENCE_CHOICES`
  /// (`fresher`/`1-2`/`3-5`/`5-8`/`8+`) — confirmed live, not a typo to
  /// "fix".
  static const String employerSearchCandidates = '/employer/employer/candidates/search/';

  /// `jobs_app.views.job_detail` (`employer_portal:job_detail`,
  /// `templates/jobs/job_detail.html`) — the public, job-seeker-facing job
  /// listing + apply page. No auth required for GET; works for anonymous,
  /// student, or employer sessions alike (the apply form itself is only
  /// rendered when the session isn't an employer portal session). POST
  /// (same URL) submits an application and redirects back to itself
  /// (302) on success, re-renders (200) on validation failure — the real
  /// `clean_applicant_phone` failure path ("already applied") surfaces as
  /// a Django message on the next render, not a form field error.
  static String publicJobDetail(int pk) => '/employer/jobs/$pk/';

  /// `jobs_app.views.my_application_detail` (`templates/jobs/
  /// my_application.html`) — student-facing read-only view of one of the
  /// caller's own applications (`@login_required`, root-level URL, not
  /// namespaced). Scoped to applications linked to the caller's account
  /// **or** carrying their registered email (`student_applications_for`,
  /// `jobs_app/views.py:131-144`) — a foreign id 404s, not 403, so another
  /// student's application id can't be fingerprinted.
  static String myApplicationDetail(int pk) => '/applications/$pk/';

  /// `jobs_app.views.job_openings` (`templates/employer/job_openings.html`)
  /// — GET only, every active job (employer-posted + seeded). Despite
  /// living under `jobs_app.employer_urls`, this is job-seeker facing:
  /// plain `@login_required`, no employer-profile/portal-session check
  /// (confirmed live) — see [employerJobOpenings]'s equivalent note.
  static const String jobOpenings = '/employer/employer/job-openings/';

  /// Email OTP verification (`users/urls.py:9-10`, `users/views.py:
  /// send_email_otp`/`verify_email_otp`) — a single, shared subsystem used
  /// by both the (pre-existing, unimplemented-in-Flutter) student
  /// registration flow and employer registration
  /// (`accounts_app/views.py:employer_register` gates on
  /// `is_email_verified`/this same session key). Both are `@require_POST`,
  /// always return JSON (never a redirect), and their verified-state lives
  /// entirely in the Django session (`OTP_VERIFIED_SESSION_KEY`) — so the
  /// actual registration POST must reuse the exact same session cookie
  /// these two calls established. Confirmed live: an unauthenticated POST
  /// without a CSRF cookie 403s (not 404), proving the path is real.
  static const String sendEmailOtp = '/users/register/send-otp/';
  static const String verifyEmailOtp = '/users/register/verify-otp/';

  /// Student registration (`users/urls.py:'register/'`, `users/views.py:
  /// register_view`) — plain server-rendered HTML form, same GET-then-POST/
  /// 302-on-success convention as [login].
  static const String register = '/users/register/';

  /// `/users/profile/` (`users/urls.py`, `users/views.py:profile_view`) —
  /// `@login_required`. GET renders the Overview/Edit tabs; POST (same URL)
  /// submits the Edit form.
  static const String profile = '/users/profile/';

  /// Password reset request (`users/urls.py`, Django's
  /// `PasswordResetView`) — always redirects to [passwordResetDone] on a
  /// valid POST regardless of whether the email exists (Django's own
  /// anti-enumeration behavior), so there is no "email not found" failure
  /// state to model here.
  static const String passwordReset = '/users/password-reset/';

  /// `PasswordResetConfirmView` (`users/urls.py:'reset/<uidb64>/<token>/'`)
  /// — reached from the emailed reset link. No JSON sibling exists; GET
  /// renders either the new-password form (valid link) or an "invalid/
  /// expired" message, and POST re-renders the same template with field
  /// errors on failure or 302s to [passwordResetComplete] on success.
  static String passwordResetConfirm(String uidb64, String token) => '/users/reset/$uidb64/$token/';

  /// `activities.views.dashboard_api` — see
  /// `docs/BACKEND_CONTRACT_dashboard.md` for the response contract this
  /// was built against. **Confirmed not deployed to production this
  /// session**: a live, unauthenticated `GET` returns a genuine Django 404
  /// (not the view's own `401 {"error":"Not authenticated"}`, which is
  /// what an unauthenticated request would get back if the route existed
  /// at all) — so this constant is currently unused; see [dashboardHtml]
  /// for what `DashboardRemoteDataSource` actually calls instead. Left
  /// defined (not deleted) so swapping back is a one-line change the day
  /// this ships to production — the parsing/domain layer above it needs no
  /// other change either way, since [dashboardHtml]'s scrape produces the
  /// exact same `DashboardData` shape.
  static const String dashboard = '/dashboard/api/';

  /// `activities.views.dashboard` (`templates/dashboard.html`) — the real,
  /// live, server-rendered page [dashboard]'s JSON sibling was meant to
  /// replace. Confirmed live this session (anonymous `GET` 302s to
  /// `/users/login/?next=/dashboard/`, exactly the `@login_required`
  /// behavior expected — not a 404). `_build_dashboard_context` backs both
  /// views with the identical queries, so this HTML carries the same data,
  /// just a different wire format — see `parseDashboardHtml`.
  static const String dashboardHtml = '/dashboard/';

  /// Read-only Learning Activities endpoints — documented, deliberately
  /// mobile-shaped source (`docs/BACKEND_CONTRACT_activities.md`), but
  /// confirmed this session **not deployed to production**: anonymous
  /// `GET`s to `/activities/api/`, `/activities/api/1/`, and
  /// `/activities/api/exercise/1/` all return a genuine Django 404, the
  /// same "documented but undeployed" pattern already confirmed for
  /// [dashboard]. Left defined (not deleted) for the same reason — see
  /// [activityListHtml]/[activityDetailHtml]/[subActivityDetailHtml] for
  /// what's actually called instead.
  static const String activityList = '/activities/api/';
  static String activityDetail(int id) => '/activities/api/$id/';
  static String subActivityDetail(int id) => '/activities/api/sub/$id/';

  /// `activities.views.activity_list`/`activity_detail`/
  /// `sub_activity_detail` — the real, live, server-rendered pages the
  /// JSON endpoints above were meant to replace. Confirmed live (anonymous
  /// `GET` 302s to the login page, the expected `@login_required`
  /// behavior). `sub_activity_detail` genuinely needs both ids — its real
  /// URL is `/activities/<activity_pk>/sub/<sub_pk>/`, with no single-id
  /// lookup on the real web at all (see `RoutePaths.subActivityDetail`'s
  /// doc comment) — see `parseActivityListHtml`/`parseActivityDetailHtml`/
  /// `parseSubActivityDetailHtml`.
  static const String activityListHtml = '/activities/';
  static String activityDetailHtml(int id) => '/activities/$id/';
  static String subActivityDetailHtml(int activityId, int subActivityId) => '/activities/$activityId/sub/$subActivityId/';

  /// `activities.views.workshop_dashboard` (`templates/activities/
  /// workshop_dashboard.html`) — the dedicated `/activities/workshop/`
  /// page, built from a plain `Activity.objects.filter(category='workshop',
  /// is_active=True)` query with **no plan-gating of any kind**. This is
  /// deliberately NOT the same request [activityListHtml] makes: that
  /// endpoint's own view (`_activity_list_data`) ignores any `?category=`
  /// filter for a non-full-access user and substitutes their fixed
  /// `FREE_PLAN_ACTIVITY_TITLES` selection instead (none of which are
  /// workshop activities) — so a Free Plan user hitting [activityListHtml]
  /// with `category: 'workshop'` could see 0 cards, while this page always
  /// shows all 3 to every authenticated user regardless of plan, exactly
  /// like the real web page does. Its rendered card markup (`activity-
  /// card`/`activity-title`/`activity-objective`/`badge-level`/`badge-
  /// category`) is confirmed identical to [activityListHtml]'s, so
  /// `parseActivityListHtml` parses this page correctly too — no separate
  /// parser needed.
  static const String workshopDashboardHtml = '/activities/workshop/';

  /// Server-authoritative MCQ exercise endpoints — documented source
  /// (`docs/BACKEND_CONTRACT_activities.md` section D) but, like
  /// [activityList] above, confirmed **not deployed to production** (same
  /// `/activities/api/...` prefix, same live-404 confirmation). MCQ is
  /// still fixed the same way as every other HTML-scraped exercise type —
  /// see `McqExerciseRemoteDataSource` and `exerciseDetailPage`/
  /// `submitExercise` below. Other exercise types
  /// (fill_blank/matching/bingo/ordering/writing/timer/AI modules/roleplay/
  /// quiz-bank) have no mobile JSON API either — see
  /// `docs/PHASE_3_EXERCISE_ARCHITECTURE.md`.
  static String mcqExercise(int exerciseId) => '/activities/api/exercise/$exerciseId/';
  static String submitMcqExercise(int exerciseId) => '/activities/api/exercise/$exerciseId/submit/';

  /// The web's own "Mark Complete" form target (`activities/urls.py`,
  /// `views.mark_sub_complete`) — no JSON sibling exists, so this is
  /// called the same way the browser's `<form method="post">` does (see
  /// `ActivitiesRemoteDataSource.markSubComplete`), the same technique
  /// already used for `login`/`logout`.
  static String markSubComplete(int subActivityId) => '/activities/sub/$subActivityId/complete/';

  /// The "mock quiz" family — already a genuine, standalone JSON API (not
  /// tied to the `Activity`/`Exercise` models at all; the real UI is a
  /// static HTML mini-SPA under `static/001 Career Buddy/TechCenter/`, but
  /// these two endpoints are the actual data contract it calls). Verified
  /// against `activities/urls.py`/`activities/views.py`:
  /// `oop_quiz_questions`/`oop_quiz_submit` — see
  /// `docs/EXERCISE_FEASIBILITY_AUDIT.md` §2 (classification A). No auth
  /// is required by either (`@require_GET`/`@csrf_exempt @require_POST`
  /// only) — an attempt is scored either way; it's simply not persisted to
  /// `skillup_assessment.QuizAttempt` unless the user happens to be logged
  /// in, since this app's session cookie is attached automatically.
  static const String oopQuizQuestions = '/activities/oop-quiz/questions/';
  static const String oopQuizSubmit = '/activities/oop-quiz/submit/';

  /// The generic per-subject sibling of the above (`quiz_questions`/
  /// `quiz_submit`, `activities/views.py:2217-2264`) — verified byte-for-
  /// byte identical server logic to the OOP endpoints, only the question
  /// bank file differs. [subject] must be one of `_QUIZ_SUBJECTS`
  /// (`activities/views.py:2201-2206`: oop, python, dsa, devops, claude,
  /// uiux, design, vector, nltk, dbms, prompt, genai, crewai, english,
  /// aptitude, quantum, vr, robotics, nodejs, mlops, ethical, tensorflow,
  /// cyber, blockchain, crypto) — an unknown slug 404s
  /// (`{"error": "unknown subject"}`), which the app's existing
  /// `NotFoundException`/`NotFoundFailure` mapping already handles cleanly.
  static String quizQuestions(String subject) => '/activities/quiz/$subject/questions/';
  static String quizSubmit(String subject) => '/activities/quiz/$subject/submit/';

  /// W022 — AMCAT full mock (`amcat_questions`/`amcat_submit`,
  /// `activities/views.py:2291-2343`, `activities/urls.py:42-43`). No auth
  /// required; `amcat_submit` is `@csrf_exempt`.
  static const String amcatQuestions = '/activities/amcat/questions/';
  static const String amcatSubmit = '/activities/amcat/submit/';

  /// W023 — CoCubes full mock (`cocubes_questions`/`cocubes_submit`,
  /// `activities/views.py:2369-2429`, `activities/urls.py:46-47`) — verified
  /// to share `amcat_questions`/`amcat_submit`'s exact response shape and
  /// semantics (same "sections" list, same submit/scoring contract), so it
  /// reuses `AmcatRemoteDataSource` rather than a new datasource class. No
  /// auth required; `cocubes_submit` is `@csrf_exempt`.
  static const String cocubesQuestions = '/activities/cocubes/questions/';
  static const String cocubesSubmit = '/activities/cocubes/submit/';

  /// W014 — AI Speaking (`analyze_speaking`, `activities/views.py:1629-1685`,
  /// `activities/urls.py:28`). `@login_required @require_POST`, **not**
  /// `@csrf_exempt` (verified directly — unlike the mock-quiz family above),
  /// so callers must send `X-CSRFToken`. Accepts `multipart/form-data`
  /// (`audio`, `duration_seconds`, `pause_count`, `client_transcript`,
  /// `language`, `reference_text`). Responds `200` even on a rejected
  /// submission (e.g. no meaningful speech) — the body's own `"success"`
  /// field is authoritative, not the HTTP status.
  static String analyzeSpeaking(int exerciseId) => '/activities/exercise/$exerciseId/analyze/speaking/';

  /// W015 — AI Writing (`analyze_writing`, `activities/views.py:1690-1767`,
  /// `activities/urls.py:29`). Same auth/CSRF shape as `analyzeSpeaking`
  /// (`@login_required @require_POST`, not `@csrf_exempt`). Accepts
  /// `multipart/form-data` (`text`, `language`, `reference_text`, and
  /// `previous_improved_passage` only when a prior successful analysis in
  /// this session produced one — mirrors `window.lastImprovedPassage` in
  /// `writing.js`, an anti-copy-paste check server-side). Also responds
  /// `200` on a rejected submission (`success: false`) — **except** two
  /// narrower cases confirmed by reading the view directly: `_module_access_denied`
  /// returns `403`, and one specific exercise
  /// (`"Proposal Section Writing"` under `"Proposal and Bid Writing"`)
  /// enforces a distinct 150-200 *word* rule server-side and returns `400`
  /// — both still JSON `{success:false, error}` bodies, but surfaced by
  /// this app's shared `ApiExceptionsInterceptor` as a generic
  /// `ForbiddenFailure`/`UnexpectedFailure` rather than that exact message,
  /// consistent with how every other endpoint in this app already handles
  /// a non-2xx status (not a W015-specific gap). Unlike `analyzeSpeaking`,
  /// **`score_25` is a top-level field of the response body, a sibling of
  /// `data`, not nested inside it** (verified directly against the view —
  /// `result['score_25'] = score_25`, with no equivalent write into
  /// `result['data']`) — confirmed by re-reading the source rather than
  /// assumed from `analyzeSpeaking`'s contract.
  static String analyzeWriting(int exerciseId) => '/activities/exercise/$exerciseId/analyze/writing/';

  /// W016 — AI Listening. Same `@login_required @require_POST`, not
  /// `@csrf_exempt` shape as `analyzeWriting`/`analyzeSpeaking`, but with a
  /// genuinely distinct error contract confirmed by reading
  /// `activities/views.py:1770-1908` directly: a missing or already-used
  /// `attempt_token` returns HTTP **409** (`{success:false, error}`, not
  /// 200) — verified separately rather than assumed identical to Speaking/
  /// Writing. `score_25`/`content_match_percent` are nested inside `data`
  /// (mutated in place — confirmed the same placement as `analyzeSpeaking`,
  /// **not** `analyzeWriting`'s top-level placement).
  static String analyzeListening(int exerciseId) => '/activities/exercise/$exerciseId/analyze/listening/';

  /// `exercise_detail` (`activities/views.py:1327-1364`,
  /// `activities/urls.py:22`) — a plain server-rendered **HTML** view, the
  /// only place `attempt_token` (a `secrets.token_hex(16)` minted fresh
  /// per page load) is produced; no JSON sibling exists. Fetching this
  /// page (with the app's existing authenticated session cookie — the
  /// same one a browser would use) and reading the embedded
  /// `<script type="application/json" id="listening-config">` JSON blob
  /// is a legitimate reuse of this existing, already-public endpoint —
  /// not a bypass of the anti-replay token, which the server validates
  /// identically regardless of client. See
  /// `AiListeningRemoteDataSource.fetchAttemptToken` and
  /// `docs/W016_AI_LISTENING.md` for the full reasoning.
  static String exerciseDetailPage(int exerciseId) => '/activities/exercise/$exerciseId/';

  /// W017 — AI Reading. Same `@login_required @require_POST`, not
  /// `@csrf_exempt` shape as `analyzeSpeaking`, multipart audio upload
  /// (mic recording, not a text answer). Confirmed directly:
  /// `score_25` is duplicated at **both** the top level and nested inside
  /// `data` (`activities/views.py:1966-1967`) — the same placement as
  /// `analyzeSpeaking`, unlike `analyzeWriting` (top-level only) or
  /// `analyzeListening` (nested only). No anti-replay `attempt_token` is
  /// involved at all — confirmed the `reading-config` embedded script
  /// (`templates/activities/modules/reading.html:263-268`) only carries
  /// `analyzeEndpoint`/`lessonsPath`, unlike Listening's `listening-config`.
  static String analyzeReading(int exerciseId) => '/activities/exercise/$exerciseId/analyze/reading/';

  /// W008 — Matching. `submit_exercise` (`activities/views.py:1413-1526`,
  /// `activities/urls.py:23`) — the generic, non-MCQ exercise submit
  /// endpoint every exercise type but MCQ still uses. `@login_required
  /// @require_POST`, not `@csrf_exempt`. Unlike `submitMcqExercise`, this
  /// endpoint trusts the client-sent `score`/`max_score` verbatim for
  /// `matching` (only `writing`/`timer` get server-side re-grading) — see
  /// `MatchingSubmissionResult`'s doc comment and
  /// `docs/EXERCISE_FEASIBILITY_AUDIT.md` §W008. Response is a flat JSON
  /// object (`status`/`score`/`max_score`/`percentage`/`attempt`/
  /// `customSummaryHtml`), not the `{success, data}` envelope the newer
  /// `/api/` endpoints use.
  static String submitExercise(int exerciseId) => '/activities/exercise/$exerciseId/submit/';

  /// Resume Parsing / ATS (`career_app.views`, mounted at `/resume-builder/`
  /// via `business_english_lms/urls.py:65-80`). Plain server-rendered HTML
  /// throughout — no JSON API. `@login_required` on every one of these;
  /// confirmed live (302, not 404, when hit unauthenticated).
  ///
  /// [resumeJobMatch] (`resume_job_match`, `career_app/views.py:718-818`) is
  /// the upload+analyze endpoint: a `multipart/form-data` POST with a
  /// `file` field (the resume) and an optional `text` field (job
  /// description), returning a direct 200 HTML render of either the result
  /// page (`resume_match_result.html`) or the upload page again with an
  /// `error` (`resume_builder.html`) — never a redirect, never JSON.
  static const String resumeBuilderHome = '/resume-builder/';
  static const String resumeJobMatch = '/resume-builder/match/';
  static const String resumeHistory = '/resume-builder/history/';

  /// `resume_reanalyze` (`career_app/views.py:844-896`), `@require_POST` —
  /// re-runs analysis on a resume already stored server-side (by id), no
  /// file re-upload needed. Same response shape as [resumeJobMatch].
  static String resumeReanalyze(int resumeId) => '/resume-builder/reanalyze/$resumeId/';

  /// Grammar (`subject_views.py`, mounted at `/subject/`). The 9 topics'
  /// text content is static (bundled as a JSON asset, see
  /// `GrammarDataSource`) — these two are the only genuinely dynamic,
  /// per-topic *media* endpoints, both `@login_required`, confirmed live
  /// (302, not 404, when hit unauthenticated). [subjectSlideImage]'s
  /// `fileName` is the real `NN.png` deck filename
  /// (`kGrammarSlideDeckCounts`); [subjectVideo] streams the topic's local
  /// `.mp4` with HTTP Range support for seeking.
  static String subjectSlideImage(String slug, String fileName) => '/subject/slides/$slug/$fileName';
  static String subjectVideo(String slug) => '/subject/video/$slug.mp4';

  /// Certifications (`skillup_assessment` app, mounted at
  /// `/skill-up/assessment/` via `business_english_lms/urls.py:32`
  /// — `path('skill-up/assessment/', include('skillup_assessment.urls'))`)
  /// — the real, live, `@login_required` JSON API backing the Skill Up
  /// page's `#section-certifications` anchor. Every path below verified
  /// directly against `skillup_assessment/urls.py` + `views.py`, not
  /// inferred.
  ///
  /// [certificationsStatus] (`api_certifications_status`, GET) returns
  /// every subject's status grouped by category — see
  /// `CertificationsRemoteDataSource`/the `certifications` feature's domain
  /// entities for the exact response shape.
  ///
  /// [certificateGenerate]/[certificateRegenerate]
  /// (`api_certificate_generate`/`api_certificate_regenerate`) are both
  /// `@require_http_methods(["POST"])`, **not** `@csrf_exempt`, and read the
  /// printed name from a form-encoded `certificate_name` field
  /// (`request.POST.get("certificate_name", "")`), not a JSON body — same
  /// `FormData` + `X-CSRFToken` technique as `ResumeRemoteDataSource`.
  ///
  /// [certificateDownload] (`certificate_download`, GET) serves the
  /// generated PDF as a binary `FileResponse` (`as_attachment=True`) —
  /// fetched as bytes through the app's own authenticated Dio client, the
  /// same technique `GrammarMediaDataSource.fetchSlideImage` already uses
  /// for other session-cookie-gated binary media.
  ///
  /// [certificationsHub] (`certifications_hub`, GET) is the plain
  /// server-rendered HTML hub page — used solely to prime the CSRF cookie
  /// before a POST when one isn't already set, the same technique
  /// `ResumeRemoteDataSource._ensureCsrfCookie` uses via `resumeBuilderHome`.
  static const String certificationsHub = '/skill-up/assessment/';
  static const String certificationsStatus = '/skill-up/assessment/api/status/';
  static String certificateGenerate(String subject) => '/skill-up/assessment/api/$subject/certificate/generate/';
  static String certificateRegenerate(String subject) =>
      '/skill-up/assessment/api/$subject/certificate/regenerate/';
  static String certificateDownload(String subject) => '/skill-up/assessment/$subject/certificate/download/';

  /// JAM — "Just A Minute" (`jam_app`, mounted at `/jam/` via
  /// `business_english_lms/urls.py:39`, `path('jam/', include('jam_app.urls'))`).
  /// Plain server-rendered HTML throughout **except** [jamSaveAudio], the
  /// only JSON-returning endpoint in this app — confirmed directly against
  /// `jam_app/views.py`/`jam_app/urls.py`. None of the paths below are
  /// `@login_required` or `@csrf_exempt` except where noted; `get_app_user`
  /// falls back to `User.objects.first()` for an anonymous request, so a
  /// real authenticated session (the app's normal cookie-based auth) is what
  /// makes these behave correctly, same as everywhere else in this app.
  /// **Access gating**: only `jam:home`/`jam:dashboard` (neither used by
  /// this client) call `_can_access_workshop(user, 'jam')` — confirmed by
  /// reading every view in `jam_app/views.py`; the session/topic endpoints
  /// below perform no such check server-side. This client still surfaces a
  /// locked state defensively (see `JamLockedView`) in case a
  /// `ForbiddenFailure` is ever returned, but does not depend on the
  /// endpoints below to enforce the gate — access is effectively gated one
  /// layer up, by however the human-wired entry point reaches this feature
  /// (see `ActivityDetailScreen`'s own `ForbiddenFailure` → `_LockedState`
  /// handling for the parent Activity).
  ///
  /// [jamSessionStart] (`jam:jam_session`, `jam_session()`,
  /// `jam_app/views.py:180-188`) — GET, picks `random.choice` from
  /// `Topic.objects.filter(is_active=True)`, creates a `JAMSession`, and
  /// renders `templates/jam/session.html` (200, not a redirect) with the
  /// chosen topic and new session embedded (`SESSION_ID`, topic title/
  /// description/difficulty) — parsed by `parseJamSessionStartHtml`.
  static const String jamSessionStart = '/jam/session/start/';

  /// (`jam:jam_session_topic`, `jam_session_with_topic()`,
  /// `jam_app/views.py:191-194`) — same as [jamSessionStart] but for a
  /// specific `topic_id` (404s if inactive/missing), reached from the
  /// Topics list's "Practice Session" buttons.
  static String jamSessionStartWithTopic(int topicId) => '/jam/session/start/$topicId/';

  /// (`jam:save_audio`, `save_audio()`, `jam_app/views.py:197-227`) —
  /// `@require_POST`, **not** `@csrf_exempt`. The one real JSON endpoint:
  /// `multipart/form-data` with `session_id`, `audio` (file, optional),
  /// `duration` (seconds, int), `transcript` (optional — the web's own
  /// Web Speech API result; sent empty by this client, see
  /// `JamRemoteDataSource.saveAudio`'s doc comment for why that's safe),
  /// and `language` (defaults server-side to `'english'` if omitted).
  /// Responds `{"status": "ok", "session_id": <id>}` on success or
  /// `{"status": "error", "message": "Session not found"}` (HTTP 404) if
  /// `session_id` doesn't belong to the current user.
  static const String jamSaveAudio = '/jam/session/save-audio/';

  /// (`jam:complete_session`, `complete_session()`,
  /// `jam_app/views.py:634-704`) — GET (reached via an `<a href>` on the
  /// web, not a POST/form submit). Marks the session completed, generates
  /// AI feedback (Sarvam if `SARVAM_API_KEY` is set — confirmed still true,
  /// `jam_app/views.py:215-220` — falling back to rule-based scoring
  /// otherwise, `_rule_based_feedback`), and **redirects** (never returns
  /// JSON): to [jamSessionDetail] with `#ai-feedback` for a normal session —
  /// parsed by [JamRemoteDataSource.completeSession] — or, only for a
  /// session that's part of an `AssessmentGroup` (looked up server-side by
  /// `complete_session` itself, `jam_app/views.py:685-701` — this client
  /// never tells the server "this is an assessment stage"; the server
  /// already knows from the session id alone), onward to the **same URL
  /// shape as [jamAssessmentStart]'s redirect target** for stage 1→2/2→3
  /// (`templates/jam/session.html` again, `is_assessment: True`, `stage`
  /// incremented), or to `jam:assessment_result`
  /// (`templates/jam/assessment_result.html`) after stage 3 — this 3-way
  /// outcome is parsed by [JamRemoteDataSource.completeAssessmentStage]
  /// instead, used only when the calling session is known (client-side) to
  /// be part of the assessment flow (`JamSessionStart.stage != null`).
  /// This client relies on Dio's default `followRedirects: true` to land
  /// directly on the final HTML page either way.
  static String jamCompleteSession(int sessionId) => '/jam/session/complete/$sessionId/';

  /// (`jam:session_detail`, `session_detail()`, `jam_app/views.py:718-727`)
  /// — `@login_required`. Renders `templates/jam/session_detail.html` with
  /// the full scored result — parsed by `parseJamSessionResultHtml`. Not
  /// called directly by this client today (reached as [jamCompleteSession]'s
  /// redirect target instead), kept as a named constant for documentation
  /// and potential future direct use (e.g. viewing a past session from
  /// History, not built in this batch).
  static String jamSessionDetail(int sessionId) => '/jam/session/$sessionId/';

  /// (`jam:topics`, `topics_list()`, `jam_app/views.py:746-751`) — GET, no
  /// auth required. Renders `templates/jam/topics.html`: every active
  /// `Topic`, grouped into Easy/Medium/Hard sections — parsed by
  /// `parseJamTopicsHtml`.
  static const String jamTopics = '/jam/topics/';

  /// (`jam:history`, `history()`, `jam_app/views.py:730-743`) —
  /// `@login_required`. Renders `templates/jam/history.html`: the "Regular
  /// Sessions" tab lists every `completed=True` `JAMSession` that is **not**
  /// part of an `AssessmentGroup` (`assessment_easy/medium/hard__isnull`),
  /// each tagged with its topic's `badge-jam-{difficulty}` span — the same
  /// class the Topics page already uses. This client calls it for exactly
  /// one purpose: reproducing `get_jam_level_progress(user)`
  /// (`jam_app/views.py:59-81`) client-side — the distinct set of
  /// difficulties among a user's completed practice sessions is exactly
  /// what that function (and `start_assessment`'s eligibility gate) checks
  /// server-side — see `computeJamAssessmentEligibility`/
  /// `parseJamHistoryHtml`. No JSON `api_sessions` endpoint exists anywhere
  /// in `jam_app` (confirmed directly against `jam_app/urls.py`, which has
  /// no such path); this and every other JAM endpoint is plain
  /// server-rendered HTML.
  static const String jamHistory = '/jam/history/';

  /// (`jam:start_assessment`, `start_assessment()`, `jam_app/views.py:
  /// 230-280`) — GET. Gated server-side on `get_jam_level_progress(user)`
  /// returning true for all 3 difficulties (one completed practice
  /// `JAMSession` at each of easy/medium/hard); if not yet eligible it sets
  /// a Django flash message and **redirects to `jam:dashboard`** (never
  /// creates an `AssessmentGroup`). If eligible, creates 3 fresh
  /// `JAMSession`s (one per difficulty, `random.choice` within that
  /// difficulty — same selection logic as [jamSessionStart]) grouped into a
  /// new `AssessmentGroup`, and redirects to `jam:assessment_session` for
  /// the easy-stage session — `templates/jam/session.html` again (the exact
  /// same template [jamSessionStart] renders), with extra context
  /// (`is_assessment: True`, `stage: 1`) this client reads via
  /// `parseJamAssessmentStageHtml`. This client gates the "Start Assessment"
  /// action on its own client-side eligibility check before ever calling
  /// this (see `JamAssessmentEligibilityController`), but still parses
  /// defensively in case of a race (e.g. the user's last practice session
  /// was deleted between the eligibility check and this call).
  static const String jamAssessmentStart = '/jam/assessment/start/';

  /// (`jam:assessment_result`, `assessment_result()`, `jam_app/views.py:
  /// 707-717`) — `@login_required`. Renders `templates/jam/
  /// assessment_result.html` for an already-completed `AssessmentGroup` —
  /// the same template [JamRemoteDataSource.completeAssessmentStage] parses
  /// inline when stage 3 finishes; this constant is for revisiting a past
  /// assessment from History (not built until this batch).
  static String jamAssessmentResult(int assessmentId) => '/jam/assessment/result/$assessmentId/';

  /// (`jam:profile`, `profile_view()`, `jam_app/views.py:754-771`) — no
  /// `@login_required` (falls back to `get_app_user`'s single-user-mode
  /// resolution like [jamResetProgress]), GET renders `templates/jam/
  /// profile.html` pre-filled from `UserProfile`/`User`; POST (same URL)
  /// updates `bio` (`ProfileForm`) plus `first_name`/`last_name`/`email`
  /// (read directly off `request.POST`, not part of `ProfileForm` itself)
  /// and redirects (302) on success. **Confirmed never linked from any JAM
  /// template** (`grep -rn "jam:profile" templates/jam/*.html` → zero
  /// hits, unlike [jamHistory] which dashboard.html does link) — a real,
  /// fully functional page the web itself just never surfaces a nav entry
  /// for. On validation failure the view re-renders the same page (200)
  /// with the **unchanged** old values (the template reads `user.*`/
  /// `profile.bio` directly, never `form.*` or `form.errors` — confirmed by
  /// reading `templates/jam/profile.html` in full), so a failed submission
  /// looks identical to a no-op, not an error — reproduced as-is, not
  /// invented extra error UI the real page doesn't have.
  static const String jamProfile = '/jam/profile/';

  /// (`jam:delete_session`, `delete_session()`, `jam_app/views.py:
  /// 779-796`) — `@require_POST`. Deletes one `JAMSession` (and its audio
  /// file) and adjusts `UserProfile.total_sessions`/`total_minutes`
  /// accordingly if it was completed; redirects to `HTTP_REFERER` on the
  /// web (meaningless for this client — treated as plain success/refetch).
  /// Confirmation wording differs by caller on the web (`history.html`:
  /// `"Delete this session?"`; `dashboard.html`: `"Are you sure?"`) — this
  /// client uses History's own wording since that's the page it's reached
  /// from here.
  static String jamDeleteSession(int sessionId) => '/jam/session/delete/$sessionId/';

  /// (`jam:delete_assessment`, `delete_assessment()`, `jam_app/views.py:
  /// 801-821`) — `@require_POST`. Deletes an `AssessmentGroup` and all 3 of
  /// its sessions, adjusting profile stats the same way
  /// [jamDeleteSession] does per completed session; redirects to
  /// `jam:history` on success. Web confirmation wording: `"Delete this
  /// assessment and all its sessions?"`.
  static String jamDeleteAssessment(int assessmentId) => '/jam/assessment/delete/$assessmentId/';

  /// (`jam:reset_progress`, `reset_progress()`, `jam_app/views.py:94-112`)
  /// — `@login_required`, `@require_POST` (a prior, now-fixed version of
  /// this view had neither — see the view's own comment). Deletes **every**
  /// `JAMSession` for the user and zeroes `UserProfile.total_sessions`/
  /// `total_minutes`; redirects to `jam:dashboard` on success. Web
  /// confirmation wording: `"Are you sure you want to reset all your
  /// progress?"`, with a standing warning: "Resetting your progress will
  /// permanently delete all your sessions, scores, and practice history.
  /// This action cannot be undone."
  static const String jamResetProgress = '/jam/reset-progress/';

  /// The real "ARIA"/"Buddy" chat assistant (`riya_bot` app, mounted at the
  /// project root via `business_english_lms/urls.py`
  /// — `path('', include('riya_bot.urls'))`). `riya_bot/urls.py` maps this
  /// exact path to `views.riya_chat` — confirmed live: an anonymous POST
  /// returns 200 with a real reply. `@csrf_exempt` (no `X-CSRFToken`
  /// needed) and no `@login_required` (works anonymously; `is_employer` is
  /// computed server-side from `request.user`, so an authenticated
  /// session's cookie is what actually drives it, not any client-sent
  /// field).
  ///
  /// A streaming SSE sibling exists at [riyaChatStream] (`views.
  /// riya_chat_stream`) — the real web's actual default chat path
  /// (`BOTscript.js`'s `requestAssistantReplyStream`, wired to every normal
  /// send); this plain JSON endpoint is this app's own non-streaming
  /// alternative. Verified directly against `riya_bot/views.py`/
  /// `riya_bot/urls.py`, not inferred: this view reads `message`/`page`/
  /// `path`/`hash`/`input_mode`/`language` from the JSON body, but **does
  /// not read `history` or `conversation_id` at all** (only
  /// [riyaChatStream] does) — this app still sends both on every call for
  /// forward-compatibility and shape-fidelity with the documented
  /// contract, but conversation continuity for this endpoint is purely a
  /// client-side (Riverpod, in-memory) concept today, not server-enforced.
  static const String riyaChat = '/api/riya/chat/';

  /// `riya_bot.views.riya_chat_stream` (`riya_bot/urls.py`) — the real
  /// web's actual default chat path (confirmed directly:
  /// `static/js/BOTscript.js`'s `requestAssistantReplyStream` is what every
  /// normal send calls, not the plain [riyaChat]). `@csrf_exempt`, no
  /// `@login_required`, same `is_employer`-from-session behavior as
  /// [riyaChat]. POST body (confirmed against both the view and the real
  /// JS that builds it): `message`/`page`/`path`+`hash`/`input_mode`/
  /// `language`/`is_employer`/`conversation_id`/`history` (list of
  /// `{role, content}`) — `assistant_role`/`role_context` are also sent by
  /// the real JS but the view never reads them (confirmed: absent from
  /// every `body.get(...)` call in `riya_chat_stream`), so this app omits
  /// them.
  ///
  /// Response: `Content-Type: text/event-stream`, each event one line
  /// `data: <json>\n\n` (verified against `riya_bot/riya_assistant.py`'s
  /// `_sse`/`_done` helpers inside `stream_assistant_response`, not
  /// guessed):
  /// - `{"t": "<token>"}` — one streamed token to append to the
  ///   in-progress reply.
  /// - `{"reply": "...", "actions": [...], "source": "..."}` — a
  ///   fast-path's single complete event (no streaming tokens preceded
  ///   it).
  /// - `{"done": true, "reply": "...", "actions": [...], "source": "ai"}`
  ///   — the AI path's completion event, sent after its own `{"t": ...}`
  ///   tokens.
  /// - A final literal `data: [DONE]\n\n` line always ends the stream
  ///   (after whichever of the two complete-event shapes above was sent).
  ///
  /// **`<LANG:code>` interception**: the model's own streamed text can
  /// contain a literal `<LANG:xx>` directive (confirmed in
  /// `BOTscript.js`'s token-handling branch, not server-stripped) — the
  /// real web regex-matches it out of the accumulated display text and
  /// switches its language selector; this app reproduces that same
  /// client-side interception rather than leaving the raw tag visible.
  static const String riyaChatStream = '/api/riya/chat/stream/';

  /// `riya_bot.views.riya_voice_transcribe` — `@csrf_exempt`,
  /// `@require_POST`, no `@login_required`. Body (re-verified this session
  /// against both the view and the real JS that builds it, `BOTscript.js`'s
  /// `MediaRecorder.onstop` handler): `audio` (base64, no `data:` URI
  /// prefix — `_transcribe_with_sarvam` in `riya_bot/agents/utils.py` also
  /// tolerates one if present, but the real JS's own `blobToBase64` already
  /// strips it before sending), `mime_type` (default `"audio/webm"`),
  /// `language` (default `"english"`), optional `client_transcript` (the
  /// browser's own Web Speech API result, used as a fallback — see below).
  /// `file_name` is also sent by the real JS but the view never reads it
  /// (confirmed: absent from every `body.get(...)` call), so this app
  /// omits it. Always 200 on a handled request: `{success: true, text,
  /// source: "sarvam"}` on a real Sarvam STT result; if Sarvam itself
  /// errors, falls back to the given `client_transcript` if non-empty
  /// (`{success: true, text, source: "browser_fallback"}` — this app has
  /// no browser STT to supply here, so `client_transcript` is always
  /// omitted and this fallback branch is unreachable from this client),
  /// otherwise `{success: false, error, source: "stt_error"}` (still HTTP
  /// 200, not an error status).
  ///
  /// **Confirmed real web bug, deliberately not reproduced**: the real
  /// JS reads the transcript as `(await response.json()).data.text`, but
  /// the view above returns `text` at the **top level** — there is no
  /// `data` wrapper anywhere in this response (re-read directly, not
  /// inferred). `raw.data` is therefore always `undefined` in the real
  /// browser, `payload.text` throws, and the whole call falls into the
  /// JS's own `catch` block — meaning **server-side voice transcription
  /// never actually reaches the user on the real web**; it only "works"
  /// today via the browser's separate, unrelated `SpeechRecognition`
  /// fast-path, which bypasses this endpoint entirely. This client reads
  /// the field the server actually sends (`text`, top level) rather than
  /// copying the browser's broken path — the server's own contract is
  /// internally consistent (same flat shape as every other endpoint in
  /// this app) and demonstrably correct when read as written; reproducing
  /// the JS's accidental property-path typo would ship a feature that
  /// always fails for no reason tied to this app's own behavior. See this
  /// session's report for the full reasoning.
  ///
  /// **Production-verified live** (read-only, zero personal audio): fed
  /// this endpoint fully synthetic audio — the exact WAV bytes
  /// [riyaTts] itself generated for a generic phrase a moment earlier, no
  /// real microphone recording involved at any point — and got back
  /// `{success: true, text: "Hello, this is a voice test.", source:
  /// "sarvam", language: "english"}`: the top-level `text`/`source`
  /// fields exactly as implemented above (no `data` wrapper), and the
  /// transcribed text round-tripped back to the original phrase exactly,
  /// confirming the full Sarvam TTS→STT pipeline really works end to end.
  ///
  /// **Format matters here, confirmed in a later session**: this app's own
  /// default mobile recorder output (`.m4a`/AAC-LC, via `package:record`)
  /// was fed to this same endpoint/session and consistently got back
  /// `{success: false, error: "...temporarily unavailable for this
  /// language.", source: "stt_error"}` — reproduced across retries and both
  /// `english`/`hindi`, while a `.wav` file to the exact same endpoint
  /// succeeded every time. So despite the `mime_type` field accepting any
  /// string, the real Sarvam call this view makes (`transcribe_with_sarvam`,
  /// `riya_bot/agents/utils.py:261`) is NOT actually format-agnostic in
  /// practice today — ARIA's recorder (`ariaAudioRecorderServiceProvider`)
  /// therefore records to `.wav`, not this app's usual `.m4a`.
  static const String riyaVoiceTranscribe = '/api/voice/transcribe/';

  /// `riya_bot.views.riya_tts` — `@csrf_exempt`, `@require_POST`, no
  /// `@login_required`. Body: `text`, `language` (default `"english"`),
  /// `speaker` (default `"priya"`, one of a fixed Sarvam bulbul:v3 voice
  /// list — `generate_riya_tts_audio`, `riya_bot/agents/utils.py:1084-1091`
  /// — this app always omits it, letting the server default apply, same
  /// as the real JS). Note: [riyaChat]'s own JSON response already embeds
  /// a generated `audio` field (base64) for the reply text whenever
  /// `want_audio` isn't explicitly `false` and `SARVAM_API_KEY` is
  /// configured (`riya_bot/views.py:86-100`) — this endpoint exists for
  /// synthesizing arbitrary other text on demand, not as the only way to
  /// get a reply spoken. 400 if `text`/the server API key is missing;
  /// otherwise 200 with `{success, audio (base64 WAV or null), language,
  /// available}` — `success`/`available` both false (not an error status)
  /// when Sarvam itself returns nothing.
  ///
  /// **Same confirmed real web bug as [riyaVoiceTranscribe], re-verified
  /// directly against `BOTscript.js`'s `speakText()`**: the real JS reads
  /// `(await response.json()).data.audio`, but this view returns `audio`
  /// at the **top level** — no `data` wrapper here either. Every real
  /// browser call to this endpoint throws on the undefined access and
  /// falls into `.catch(() => speakWithBrowser(text))` — on the real web,
  /// a *streamed* reply (the now-default chat path, see [riyaChatStream])
  /// is therefore **always** spoken via the browser's own
  /// `speechSynthesis` voice, never this endpoint's real Sarvam audio.
  /// Same reasoning as [riyaVoiceTranscribe]: this app reads the field the
  /// server actually sends, using the real audio where the real web's own
  /// integration bug silently discards it, rather than reproducing a
  /// property-path typo that serves no one's actual intent.
  ///
  /// **Production-verified live** (read-only, zero personal data): POSTed
  /// a generic phrase ("Hello, this is a voice test.") and got back
  /// `{success: true, audio: "(base64 wav)", available: true, language:
  /// "english", emotion: "..."}` — confirming the top-level `audio` field
  /// and no `data` wrapper, exactly as implemented above. `emotion` is an
  /// extra field beyond what's documented here; this client doesn't use
  /// it (nothing in the real web's own `speakText()` reads it either).
  static const String riyaTts = '/api/voice/tts/';

  /// Roleplay Workshop (Storytelling / Situations / Roleplay sub-features) —
  /// `activities/roleplay_urls.py`, mounted at `/roleplay/`
  /// (`business_english_lms/urls.py:40`,
  /// `path('roleplay/', include('activities.roleplay_urls'))`). Both
  /// endpoints are `@login_required`, **not** `@csrf_exempt` — same
  /// `X-CSRFToken` + session-cookie shape as [analyzeSpeaking].
  ///
  /// [roleplayPractice] (`roleplay_practice`, `activities/views.py:2028-2080`)
  /// generates the session content: `multipart/form-data` (`topic` — the
  /// sub-feature slug, `prompt`, `language`). Gated by
  /// `_can_access_workshop(user, 'roleplay')` — an access-denied hit returns
  /// **403** `{"success": false, "error": "..."}`; an unknown `topic` slug or
  /// (Roleplay-only) a prompt missing a second named character returns
  /// **400** `{"error": "..."}` (no `"success"` key at all on this one — a
  /// different shape from the 403 case, confirmed by reading the view
  /// directly). A normal 200 response is `{"topic", "used_prompt",
  /// "result": {...}}` — no `"success"` key on the happy path either.
  static const String roleplayPractice = '/roleplay/practice/';

  /// [analyzeRoleplay] (`analyze_roleplay`, `activities/views.py:2083-2124`)
  /// scores a recorded attempt. Confirmed by reading the view directly: it
  /// builds `SpeakingAgent()` — the exact same agent class [analyzeSpeaking]
  /// uses — and returns `JsonResponse(agent.safe_run(payload))` verbatim, so
  /// the request/response contract is otherwise identical to
  /// [analyzeSpeaking] (`multipart/form-data`: `audio`, `client_transcript`,
  /// `reference_text`, `duration_seconds`, `pause_count`, `language`, plus a
  /// `topic` field used only as this attempt's `ScoreRecord` label — always
  /// 200 with the body's own `"success"` field authoritative). Two
  /// confirmed differences from [analyzeSpeaking]: (1) **no**
  /// `_can_access_workshop`/plan gate at all on this endpoint — only
  /// `roleplayPractice` is plan-gated; (2) `score_25` is computed
  /// server-side for the `ScoreRecord` but is **never** written into the
  /// response body (unlike `analyze_speaking`, which injects it both
  /// top-level and inside `data`) — see `RoleplayAnalysisResult`'s doc
  /// comment.
  static const String analyzeRoleplay = '/roleplay/analyze/';

  /// Group Discussion — `GD_app`, mounted at `/gd/` via
  /// `business_english_lms/urls.py` (`path('gd/', include('GD_app.urls'))`).
  /// Confirmed directly against `GD_app/urls.py`/`views.py`/`consumers.py`/
  /// `routing.py`/`asgi.py`.
  ///
  /// [gdHome] (`GD_app:home`, `@login_required`) — plain server-rendered
  /// HTML (topic picker + recent sessions). Only fetched here to prime the
  /// `csrftoken` cookie before [gdCreateSession], the same
  /// `_ensureCsrfCookie`-style technique used elsewhere in this app (e.g.
  /// `ResumeRemoteDataSource`).
  static const String gdHome = '/gd/';

  /// [gdCreateSession] (`GD_app:create_session`, `views.create_session`) —
  /// `@require_POST @login_required`, form-encoded (`topic`), **not**
  /// `@csrf_exempt`. Gated by `_can_access_workshop(user, 'gd')` — confirmed
  /// by reading the view directly, unlike Roleplay/JAM this gate is real and
  /// enforced on the exact endpoint this client calls, not just on an
  /// unused `home`/`dashboard` view. On success it's a redirect (302) to
  /// [gdRoom]'s path (`/gd/room/<id>/`) — that id is the only thing this
  /// client actually needs from this call, so it's parsed straight out of
  /// the `Location` header rather than pulled from an HTML render (this
  /// call uses `followRedirects: false` to read it). On the access-denied
  /// branch it instead redirects to `/activities/?locked=1`
  /// (`_locked_redirect`) — same target, confirmed by reading
  /// `activities/views.py` directly. An empty `topic` redirects back to
  /// [gdHome] instead; this client never sends an empty topic.
  static const String gdCreateSession = '/gd/create/';

  /// [gdRoom] (`GD_app:gd_room`, `views.gd_room`) — plain server-rendered
  /// HTML room shell; the actual discussion happens entirely over the
  /// WebSocket (see [gdWebSocketPath]), so this client has no reason to GET
  /// this page itself — kept as a named constant purely to document where
  /// [gdCreateSession]'s `Location` redirect points.
  static String gdRoom(int sessionId) => '/gd/room/$sessionId/';

  /// [gdSessionReport] (`GD_app:session_report`, `views.session_report`) —
  /// `@login_required`, plain server-rendered HTML (`GD_app/report.html`),
  /// no JSON sibling. Scoped to the requesting user
  /// (`get_object_or_404(GDSession, id=session_id, user=request.user)`).
  /// Parsed by `parseGdReportHtml` — see that function's doc comment for
  /// exactly which markup is read.
  static String gdSessionReport(int sessionId) => '/gd/report/$sessionId/';

  /// [gdApiSessions] (`GD_app:api_sessions`, `views.api_sessions`) —
  /// `@login_required`, the one real JSON endpoint on this feature:
  /// `{"sessions": [{"id", "topic", "created_at", "is_active"}, ...]}`,
  /// already scoped server-side to `request.user`'s own sessions.
  static const String gdApiSessions = '/gd/api/sessions/';

  /// The WebSocket route backing the live discussion (`GD_app/routing.py`'s
  /// `websocket_urlpatterns`, matching `ws/GD_app/<session_id>/`). Confirmed
  /// directly against
  /// `business_english_lms/asgi.py`: this pattern is wired straight into
  /// `ProtocolTypeRouter`'s `"websocket"` branch
  /// (`AuthMiddlewareStack(URLRouter(gd_ws_patterns))`) with **no**
  /// additional path prefix — unlike every HTTP view above, this is
  /// **not** nested under `/gd/`. `AuthMiddlewareStack` authenticates the
  /// same way the rest of this app's session-cookie auth works: it reads
  /// the `Cookie` header sent on the WebSocket's initial HTTP upgrade
  /// request and resolves `scope['user']` from the Django session it
  /// names — there is no separate token/handshake message. `GDConsumer.
  /// connect()` then does one more check on top of "is this a logged-in
  /// user at all" — the connecting user must actually own `session_id`
  /// (`_is_session_owner`) — closing with code 4403 otherwise.
  static String gdWebSocketPath(int sessionId) => '/ws/GD_app/$sessionId/';

  /// AI Mock Interview (`career_app.views`, same `/resume-builder/` mount as
  /// the Resume Parsing endpoints above, `business_english_lms/urls.py:
  /// 68-77`). Every path verified directly against `career_app/views.py`
  /// (line numbers as of this session): `resume_start_interview`
  /// (929-957), `resume_camera_verified` (1021-1038, `@require_POST`),
  /// `resume_get_next_question` (1180-1311, `@require_GET`, `?next=true`
  /// advances to the next question), `resume_submit_answer` (1313-1369,
  /// `@require_POST`), `resume_record_violation` (1067-1142,
  /// `@require_POST`), `resume_violation_state` (1047-1064, `@require_GET`),
  /// `resume_upload_interview_video` (1145-1177, `@require_POST`,
  /// multipart), `resume_analytics` (1505-1601, plain HTML, no JSON
  /// sibling). None are `@csrf_exempt` — every POST needs `X-CSRFToken` +
  /// the `csrftoken` cookie, same as [resumeJobMatch].
  ///
  /// [resumeStartInterview] is a plain `@login_required` **GET** view (no
  /// `@require_POST`) that reads `rb_resume_id`/`rb_jd_id` out of
  /// `request.session` — both only ever set by [resumeJobMatch]/
  /// [resumeReanalyze] in this same cookie-jar session, so this feature is
  /// only reachable after a resume has already been analyzed through those
  /// two endpoints. On success it 302-redirects to `resume_interview_chat`
  /// (`career_app/views.py:959-972`), which itself calls
  /// `_ensure_resume_interview_questions` (creating the fixed Q1-10
  /// behavioural/experience questions before Q11-20 are generated lazily,
  /// one at a time, by [resumeGetNextQuestion] itself) — Dio's default
  /// `followRedirects: true` means a single GET here lands directly on that
  /// rendered `resume_interview.html` page, so no separate call to
  /// `resume_interview_chat` is needed. A blocked attempt (no Premium plan
  /// via `_can_access_interview`, or no parsed resume via
  /// `has_parsed_resume`) instead redirects to `pro_page`/`resume_builder`/
  /// `resume_job_match`, none of which render that page's own
  /// `id="camera-gate-screen"` marker — exactly like [resumeJobMatch]'s
  /// `isResumeMatchResultHtml` check, this marker's absence is this
  /// client's success/failure signal (see `mock_interview_html_parser.dart`).
  ///
  /// [resumeAnalytics] is likewise plain HTML (`resume_analytics.html`) —
  /// but the per-question breakdown is also embedded verbatim as JSON in
  /// `<script id="analytics-data" type="application/json">{{ json_data|safe
  /// }}</script>` (`templates/resume_analytics.html:524`), so only the
  /// summary numbers (`total_integer_score`/`avg_score`/`answered_count`/
  /// `total_questions`/`is_passed`/`years_exp`) need regex extraction from
  /// the surrounding markup — see `parseInterviewAnalyticsHtml`.
  ///
  /// `resume_transcribe_answer` (Sarvam server-side STT) and
  /// `resume_interview_chat` (the HTML SPA shell) are deliberately **not**
  /// added here — this client drives the interview with its own native UI
  /// and on-device `speech_to_text` instead of that server round-trip, and
  /// the shell page is never rendered natively (see the mock_interview
  /// feature's top-level doc comment).
  static const String resumeStartInterview = '/resume-builder/start-interview/';
  static const String resumeCameraVerified = '/resume-builder/camera-verified/';
  static const String resumeGetNextQuestion = '/resume-builder/get-question/';
  static const String resumeSubmitAnswer = '/resume-builder/submit-answer/';
  static const String resumeRecordViolation = '/resume-builder/record-violation/';
  static const String resumeViolationState = '/resume-builder/violation-state/';
  static const String resumeUploadInterviewVideo = '/resume-builder/upload-interview-video/';
  static const String resumeAnalytics = '/resume-builder/analytics/';
}
