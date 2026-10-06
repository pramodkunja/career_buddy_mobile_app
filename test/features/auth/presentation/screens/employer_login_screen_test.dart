import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/employer_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/employer_auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/auth/presentation/screens/employer_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => throw UnimplementedError();

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeEmployerAuthRepository implements EmployerAuthRepository {
  _FakeEmployerAuthRepository({this.loginResult});

  Result<AuthUser>? loginResult;
  int loginCallCount = 0;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    loginCallCount++;
    return loginResult!;
  }

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(EmployerRegistrationData data) async => throw UnimplementedError();
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.employerLogin,
  routes: [
    GoRoute(path: RoutePaths.employerLogin, builder: (context, state) => const EmployerLoginScreen()),
    GoRoute(path: RoutePaths.employerRegister, builder: (context, state) => const Scaffold(body: Text('Employer Registration Screen'))),
    GoRoute(path: RoutePaths.employerHome, builder: (context, state) => const Scaffold(body: Text('Employer Home Screen'))),
    GoRoute(path: RoutePaths.employerDashboard, builder: (context, state) => const Scaffold(body: Text('Employer Dashboard Screen'))),
    GoRoute(path: RoutePaths.login, builder: (context, state) => const Scaffold(body: Text('Login Screen'))),
  ],
);

Future<_FakeEmployerAuthRepository> _pump(WidgetTester tester, {Result<AuthUser>? loginResult}) async {
  // The shared shell (top bar + footer + chatbot) is taller than the
  // default 800x600 test surface once stacked with the login card.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeEmployerAuthRepository(loginResult: loginResult);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        employerAuthRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('EmployerLoginScreen', () {
    testWidgets('renders the header, form fields, and secondary links', (tester) async {
      await _pump(tester);

      expect(find.text('Employer Login'), findsOneWidget);
      expect(find.text('Sign in to your hiring dashboard'), findsOneWidget);
      expect(find.text('Username or Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Employer Account'), findsOneWidget);
      expect(find.text('Job Seeker Login'), findsOneWidget);
    });

    testWidgets('shows a validation error and does not submit when fields are empty', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Username or email is required.'), findsOneWidget);
      expect(repo.loginCallCount, 0);
    });

    testWidgets('submitting valid credentials calls the repository and shows a server error inline', (tester) async {
      final repo = await _pump(
        tester,
        loginResult: const Failed(ValidationFailure({}, 'Invalid username or password.')),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Enter username or email').first, 'acme');
      await tester.enterText(find.widgetWithText(TextField, 'Enter password').first, 'wrongpass');
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.loginCallCount, 1);
      expect(find.text('Invalid username or password.'), findsOneWidget);
    });

    testWidgets('a successful login calls the employer repository and shows no error', (tester) async {
      // Post-login navigation is the top-level auth-redirect guard's job
      // (covered separately in `route_guards_test.dart`), same convention
      // as the student `LoginScreen`'s own tests — this mini router has no
      // redirect wired.
      final repo = await _pump(
        tester,
        loginResult: const Success(AuthUser(username: 'acme', isEmployer: true)),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Enter username or email').first, 'acme');
      await tester.enterText(find.widgetWithText(TextField, 'Enter password').first, 'Abcdef1!');
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.loginCallCount, 1);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('tapping Create Employer Account navigates to registration', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('Create Employer Account'));
      await tester.tap(find.text('Create Employer Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Employer Registration Screen'), findsOneWidget);
    });

    testWidgets('tapping Job Seeker Login navigates to the student login', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('Job Seeker Login'));
      await tester.tap(find.text('Job Seeker Login'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
