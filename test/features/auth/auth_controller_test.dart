import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/employer_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/employer_auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser, this.loginResult});

  AuthUser? restoredUser;
  Result<AuthUser>? loginResult;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    return loginResult!;
  }

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

class _FakeEmployerAuthRepository implements EmployerAuthRepository {
  _FakeEmployerAuthRepository({this.loginResult, this.registerResult});

  Result<AuthUser>? loginResult;
  Result<AuthUser>? registerResult;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    return loginResult!;
  }

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(EmployerRegistrationData data) async => registerResult!;
}

class _FakeDashboardRepository implements DashboardRepository {
  int callCount = 0;

  @override
  Future<Result<DashboardData>> getDashboard() async {
    callCount++;
    return Success(
      DashboardData(
        stats: DashboardStats(completedCount: callCount, inProgressCount: 0, totalActivities: 0, totalScore: 0),
        activities: const [],
        recentResults: const [],
        recommendedJobs: const [],
        paymentHistory: const [],
      ),
    );
  }
}

const _sampleRegistration = EmployerRegistrationData(
  username: 'acmehr',
  password: 'Abcdef1!',
  passwordConfirm: 'Abcdef1!',
  email: 'acct@acme.com',
  firstName: 'Jane',
  lastName: 'Doe',
  companyName: 'Acme Corp',
  industry: 'it_software',
  hrContactE164: '+919876543210',
  hrMail: 'hr@acme.com',
);

/// Builds the controller and waits for its `build()`-time `restoreSession()`
/// call to settle, so tests start from a known, resolved state rather than
/// racing that pending future.
Future<ProviderContainer> _readyContainer(AuthRepository repo, [EmployerAuthRepository? employerRepo]) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      if (employerRepo != null) employerAuthRepositoryProvider.overrideWithValue(employerRepo),
    ],
  );
  container.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  group('AuthController', () {
    test('resolves to AuthUnauthenticated when there is no cached session', () async {
      final container = await _readyContainer(_FakeAuthRepository());
      addTearDown(container.dispose);

      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('resolves to AuthAuthenticated when a session is cached', () async {
      const cachedUser = AuthUser(username: 'jane');
      final container = await _readyContainer(_FakeAuthRepository(restoredUser: cachedUser));
      addTearDown(container.dispose);

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, cachedUser);
    });

    test('login() success moves state to AuthAuthenticated', () async {
      const user = AuthUser(username: 'jane');
      final container = await _readyContainer(
        _FakeAuthRepository(loginResult: const Success(user)),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).login(
        usernameOrEmail: 'jane',
        password: 'secret',
      );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, user);
    });

    test('login() failure moves state to AuthUnauthenticated with the failure message', () async {
      final container = await _readyContainer(
        _FakeAuthRepository(loginResult: const Failed(UnauthorizedFailure())),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).login(
        usernameOrEmail: 'jane',
        password: 'wrong',
      );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).errorMessage, const UnauthorizedFailure().message);
    });

    test('logout() moves state to AuthUnauthenticated', () async {
      const user = AuthUser(username: 'jane');
      final container = await _readyContainer(_FakeAuthRepository(restoredUser: user));
      addTearDown(container.dispose);
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

      await container.read(authControllerProvider.notifier).logout();

      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('loginEmployer() success moves state to AuthAuthenticated with isEmployer:true', () async {
      const user = AuthUser(username: 'acmehr', isEmployer: true);
      final container = await _readyContainer(
        _FakeAuthRepository(),
        _FakeEmployerAuthRepository(loginResult: const Success(user)),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).loginEmployer(
        usernameOrEmail: 'acmehr',
        password: 'secret',
      );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, user);
      expect(state.user.isEmployer, isTrue);
    });

    test('loginEmployer() failure moves state to AuthUnauthenticated with the failure message', () async {
      const failure = ValidationFailure({}, 'Invalid username or password, or this account cannot sign in here.');
      final container = await _readyContainer(
        _FakeAuthRepository(),
        _FakeEmployerAuthRepository(loginResult: const Failed(failure)),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).loginEmployer(
        usernameOrEmail: 'acmehr',
        password: 'wrong',
      );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).errorMessage, failure.message);
    });

    test('registerEmployer() success moves state to AuthAuthenticated with isEmployer:true', () async {
      const user = AuthUser(username: 'acmehr', isEmployer: true);
      final container = await _readyContainer(
        _FakeAuthRepository(),
        _FakeEmployerAuthRepository(registerResult: const Success(user)),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).registerEmployer(_sampleRegistration);

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, user);
    });

    test('registerEmployer() failure moves state to AuthUnauthenticated with the failure message', () async {
      const failure = ValidationFailure({}, 'Registration failed.');
      final container = await _readyContainer(
        _FakeAuthRepository(),
        _FakeEmployerAuthRepository(registerResult: const Failed(failure)),
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).registerEmployer(_sampleRegistration);

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).errorMessage, failure.message);
    });

    test(
      'logout() then a new login() invalidates user-scoped providers (e.g. Dashboard), so a different '
      'account never sees the previous account\'s cached data',
      () async {
        // Confirmed live, on-device, with two real production accounts in
        // the same app session: without this invalidation, every
        // `AsyncNotifierProvider`-based controller (Dashboard, Profile,
        // Resume history, Employer Dashboard, etc.) stays alive in the
        // single app-wide `ProviderContainer` for the process's lifetime —
        // logging out and back in as someone else showed the PREVIOUS
        // account's Dashboard stats verbatim under the new account's name.
        final dashboardRepo = _FakeDashboardRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'a'))),
            dashboardRepositoryProvider.overrideWithValue(dashboardRepo),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);

        // User A's Dashboard is fetched and cached.
        final firstFetch = await container.read(dashboardControllerProvider.future);
        expect(firstFetch.stats.completedCount, 1);
        expect(dashboardRepo.callCount, 1);

        // Re-reading without any session change must NOT refetch — this is
        // the normal, desired caching behavior the fix must not break.
        await container.read(dashboardControllerProvider.future);
        expect(dashboardRepo.callCount, 1);

        await container.read(authControllerProvider.notifier).logout();

        // User B logs in. The stale Dashboard data from User A must be gone
        // — reading it again must trigger a genuine refetch, not serve the
        // old cached value.
        final authRepo = _FakeAuthRepository(loginResult: const Success(AuthUser(username: 'b')));
        container.updateOverrides([
          authRepositoryProvider.overrideWithValue(authRepo),
          dashboardRepositoryProvider.overrideWithValue(dashboardRepo),
        ]);
        await container.read(authControllerProvider.notifier).login(usernameOrEmail: 'b', password: 'secret');

        final secondFetch = await container.read(dashboardControllerProvider.future);
        expect(dashboardRepo.callCount, 2, reason: 'Dashboard must refetch for the new account, not serve User A\'s cached data');
        expect(secondFetch.stats.completedCount, 2);
      },
    );
  });
}
