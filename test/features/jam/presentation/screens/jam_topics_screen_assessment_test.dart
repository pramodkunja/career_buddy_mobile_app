import 'dart:async';

import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_assessment_repository.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_assessment_eligibility_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_topics_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_recording_screen.dart';
import 'package:career_buddy_lms/features/jam/presentation/screens/jam_topics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly — same pattern as
/// `JamTopicsScreen`'s own sibling test file (`jam_topics_screen_test.dart`)
/// — avoids that without this file's own tests needing to care about auth.
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

/// Never resolves — the recording screen this taps into always kicks off a
/// real `startSession`/`startAssessment` call from `initState`; these tests
/// only assert navigation happened, so the call never needs to resolve.
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

/// Never resolves `startAssessment` — same role as [_NeverJamRepository]
/// but for the assessment-only repository seam
/// (`JamSessionController.startAssessment` reads
/// `jamAssessmentRepositoryProvider`, not `jamRepositoryProvider`).
class _NeverJamAssessmentRepository implements JamAssessmentRepository {
  @override
  Future<Result<JamSessionStart>> startAssessment() => Completer<Result<JamSessionStart>>().future;

  @override
  Future<Result<List<JamPracticeSessionSummary>>> getHistory() async => const Success([]);

  @override
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId) => throw UnimplementedError();
}

class _FixedTopicsController extends JamTopicsController {
  @override
  Future<JamTopicsState> build() async => const JamTopicsState(easy: [], medium: [], hard: []);
}

class _FixedEligibilityController extends JamAssessmentEligibilityController {
  _FixedEligibilityController(this.result);
  final AsyncValue<JamAssessmentEligibility>? result;

  @override
  Future<JamAssessmentEligibility> build() {
    final r = result;
    if (r == null) return Completer<JamAssessmentEligibility>().future; // loading forever
    if (r is AsyncError<JamAssessmentEligibility>) return Future.error(r.error, r.stackTrace);
    return Future.value(r.value as JamAssessmentEligibility);
  }
}

Future<void> _pump(WidgetTester tester, AsyncValue<JamAssessmentEligibility>? eligibility) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jamTopicsControllerProvider.overrideWith(() => _FixedTopicsController()),
        jamAssessmentEligibilityControllerProvider.overrideWith(() => _FixedEligibilityController(eligibility)),
        jamRepositoryProvider.overrideWithValue(_NeverJamRepository()),
        jamAssessmentRepositoryProvider.overrideWithValue(_NeverJamAssessmentRepository()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: const MaterialApp(home: JamTopicsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  // The entry card sits below the (empty) topic sections.
  await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
  await tester.pump();
}

void main() {
  group('"Start Assessment" entry point', () {
    testWidgets('shows "Start Assessment" enabled and, on tap, opens the recording screen in assessment mode', (
      tester,
    ) async {
      const eligibility = JamAssessmentEligibility(easyDone: true, mediumDone: true, hardDone: true);
      await _pump(tester, const AsyncValue.data(eligibility));

      expect(find.text('Start Assessment'), findsOneWidget);
      expect(find.textContaining('Still pending'), findsNothing);

      await tester.tap(find.text('Start Assessment'));
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }

      expect(find.byType(JamRecordingScreen), findsOneWidget);
    });

    testWidgets('disabled with the real flash-message copy when missing only Hard', (tester) async {
      const eligibility = JamAssessmentEligibility(easyDone: true, mediumDone: true, hardDone: false);
      await _pump(tester, const AsyncValue.data(eligibility));

      expect(find.text('Start Assessment'), findsOneWidget);
      expect(
        find.textContaining(
          'Complete one topic from each of the three levels (Simple, Intermediate, Hard) '
          'before starting the assessment. Still pending: Hard.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Start Assessment'), warnIfMissed: false);
      await tester.pump();

      expect(find.byType(JamRecordingScreen), findsNothing);
    });

    testWidgets('disabled with all 3 levels pending when nothing is done yet', (tester) async {
      const eligibility = JamAssessmentEligibility(easyDone: false, mediumDone: false, hardDone: false);
      await _pump(tester, const AsyncValue.data(eligibility));

      expect(find.textContaining('Still pending: Simple, Intermediate, Hard.'), findsOneWidget);
    });

    testWidgets('shows a neutral message (never a fabricated eligibility claim) while still loading', (tester) async {
      await _pump(tester, null);

      expect(find.text('Checking your progress...'), findsOneWidget);
      await tester.tap(find.text('Start Assessment'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(JamRecordingScreen), findsNothing);
    });
  });
}
