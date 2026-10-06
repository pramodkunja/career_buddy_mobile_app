import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_all_applications.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_all_applications_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_all_applications_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/employer_all_applications_screen.dart';
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

class _FakeRepository implements EmployerAllApplicationsRepository {
  _FakeRepository(this.result);

  Result<EmployerAllApplicationsPage> result;
  String? lastStatusFilter;
  String? lastSourceFilter;
  int callCount = 0;

  @override
  Future<Result<EmployerAllApplicationsPage>> getApplications({
    String query = '',
    String statusFilter = '',
    String sourceFilter = '',
  }) async {
    callCount++;
    lastStatusFilter = statusFilter;
    lastSourceFilter = sourceFilter;
    return result;
  }
}

const _oneApplication = EmployerAllApplicationsPage(
  applications: [
    EmployerAllApplicationListItem(
      applicationId: 12,
      applicantName: 'Sai Venkat',
      applicantEmail: 'sai@example.com',
      jobTitle: 'Senior Python Developer',
      source: 'direct',
      appliedAt: '25 Aug 2026, 13:01',
      status: 'reviewing',
    ),
  ],
);

Future<_FakeRepository> _pump(WidgetTester tester, Result<EmployerAllApplicationsPage> result) async {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeRepository(result);
  final router = GoRouter(
    initialLocation: RoutePaths.employerAllApplications,
    routes: [
      GoRoute(
        path: RoutePaths.employerAllApplications,
        builder: (context, state) => const EmployerAllApplicationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.employerApplicationDetailPattern,
        builder: (context, state) => Scaffold(body: Text('DETAIL:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        employerAllApplicationsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('EmployerAllApplicationsScreen', () {
    testWidgets('renders every candidate card with job title and source', (tester) async {
      await _pump(tester, const Success(_oneApplication));

      expect(find.text('Sai Venkat'), findsOneWidget);
      expect(find.text('Senior Python Developer'), findsOneWidget);
      expect(find.text('Direct Apply'), findsOneWidget);
    });

    testWidgets('shows the empty-state copy when there are no applications', (tester) async {
      await _pump(tester, const Success(EmployerAllApplicationsPage(applications: [])));

      expect(find.text('No applications found'), findsOneWidget);
    });

    testWidgets('tapping a candidate navigates to the existing Application Detail screen', (tester) async {
      await _pump(tester, const Success(_oneApplication));

      await tester.tap(find.text('Sai Venkat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('DETAIL:12'), findsOneWidget);
    });

    testWidgets('selecting a status filter refetches with that status', (tester) async {
      final repo = await _pump(tester, const Success(_oneApplication));
      expect(repo.lastStatusFilter, '');

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'All Statuses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Under Review').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.lastStatusFilter, 'reviewing');
      expect(repo.callCount, 2);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
