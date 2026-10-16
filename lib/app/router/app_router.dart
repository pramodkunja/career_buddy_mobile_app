import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/demo/demo_entry_screen.dart';
import '../../core/demo/demo_mode.dart';
import '../../features/activities/presentation/screens/activity_detail_screen.dart';
import '../../features/activities/presentation/screens/activity_list_screen.dart';
import '../../features/activities/presentation/screens/mcq_exercise_screen.dart';
import '../../features/activities/presentation/screens/sub_activity_detail_screen.dart';
import '../../features/matching/presentation/matching_route_args.dart';
import '../../features/matching/presentation/screens/matching_exercise_screen.dart';
import '../../features/bingo/presentation/bingo_route_args.dart';
import '../../features/bingo/presentation/screens/bingo_exercise_screen.dart';
import '../../features/fill_blank/presentation/fill_blank_route_args.dart';
import '../../features/fill_blank/presentation/screens/fill_blank_exercise_screen.dart';
import '../../features/generic_writing/presentation/generic_writing_route_args.dart';
import '../../features/generic_writing/presentation/screens/generic_writing_screen.dart';
import '../../features/timer_exercise/presentation/screens/timer_exercise_screen.dart';
import '../../features/timer_exercise/presentation/timer_exercise_route_args.dart';
import '../../features/activities/presentation/screens/workshop_dashboard_screen.dart';
import '../../features/ai_speaking/presentation/ai_speaking_route_args.dart';
import '../../features/ai_speaking/presentation/screens/ai_speaking_screen.dart';
import '../../features/ai_listening/presentation/ai_listening_route_args.dart';
import '../../features/ai_listening/presentation/screens/ai_listening_screen.dart';
import '../../features/ai_reading/presentation/ai_reading_route_args.dart';
import '../../features/ai_reading/presentation/screens/ai_reading_screen.dart';
import '../../features/ai_writing/presentation/ai_writing_route_args.dart';
import '../../features/ai_writing/presentation/screens/ai_writing_screen.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/auth/presentation/screens/employer_login_screen.dart';
import '../../features/auth/presentation/screens/employer_register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/password_reset_complete_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/employer/presentation/screens/employer_all_applications_screen.dart';
import '../../features/employer/presentation/screens/employer_application_detail_screen.dart';
import '../../features/employer/presentation/screens/employer_candidate_search_screen.dart';
import '../../features/employer/presentation/screens/job_openings_screen.dart';
import '../../features/employer/presentation/screens/my_application_detail_screen.dart';
import '../../features/employer/presentation/screens/post_new_job_screen.dart';
import '../../features/employer/presentation/screens/public_job_detail_screen.dart';
import '../../features/employer/presentation/screens/employer_company_profile_screen.dart';
import '../../features/employer/presentation/screens/employer_dashboard_screen.dart';
import '../../features/employer/presentation/screens/employer_job_applications_screen.dart';
import '../../features/employer/presentation/screens/employer_home_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/resume/domain/entities/create_resume_state.dart';
import '../../features/resume/domain/entities/manual_resume_draft.dart';
import '../../features/resume/domain/entities/resume_role.dart';
import '../../features/resume/presentation/screens/create_resume_builder_screen.dart';
import '../../features/resume/presentation/screens/create_resume_drafts_screen.dart';
import '../../features/resume/presentation/screens/create_resume_preview_screen.dart';
import '../../features/resume/presentation/screens/manual_resume_builder_screen.dart';
import '../../features/resume/presentation/screens/manual_resume_page_preview_screen.dart';
import '../../features/resume/presentation/screens/manual_resume_preview_screen.dart';
import '../../features/resume/presentation/screens/resume_builder_screen.dart';
import '../../features/resume/presentation/screens/resume_history_screen.dart';
import '../../features/resume/presentation/screens/role_picker_screen.dart';
import '../../features/mock_tests/amcat/presentation/screens/amcat_mock_test_screen.dart';
import '../../features/mock_tests/amcat/presentation/screens/cocubes_mock_test_screen.dart';
import '../../features/mock_tests/domain/entities/quiz_subject.dart';
import '../../features/mock_tests/presentation/screens/mock_tests_hub_screen.dart';
import '../../features/mock_tests/presentation/screens/oop_mastery_mock_test_screen.dart';
import '../../features/mock_tests/presentation/screens/subject_quiz_mock_test_screen.dart';
import '../../features/grammar/presentation/screens/grammar_detail_screen.dart';
import '../../features/grammar/presentation/screens/grammar_index_screen.dart';
import '../../features/group_discussion/presentation/screens/gd_topic_screen.dart';
import '../../features/jam/presentation/screens/jam_assessment_detail_screen.dart';
import '../../features/jam/presentation/screens/jam_history_screen.dart';
import '../../features/jam/presentation/screens/jam_profile_screen.dart';
import '../../features/jam/presentation/screens/jam_session_detail_screen.dart';
import '../../features/jam/presentation/screens/jam_topics_screen.dart';
import '../../features/mock_interview/presentation/screens/mock_interview_screen.dart';
import '../../features/roleplay/presentation/screens/roleplay_home_screen.dart';
import '../../features/skill_up/presentation/screens/skill_up_screen.dart';
import '../../features/skill_up/presentation/screens/skill_up_lesson_screen.dart';
import '../../features/skill_up/presentation/skill_up_lesson_route_args.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import 'route_guards.dart';
import 'route_paths.dart';

/// Notifies [GoRouter] to re-run its `redirect` whenever auth state changes,
/// so login/logout navigate immediately without the screen polling.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      return computeRedirect(
        authState: ref.read(authControllerProvider),
        matchedLocation: state.matchedLocation,
        demoBypass: kDebugMode && ref.read(demoModeEnabledProvider),
      );
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // Debug-only Direct Demo Entry — see `DemoEntryScreen`'s doc comment
      // for why this route existing in the table is safe even in a
      // release build.
      GoRoute(
        path: RoutePaths.demoEntry,
        builder: (context, state) => const DemoEntryScreen(),
      ),
      // Linked from the login screen (`register`/`password_reset`/
      // `employer_portal:employer_login` on the web); none of these
      // destination screens are built yet, so each is a placeholder — see
      // `ComingSoonScreen`.
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.passwordReset,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.checkEmail,
        builder: (context, state) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPasswordConfirm,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.passwordResetComplete,
        builder: (context, state) => const PasswordResetCompleteScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerLogin,
        builder: (context, state) => const EmployerLoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerRegister,
        builder: (context, state) => const EmployerRegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerHome,
        builder: (context, state) => const EmployerHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerDashboard,
        builder: (context, state) => const EmployerDashboardScreen(),
      ),
      // Linked from the employer sidebar (`templates/employer_base.html:
      // 214-238`). Built against the live production form, not the
      // committed (and much smaller) `JobPostingForm` — see
      // `ApiEndpoints.employerJobCreate`'s doc comment for the full
      // divergence and the live-verified contract this now follows.
      GoRoute(
        path: RoutePaths.employerJobCreate,
        builder: (context, state) => const PostNewJobScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerJobEditPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return PostNewJobScreen(jobId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.employerAllApplications,
        builder: (context, state) => const EmployerAllApplicationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerCompanyProfile,
        builder: (context, state) =>
            const EmployerCompanyProfileScreen(isCreate: false),
      ),
      GoRoute(
        path: RoutePaths.employerCompanyProfileCreate,
        builder: (context, state) =>
            const EmployerCompanyProfileScreen(isCreate: true),
      ),
      GoRoute(
        path: RoutePaths.employerJobOpenings,
        builder: (context, state) => const JobOpeningsScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerSearchCandidates,
        builder: (context, state) => const EmployerCandidateSearchScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerApplicationDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return EmployerApplicationDetailScreen(applicationId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.employerJobApplicationsPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return EmployerJobApplicationsScreen(jobId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.publicJobDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return PublicJobDetailScreen(jobId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.myApplicationDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return MyApplicationDetailScreen(applicationId: id);
        },
      ),
      // W024 — Home. See `RoutePaths.home`'s doc comment for why this is
      // reachable by both auth states rather than being either a
      // `publicRoutes` or a protected destination.
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      // Linked from the new nav drawer (Batch 5A); none of these
      // destination screens exist in Flutter yet — each currently renders
      // a `ComingSoonScreen`, same pattern as `register`/`passwordReset`/
      // `employerLogin` above.
      GoRoute(
        path: RoutePaths.skillUp,
        builder: (context, state) => const SkillUpScreen(),
      ),
      // Not a separate page on the real web either — see `RoutePaths.sitemap`'s
      // doc comment. Opens the same hub pre-selected to its Sitemap tab.
      GoRoute(
        path: RoutePaths.sitemap,
        builder: (context, state) => const SkillUpScreen(initialTabIndex: 2),
      ),
      // See `RoutePaths.skillUpSections`'s doc comment.
      GoRoute(
        path: RoutePaths.skillUpSections,
        builder: (context, state) => const SkillUpScreen(initialTabIndex: 1),
      ),
      // See `RoutePaths.skillUpCertifications`'s doc comment.
      GoRoute(
        path: RoutePaths.skillUpCertifications,
        builder: (context, state) => const SkillUpScreen(initialTabIndex: 3),
      ),
      GoRoute(
        path: RoutePaths.skillUpLesson,
        builder: (context, state) =>
            SkillUpLessonScreen(args: state.extra! as SkillUpLessonRouteArgs),
      ),
      GoRoute(
        path: RoutePaths.resumeBuilder,
        builder: (context, state) => const ResumeBuilderScreen(),
      ),
      GoRoute(
        path: RoutePaths.resumeHistory,
        builder: (context, state) => const ResumeHistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.resumeRolePicker,
        builder: (context, state) => const RolePickerScreen(),
      ),
      // Not in `publicRoutes`/`universalRoutes` — the auth-redirect guard
      // already protects this route, matching Decision 1 of the Phase 25
      // brief (authenticated users only).
      GoRoute(
        path: RoutePaths.manualResumeBuilder,
        builder: (context, state) =>
            ManualResumeBuilderScreen(role: state.extra as ResumeRole?),
      ),
      GoRoute(
        path: RoutePaths.manualResumePreview,
        builder: (context, state) =>
            ManualResumePreviewScreen(draft: state.extra! as ManualResumeDraft),
      ),
      GoRoute(
        path: RoutePaths.manualResumePagePreview,
        builder: (context, state) => ManualResumePagePreviewScreen(
          draft: state.extra! as ManualResumeDraft,
        ),
      ),
      // Phase 39 — Create Resume. [createResumeBuilder]/[createResumePreview]
      // are in `universalRoutes` (see their own doc comments: the real
      // endpoints genuinely have no login requirement); [createResumeDrafts]
      // is not, matching the real `drafts_list`'s own `@login_required`.
      GoRoute(
        path: RoutePaths.createResumeBuilder,
        builder: (context, state) => CreateResumeBuilderScreen(
          initialForm: state.extra as CreateResumeFormState?,
        ),
      ),
      GoRoute(
        path: RoutePaths.createResumePreview,
        builder: (context, state) => CreateResumePreviewScreen(
          form: state.extra! as CreateResumeFormState,
        ),
      ),
      GoRoute(
        path: RoutePaths.createResumeDrafts,
        builder: (context, state) => const CreateResumeDraftsScreen(),
      ),
      // The ATS result page's "Try Interview" CTA — Batch 9 implements the
      // real feature; both CTA call sites in `resume_builder_screen.dart`
      // already push this same path, so pointing it straight at
      // `MockInterviewScreen` (rather than also adding a second, separate
      // `RoutePaths.mockInterview` route) needed no other file touched.
      GoRoute(
        path: RoutePaths.resumeInterviewPlaceholder,
        builder: (context, state) => const MockInterviewScreen(),
      ),
      GoRoute(
        path: RoutePaths.groupDiscussion,
        builder: (context, state) => const GdTopicScreen(),
      ),
      GoRoute(
        path: RoutePaths.grammar,
        builder: (context, state) => const GrammarIndexScreen(),
      ),
      GoRoute(
        path: RoutePaths.grammarTopicPattern,
        builder: (context, state) =>
            GrammarDetailScreen(slug: state.pathParameters['slug']!),
      ),
      // Batch 8 — Roleplay/JAM workshop entry points. Each feature's own
      // in-flow screens (practice/recording/results) are reached via plain
      // `Navigator.push`, not go_router — see `RoleplayHomeScreen`'s/
      // `JamTopicsScreen`'s own doc comments for why only the entry point
      // needs a registered route.
      GoRoute(
        path: RoutePaths.roleplayHome,
        builder: (context, state) => const RoleplayHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.jamTopics,
        builder: (context, state) => const JamTopicsScreen(),
      ),
      GoRoute(
        path: RoutePaths.jamHistory,
        builder: (context, state) => const JamHistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.jamProfile,
        builder: (context, state) => const JamProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.jamSessionDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return JamSessionDetailScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.jamAssessmentDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return JamAssessmentDetailScreen(assessmentId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      // No longer linked from anywhere (Phase 4 of the parity-remediation
      // work moved the dashboard's "View & Apply" action to
      // [RoutePaths.publicJobDetail] once a real job id — always present
      // in the scraped HTML, just never extracted — was wired through).
      // Left registered, unused, as a harmless no-id fallback — see
      // `route_paths.dart`'s doc comment on [RoutePaths.jobDetail].
      GoRoute(
        path: RoutePaths.jobDetail,
        builder: (context, state) => const ComingSoonScreen(
          title: 'Job Details',
          message:
              'Job details and applying aren\'t available in the app yet. '
              'Please view and apply for this job on the Career Buddy website for now.',
        ),
      ),
      // Phase 3 — Subscription. Linked from the Activities list's Free-Plan
      // banner, Upgrade-Required dialog, Resume Builder's interview CTA, the
      // GD/JAM/Roleplay locked views, the nav drawer, and ARIA's own `/pro/`
      // action chip (`ariaActionFlutterRoute`) — all of these already
      // `context.push(RoutePaths.pro)`, so replacing this one builder is
      // the only router change this phase needs. Protected the same as
      // before (not in `publicRoutes`/`universalRoutes`, matching the real
      // backend's `@login_required` on `pro_page`/`create_razorpay_order`/
      // `verify_razorpay_payment`).
      GoRoute(
        path: RoutePaths.pro,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: RoutePaths.activities,
        builder: (context, state) => ActivityListScreen(
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      // Must be declared BEFORE `activityDetailPattern` below: GoRoute
      // matching walks the route list in declaration order and uses the
      // first structural match, and `/activities/workshop` structurally
      // matches the `/activities/:id` pattern too (a single path segment).
      // With the parameterized route declared first, `/activities/workshop`
      // was being matched as `activityDetail(id: "workshop")`, which
      // `int.tryParse` reduces to `-1`, producing a real `GET
      // /activities/api/-1/` request that 404s — the exact bug this fixes
      // (confirmed via a reproduction test before this change; see
      // `workshop_route_order_test.dart`).
      GoRoute(
        path: RoutePaths.workshopDashboard,
        builder: (context, state) => const WorkshopDashboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.activityDetailPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return ActivityDetailScreen(activityId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.subActivityDetailPattern,
        builder: (context, state) {
          final activityId =
              int.tryParse(state.pathParameters['activityId'] ?? '') ?? -1;
          final subId = int.tryParse(state.pathParameters['subId'] ?? '') ?? -1;
          return SubActivityDetailScreen(
            activityId: activityId,
            subActivityId: subId,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.mcqExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return McqExerciseScreen(exerciseId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.aiSpeakingPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiSpeakingScreen(
            exerciseId: id,
            activityId: args is AiSpeakingRouteArgs ? args.activityId : -1,
            subActivityId: args is AiSpeakingRouteArgs
                ? args.subActivityId
                : -1,
            activityTitle: args is AiSpeakingRouteArgs
                ? args.activityTitle
                : '',
            previousAttempt: args is AiSpeakingRouteArgs
                ? args.previousAttempt
                : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.aiWritingPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiWritingScreen(
            exerciseId: id,
            activityId: args is AiWritingRouteArgs ? args.activityId : -1,
            subActivityId: args is AiWritingRouteArgs ? args.subActivityId : -1,
            activityTitle: args is AiWritingRouteArgs ? args.activityTitle : '',
            previousAttempt: args is AiWritingRouteArgs
                ? args.previousAttempt
                : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.aiListeningPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiListeningScreen(
            exerciseId: id,
            activityId: args is AiListeningRouteArgs ? args.activityId : -1,
            subActivityId: args is AiListeningRouteArgs
                ? args.subActivityId
                : -1,
            activityTitle: args is AiListeningRouteArgs
                ? args.activityTitle
                : '',
            previousAttempt: args is AiListeningRouteArgs
                ? args.previousAttempt
                : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.aiReadingPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return AiReadingScreen(
            exerciseId: id,
            activityId: args is AiReadingRouteArgs ? args.activityId : -1,
            subActivityId: args is AiReadingRouteArgs ? args.subActivityId : -1,
            activityTitle: args is AiReadingRouteArgs ? args.activityTitle : '',
            previousAttempt: args is AiReadingRouteArgs
                ? args.previousAttempt
                : null,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.matchingExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return MatchingExerciseScreen(
            exerciseId: id,
            args: args is MatchingRouteArgs
                ? args
                : const MatchingRouteArgs(
                    title: 'Exercise',
                    order: 1,
                    activityId: -1,
                    subActivityId: -1,
                  ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.bingoExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return BingoExerciseScreen(
            exerciseId: id,
            args: args is BingoRouteArgs
                ? args
                : const BingoRouteArgs(
                    title: 'Exercise',
                    order: 1,
                    activityId: -1,
                    subActivityId: -1,
                  ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.fillBlankExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return FillBlankExerciseScreen(
            exerciseId: id,
            args: args is FillBlankRouteArgs
                ? args
                : const FillBlankRouteArgs(
                    title: 'Exercise',
                    order: 1,
                    activityId: -1,
                    subActivityId: -1,
                  ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.genericWritingExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return GenericWritingScreen(
            exerciseId: id,
            args: args is GenericWritingRouteArgs
                ? args
                : const GenericWritingRouteArgs(
                    title: 'Exercise',
                    order: 1,
                    activityId: -1,
                    subActivityId: -1,
                  ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.timerExercisePattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final args = state.extra;
          return TimerExerciseScreen(
            exerciseId: id,
            args: args is TimerExerciseRouteArgs
                ? args
                : const TimerExerciseRouteArgs(
                    title: 'Exercise',
                    order: 1,
                    activityId: -1,
                    subActivityId: -1,
                  ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.mockTestsHub,
        builder: (context, state) => const MockTestsHubScreen(),
      ),
      GoRoute(
        path: RoutePaths.oopMasteryMockTest,
        builder: (context, state) => const OopMasteryMockTestScreen(),
      ),
      GoRoute(
        path: RoutePaths.subjectQuizPattern,
        builder: (context, state) {
          final subject = state.pathParameters['subject'] ?? '';
          final title = kQuizSubjects
              .firstWhere(
                (s) => s.slug == subject,
                orElse: () => QuizSubject(slug: subject, title: subject),
              )
              .title;
          return SubjectQuizMockTestScreen(subject: subject, title: title);
        },
      ),
      GoRoute(
        path: RoutePaths.amcatMockTest,
        builder: (context, state) => const AmcatMockTestScreen(),
      ),
      GoRoute(
        path: RoutePaths.cocubesMockTest,
        builder: (context, state) => const CocubesMockTestScreen(),
      ),
    ],
  );
});
