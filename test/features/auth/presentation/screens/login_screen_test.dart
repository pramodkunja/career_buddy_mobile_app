import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/auth/presentation/screens/login_screen.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Mirrors `templates/users/login.html`. `restoreSession` always returns
/// null: these tests exercise [LoginScreen] directly, not the app's
/// top-level auth-redirect guard (covered separately in
/// `test/app/router/route_guards_test.dart`).
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginResult});

  Result<AuthUser>? loginResult;
  Completer<Result<AuthUser>>? pendingLogin;
  int loginCallCount = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    loginCallCount++;
    lastUsername = usernameOrEmail;
    lastPassword = password;
    if (pendingLogin != null) return pendingLogin!.future;
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

/// A router covering just the login screen and the three placeholder
/// destinations it links to (`app_router.dart`'s real wiring), with no
/// top-level auth redirect — that's `route_guards_test.dart`'s job.
Widget _buildApp(_FakeAuthRepository repo) {
  final router = GoRouter(
    initialLocation: RoutePaths.login,
    routes: [
      GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const ComingSoonScreen(title: 'Create Account', message: 'not built yet'),
      ),
      GoRoute(
        path: RoutePaths.passwordReset,
        builder: (context, state) => const ComingSoonScreen(title: 'Forgot Password', message: 'not built yet'),
      ),
      GoRoute(
        path: RoutePaths.employerLogin,
        builder: (context, state) => const ComingSoonScreen(title: 'Employer Portal', message: 'not built yet'),
      ),
      GoRoute(
        path: RoutePaths.demoEntry,
        builder: (context, state) => const Scaffold(body: Text('Demo Entry Screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _enterCredentials(WidgetTester tester, {String username = 'jane', String password = 'secret'}) async {
  await tester.enterText(find.byType(TextFormField).first, username);
  await tester.enterText(find.byType(TextFormField).last, password);
}

/// The new two-pane layout (branding pane + form pane, stacked below the
/// web's own 860px breakpoint) is materially taller than the old
/// single-pane form — well below the fold at the default 800×600 test
/// window. A tall viewport keeps every control reachable for taps,
/// matching the same gotcha/fix already established for the AI-module
/// screen tests (`ai_reading_screen_test.dart` etc.).
void _setTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders the web login page\'s title, fields, and links', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      expect(find.text('Job Seeker Sign In'), findsOneWidget);
      expect(find.text('Enter your login credentials to access your dashboard'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In to Dashboard'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create Free Candidate Account'), findsOneWidget);
      expect(find.text('Employer Portal Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the branding pane\'s "Welcome Back!" copy and the 4-item feature checklist', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      expect(find.text('Career Buddy'), findsOneWidget);
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('20+ Comprehensive Learning Activities'), findsOneWidget);
      expect(find.text('Interactive Exercises & Speaking Quizzes'), findsOneWidget);
      expect(find.text('AI Resume Matcher & ATS Score Analytics'), findsOneWidget);
      expect(find.text('Direct Recruiter Hiring & Job Applications'), findsOneWidget);
    });

    testWidgets('lays out as a wide two-pane Row at >=860px and a stacked Column below it', (tester) async {
      Future<bool> hasSideBySidePanes() async {
        return find
            .byWidgetPredicate((w) => w is Row && w.crossAxisAlignment == CrossAxisAlignment.stretch)
            .evaluate()
            .isNotEmpty;
      }

      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();
      expect(await hasSideBySidePanes(), isFalse, reason: 'below the 860px breakpoint the panes should stack');

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(1024, 900);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();
      expect(await hasSideBySidePanes(), isTrue, reason: 'at/above the 860px breakpoint the panes should sit side by side');
    });

    // `flutter test` runs in a debug-mode-equivalent environment, so
    // `kDebugMode` is true here and the button renders — matching what a
    // developer running `flutter run` (debug) sees. See
    // `demo_mode_toggle_test.dart` for the same, unavoidable limitation on
    // testing the release (`!kDebugMode`) branch from this test process.
    testWidgets('shows a debug-only "Preview Demo (Debug)" entry that navigates to Direct Demo Entry', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      expect(find.text('Preview Demo (Debug)'), findsOneWidget);

      await tester.ensureVisible(find.text('Preview Demo (Debug)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Preview Demo (Debug)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Demo Entry Screen'), findsOneWidget);
    });

    testWidgets('shows a required-field error for an empty username and an empty password', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();

      expect(find.text('Username or email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('password visibility toggle switches obscureText', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('submits the trimmed username and the exact password', (tester) async {
      _setTallWindow(tester);
      final repo = _FakeAuthRepository(loginResult: const Success(AuthUser(username: 'jane')));
      await tester.pumpWidget(_buildApp(repo));
      await tester.pump();

      await _enterCredentials(tester, username: '  jane  ', password: 'secret');
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.loginCallCount, 1);
      expect(repo.lastUsername, 'jane');
      expect(repo.lastPassword, 'secret');
    });

    testWidgets('shows a loading state and prevents duplicate submission while login is in flight', (
      tester,
    ) async {
      _setTallWindow(tester);
      final repo = _FakeAuthRepository()..pendingLogin = Completer<Result<AuthUser>>();
      await tester.pumpWidget(_buildApp(repo));
      await tester.pump();

      await _enterCredentials(tester);
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();

      // Loading: the label is replaced by a spinner and re-tapping doesn't
      // fire a second request.
      expect(find.text('Sign In to Dashboard'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      await tester.pump();
      expect(repo.loginCallCount, 1);

      repo.pendingLogin!.complete(const Success(AuthUser(username: 'jane')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('invalid credentials show the mapped error message', (tester) async {
      const message = 'Invalid username or password, or this account cannot sign in here.';
      _setTallWindow(tester);
      final repo = _FakeAuthRepository(
        loginResult: const Failed(ValidationFailure({'form': [message]}, message)),
      );
      await tester.pumpWidget(_buildApp(repo));
      await tester.pump();

      await _enterCredentials(tester, password: 'wrong');
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(message), findsOneWidget);
      // `.alert.alert-danger` (`login.html:49-65`) is an inline, persistent
      // box in the page itself — not a transient SnackBar.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('a network failure shows the project\'s standard network-error message', (tester) async {
      _setTallWindow(tester);
      final repo = _FakeAuthRepository(loginResult: const Failed(NetworkFailure()));
      await tester.pumpWidget(_buildApp(repo));
      await tester.pump();

      await _enterCredentials(tester);
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(const NetworkFailure().message), findsOneWidget);
    });

    testWidgets('a server failure shows the project\'s standard server-error message and stays retryable', (
      tester,
    ) async {
      _setTallWindow(tester);
      final repo = _FakeAuthRepository(loginResult: const Failed(ServerFailure()));
      await tester.pumpWidget(_buildApp(repo));
      await tester.pump();

      await _enterCredentials(tester);
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(const ServerFailure().message), findsOneWidget);
      // The form is still there (not replaced by a dead-end), so the user
      // can retry immediately.
      expect(find.text('Sign In to Dashboard'), findsOneWidget);

      repo.loginResult = const Success(AuthUser(username: 'jane'));
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.loginCallCount, 2);
    });

    testWidgets('Forgot password navigates to the password-reset placeholder', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('not built yet'), findsOneWidget);
    });

    testWidgets('Create Free Candidate Account navigates to the registration placeholder', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      await tester.tap(find.text('Create Free Candidate Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('not built yet'), findsOneWidget);
    });

    testWidgets('Employer Portal Sign In navigates to the employer-login placeholder', (tester) async {
      _setTallWindow(tester);
      await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
      await tester.pump();

      await tester.tap(find.text('Employer Portal Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Employer Portal'), findsOneWidget);
      expect(find.text('not built yet'), findsOneWidget);
    });

    testWidgets('renders without overflow at narrow phone and tablet widths', (tester) async {
      // 320/375/430 stay below the web's own 860px stack breakpoint
      // (single-pane); 1024 is above it (two-pane) — both layouts get
      // exercised. Heights are generous since the stacked layout is
      // materially taller than the old single-pane form.
      for (final size in [const Size(320, 1400), const Size(375, 1300), const Size(430, 1300), const Size(1024, 900)]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildApp(_FakeAuthRepository()));
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });
  });
}
