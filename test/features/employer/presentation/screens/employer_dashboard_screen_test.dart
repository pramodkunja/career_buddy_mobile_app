import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_dashboard_summary.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_dashboard_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_dashboard_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/employer_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'acmehr', isEmployer: true);

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

class _FakeEmployerDashboardRepository implements EmployerDashboardRepository {
  _FakeEmployerDashboardRepository(this.result);

  Result<EmployerDashboardSummary> result;
  int callCount = 0;

  @override
  Future<Result<EmployerDashboardSummary>> getDashboard() async {
    callCount++;
    return result;
  }

  Result<void> deleteJobResult = const Success(null);
  int? lastDeletedJobId;

  @override
  Future<Result<void>> deleteJob(int jobId) async {
    lastDeletedJobId = jobId;
    return deleteJobResult;
  }
}

const _summary = EmployerDashboardSummary(
  greetingName: 'Priya',
  totalJobsCount: 3,
  activeJobs: 2,
  totalApps: 15,
  jobs: [
    EmployerJobListItem(
      jobId: 1,
      title: 'Senior Backend Engineer',
      jobType: 'Full Time',
      status: 'active',
      applicationsCount: 8,
      postedDate: '05 Jan 2026',
    ),
  ],
);

Future<_FakeEmployerDashboardRepository> _pump(
  WidgetTester tester,
  Result<EmployerDashboardSummary> result,
) async {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeEmployerDashboardRepository(result);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          employerDashboardRepositoryProvider.overrideWithValue(repo),
        ],
      child: const MaterialApp(home: EmployerDashboardScreen()),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('EmployerDashboardScreen', () {
    testWidgets('shows a loading indicator while the fetch is in flight', (tester) async {
      final repo = _FakeEmployerDashboardRepository(const Success(_summary));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          employerDashboardRepositoryProvider.overrideWithValue(repo),
        ],
          child: const MaterialApp(home: EmployerDashboardScreen()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the greeting, stats, and job list once loaded', (tester) async {
      await _pump(tester, const Success(_summary));

      expect(find.textContaining('Welcome back, Priya!'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Total Jobs'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Active Listings'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Applications'), findsOneWidget);
      expect(find.text('Senior Backend Engineer'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('8 applications'), findsOneWidget);
    });

    testWidgets('shows the empty-state copy when there are no jobs', (tester) async {
      await _pump(
        tester,
        const Success(
          EmployerDashboardSummary(greetingName: 'Priya', totalJobsCount: 0, activeJobs: 0, totalApps: 0, jobs: []),
        ),
      );

      expect(find.textContaining('No jobs posted yet.'), findsOneWidget);
    });

    testWidgets('shows the profile-incomplete message instead of a generic error', (tester) async {
      await _pump(
        tester,
        const Failed(EmployerProfileIncompleteFailure('Please complete your company profile first.')),
      );

      expect(find.text('Please complete your company profile first.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Was a dead end before this session: no way to actually complete the
      // profile from here. See `RoutePaths.employerCompanyProfileCreate`.
      expect(find.text('Complete Company Profile'), findsOneWidget);
    });

    testWidgets('shows a retryable error view for a generic failure, and Retry re-fetches', (tester) async {
      final repo = await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
      expect(repo.callCount, 1);

      repo.result = const Success(_summary);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(repo.callCount, 2);
      expect(find.textContaining('Welcome back, Priya!'), findsOneWidget);
    });

    testWidgets('tapping Delete shows a confirmation, Cancel leaves the job untouched', (tester) async {
      final repo = await _pump(tester, const Success(_summary));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      expect(find.text('Delete this job?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(repo.lastDeletedJobId, isNull);
      expect(find.text('Delete this job?'), findsNothing);
    });

    testWidgets('tapping Delete then confirming calls deleteJob and shows a snackbar', (tester) async {
      final repo = await _pump(tester, const Success(_summary));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      // Two "Delete" texts now exist: the dialog's confirm button and (once
      // it closes) none — safe to match by exact dialog-button text here.
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await tester.pump();

      expect(repo.lastDeletedJobId, 1);
      expect(find.text('Job deleted.'), findsOneWidget);
    });

    testWidgets('tapping Edit shows the not-yet-available notice, not a broken screen', (tester) async {
      await _pump(tester, const Success(_summary));

      await tester.tap(find.byTooltip('Edit'));
      await tester.pump();

      expect(find.text('Edit Job'), findsOneWidget);
      expect(find.textContaining('isn\'t available in the app yet'), findsOneWidget);
    });
  });
}
