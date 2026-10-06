import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/quiz_subject.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/screens/mock_tests_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly avoids that without this file's own
/// tests needing to care about auth at all.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async =>
      throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: RoutePaths.mockTestsHub,
    routes: [
      GoRoute(
        path: RoutePaths.mockTestsHub,
        builder: (context, state) => const MockTestsHubScreen(),
      ),
      GoRoute(
        path: RoutePaths.oopMasteryMockTest,
        builder: (context, state) => const Scaffold(body: Text('OOP SCREEN')),
      ),
      GoRoute(
        path: RoutePaths.amcatMockTest,
        builder: (context, state) => const Scaffold(body: Text('AMCAT SCREEN')),
      ),
      GoRoute(
        path: RoutePaths.cocubesMockTest,
        builder: (context, state) =>
            const Scaffold(body: Text('COCUBES SCREEN')),
      ),
      GoRoute(
        path: RoutePaths.subjectQuizPattern,
        builder: (context, state) => Scaffold(
          body: Text('SUBJECT SCREEN: ${state.pathParameters['subject']}'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('lists OOP Mastery plus every kQuizSubjects entry', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('OOP Mastery'), findsOneWidget);
    // Scrolling forward through the 25-item list in the same order the
    // subjects appear — each is further down than the last, so a single
    // forward scroll per item (never needing to scroll back up) reaches
    // every one, including those below the initial viewport + cache extent.
    for (final subject in kQuizSubjects) {
      await tester.scrollUntilVisible(
        find.text(subject.title),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text(subject.title),
        findsOneWidget,
        reason: 'missing tile for "${subject.slug}"',
      );
    }
  });

  testWidgets('tapping OOP Mastery navigates to the OOP route', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('OOP Mastery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('OOP SCREEN'), findsOneWidget);
  });

  testWidgets('tapping AMCAT Mock Test navigates to the AMCAT route', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('AMCAT Mock Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('AMCAT SCREEN'), findsOneWidget);
  });

  testWidgets('tapping CoCubes Mock Test navigates to the CoCubes route', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('CoCubes Mock Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('COCUBES SCREEN'), findsOneWidget);
  });

  testWidgets(
    'tapping a subject navigates to the subject route with the correct slug',
    (tester) async {
      await _pump(tester);

      await tester.scrollUntilVisible(
        find.text('DSA Mastery'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('DSA Mastery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('SUBJECT SCREEN: dsa'), findsOneWidget);
    },
  );

  testWidgets('renders without overflow at narrow phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    expect(tester.takeException(), isNull);
  });
}
