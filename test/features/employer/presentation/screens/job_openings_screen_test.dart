import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/job_openings.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/job_openings_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/job_openings_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/job_openings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly — same pattern as
/// `GrammarDetailScreen`'s own test doubles — avoids that without this
/// screen's own tests needing to care about auth at all.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeRepository implements JobOpeningsRepository {
  _FakeRepository(this.result);

  Result<JobOpeningsPage> result;

  @override
  Future<Result<JobOpeningsPage>> getJobOpenings() async => result;
}

const _twoJobs = JobOpeningsPage(
  jobs: [
    JobOpeningListItem(
      jobId: 68,
      title: 'Senior Python Developer',
      companyName: 'Acme Corp',
      jobType: 'Full Time',
      isSeeded: false,
      location: 'Hyderabad',
      experience: '5-8 Years',
      skills: ['Python', 'Django'],
      salaryDisplay: '₹12 LPA – ₹18 LPA',
    ),
    JobOpeningListItem(
      jobId: 70,
      title: 'QA Tester',
      companyName: 'Career Buddy Partner',
      jobType: 'Remote',
      isSeeded: true,
      location: 'Remote',
      experience: 'Fresher',
      skills: [],
      salaryDisplay: 'As per industry norms',
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Result<JobOpeningsPage> result) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeRepository(result);
  final router = GoRouter(
    initialLocation: RoutePaths.employerJobOpenings,
    routes: [
      GoRoute(path: RoutePaths.employerJobOpenings, builder: (context, state) => const JobOpeningsScreen()),
      GoRoute(
        path: RoutePaths.publicJobDetailPattern,
        builder: (context, state) => Scaffold(body: Text('JOB:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jobOpeningsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  group('JobOpeningsScreen', () {
    testWidgets('renders every job card', (tester) async {
      await _pump(tester, const Success(_twoJobs));

      expect(find.text('Senior Python Developer'), findsOneWidget);
      expect(find.text('QA Tester'), findsOneWidget);
    });

    testWidgets('My Postings filter hides seeded jobs', (tester) async {
      await _pump(tester, const Success(_twoJobs));

      await tester.tap(find.widgetWithText(ChoiceChip, 'My Postings'));
      await tester.pump();

      expect(find.text('Senior Python Developer'), findsOneWidget);
      expect(find.text('QA Tester'), findsNothing);
    });

    testWidgets('Career Buddy Listed filter hides own jobs', (tester) async {
      await _pump(tester, const Success(_twoJobs));

      await tester.drag(find.byKey(const Key('jobFilterScroll')), const Offset(-200, 0));
      await tester.pump();
      await tester.tap(find.text('Career Buddy Listed'));
      await tester.pump();

      expect(find.text('Senior Python Developer'), findsNothing);
      expect(find.text('QA Tester'), findsOneWidget);
    });

    testWidgets('tapping a card navigates to the existing Public Job Detail screen', (tester) async {
      await _pump(tester, const Success(_twoJobs));

      await tester.tap(find.text('Senior Python Developer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('JOB:68'), findsOneWidget);
    });

    testWidgets('shows the empty-state copy when there are no jobs', (tester) async {
      await _pump(tester, const Success(JobOpeningsPage(jobs: [])));

      expect(find.text('No active job openings found.'), findsOneWidget);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
