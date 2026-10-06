import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/activity_progress.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  AuthUser? restoredUser;
  int logoutCallCount = 0;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async {
    logoutCallCount++;
    return const Success(null);
  }

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository(this.result);

  final Result<DashboardData> result;

  @override
  Future<Result<DashboardData>> getDashboard() async => result;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders the welcome banner and stats once data loads', (tester) async {
    final data = DashboardData(
      stats: const DashboardStats(completedCount: 3, inProgressCount: 2, totalActivities: 20, totalScore: 145),
      activities: const <ActivityProgress>[],
      recentResults: const [],
      recommendedJobs: const [],
      paymentHistory: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'jane'))),
          dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository(Success(data))),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await _settle(tester);

    // The username is its own accent-colored `TextSpan`, matching the web's
    // `<span class="text-accent">` (`dashboard.html:54`) — `findRichText`
    // is required since this is no longer a single plain `Text`.
    expect(find.text('Welcome back, jane', findRichText: true), findsOneWidget);
    expect(find.text('20'), findsOneWidget); // total activities tile
  });

  testWidgets('signs the user out when the dashboard request comes back unauthorized', (tester) async {
    final authRepo = _FakeAuthRepository(restoredUser: const AuthUser(username: 'jane'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(const Failed(UnauthorizedFailure())),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await _settle(tester);

    expect(authRepo.logoutCallCount, 1);
  });

  testWidgets('shows a retryable error view for a non-auth failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'jane'))),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(const Failed(NotFoundFailure())),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await _settle(tester);

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'the nav drawer is reachable even when the dashboard itself failed to load '
    '(the real dead-end this screen used to have when /dashboard/api/ 404s in production)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'jane'))),
            dashboardRepositoryProvider.overrideWithValue(
              _FakeDashboardRepository(const Failed(NotFoundFailure())),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await _settle(tester);

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await _settle(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
    },
  );
}
