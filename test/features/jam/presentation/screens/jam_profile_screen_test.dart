import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_history_profile.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_profile_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly — same pattern as
/// `GrammarDetailScreen`'s own test doubles — avoids that without this
/// screen's own tests needing to care about auth at all.
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

class _FakeRepository implements JamProfileRepository {
  _FakeRepository(this.profileResult);

  Result<JamProfile> profileResult;
  Result<void> updateResult = const Success(null);
  Result<void> resetResult = const Success(null);
  JamProfileUpdate? lastUpdate;
  int resetCallCount = 0;

  @override
  Future<Result<JamProfile>> getProfile() async => profileResult;

  @override
  Future<Result<void>> updateProfile(JamProfileUpdate data) async {
    lastUpdate = data;
    return updateResult;
  }

  @override
  Future<Result<void>> resetProgress() async {
    resetCallCount++;
    return resetResult;
  }
}

const _profile = JamProfile(
  fullName: 'Alex Kumar',
  email: 'alex@example.com',
  firstName: 'Alex',
  lastName: 'Kumar',
  bio: 'Learning for my new job.',
  totalSessions: 12,
  totalMinutes: 34,
);

Future<_FakeRepository> _pump(WidgetTester tester, Result<JamProfile> result) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeRepository(result);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jamProfileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: JamProfileScreen()),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('JamProfileScreen', () {
    testWidgets('renders stats and pre-fills the edit form', (tester) async {
      await _pump(tester, const Success(_profile));

      expect(find.text('Alex Kumar'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('34m'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'First Name'), findsOneWidget);
    });

    testWidgets('saving calls updateProfile with the edited values', (tester) async {
      final repo = await _pump(tester, const Success(_profile));

      await tester.enterText(find.widgetWithText(TextField, 'First Name'), 'Alexis');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(repo.lastUpdate?.firstName, 'Alexis');
      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    testWidgets('Reset All Progress shows a confirmation and calls the repository', (tester) async {
      final repo = await _pump(tester, const Success(_profile));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset All Progress'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('cannot be undone'), findsWidgets);

      await tester.tap(find.widgetWithText(TextButton, 'Reset All Progress'));
      await tester.pump();
      await tester.pump();

      expect(repo.resetCallCount, 1);
      expect(find.text('All progress has been reset successfully.'), findsOneWidget);
    });

    testWidgets('canceling the reset dialog does not call the repository', (tester) async {
      final repo = await _pump(tester, const Success(_profile));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset All Progress'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(repo.resetCallCount, 0);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
