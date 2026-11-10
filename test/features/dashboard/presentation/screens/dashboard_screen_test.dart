import 'package:career_buddy_lms/app/theme/app_theme.dart';
import 'package:career_buddy_lms/app/theme/theme_provider.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
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

class _FakeStorageService extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}

/// A themed wrapper that lets the test's [ProviderScope] drive [themeMode] so
/// tapping the toggle icon causes a real theme rebuild.
class _ThemedTestApp extends ConsumerWidget {
  const _ThemedTestApp({required this.authRepo, required this.dashboardRepo});

  final AuthRepository authRepo;
  final DashboardRepository dashboardRepo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const DashboardScreen(),
    );
  }
}

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
      // Phase 71 — "Activities" moved from a flat drawer item into the
      // Resources submenu; "Resources" itself is still a reliable
      // top-level, always-visible marker that the drawer rendered real
      // content, not a blank/broken one.
      expect(find.text('Resources'), findsOneWidget);
    },
  );

  testWidgets('logout icon is not shown in the AppBar', (tester) async {
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

    expect(find.byIcon(Icons.logout), findsNothing);
  });

  testWidgets('AppBar shows the dark_mode (moon) icon when the theme is light', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'jane'))),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(const Failed(NotFoundFailure())),
          ),
        ],
        // Plain MaterialApp defaults to light theme — the icon should be the moon.
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);
  });

  testWidgets('tapping the theme toggle switches ThemeModeNotifier to dark and persists the choice', (tester) async {
    final authRepo = _FakeAuthRepository(restoredUser: const AuthUser(username: 'jane'));
    final dashRepo = _FakeDashboardRepository(const Failed(NotFoundFailure()));
    final storage = _FakeStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          dashboardRepositoryProvider.overrideWithValue(dashRepo),
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: _ThemedTestApp(authRepo: authRepo, dashboardRepo: dashRepo),
      ),
    );
    await _settle(tester);

    // Start in light mode — moon icon visible.
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await _settle(tester);

    // The provider state must have changed to dark.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // The choice must be persisted to storage.
    expect(await storage.read('app_theme_mode'), 'dark');

    // The sun icon must be shown after MaterialApp finishes its theme animation
    // (AnimatedTheme default duration is 200 ms).
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
  });
}
