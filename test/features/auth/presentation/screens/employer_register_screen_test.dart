import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/employer_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/employer_auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/auth/presentation/screens/employer_register_screen.dart';
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
  _FakeEmployerAuthRepository();

  Result<String> otpResult = const Success('Code sent to this email.');
  Result<String> verifyResult = const Success('Verified.');
  Result<AuthUser>? registerResult;
  EmployerRegistrationData? lastRegistration;
  int registerCallCount = 0;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> sendOtp(String email) async => otpResult;

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async => verifyResult;

  @override
  Future<Result<AuthUser>> register(EmployerRegistrationData data) async {
    registerCallCount++;
    lastRegistration = data;
    return registerResult!;
  }
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.employerRegister,
  routes: [
    GoRoute(path: RoutePaths.employerRegister, builder: (context, state) => const EmployerRegisterScreen()),
    GoRoute(path: RoutePaths.employerLogin, builder: (context, state) => const Scaffold(body: Text('Employer Login Screen'))),
    GoRoute(path: RoutePaths.employerHome, builder: (context, state) => const Scaffold(body: Text('Employer Home Screen'))),
  ],
);

Future<_FakeEmployerAuthRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeEmployerAuthRepository();
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
  group('EmployerRegisterScreen', () {
    testWidgets('renders the header and all 4 section cards in the template\'s own order', (tester) async {
      await _pump(tester);

      expect(find.text('Employer Registration'), findsOneWidget);
      expect(find.text('Company Profile'), findsOneWidget);
      expect(find.text('Tax & Registrations'), findsOneWidget);
      expect(find.text('HR / Contact Person'), findsOneWidget);
      expect(find.text('Account Credentials'), findsOneWidget);
      expect(find.text('Create Employer Account'), findsOneWidget);
    });

    testWidgets('shows validation errors for required fields when submitted empty', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('Create Employer Account'));
      await tester.tap(find.text('Create Employer Account'));
      await tester.pump();

      expect(find.text('Company name is required.'), findsOneWidget);
      expect(find.text('HR first name is required.'), findsOneWidget);
      expect(find.text('Username is required.'), findsOneWidget);
    });

    testWidgets('rejects a malformed GST/PAN without blocking on the (optional) fields being empty', (tester) async {
      await _pump(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. 27ABCDE1234F1Z5'), 'not-a-gst');
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. ABCDE1234F (optional)'), '12345');
      await tester.ensureVisible(find.text('Create Employer Account'));
      await tester.tap(find.text('Create Employer Account'));
      await tester.pump();

      expect(find.text('Invalid GSTIN format. Must be 99AAAAA9999A1Z9.'), findsOneWidget);
      expect(
        find.text('Invalid PAN format. Must be AAAAA9999A (5 letters, 4 digits, 1 letter).'),
        findsOneWidget,
      );
    });

    testWidgets('the OTP send/confirm flow marks an email verified and locks the field', (tester) async {
      await _pump(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'HR Email Address *').first, 'hr@acme.com');
      await tester.ensureVisible(find.text('Verify').first);
      await tester.tap(find.text('Verify').first);
      await tester.pump();
      await tester.pump();

      expect(find.text('Enter 6-digit code'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Enter 6-digit code'), '123456');
      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('submitting with all required fields filled but emails unverified shows the OTP gate error', (tester) async {
      await _pump(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Registered Company Name'), 'Acme Corp');
      await tester.enterText(find.widgetWithText(TextFormField, 'HR First Name'), 'Jane');
      await tester.enterText(find.widgetWithText(TextFormField, 'HR Last Name'), 'Doe');
      await tester.enterText(find.widgetWithText(TextFormField, 'HR Email Address *').first, 'hr@acme.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'acmehr');
      await tester.enterText(find.widgetWithText(TextFormField, 'Account Email Address *').first, 'acct@acme.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password').first, 'Abcdef1!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'Abcdef1!');
      await tester.enterText(find.widgetWithText(TextField, 'HR Contact Number'), '9876543210');
      await tester.ensureVisible(find.text('Select Industry'));
      await tester.tap(find.text('Select Industry'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('IT / Software').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.text('Create Employer Account'));
      await tester.tap(find.text('Create Employer Account'));
      await tester.pump();

      expect(
        find.text('Please verify both email addresses with the OTP before creating your account.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping "Sign in here" navigates to Employer Login', (tester) async {
      await _pump(tester);

      await tester.ensureVisible(find.text('Already have an account? Sign in here'));
      await tester.tap(find.text('Already have an account? Sign in here'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Employer Login Screen'), findsOneWidget);
    });
  });
}
