import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/roleplay/data/roleplay_topics_data.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/screens/roleplay_home_screen.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/screens/roleplay_practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _pump(WidgetTester tester, {Size size = const Size(800, 1600)}) async {
  // Tall enough for all 3 topic cards to be realized by the
  // (lazily-built) `ListView` at once — the default 800×600 test surface
  // isn't.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
      child: const MaterialApp(home: RoleplayHomeScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('RoleplayHomeScreen', () {
    testWidgets('shows the real hero copy and all 3 real sub-feature topics', (tester) async {
      await _pump(tester);

      expect(find.text('Topic Practice Workshop'), findsOneWidget);
      for (final topic in RoleplayTopicsData.all) {
        expect(find.text(topic.pageTitle), findsOneWidget);
        expect(find.text(topic.pageDescription), findsOneWidget);
        // Not `findsOneWidget`: all 3 real topics happen to have exactly 3
        // examples each, so this exact string legitimately repeats.
        expect(find.text('${topic.examples.length} Examples'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a topic card navigates to RoleplayPracticeScreen for that topic', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Start Session').first);
      // Never pumpAndSettle() once `BuddyChatbotOverlay` is in the tree —
      // its launcher's float animation repeats forever and would hang this.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final screen = tester.widget<RoleplayPracticeScreen>(find.byType(RoleplayPracticeScreen));
      expect(screen.topicSlug, RoleplayTopicsData.all.first.slug);
    });

    testWidgets('renders without overflow at 320/375/430px', (tester) async {
      for (final width in [320.0, 375.0, 430.0]) {
        await _pump(tester, size: Size(width, 1600));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
