import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_session_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_recording_screen.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_result_screen.dart';
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

JamSessionStart _session() =>
    const JamSessionStart(sessionId: 42, topicTitle: 'My Family', topicDescription: 'Talk about family.', topicDifficulty: 'easy');

/// Never resolves `startSession` — the recording screen's own `initState`
/// always kicks off a real `startSession` call regardless of the fixed
/// controller state these tests inject, so every test needs this override
/// to avoid hitting the real (unconfigured-in-tests) network stack.
class _NeverJamRepository implements JamRepository {
  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) => Completer<Result<JamSessionStart>>().future;

  @override
  Future<Result<List<JamTopic>>> getTopics() async => const Success([]);

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) => throw UnimplementedError();

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) => throw UnimplementedError();
}

/// A [JamSessionController] that starts from a fixed, caller-supplied
/// state — lets widget tests render every sealed state without driving the
/// real recorder/timer/network machinery, same pattern as
/// `ai_speaking_screen_test.dart`'s `_FixedController`. `build()`
/// deliberately skips wiring `_recorder`, so only actions that don't touch
/// it (`getFeedback` after already-uploaded states) are safe to trigger
/// from a test using this.
class _FixedSessionController extends JamSessionController {
  _FixedSessionController(this.fixedState);
  final JamSessionState fixedState;

  @override
  JamSessionState build() => fixedState;

  /// Test-only: pushes a new state directly, to exercise `ref.listen`
  /// side effects (e.g. navigation on `JamResultReady`) that only fire on a
  /// state *change*, not on the fixed initial state itself.
  void emit(JamSessionState next) => state = next;
}

Future<void> _pumpFixed(WidgetTester tester, JamSessionState fixedState, {int? topicId}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jamSessionControllerProvider.overrideWith(() => _FixedSessionController(fixedState)),
        jamRepositoryProvider.overrideWithValue(_NeverJamRepository()),
      ],
      child: MaterialApp(home: JamRecordingScreen(topicId: topicId)),
    ),
  );
  await tester.pump();
}

void main() {
  group('rendering — starting', () {
    testWidgets('shows a loader while starting the session', (tester) async {
      await _pumpFixed(tester, const JamSessionInitial());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a retryable error when starting fails', (tester) async {
      await _pumpFixed(tester, const JamStartFailed(ServerFailure()));
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('rendering — ready (instructions)', () {
    testWidgets('shows the topic title/description/difficulty and the start button', (tester) async {
      await _pumpFixed(tester, JamReady(session: _session()));

      expect(find.text('My Family'), findsOneWidget);
      expect(find.text('Talk about family.'), findsOneWidget);
      expect(find.text('EASY'), findsOneWidget);
      expect(find.text("I'm Ready — Start Session"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a mic error message when one is set', (tester) async {
      await _pumpFixed(tester, JamReady(session: _session(), micErrorMessage: 'Microphone access denied.'));
      expect(find.text('Microphone access denied.'), findsOneWidget);
    });
  });

  group('rendering — recording', () {
    testWidgets('shows the remaining time and a Stop button', (tester) async {
      await _pumpFixed(tester, JamRecordingInProgress(session: _session(), elapsedSeconds: 55));

      expect(find.text('0:05'), findsOneWidget); // 60 - 55 remaining
      expect(find.text('RECORDING LIVE'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });
  });

  group('rendering — too short / uploading / upload failed', () {
    testWidgets('too-short shows the retry copy and a Try Again button', (tester) async {
      await _pumpFixed(tester, JamRecordingTooShort(session: _session()));

      expect(find.text('Recording too short, please try again.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('uploading shows a loader', (tester) async {
      await _pumpFixed(tester, JamUploading(session: _session(), audioFilePath: '/tmp/a.m4a', elapsedSeconds: 30));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('upload failure shows the failure message and a Retry action', (tester) async {
      await _pumpFixed(
        tester,
        JamUploadFailed(session: _session(), audioFilePath: '/tmp/a.m4a', elapsedSeconds: 30, failure: const ServerFailure()),
      );

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('rendering — captured / completing / complete failed', () {
    testWidgets('captured shows "Session Captured Successfully" and Get AI Feedback', (tester) async {
      await _pumpFixed(tester, JamReadyForFeedback(session: _session(), elapsedSeconds: 48));

      expect(find.text('Session Captured Successfully'), findsOneWidget);
      expect(find.text('You spoke for 48 seconds.'), findsOneWidget);
      expect(find.text('Get AI Feedback'), findsOneWidget);
    });

    testWidgets('completing shows a loader', (tester) async {
      await _pumpFixed(tester, JamCompleting(session: _session()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('complete failure shows the failure message and Retry', (tester) async {
      await _pumpFixed(tester, JamCompleteFailed(session: _session(), failure: const ServerFailure()));
      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('navigation on result', () {
    testWidgets('transitioning to JamResultReady navigates to JamResultScreen', (tester) async {
      const result = JamSessionResult(
        sessionId: 42,
        topicTitle: 'My Family',
        topicDifficulty: 'easy',
        durationDisplay: '48s',
        confidenceScore: 4,
        fluencyScore: 4,
        languageScore: 4,
        pronunciationScore: 4,
        timeManagementScore: 4,
        overallScore: 20,
        transcript: 'Some transcript.',
        aiFeedback: 'Great job.',
        improvementTips: 'Keep going.',
        audioUrl: null,
        createdAtDisplay: 'Feb 10 2026',
      );
      final controller = _FixedSessionController(JamCompleting(session: _session()));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            jamSessionControllerProvider.overrideWith(() => controller),
            jamRepositoryProvider.overrideWithValue(_NeverJamRepository()),
          ],
          child: const MaterialApp(home: JamRecordingScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(JamResultScreen), findsNothing);

      controller.emit(const JamResultReady(result));
      await tester.pump();
      await tester.pump();

      expect(find.byType(JamResultScreen), findsOneWidget);
      expect(find.text('Great job.'), findsOneWidget);
    });
  });
}
