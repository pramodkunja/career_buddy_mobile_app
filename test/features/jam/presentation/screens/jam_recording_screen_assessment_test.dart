import 'dart:async';

import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_session_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_assessment_result_screen.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_recording_screen.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
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

JamSessionStart _stageSession({int stage = 1}) =>
    JamSessionStart(sessionId: 42, topicTitle: 'My Family', topicDescription: 'Talk about family.', topicDifficulty: 'easy', stage: stage);

/// Never resolves anything — this screen's own `initState` always kicks off
/// a real `startSession`/`startAssessment` call regardless of the fixed
/// controller state these tests inject, so every test needs this override
/// to avoid hitting the real (unconfigured-in-tests) network stack. Same
/// role as `jam_recording_screen_test.dart`'s own private `_NeverJamRepository`
/// (not reusable here — that class is file-private).
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
/// state — same technique `jam_recording_screen_test.dart`'s own
/// `_FixedSessionController` uses, duplicated here since that one is
/// file-private.
class _FixedSessionController extends JamSessionController {
  _FixedSessionController(this.fixedState);
  final JamSessionState fixedState;

  @override
  JamSessionState build() => fixedState;

  void emit(JamSessionState next) => state = next;
}

Future<void> _pumpFixed(WidgetTester tester, JamSessionState fixedState, {bool startAsAssessment = false}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jamSessionControllerProvider.overrideWith(() => _FixedSessionController(fixedState)),
        jamRepositoryProvider.overrideWithValue(_NeverJamRepository()),
      ],
      child: MaterialApp(home: JamRecordingScreen(startAsAssessment: startAsAssessment)),
    ),
  );
  await tester.pump();
}

void main() {
  group('assessment stage indicator', () {
    testWidgets('shows "Stage 1 of 3" for a stage-1 session', (tester) async {
      await _pumpFixed(tester, JamReady(session: _stageSession(stage: 1)));

      expect(find.text('Stage 1 of 3'), findsOneWidget);
      expect(find.text('ASSESSMENT JOURNEY'), findsOneWidget);
    });

    testWidgets('shows "Stage 2 of 3" while recording a stage-2 session', (tester) async {
      await _pumpFixed(tester, JamRecordingInProgress(session: _stageSession(stage: 2), elapsedSeconds: 5));

      expect(find.text('Stage 2 of 3'), findsOneWidget);
    });

    testWidgets('is absent for an ordinary (non-assessment) session', (tester) async {
      const ordinary = JamSessionStart(sessionId: 1, topicTitle: 'My Family', topicDescription: '', topicDifficulty: 'easy');
      await _pumpFixed(tester, const JamReady(session: ordinary));

      expect(find.text('ASSESSMENT JOURNEY'), findsNothing);
      expect(find.textContaining('Stage'), findsNothing);
    });

    testWidgets('the captured view shows stage-aware copy ("Next Stage" for stage 1)', (tester) async {
      await _pumpFixed(tester, JamReadyForFeedback(session: _stageSession(stage: 1), elapsedSeconds: 40));

      expect(find.text('Next Stage (Medium)'), findsOneWidget);
      expect(find.text('Get AI Feedback'), findsNothing);
    });

    testWidgets('the captured view shows "Generate Diagnostic Report" for stage 3', (tester) async {
      await _pumpFixed(tester, JamReadyForFeedback(session: _stageSession(stage: 3), elapsedSeconds: 55));

      expect(find.text('Generate Diagnostic Report'), findsOneWidget);
    });
  });

  group('navigation on assessment completion', () {
    testWidgets('transitioning to JamAssessmentResultReady navigates to JamAssessmentResultScreen', (tester) async {
      const finalResult = JamAssessmentResult(
        level: 'Advanced',
        averageDurationSeconds: 50,
        averageFluency: 4.5,
        totalScore: 65,
        stages: [
          JamAssessmentStageSummary(difficulty: 'easy', topicTitle: 'My Family', overallScore: 22),
          JamAssessmentStageSummary(difficulty: 'medium', topicTitle: 'Climate Change', overallScore: 21),
          JamAssessmentStageSummary(difficulty: 'hard', topicTitle: 'AI Ethics', overallScore: 22),
        ],
        reportText: 'Great work.',
      );
      final controller = _FixedSessionController(JamCompleting(session: _stageSession(stage: 3)));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            jamSessionControllerProvider.overrideWith(() => controller),
            jamRepositoryProvider.overrideWithValue(_NeverJamRepository()),
          ],
          child: const MaterialApp(home: JamRecordingScreen(startAsAssessment: true)),
        ),
      );
      await tester.pump();
      expect(find.byType(JamAssessmentResultScreen), findsNothing);

      controller.emit(JamAssessmentResultReady(finalResult));
      await tester.pump();
      await tester.pump();

      expect(find.byType(JamAssessmentResultScreen), findsOneWidget);
    });
  });
}
