import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/exercise_attempt.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_issue.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_topic.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/repositories/ai_speaking_repository.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/controllers/ai_speaking_controller.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/providers/ai_speaking_providers.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/screens/ai_speaking_screen.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
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

class _FakeAudioRecorderService implements AudioRecorderService {
  bool permissionGranted = true;
  String? stopPath = '/tmp/rec.m4a';

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => stopPath;

  @override
  Future<void> cancel() async {}
}

class _FakeAiSpeakingRepository implements AiSpeakingRepository {
  Result<SpeakingAnalysisResult>? analyzeResult;

  @override
  Future<Result<SpeakingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async => analyzeResult!;
}

/// A [AiSpeakingController] that starts from a fixed, caller-supplied
/// state — lets widget tests render every sealed state (Recording,
/// Recorded, Submitting, Failed, Result) directly, without driving the
/// real recorder/timer machinery. `build()` deliberately skips
/// `super.build()`'s `_recorder` wiring; tests using this must not tap a
/// control that touches the recorder (mic tap / pause / resume) — only
/// `tryAgain`/`pickNewTopic`/`submitForAnalysis` are safe, since they don't
/// reference `_recorder`.
class _FixedController extends AiSpeakingController {
  _FixedController(super.exerciseId, this.fixedState);
  final AiSpeakingState fixedState;

  @override
  AiSpeakingState build() => fixedState;
}

Future<void> _pumpFixed(
  WidgetTester tester,
  AiSpeakingState fixedState, {
  ExerciseAttempt? previousAttempt,
  AiSpeakingRepository? repo,
}) async {
  // The default 800×600 test surface is no longer tall enough for
  // `ModuleHero` + the rest of the content to all sit within the
  // hit-testable viewport at once.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        aiSpeakingControllerProvider(1).overrideWith(() => _FixedController(1, fixedState)),
        if (repo != null) aiSpeakingRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: AiSpeakingScreen(exerciseId: 1, activityId: 12, subActivityId: 34, activityTitle: 'Professional Speaking', previousAttempt: previousAttempt),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpReal(
  WidgetTester tester, {
  required _FakeAudioRecorderService recorder,
  required _FakeAiSpeakingRepository repo,
  ExerciseAttempt? previousAttempt,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        audioRecorderServiceProvider.overrideWithValue(recorder),
        aiSpeakingRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: AiSpeakingScreen(exerciseId: 1, activityId: 12, subActivityId: 34, activityTitle: 'Professional Speaking', previousAttempt: previousAttempt),
      ),
    ),
  );
  await tester.pump();
}

SpeakingAnalysisResult _result() => const SpeakingAnalysisResult(
  transcript: 'This is my transcript.',
  issues: [SpeakingIssue(phrase: 'a apple', type: 'Grammar', message: 'Article mismatch.', suggestion: 'an apple')],
  improvedPassage: 'This is my improved transcript.',
  feedback: 'Solid attempt overall.',
  scores: {'fluency': 90, 'pronunciation': 90, 'confidence': 90},
  score25: 21,
  durationSeconds: 12,
  pauseCount: 1,
);

void main() {
  group('rendering — idle', () {
    testWidgets('shows the hardcoded initial topic and "Click to start recording"', (tester) async {
      await _pumpFixed(tester, const AiSpeakingIdle(topic: kSpeakingInitialTopic));

      expect(find.text(kSpeakingInitialTopic), findsOneWidget);
      expect(find.text('Click to start recording'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a mic error message when one is set', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingIdle(topic: kSpeakingInitialTopic, micErrorMessage: 'Microphone access denied.'),
      );

      expect(find.text('Microphone access denied.'), findsOneWidget);
    });

    testWidgets('"New Topic" switches to a topic from the pool', (tester) async {
      await _pumpFixed(tester, const AiSpeakingIdle(topic: kSpeakingInitialTopic));

      await tester.tap(find.text('New Topic'));
      await tester.pump();

      expect(find.text(kSpeakingInitialTopic), findsNothing);
      expect(kSpeakingTopics.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });
  });

  group('rendering — recording', () {
    testWidgets('shows the elapsed-time, status, and pause-count chips while recording', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingRecording(topic: kSpeakingInitialTopic, elapsedSeconds: 45, paused: false, pauseCount: 2),
      );

      expect(find.text('45s'), findsOneWidget);
      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('Pauses: 2'), findsOneWidget);
      expect(find.text('Recording in progress. Tap Stop to finish.'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('a paused recording shows "Paused" and a Resume action', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingRecording(topic: kSpeakingInitialTopic, elapsedSeconds: 10, paused: true, pauseCount: 1),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Paused recording. Tap Resume to continue.'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('hides the language dropdown while recording', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingRecording(topic: kSpeakingInitialTopic, elapsedSeconds: 1, paused: false, pauseCount: 0),
      );

      expect(find.byType(DropdownButton<String>), findsNothing);
    });
  });

  group('rendering — recorded / submitting / failed', () {
    testWidgets('a plain recorded state shows the default ready-to-analyze note', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingRecorded(topic: kSpeakingInitialTopic, audioFilePath: '/tmp/a.m4a', elapsedSeconds: 30, pauseCount: 0),
      );

      expect(
        find.text('Recording ready. Tap Submit for Analysis to generate your transcript and feedback.'),
        findsOneWidget,
      );
      expect(find.text('Submit for Analysis'), findsOneWidget);
      expect(find.text('Record Again'), findsOneWidget);
    });

    testWidgets('timeLimitReached shows the 90-second note', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingRecorded(
          topic: kSpeakingInitialTopic,
          audioFilePath: '/tmp/a.m4a',
          elapsedSeconds: 90,
          pauseCount: 0,
          timeLimitReached: true,
        ),
      );

      expect(find.text('Time limit reached (90 seconds). Ready to analyze.'), findsOneWidget);
    });

    testWidgets('pauseLimitExceeded shows the pause-limit note', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingRecorded(
          topic: kSpeakingInitialTopic,
          audioFilePath: '/tmp/a.m4a',
          elapsedSeconds: 20,
          pauseCount: 6,
          pauseLimitExceeded: true,
        ),
      );

      expect(find.text('Maximum pause limit (5) exceeded. Recording stopped — ready to analyze.'), findsOneWidget);
    });

    testWidgets('submitting shows a loading indicator and no crash', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingSubmitting(topic: kSpeakingInitialTopic, audioFilePath: '/tmp/a.m4a', elapsedSeconds: 30, pauseCount: 0),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit for Analysis'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a submit failure shows the failure message and a Retry action', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingSubmitFailed(
          topic: kSpeakingInitialTopic,
          audioFilePath: '/tmp/a.m4a',
          elapsedSeconds: 30,
          pauseCount: 0,
          failure: ServerFailure(),
        ),
      );

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry Analysis'), findsOneWidget);
    });

    testWidgets('tapping Retry Analysis re-submits and shows the result on success', (tester) async {
      final repo = _FakeAiSpeakingRepository()..analyzeResult = Success(_result());
      await _pumpFixed(
        tester,
        const AiSpeakingSubmitFailed(
          topic: kSpeakingInitialTopic,
          audioFilePath: '/tmp/a.m4a',
          elapsedSeconds: 30,
          pauseCount: 0,
          failure: ServerFailure(),
        ),
        repo: repo,
      );

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Retry Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('21/25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('rendering — result', () {
    testWidgets('shows the score, improved passage, feedback, quick tip, and issues', (tester) async {
      await _pumpFixed(
        tester,
        AiSpeakingResult(topic: kSpeakingInitialTopic, result: _result(), quickTip: 'Speak a little slower.'),
      );

      expect(find.text('21/25'), findsOneWidget);
      expect(find.text('This is my improved transcript.'), findsOneWidget);
      expect(find.text('Solid attempt overall.'), findsOneWidget);
      expect(find.text('Speak a little slower.'), findsOneWidget);
      expect(find.text('"a apple"'), findsOneWidget);
      expect(find.text('Article mismatch.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('"Try Again" resets to idle on the same topic', (tester) async {
      await _pumpFixed(
        tester,
        AiSpeakingResult(topic: kSpeakingInitialTopic, result: _result(), quickTip: 'Speak a little slower.'),
      );

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(find.text('Click to start recording'), findsOneWidget);
      expect(find.text(kSpeakingInitialTopic), findsOneWidget);
    });
  });

  group('previous score', () {
    testWidgets('shows the Previous Score card when a previous attempt is supplied', (tester) async {
      await _pumpFixed(
        tester,
        const AiSpeakingIdle(topic: kSpeakingInitialTopic),
        previousAttempt: ExerciseAttempt(score: 18, maxScore: 25, percentage: 72, attemptNumber: 1, completedAt: DateTime(2026, 2, 10)),
      );

      expect(find.text('Previous Score'), findsOneWidget);
      expect(find.text('18/25'), findsOneWidget);
    });

    testWidgets('shows no Previous Score card when there is no previous attempt', (tester) async {
      await _pumpFixed(tester, const AiSpeakingIdle(topic: kSpeakingInitialTopic));

      expect(find.text('Previous Score'), findsNothing);
    });
  });

  group('real controller flow', () {
    testWidgets('idle -> recording -> recorded -> submitted -> result, end to end', (tester) async {
      final recorder = _FakeAudioRecorderService();
      final repo = _FakeAiSpeakingRepository()..analyzeResult = Success(_result());
      await _pumpReal(tester, recorder: recorder, repo: repo);

      expect(find.text('Click to start recording'), findsOneWidget);

      // `.last` — `Icons.mic` also appears in `ModuleHero`'s badge (14px);
      // the recorder's own mic button (44px) is the one after it in the tree.
      await tester.tap(find.byIcon(Icons.mic).last);
      await tester.pump();
      expect(find.byIcon(Icons.stop), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(find.text('Submit for Analysis'), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000, warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Submit for Analysis'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('21/25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('denied microphone permission shows an error without entering the recording state', (tester) async {
      final recorder = _FakeAudioRecorderService()..permissionGranted = false;
      final repo = _FakeAiSpeakingRepository();
      await _pumpReal(tester, recorder: recorder, repo: repo);

      // `.last` — see the previous test's comment.
      await tester.tap(find.byIcon(Icons.mic).last);
      await tester.pump();

      expect(find.textContaining('Microphone access denied'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);
    });
  });

  group('responsive', () {
    testWidgets('renders the idle and result states without overflow at 320/375/430px', (tester) async {
      for (final width in [320.0, 375.0, 430.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpFixed(
          tester,
          const AiSpeakingIdle(topic: kSpeakingInitialTopic),
          previousAttempt: ExerciseAttempt(score: 18, maxScore: 25, percentage: 72, attemptNumber: 1, completedAt: DateTime(2026, 2, 10)),
        );
        expect(tester.takeException(), isNull);

        await _pumpFixed(
          tester,
          AiSpeakingResult(topic: kSpeakingInitialTopic, result: _result(), quickTip: 'Speak a little slower.'),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
