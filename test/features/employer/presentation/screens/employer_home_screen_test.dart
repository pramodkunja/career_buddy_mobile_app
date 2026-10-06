import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/employer_home_screen.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  final AuthUser? restoredUser;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

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

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.employerHome,
  routes: [
    GoRoute(path: RoutePaths.employerHome, builder: (context, state) => const EmployerHomeScreen()),
    GoRoute(path: RoutePaths.employerLogin, builder: (context, state) => const Scaffold(body: Text('Employer Login Screen'))),
    GoRoute(path: RoutePaths.employerRegister, builder: (context, state) => const Scaffold(body: Text('Employer Registration Screen'))),
    GoRoute(path: RoutePaths.employerDashboard, builder: (context, state) => const Scaffold(body: Text('Employer Dashboard Screen'))),
    GoRoute(path: RoutePaths.employerSearchCandidates, builder: (context, state) => const ComingSoonScreen(title: 'Candidate Search', message: 'x')),
  ],
);

Future<void> _pump(WidgetTester tester, {AuthUser? user}) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: user))],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
}

Future<void> _pumpAfterTap(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('EmployerHomeScreen (guest)', () {
    testWidgets('renders the hero cards, How It Works section, and guest CTAs', (tester) async {
      await _pump(tester);

      expect(find.text('Screen Top Candidates with AI'), findsOneWidget);
      expect(find.text('Build Your Dream Team'), findsOneWidget);
      expect(find.text('How It Works'), findsOneWidget);
      expect(find.text('Post Your Job'), findsOneWidget);
      expect(find.text('AI-Powered Screening'), findsOneWidget);
      expect(find.text('Direct Hire'), findsOneWidget);
      expect(find.text('Join as Recruiter'), findsOneWidget);
      expect(find.text('Employer Login'), findsOneWidget);
      expect(find.text('Manage Dashboard'), findsNothing);
    });

    testWidgets('tapping Join as Recruiter navigates to registration', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Join as Recruiter'));
      await _pumpAfterTap(tester);

      expect(find.text('Employer Registration Screen'), findsOneWidget);
    });

    testWidgets('tapping Employer Login navigates to the login screen', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Employer Login'));
      await _pumpAfterTap(tester);

      expect(find.text('Employer Login Screen'), findsOneWidget);
    });
  });

  group('EmployerHomeScreen (authenticated)', () {
    const employer = AuthUser(username: 'acmehr', isEmployer: true);

    testWidgets('shows Manage Dashboard / Find Candidates instead of the guest CTAs', (tester) async {
      await _pump(tester, user: employer);

      expect(find.text('Manage Dashboard'), findsOneWidget);
      expect(find.text('Find Candidates'), findsOneWidget);
      expect(find.text('Join as Recruiter'), findsNothing);
    });

    testWidgets('tapping Manage Dashboard navigates to the employer dashboard', (tester) async {
      await _pump(tester, user: employer);

      await tester.tap(find.text('Manage Dashboard'));
      await _pumpAfterTap(tester);

      expect(find.text('Employer Dashboard Screen'), findsOneWidget);
    });
  });
}
