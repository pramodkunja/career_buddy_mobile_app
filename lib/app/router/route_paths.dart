abstract final class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  /// W024 — Home (`templates/home.html` / `{% url 'home' %}`,
  /// `activities/views.py:76 home()`). Distinct from [dashboard] and from
  /// [splash] — on the web, `/` (home) branches server-side on
  /// `user.is_authenticated` and is reachable by *both* logged-out and
  /// logged-in users showing different content, exactly like [dashboard]
  /// and [activities] are reachable only once authenticated. See
  /// [universalRoutes]'s doc comment for how the redirect guard
  /// distinguishes this from the pre-login-only [publicRoutes].
  static const String home = '/home';

  // Reachable from the login screen (`register`/`password_reset`/
  // `employer_portal:employer_login` in `templates/users/login.html`).
  // `employerLogin` still renders its real screen; `register` remains a
  // `ComingSoonScreen` (see `app_router.dart`) pending Phase 1's
  // registration-form work, and `passwordReset` now starts a real 4-step
  // flow (see the block below).
  static const String register = '/register';
  static const String passwordReset = '/password-reset';
  static const String employerLogin = '/employer-login';

  /// Password reset — `templates/registration/password_reset_done.html`.
  /// Reached after [passwordReset]'s request succeeds.
  static const String checkEmail = '/password-reset/check-email';

  /// Password reset step 3 — `templates/registration/
  /// password_reset_confirm.html`. Unlike the web (which reaches this via
  /// the emailed link's own `uidb64`/`token` URL segments), this app has no
  /// app-link/universal-link verification configured against the
  /// production host, so the user pastes the link's text here instead —
  /// see `ResetPasswordScreen`'s doc comment.
  static const String resetPasswordConfirm = '/password-reset/confirm';

  /// Password reset step 4 — `templates/registration/
  /// password_reset_complete.html`.
  static const String passwordResetComplete = '/password-reset/complete';

  /// Batch 5B — Employer Portal (`accounts_app.views.employer_register`,
  /// `templates/employer_login/signup.html`). Reachable from
  /// [employerLogin]'s own "Create Employer Account" link.
  static const String employerRegister = '/employer-register';

  /// The real post-login/-registration redirect target
  /// (`redirect('job_home')`, `/employer-home/`) — the Recruiter Portal
  /// landing page (`templates/jobs/employer_home.html`), reachable by both
  /// auth states like [home], just for the employer side. See
  /// [universalRoutes].
  static const String employerHome = '/employer-home';

  /// `jobs_app.views.employer_dashboard` (`@login_required(login_url=
  /// 'employer_portal:employer_login')`, plus an in-view check that
  /// `session['portal'] == 'employer'`) — see [employerProtectedRoutes].
  static const String employerDashboard = '/employer-dashboard';

  // Linked from the employer sidebar (`templates/employer_base.html:
  // 214-238`). All real, built screens — `employerJobCreate` (built
  // against the live production form, not this repo's much smaller
  // committed `JobPostingForm` — see `ApiEndpoints.employerJobCreate`'s
  // doc comment), `employerAllApplications`, `employerJobOpenings`, and
  // `employerSearchCandidates`. `employerJobCreate`/`employerAllApplications`/
  // `employerSearchCandidates` are `@login_required(login_url=
  // 'employer_portal:employer_login')` on the web — see
  // [employerProtectedRoutes]. `employerJobOpenings` is the one exception —
  // see its own doc comment below.
  static const String employerJobCreate = '/employer-jobs/new';

  /// `jobs_app.views.job_edit` (`ApiEndpoints.employerJobEdit`) — reuses
  /// `PostNewJobScreen` in edit mode (`jobId` non-null), not a second form.
  /// Employer-only, same as every other per-job action — see
  /// [employerProtectedRoutes].
  static const String employerJobEditPattern = '/employer-jobs/:id/edit';
  static String employerJobEdit(int jobId) => '/employer-jobs/$jobId/edit';

  static const String employerAllApplications = '/employer-applications';

  /// `jobs_app.views.job_applications` — per-job candidate list, reached
  /// from a Dashboard job card's applications badge. Reuses
  /// [employerApplicationDetail] for the "Review Submission" destination.
  static const String employerJobApplicationsPattern = '/employer-jobs/:id/applications';
  static String employerJobApplications(int jobId) => '/employer-jobs/$jobId/applications';

  /// `jobs_app.views.job_detail` (`employer_portal:job_detail`) — the
  /// public job listing + apply page, reachable by anyone regardless of
  /// auth state. No natural web-parity entry point exists in Flutter yet
  /// (Job Openings is still a placeholder — same situation
  /// [employerApplicationDetailPattern] was in before this list existed).
  static const String publicJobDetailPattern = '/jobs/:id';
  static String publicJobDetail(int id) => '/jobs/$id';

  /// `jobs_app.views.my_application_detail` — student-facing, reached from
  /// the status-update email. No natural in-app entry point exists yet
  /// (the student dashboard's own activity list doesn't surface job
  /// applications — confirmed by reading `dashboard.html` directly).
  static const String myApplicationDetailPattern = '/my-applications/:id';
  static String myApplicationDetail(int id) => '/my-applications/$id';

  /// `jobs_app.views.employer_profile_edit` — the nav-drawer "Company
  /// Profile" destination, for a profile that's already complete. See
  /// [employerCompanyProfileCreate] for the other real web view sharing the
  /// same template.
  static const String employerCompanyProfile = '/employer-company-profile';

  /// `jobs_app.views.employer_profile_create` — reached by push from the
  /// employer dashboard's "complete your profile" prompt
  /// (`EmployerDashboardScreen`'s `_ProfileIncompleteView`), not from the
  /// nav drawer. Same `EmployerCompanyProfileScreen`, `isCreate: true`.
  static const String employerCompanyProfileCreate = '/employer-company-profile/create';

  /// `jobs_app.views.job_openings` — despite living under the `employer_urls`
  /// module and this constant's name (kept as-is to avoid a wider rename
  /// across the router/nav drawer/tests for a Phase 1 navigation fix), the
  /// real view is plain `@login_required` with no employer-portal-session
  /// check at all — confirmed live: a plain student account reaches it with
  /// a 200. It is therefore deliberately left OUT of
  /// [employerProtectedRoutes] (unlike every other constant in this block)
  /// so both roles can reach it, matching that exact contract — see
  /// `JobOpeningsScreen`'s own doc comment, which confirms the screen/
  /// controller/datasource are already fully role-agnostic.
  static const String employerJobOpenings = '/employer-job-openings';
  static const String employerSearchCandidates = '/employer-candidates';

  /// `jobs_app.views.application_detail` — the one employer screen this
  /// session actually built (not a `ComingSoonScreen`); see
  /// `EmployerApplicationDetailScreen`'s doc comment. No natural web-parity
  /// entry point exists in Flutter yet (`employerAllApplications` is still
  /// a placeholder) — reachable today only by a direct `context.push` with
  /// a known application id, same as this app's other detail-pattern
  /// routes before their own list screen existed.
  static const String employerApplicationDetailPattern = '/employer-applications/:id';
  static String employerApplicationDetail(int id) => '/employer-applications/$id';

  static const String activities = '/activities';
  static const String activityDetailPattern = '/activities/:id';

  /// Mirrors the real web's own URL shape — `activities/urls.py`:
  /// `<int:activity_pk>/sub/<int:sub_pk>/` (`sub_activity_detail`) — which
  /// genuinely requires both ids; there is no single-id lookup route on
  /// the real web at all (the earlier single-id Flutter route only ever
  /// worked against the JSON `sub_activity_detail_api` sibling, confirmed
  /// not deployed to production — see `ApiEndpoints.subActivityDetail`'s
  /// doc comment).
  static const String subActivityDetailPattern = '/activities/:activityId/sub/:subId';
  static const String mcqExercisePattern = '/activities/exercise/:id';

  static String activityDetail(int id) => '/activities/$id';
  static String subActivityDetail(int activityId, int subActivityId) => '/activities/$activityId/sub/$subActivityId';
  static String mcqExercise(int id) => '/activities/exercise/$id';

  /// W014 — AI Speaking. Two path segments after `/activities/exercise/`
  /// (`:id/speaking`), so this can never structurally collide with
  /// `mcqExercisePattern` (`:id` only, one segment) regardless of
  /// declaration order — unlike the W013 `/activities/workshop` bug, see
  /// `workshop_route_order_test.dart`. `subActivityId`/`previousAttempt`
  /// travel via `context.push`'s `extra` (see `app_router.dart`), not the
  /// URL — the caller (`SubActivityDetailScreen`) already holds that exact
  /// `ExerciseAttempt` from the same `sub_activity_detail_api` response it
  /// built its exercise tiles from, so there is nothing to re-fetch or
  /// re-encode.
  static const String aiSpeakingPattern = '/activities/exercise/:id/speaking';
  static String aiSpeaking(int exerciseId) => '/activities/exercise/$exerciseId/speaking';

  /// W015 — AI Writing. Same collision-safety reasoning as
  /// `aiSpeakingPattern`: two path segments after
  /// `/activities/exercise/:id/`, so it can never structurally collide
  /// with `mcqExercisePattern` regardless of declaration order.
  static const String aiWritingPattern = '/activities/exercise/:id/writing';
  static String aiWriting(int exerciseId) => '/activities/exercise/$exerciseId/writing';

  /// W016 — AI Listening. Same collision-safety reasoning as
  /// `aiSpeakingPattern`/`aiWritingPattern`.
  static const String aiListeningPattern = '/activities/exercise/:id/listening';
  static String aiListening(int exerciseId) => '/activities/exercise/$exerciseId/listening';

  /// W017 — AI Reading. Same collision-safety reasoning as the other
  /// three AI-module routes.
  static const String aiReadingPattern = '/activities/exercise/:id/reading';
  static String aiReading(int exerciseId) => '/activities/exercise/$exerciseId/reading';

  /// W008 — Matching. Same collision-safety reasoning as the AI-module
  /// routes: two path segments after `/activities/exercise/:id/`, so it
  /// can never structurally collide with `mcqExercisePattern`.
  static const String matchingExercisePattern = '/activities/exercise/:id/matching';
  static String matchingExercise(int exerciseId) => '/activities/exercise/$exerciseId/matching';

  /// W009 — Vocabulary Bingo. Same collision-safety reasoning as the other
  /// per-exercise-type routes: two path segments after
  /// `/activities/exercise/:id/`, so it can never structurally collide
  /// with `mcqExercisePattern`.
  static const String bingoExercisePattern = '/activities/exercise/:id/bingo';
  static String bingoExercise(int exerciseId) => '/activities/exercise/$exerciseId/bingo';

  /// W010 — Fill in the Blank. Same collision-safety reasoning as the
  /// other per-exercise-type routes: two path segments after
  /// `/activities/exercise/:id/`, so it can never structurally collide
  /// with `mcqExercisePattern`.
  static const String fillBlankExercisePattern = '/activities/exercise/:id/fill-blank';
  static String fillBlankExercise(int exerciseId) => '/activities/exercise/$exerciseId/fill-blank';

  /// Generic Writing (`Exercise.exercise_type == 'writing'` under an
  /// ordinary, non-module Activity — not the AI Writing module, which
  /// keeps its own `aiWritingPattern`). Same collision-safety reasoning as
  /// the other per-exercise-type routes: two path segments after
  /// `/activities/exercise/:id/`, so it can never structurally collide
  /// with `mcqExercisePattern`.
  static const String genericWritingExercisePattern = '/activities/exercise/:id/generic-writing';
  static String genericWritingExercise(int exerciseId) => '/activities/exercise/$exerciseId/generic-writing';

  /// Timer (`Exercise.exercise_type == 'timer'`, display label "Timed
  /// Activity"). Same collision-safety reasoning as the other
  /// per-exercise-type routes: two path segments after
  /// `/activities/exercise/:id/`, so it can never structurally collide
  /// with `mcqExercisePattern`.
  static const String timerExercisePattern = '/activities/exercise/:id/timer';
  static String timerExercise(int exerciseId) => '/activities/exercise/$exerciseId/timer';

  /// W013 — the dedicated Interactive Workshop page
  /// (`workshop_dashboard`, `/activities/workshop/`,
  /// `templates/activities/workshop_dashboard.html`) — distinct from
  /// `activitiesWithCategory('workshop')`, which is the dashboard Quick
  /// Start chip's destination (the regular Activities list, filtered).
  /// Not linked from anywhere else reachable in the web's own navigation
  /// (confirmed: no template links to it except a "back" link from inside
  /// the Role Play feature) — this app surfaces it via a real entry point
  /// on the dashboard instead (`dashboard_screen.dart`), a deliberate
  /// discoverability adaptation, not invented functionality.
  static const String workshopDashboard = '/activities/workshop';

  /// Mirrors the web dashboard's "Quick Start" links
  /// (`dashboard.html:283-303`, `{% url 'activity_list' %}?category=...`).
  static String activitiesWithCategory(String category) => '/activities?category=$category';

  // Linked from the dashboard's "View & Apply" job action
  // (`dashboard.html:142`, `{% url 'employer_portal:job_detail' job.pk %}`),
  // but a Job Detail screen doesn't exist in Flutter yet — and the
  // dashboard API's job objects carry no id to deep-link to even once one
  // does (see `docs/BACKEND_CONTRACT_dashboard.md`). Placeholder, same
  // pattern as `register`/`passwordReset`/`employerLogin`.
  static const String jobDetail = '/jobs/detail';

  // Linked from the Activities list's Free-Plan banner and Upgrade-Required
  // dialog (`{% url 'pro_page' %}` in `templates/activities/list.html`), and
  // from the dashboard's subscription-renewal surfaces. No Pro/Membership
  // screen exists in Flutter yet — placeholder, same pattern as above.
  static const String pro = '/pro';

  /// The hub of every implemented mock test (W020 OOP Mastery + W021's 24
  /// subjects, `kQuizSubjects`) — this app's single-level stand-in for the
  /// web's own multi-hop "Skill Up hub → Tech Center → per-subject guide
  /// page" navigation (see `MockTestsHubScreen`'s doc comment). Linked from
  /// the dashboard (`dashboard_screen.dart`).
  static const String mockTestsHub = '/mock-tests';

  /// W020 — OOP Mastery Mock Test. No id parameter: the backend has a
  /// single fixed endpoint pair for this quiz
  /// (`/activities/oop-quiz/questions/`, `.../submit/`), not a
  /// per-instance resource — see `ApiEndpoints.oopQuizQuestions`.
  static const String oopMasteryMockTest = '/mock-tests/oop-mastery';

  /// W021 — Subject Quiz. `subject` is the backend slug
  /// (`/activities/quiz/<subject>/...`, one of `kQuizSubjects`).
  static const String subjectQuizPattern = '/mock-tests/subject/:subject';
  static String subjectQuiz(String subject) => '/mock-tests/subject/$subject';

  /// W022 — AMCAT Mock Test. No id parameter, same reasoning as
  /// `oopMasteryMockTest`: a single fixed endpoint pair
  /// (`/activities/amcat/questions/`, `.../submit/`), not a per-instance
  /// resource.
  static const String amcatMockTest = '/mock-tests/amcat';

  /// W023 — CoCubes Mock Test. Same reasoning as `amcatMockTest`.
  static const String cocubesMockTest = '/mock-tests/cocubes';

  // Linked from the authenticated global navbar (`templates/base.html:
  // 113-157`); `profile` has no Flutter screen yet and still renders a
  // `ComingSoonScreen`, same pattern as `register`/`passwordReset`/
  // `employerLogin`. `skillUp`/`sitemap`/`grammar` are real as of Batch 7
  // — see their own doc comments below.
  static const String profile = '/profile';

  /// Batch 7 — Skill Up (`riya_bot.skillup_views.skillup_hub`,
  /// `templates/skillup/skillup_hub.html`). The real web page is a single
  /// static-HTML document (`static/001 Career Buddy/index.html`) with
  /// FOUR in-page anchor sections — Home/Featured, Sections in depth,
  /// Sitemap (`#section-sitemap`), and Certifications
  /// (`#section-certifications`) — not four separate URLs. `SkillUpScreen`
  /// reproduces that as one screen with 4 tabs; [sitemap] below opens the
  /// *same* screen pre-selected to its Sitemap tab, matching the web's own
  /// `{% url 'skill_up' %}#section-sitemap` nav link (a same-page anchor,
  /// not a distinct destination) as closely as a mobile tab structure can.
  static const String skillUp = '/skill-up';

  /// See [skillUp]'s doc comment — not a separate page on the web either.
  static const String sitemap = '/sitemap';

  /// Opens the same hub pre-selected to its "Sections in depth" tab — the
  /// nav drawer's "English & Vocabulary"/"Aptitude"/"Tech"/"Browse All"
  /// items all mirror web anchors (`#depth-english`/`#depth-aptitude`/
  /// `#depth-tech`/`#section-depth`) that are sub-anchors *within* this one
  /// section, not 4 distinct sections — so all 4 open this same tab, not 4
  /// different ones (a prior version of the drawer sent all 4 to [skillUp]
  /// itself, landing on the Home tab instead — fixed here).
  static const String skillUpSections = '/skill-up/sections';

  /// See [skillUp]'s doc comment — opens the same hub pre-selected to its
  /// Certifications tab, matching the web's `#section-certifications`
  /// anchor. Reached from ARIA's `certifications` action chip
  /// (`ariaActionFlutterRoute`) — there was previously no dedicated route
  /// for this tab at all (only [sitemap]/[skillUpSections] existed).
  static const String skillUpCertifications = '/skill-up/certifications';

  /// A Skill Up lesson (one of the 48 real, standalone static HTML pages
  /// under `static/001 Career Buddy/**/*.html`, e.g. `001 CEFR/
  /// cefr_a1_english.html`) — reached only via `context.push` with a
  /// `SkillUpLessonRouteArgs` extra (title + the real page's absolute
  /// URL), the same route-args-threading pattern already used by the
  /// AI-module routes, since there's no useful path segment to encode 48
  /// arbitrary nested file paths into. See `SkillUpLessonScreen`'s doc
  /// comment for why this renders the real page in a `WebView` rather
  /// than re-authoring its content.
  static const String skillUpLesson = '/skill-up/lesson';

  /// Grammar (`subject_views.subject_home`, `templates/subject/home.html`)
  /// — the 9-topic index.
  static const String grammar = '/grammar';

  /// Grammar topic detail (`subject_views.subject_topic`,
  /// `templates/subject/detail.html`).
  static const String grammarTopicPattern = '/grammar/:slug';
  static String grammarTopic(String slug) => '/grammar/$slug';

  /// Batch 6 — Resume Parsing / ATS (`career_app.views.resume_builder_home`/
  /// `resume_job_match`, both served at this same URL — GET shows the
  /// upload form or a cached-from-session result, POST uploads+analyzes
  /// and renders the result inline in the same response). No separate
  /// route exists for the result on the web either (it's the same page,
  /// same URL), so this screen owns its own idle/loading/result/error
  /// state rather than navigating to a second route for the result.
  static const String resumeBuilder = '/resume-builder';

  /// `career_app.views.resume_history` — lists every resume this user has
  /// ever uploaded; "Re-analyze" on a row routes back to [resumeBuilder]
  /// with that resume's result, mirroring `resume_reanalyze`'s own
  /// redirect-to-the-same-result-template behavior.
  static const String resumeHistory = '/resume-builder/history';

  /// The ATS result page's "Try Interview"/"Take Interview" CTAs link to
  /// `resume_start_interview` (`career_app/views.py:930`) — the AI Mock
  /// Interview flow, a genuinely separate feature from Resume Parsing/ATS
  /// (its own session model, question bank, camera/anti-malpractice
  /// pipeline) and out of this batch's explicit scope. Placeholder only.
  static const String resumeInterviewPlaceholder = '/resume-builder/interview';

  /// JAM — "Just A Minute" workshop (`jam_app`, mounted at `/jam/`). The
  /// Topics list is this feature's entry point — matches the real web's own
  /// navigation (`jam:dashboard` → "Practice Topics" → `jam:topics`), and is
  /// what a human should wire from `ActivityDetailScreen` for an Activity
  /// whose title matches `'jam' in title.lower()` (see
  /// `_can_access_workshop`/`get_workshop_url` in `activities/views.py`,
  /// re-verified directly against source). The Recording screen
  /// (`JamRecordingScreen`) and Results screen (`JamResultScreen`) are
  /// reached by plain in-feature `Navigator.push`, not a registered
  /// go_router route — see `JamTopicsScreen`'s doc comment for why.
  static const String jamTopics = '/jam';

  /// `jam:history` (`templates/jam/history.html`) — reached from a History
  /// icon on [jamTopics]'s own AppBar (the real web links it from
  /// `jam:dashboard`, which isn't built here — see `JamTopicsScreen`'s doc
  /// comment for why Topics is this feature's actual entry point instead).
  static const String jamHistory = '/jam/history';

  /// `jam:profile` (`templates/jam/profile.html`) — **not linked from any
  /// real JAM template** (confirmed: `grep -rn "jam:profile" templates/jam/*.html`
  /// → zero hits — see `ApiEndpoints.jamProfile`'s doc comment). A real,
  /// fully functional page the web itself just never surfaces a nav entry
  /// for; reached here from the same AppBar as [jamHistory] since there is
  /// no other faithful place to put it.
  static const String jamProfile = '/jam/profile';

  /// `jam:session_detail` — revisiting a past session from [jamHistory].
  static const String jamSessionDetailPattern = '/jam/sessions/:id';
  static String jamSessionDetail(int id) => '/jam/sessions/$id';

  /// `jam:assessment_result` — revisiting a past assessment from
  /// [jamHistory].
  static const String jamAssessmentDetailPattern = '/jam/assessments/:id';
  static String jamAssessmentDetail(int id) => '/jam/assessments/$id';

  /// Debug-only Direct Demo Entry (`lib/core/demo/demo_entry_screen.dart`):
  /// turns on Demo Mode and jumps straight to Activities without a real
  /// login. The screen itself refuses to do anything when `!kDebugMode`
  /// (redirects to `/login`, does not touch [demoModeEnabledProvider]) —
  /// this route being reachable in a release build's routing table does
  /// not, by itself, let anyone reach real/demo content without signing
  /// in.
  static const String demoEntry = '/demo';

  /// Routes reachable without an authenticated session — the login screen
  /// itself plus the pre-login destinations it links to. Used by
  /// [computeRedirect] so those links aren't immediately bounced back to
  /// `/login` by the auth guard. An **authenticated** user is bounced
  /// *away* from these onto [dashboard] (they're pre-login-only flows) —
  /// contrast with [universalRoutes] below.
  static const Set<String> publicRoutes = {
    login,
    register,
    passwordReset,
    checkEmail,
    resetPasswordConfirm,
    passwordResetComplete,
    employerLogin,
    employerRegister,
    demoEntry,
  };

  /// Routes reachable by **either** auth state, with neither of
  /// [publicRoutes]'s two redirect behaviors applying — an unauthenticated
  /// user isn't bounced to [login], and an authenticated user isn't
  /// bounced to [dashboard]/[employerDashboard]. [home] and [employerHome]
  /// both match the real web's own `home()`/`job_home` views, which serve
  /// both branches from the same URL rather than redirecting either
  /// session state away.
  static const Set<String> universalRoutes = {home, employerHome};

  /// Routes gated the same way `jobs_app.views.employer_dashboard` and its
  /// sibling employer-only views are on the web
  /// (`@login_required(login_url='employer_portal:employer_login')`) — an
  /// unauthenticated hit bounces to [employerLogin], not the student
  /// [login], matching that exact `login_url=`. [employerJobOpenings] is
  /// deliberately NOT a member — see its own doc comment for why (plain
  /// `@login_required` on the real backend, reachable by both roles).
  static const Set<String> employerProtectedRoutes = {
    employerDashboard,
    employerJobCreate,
    employerAllApplications,
    employerCompanyProfile,
    employerCompanyProfileCreate,
    employerSearchCandidates,
  };

  /// Roleplay Workshop (`RoleplayHomeScreen`) — mirrors the web's own
  /// `/roleplay/` (`roleplay_home`, `activities/roleplay_urls.py`). Lists
  /// the 3 sub-features (Storytelling/Situations/Roleplay); no id parameter,
  /// same reasoning as [mockTestsHub] — the config behind it is fixed,
  /// static data (`RoleplayTopicsData`), not a per-instance resource.
  static const String roleplayHome = '/roleplay';

  /// A single sub-feature's practice/session screen (`RoleplayPracticeScreen`)
  /// — mirrors `roleplay_practice_view`'s `/roleplay/<str:feature>/`.
  /// [feature] is one of `RoleplayTopicsData.all`'s slugs
  /// (`storytelling`/`situations`/`roleplay`). Not currently used for
  /// in-feature navigation (`RoleplayHomeScreen` pushes
  /// `RoleplayPracticeScreen` directly via `Navigator.push`, not
  /// `context.push`, so it works before this pattern is wired into
  /// `app_router.dart`) — provided so the human wiring the router can add a
  /// matching `GoRoute` if deep-linking into a specific sub-feature is
  /// wanted later.
  static const String roleplayPracticePattern = '/roleplay/:feature';
  static String roleplayPractice(String feature) => '/roleplay/$feature';

  /// Group Discussion workshop entry point (`GdTopicScreen`) — mirrors the
  /// web's own `GD_app:home` (`/gd/`), the topic picker that kicks off
  /// `GD_app:create_session`. Reached from `ActivityDetailScreen` and
  /// `WorkshopDashboardScreen` for an Activity whose title matches
  /// `isGdModuleActivity` (`'group discussion' in title.lower() or
  /// title.lower() == 'gd'` — see `_can_access_workshop`/`get_workshop_url`
  /// in `activities/views.py`, re-verified directly against source), both
  /// confirmed wired and working. The
  /// live discussion screen (`GdDiscussionScreen`) and report screen
  /// (`GdReportScreen`) are reached by plain in-feature `Navigator.push`,
  /// not a registered go_router route — same reasoning as
  /// [roleplayPracticePattern]/JAM's recording+result screens: neither has
  /// a useful standalone URL to deep-link to on its own.
  static const String groupDiscussion = '/group-discussion';

  /// AI Mock Interview (`MockInterviewScreen`) — the real, fully-functional
  /// implementation of the feature [resumeInterviewPlaceholder] above still
  /// only placeholders. A human needs to re-point `resume_builder_screen.dart`'s
  /// two "Try Interview" CTAs (currently `context.push(RoutePaths.
  /// resumeInterviewPlaceholder)`) at this route instead, and replace
  /// `app_router.dart`'s `ComingSoonScreen` builder for
  /// [resumeInterviewPlaceholder] with `MockInterviewScreen` (or simply point
  /// [resumeInterviewPlaceholder] itself at this route/screen — kept as a
  /// separate constant here only so this batch never had to touch
  /// `app_router.dart`/`resume_builder_screen.dart` directly, per this task's
  /// explicit constraints).
  static const String mockInterview = '/resume-builder/mock-interview';
}
