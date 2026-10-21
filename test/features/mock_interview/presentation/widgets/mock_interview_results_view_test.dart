import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/recommended_job.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_analytics.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/widgets/mock_interview_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// REGRESSION (Phase 8) — `mock_interview_results_view.dart`'s new
/// "Recommended Job Opportunities" section, mirroring
/// `resume_analytics.html:350-409` and following the exact same testing
/// pattern as `recommended_jobs_section_test.dart` (Dashboard's equivalent
/// card).
void main() {
  const baseAnalytics = InterviewAnalyticsResult(
    totalScore: 84,
    isPassed: true,
    avgScore: 4.2,
    answeredCount: 20,
    totalQuestions: 20,
    yearsExperience: 3.0,
    questionResults: [],
  );

  RecommendedJob job({List<String> skills = const ['A', 'B', 'C', 'D', 'E'], int? id}) => RecommendedJob(
    id: id,
    title: 'Backend Developer',
    companyName: 'Globex Inc',
    skills: skills,
    location: 'Bengaluru',
    jobType: 'Full-time',
    experienceLevel: '1-2 years',
    salaryDisplay: '₹6L - ₹9L',
  );

  Widget wrap(InterviewAnalyticsResult analytics) =>
      MaterialApp(home: Scaffold(body: MockInterviewResultsView(analytics: analytics)));

  testWidgets('renders no section when suitableJobs is empty — matches the web\'s own {% if %} gate', (tester) async {
    await tester.pumpWidget(wrap(baseAnalytics));

    expect(find.text('Recommended Job Opportunities'), findsNothing);
  });

  testWidgets('shows the header, years-experience text, and matched-jobs count badge', (tester) async {
    await tester.pumpWidget(wrap(baseAnalytics.copyWithJobs([job(id: 1)])));

    expect(find.text('Recommended Job Opportunities'), findsOneWidget);
    expect(find.textContaining('experience (3.0 years)'), findsOneWidget);
    expect(find.text('1 Matched Job'), findsOneWidget);
  });

  testWidgets('only shows the first 3 skills per job, matching the web\'s |slice:":3"', (tester) async {
    await tester.pumpWidget(wrap(baseAnalytics.copyWithJobs([job(id: 1)])));

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsNothing);
    expect(find.text('E'), findsNothing);
  });

  testWidgets(
    'View & Apply navigates to the real PublicJobDetailScreen route using the scraped job.pk',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: MockInterviewResultsView(analytics: baseAnalytics.copyWithJobs([job(id: 77)]))),
          ),
          GoRoute(
            path: RoutePaths.publicJobDetailPattern,
            builder: (context, state) => Scaffold(body: Text('Job #${state.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('View & Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Job #77'), findsOneWidget);
    },
  );

  testWidgets(
    'REGRESSION (Phase 8): View & Apply is disabled, not a dead/invalid navigation, when no job id was scraped',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: MockInterviewResultsView(analytics: baseAnalytics.copyWithJobs([job()]))),
          ),
          GoRoute(
            path: RoutePaths.publicJobDetailPattern,
            builder: (context, state) => const Scaffold(body: Text('should never be reached')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      final button = tester.widget<OutlinedButton>(
        find.ancestor(of: find.text('View & Apply'), matching: find.byType(OutlinedButton)),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('View & Apply'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('should never be reached'), findsNothing);
      expect(find.text('View & Apply'), findsOneWidget);
    },
  );

  testWidgets('still renders the question breakdown above the jobs section — existing behavior intact', (
    tester,
  ) async {
    const analytics = InterviewAnalyticsResult(
      totalScore: 84,
      isPassed: true,
      avgScore: 4.2,
      answeredCount: 20,
      totalQuestions: 20,
      yearsExperience: 3.0,
      questionResults: [
        InterviewQuestionResult(
          topic: 'Python',
          difficulty: 'Easy',
          question: 'What is a list comprehension?',
          answer: 'A concise way to build lists.',
          score: 5,
          feedback: 'Excellent, precise answer.',
        ),
      ],
    );
    await tester.pumpWidget(wrap(analytics.copyWithJobs([job(id: 1)])));

    expect(find.text('Question Breakdown'), findsOneWidget);
    expect(find.text('What is a list comprehension?'), findsOneWidget);
    expect(find.text('Recommended Job Opportunities'), findsOneWidget);
  });

  testWidgets('renders without overflow at 320/375/430 with long titles, companies, and skills', (tester) async {
    for (final width in [320.0, 375.0, 430.0]) {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        wrap(
          baseAnalytics.copyWithJobs([
            RecommendedJob(
              title: 'A Genuinely Very Long Senior Backend Platform Engineer Title',
              companyName: 'A Reasonably Long Global Globex Industries Company Name Pvt Ltd',
              skills: const ['Python', 'Django', 'PostgreSQL'],
              location: 'Bengaluru (Hybrid, Work From Home Available)',
              jobType: 'Full-time',
              experienceLevel: '1-2 years',
              salaryDisplay: '₹6L - ₹9L — negotiable based on experience',
            ),
          ]),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  group('Phase 46 — low-score recovery actions', () {
    const failedAnalytics = InterviewAnalyticsResult(
      totalScore: 62,
      isPassed: false,
      avgScore: 3.1,
      answeredCount: 20,
      totalQuestions: 20,
      yearsExperience: 2.0,
      questionResults: [],
    );

    testWidgets('a passed result shows the pass badge naming the real threshold, no recovery UI', (tester) async {
      await tester.pumpWidget(wrap(baseAnalytics));

      expect(find.text('Qualified Candidate (Score ≥ 90/100)'), findsOneWidget);
      expect(find.text('Action Required (Score < 90/100)'), findsNothing);
      expect(find.text('Skill up yourself'), findsNothing);
      expect(find.text('Recommended Skill Upgradation Courses'), findsNothing);
    });

    testWidgets('a failed result shows the fail badge naming the real threshold and the recovery guidance', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(failedAnalytics));

      expect(find.text('Action Required (Score < 90/100)'), findsOneWidget);
      expect(find.text('Qualified Candidate (Score ≥ 90/100)'), findsNothing);
      expect(find.text('You should upgrade your skill.'), findsOneWidget);
      expect(find.text('Skill up yourself'), findsOneWidget);
      expect(find.text('Recommended Skill Upgradation Courses'), findsOneWidget);
      expect(find.text('Business Communication & Speaking'), findsOneWidget);
      expect(find.text('Professional Email & Report Writing'), findsOneWidget);
      expect(find.text('Negotiation & Technical Discussion'), findsOneWidget);
      expect(find.text('View All 23 Skill Learning Activities'), findsOneWidget);
    });

    testWidgets('kInterviewPassingScore is 90, matching the verified current server constant', (tester) async {
      expect(kInterviewPassingScore, 90);
    });

    Future<GoRouter> pumpFailedWithRouter(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(body: MockInterviewResultsView(analytics: failedAnalytics)),
          ),
          GoRoute(
            path: RoutePaths.skillUpSections,
            builder: (context, state) => const Scaffold(body: Text('Skill Up Sections Screen')),
          ),
          GoRoute(
            path: RoutePaths.activities,
            builder: (context, state) =>
                Scaffold(body: Text('Activities Screen: category=${state.uri.queryParameters['category']}')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      return router;
    }

    testWidgets('the top "Skill up yourself" button navigates to the real Skill Up sections route', (tester) async {
      await pumpFailedWithRouter(tester);

      await tester.tap(find.byKey(const Key('interview-skill-up-button')));
      await tester.pumpAndSettle();

      expect(find.text('Skill Up Sections Screen'), findsOneWidget);
    });

    testWidgets('the first "Start Course" button (Speaking) navigates to Activities filtered to its real web category', (
      tester,
    ) async {
      await pumpFailedWithRouter(tester);

      // The 3 course tiles render in the real template's own order
      // (Speaking, Writing, Negotiation) — the first "Start Course" button
      // is always the Speaking one.
      expect(find.text('Start Course'), findsNWidgets(3));
      await tester.ensureVisible(find.text('Start Course').first);
      await tester.tap(find.text('Start Course').first);
      await tester.pumpAndSettle();

      expect(find.text('Activities Screen: category=speaking'), findsOneWidget);
    });

    testWidgets('"View All 23 Skill Learning Activities" navigates to the unfiltered Activities list', (
      tester,
    ) async {
      await pumpFailedWithRouter(tester);

      await tester.ensureVisible(find.text('View All 23 Skill Learning Activities'));
      await tester.tap(find.text('View All 23 Skill Learning Activities'));
      await tester.pumpAndSettle();

      expect(find.text('Activities Screen: category=null'), findsOneWidget);
    });
  });
}

extension on InterviewAnalyticsResult {
  InterviewAnalyticsResult copyWithJobs(List<RecommendedJob> jobs) => InterviewAnalyticsResult(
    totalScore: totalScore,
    isPassed: isPassed,
    avgScore: avgScore,
    answeredCount: answeredCount,
    totalQuestions: totalQuestions,
    yearsExperience: yearsExperience,
    questionResults: questionResults,
    suitableJobs: jobs,
  );
}
