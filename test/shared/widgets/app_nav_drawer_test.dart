import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/shared/widgets/app_nav_drawer.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  final AuthUser? restoredUser;
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

GoRouter _router() => GoRouter(
  initialLocation: '/host',
  routes: [
    GoRoute(
      path: '/host',
      builder: (context, state) => Scaffold(drawer: const AppNavDrawer(), body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(onPressed: () => Scaffold.of(context).openDrawer(), child: const Text('open')),
        ),
      )),
    ),
    GoRoute(path: RoutePaths.login, builder: (context, state) => const Scaffold(body: Text('Login Screen'))),
    GoRoute(path: RoutePaths.employerLogin, builder: (context, state) => const ComingSoonScreen(title: 'Employer Portal', message: 'x')),
    GoRoute(path: RoutePaths.home, builder: (context, state) => const Scaffold(body: Text('Home Screen'))),
    GoRoute(path: RoutePaths.activities, builder: (context, state) => const Scaffold(body: Text('Activities Screen'))),
    GoRoute(path: RoutePaths.dashboard, builder: (context, state) => const Scaffold(body: Text('Dashboard Screen'))),
    GoRoute(path: RoutePaths.skillUp, builder: (context, state) => const ComingSoonScreen(title: 'Skill Up', message: 'x')),
    GoRoute(path: RoutePaths.skillUpSections, builder: (context, state) => const ComingSoonScreen(title: 'Skill Up Sections', message: 'x')),
    GoRoute(path: RoutePaths.sitemap, builder: (context, state) => const ComingSoonScreen(title: 'Sitemap', message: 'x')),
    GoRoute(path: RoutePaths.resumeBuilder, builder: (context, state) => const ComingSoonScreen(title: 'Resume Parsing', message: 'x')),
    GoRoute(path: RoutePaths.grammar, builder: (context, state) => const ComingSoonScreen(title: 'Grammar', message: 'x')),
    GoRoute(path: RoutePaths.pro, builder: (context, state) => const ComingSoonScreen(title: 'Upgrade Plan', message: 'x')),
    GoRoute(path: RoutePaths.profile, builder: (context, state) => const ComingSoonScreen(title: 'Profile', message: 'x')),
    GoRoute(path: RoutePaths.employerDashboard, builder: (context, state) => const Scaffold(body: Text('Employer Dashboard Screen'))),
    GoRoute(path: RoutePaths.employerJobCreate, builder: (context, state) => const ComingSoonScreen(title: 'Post New Job', message: 'x')),
    GoRoute(path: RoutePaths.employerAllApplications, builder: (context, state) => const ComingSoonScreen(title: 'All Applications', message: 'x')),
    GoRoute(path: RoutePaths.employerCompanyProfile, builder: (context, state) => const ComingSoonScreen(title: 'Company Profile', message: 'x')),
    GoRoute(path: RoutePaths.employerJobOpenings, builder: (context, state) => const ComingSoonScreen(title: 'Job Openings', message: 'x')),
    GoRoute(path: RoutePaths.employerSearchCandidates, builder: (context, state) => const ComingSoonScreen(title: 'Candidate Search', message: 'x')),
  ],
);

Future<_FakeAuthRepository> _pumpDrawer(WidgetTester tester, {AuthUser? user}) async {
  final repo = _FakeAuthRepository(restoredUser: user);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('AppNavDrawer (unauthenticated)', () {
    testWidgets('shows Job Seeker Login and Employer Login tiles', (tester) async {
      await _pumpDrawer(tester);

      expect(find.text('Job Seeker Login'), findsOneWidget);
      expect(find.text('Employer Login'), findsOneWidget);
      expect(find.text('Logout'), findsNothing);
    });

    testWidgets('tapping Job Seeker Login navigates to /login', (tester) async {
      await _pumpDrawer(tester);

      await tester.tap(find.text('Job Seeker Login'));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('tapping Employer Login navigates to the Employer Portal placeholder', (tester) async {
      await _pumpDrawer(tester);

      await tester.tap(find.text('Employer Login'));
      await tester.pumpAndSettle();

      expect(find.text('Employer Portal'), findsOneWidget);
    });
  });

  group('AppNavDrawer (authenticated)', () {
    const user = AuthUser(username: 'janedoe');

    testWidgets('shows the authenticated nav items instead of the login tiles', (tester) async {
      await _pumpDrawer(tester, user: user);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Skill Up'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('janedoe'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Job Seeker Login'), findsNothing);
    });

    testWidgets('tapping Dashboard navigates to /dashboard', (tester) async {
      await _pumpDrawer(tester, user: user);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Screen'), findsOneWidget);
    });

    testWidgets('tapping Logout calls the auth repository logout', (tester) async {
      final repo = await _pumpDrawer(tester, user: user);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(repo.logoutCallCount, 1);
    });
  });

  group('AppNavDrawer (authenticated employer)', () {
    const employer = AuthUser(username: 'acmehr', isEmployer: true);

    testWidgets('shows the employer nav items instead of the student ones', (tester) async {
      await _pumpDrawer(tester, user: employer);

      expect(find.text('Employer Dashboard'), findsOneWidget);
      expect(find.text('Post New Job'), findsOneWidget);
      expect(find.text('All Applications'), findsOneWidget);
      expect(find.text('Company Profile'), findsOneWidget);
      expect(find.text('Job Openings'), findsOneWidget);
      expect(find.text('Candidate Search'), findsOneWidget);
      expect(find.text('acmehr'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Not the student branch's items.
      expect(find.text('Skill Up'), findsNothing);
      expect(find.text('Activities'), findsNothing);
      expect(find.text('Pro'), findsNothing);
    });

    testWidgets('tapping Employer Dashboard navigates to it', (tester) async {
      await _pumpDrawer(tester, user: employer);

      await tester.tap(find.text('Employer Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Employer Dashboard Screen'), findsOneWidget);
    });

    testWidgets('tapping Logout calls the auth repository logout', (tester) async {
      final repo = await _pumpDrawer(tester, user: employer);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(repo.logoutCallCount, 1);
    });
  });
}
