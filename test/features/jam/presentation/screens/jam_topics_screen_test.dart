import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
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

/// Never resolves `startSession` — used only to verify navigation happened
/// without also exercising (or needing to fake) the real network stack the
/// recording screen kicks off in its `initState`.
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

/// Reports every difficulty as complete, so the "Start Assessment" entry
/// card renders in its enabled state — the more content-heavy state, worth
/// exercising in the responsive sweep below.
class _EligibleJamAssessmentRepository implements JamAssessmentRepository {
  @override
  Future<Result<List<JamPracticeSessionSummary>>> getHistory() async => const Success([
    JamPracticeSessionSummary(difficulty: 'easy'),
    JamPracticeSessionSummary(difficulty: 'medium'),
    JamPracticeSessionSummary(difficulty: 'hard'),
  ]);

  @override
  Future<Result<JamSessionStart>> startAssessment() => throw UnimplementedError();

  @override
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId) => throw UnimplementedError();
}

class _FixedTopicsController extends JamTopicsController {
  _FixedTopicsController(this.result);
  final AsyncValue<JamTopicsState>? result;

  @override
  Future<JamTopicsState> build() {
    final r = result;
    if (r == null) return Completer<JamTopicsState>().future; // loading forever
    if (r is AsyncError<JamTopicsState>) return Future.error(r.error, r.stackTrace);
    return Future.value(r.value as JamTopicsState);
  }
}

Future<void> _pump(WidgetTester tester, AsyncValue<JamTopicsState>? result) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jamTopicsControllerProvider.overrideWith(() => _FixedTopicsController(result)),
      ],
      child: const MaterialApp(home: JamTopicsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  group('JamTopicsScreen', () {
    testWidgets('shows a loader while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            jamTopicsControllerProvider.overrideWith(() => _FixedTopicsController(null)),
          ],
          child: const MaterialApp(home: JamTopicsScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the Random Topic action and every topic grouped by difficulty', (tester) async {
      const state = JamTopicsState(
        easy: [JamTopic(id: 1, title: 'My Family', description: 'Talk about family.', difficulty: 'easy')],
        medium: [JamTopic(id: 2, title: 'Climate Change', description: 'Discuss impact.', difficulty: 'medium')],
        hard: [],
      );
      await _pump(tester, const AsyncValue.data(state));

      expect(find.text('Random Topic'), findsOneWidget);
      expect(find.text('My Family'), findsOneWidget);
      expect(find.text('Climate Change'), findsOneWidget);

      // The Hard section (empty in this fixture) sits below the fold — same
      // scroll-then-assert pattern as `ai_speaking_screen_test.dart`.
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      expect(find.text('No topics available yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows an error view with retry on failure', (tester) async {
      await _pump(tester, AsyncValue.error(const ServerFailure(), StackTrace.empty));

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows a locked view on ForbiddenFailure', (tester) async {
      await _pump(tester, AsyncValue.error(const ForbiddenFailure(), StackTrace.empty));

      expect(find.text(const ForbiddenFailure().message), findsOneWidget);
      expect(find.text('View Plans'), findsOneWidget);
    });

    testWidgets('tapping "Random Topic" opens the recording screen', (tester) async {
      const state = JamTopicsState(easy: [], medium: [], hard: []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            jamTopicsControllerProvider.overrideWith(() => _FixedTopicsController(const AsyncValue.data(state))),
            // The recording screen's own startSession call never resolves —
            // fine, this test only asserts navigation happened.
            jamRepositoryProvider.overrideWithValue(_NeverJamRepository()),
          ],
          child: const MaterialApp(home: JamTopicsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Random Topic'));
      // Not `pumpAndSettle` — the pushed screen's loading state has an
      // indeterminate `CircularProgressIndicator` that animates forever.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.byType(JamRecordingScreen), findsOneWidget);
    });
  });

  group('Batch 9 responsive QA', () {
    const state = JamTopicsState(
      easy: [JamTopic(id: 1, title: 'My Family', description: 'Talk about family.', difficulty: 'easy')],
      medium: [JamTopic(id: 2, title: 'Climate Change', description: 'Discuss its wide-reaching impact.', difficulty: 'medium')],
      hard: [JamTopic(id: 3, title: 'Artificial Intelligence Ethics', description: 'A longer, wrap-prone description.', difficulty: 'hard')],
    );

    for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915), Size(430, 932)]) {
      testWidgets('renders without overflow at ${size.width.toInt()}x${size.height.toInt()}, including the enabled Start Assessment card', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              jamTopicsControllerProvider.overrideWith(() => _FixedTopicsController(const AsyncValue.data(state))),
              jamAssessmentRepositoryProvider.overrideWithValue(_EligibleJamAssessmentRepository()),
            ],
            child: const MaterialApp(home: JamTopicsScreen()),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        expect(tester.takeException(), isNull);
      });
    }
  });
}
