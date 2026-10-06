import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/recommended_job.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/widgets/recommended_jobs_section.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  RecommendedJob job({List<String> skills = const ['A', 'B', 'C', 'D', 'E']}) => RecommendedJob(
    title: 'Customer Support Executive',
    companyName: 'Acme Corp',
    skills: skills,
    location: 'Remote',
    jobType: 'Full Time',
    experienceLevel: 'Fresher',
    salaryDisplay: 'As per industry norms',
  );

  testWidgets('renders nothing when there are no recommended jobs (not eligible yet)', (tester) async {
    await tester.pumpWidget(wrap(const RecommendedJobsSection(jobs: [])));

    expect(find.text('Recommended Job Opportunities'), findsNothing);
  });

  testWidgets('shows the interview-score subtitle and the matched-jobs count badge', (tester) async {
    await tester.pumpWidget(wrap(RecommendedJobsSection(jobs: [job()], interviewScore: 85)));

    expect(find.text('Recommended Job Opportunities'), findsOneWidget);
    expect(find.textContaining('interview score of 85/100'), findsOneWidget);
    expect(find.text('1 Matched Job'), findsOneWidget);
  });

  testWidgets('omits the interview-score line when it is null', (tester) async {
    await tester.pumpWidget(wrap(RecommendedJobsSection(jobs: [job()])));

    expect(find.textContaining('interview score of'), findsNothing);
  });

  testWidgets('only shows the first 3 skills per job, matching the web\'s |slice:":3"', (tester) async {
    await tester.pumpWidget(wrap(RecommendedJobsSection(jobs: [job()])));

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsNothing);
    expect(find.text('E'), findsNothing);
  });

  testWidgets('View & Apply navigates to the Job Details placeholder', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => Scaffold(body: RecommendedJobsSection(jobs: [job()]))),
        GoRoute(
          path: RoutePaths.jobDetail,
          builder: (context, state) => const ComingSoonScreen(title: 'Job Details', message: 'not built yet'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('View & Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Job Details'), findsOneWidget);
  });

  testWidgets('wraps the whole section in one outer white radius-16 card, matching .card.rounded-4', (tester) async {
    await tester.pumpWidget(wrap(RecommendedJobsSection(jobs: [job()])));

    final outer = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) => (c.decoration as BoxDecoration?)?.borderRadius == BorderRadius.circular(16));
    expect((outer.decoration! as BoxDecoration).color, Colors.white);
  });

  testWidgets('shows a job-logo icon (bare, no box) and a job-type badge, matching the web structure', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(RecommendedJobsSection(jobs: [job()])));

    expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
    expect(find.text('Full Time'), findsOneWidget);
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
          RecommendedJobsSection(
            jobs: [
              RecommendedJob(
                title: 'A Genuinely Very Long Senior Customer Support Team Lead Executive Title',
                companyName: 'A Reasonably Long Global Acme Corporation Company Name Pvt Ltd',
                skills: const ['Communication', 'Customer Relationship Management', 'English Proficiency'],
                location: 'Remote (Work From Home, Anywhere in India)',
                jobType: 'Full Time',
                experienceLevel: 'Fresher (0-1 years)',
                salaryDisplay: 'As per industry norms — negotiable based on experience',
              ),
            ],
            interviewScore: 85,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });
}
