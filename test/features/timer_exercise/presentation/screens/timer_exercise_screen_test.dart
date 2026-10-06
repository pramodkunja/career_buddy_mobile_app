import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_exercise.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_submission_result.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_task.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/repositories/timer_exercise_repository.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/services/timer_speech_service.dart';
import 'package:career_buddy_lms/features/timer_exercise/presentation/providers/timer_exercise_providers.dart';
import 'package:career_buddy_lms/features/timer_exercise/presentation/screens/timer_exercise_screen.dart';
import 'package:career_buddy_lms/features/timer_exercise/presentation/timer_exercise_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'jane');
  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async => throw UnimplementedError();
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

class _FakeTimerExerciseRepository implements TimerExerciseRepository {
  _FakeTimerExerciseRepository({this.getResult, this.submitResult});

  Result<TimerExercise>? getResult;
  Result<TimerSubmissionResult>? submitResult;

  @override
  Future<Result<TimerExercise>> getTimerExercise(int exerciseId, {required String title, required int order}) async => getResult!;

  @override
  Future<Result<TimerSubmissionResult>> submitTimerExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async => submitResult!;
}

/// A fake `TimerSpeechService` — no real microphone/plugin involved, per
/// this feature's own "wrap a platform capability behind an interface, fake
/// it in tests" pattern.
class _FakeTimerSpeechService implements TimerSpeechService {
  _FakeTimerSpeechService({this.initializeSucceeds = true});

  final bool initializeSucceeds;
  TimerSpeechResultCallback? _onResult;

  @override
  Future<bool> initialize() async => initializeSucceeds;

  @override
  Future<void> listen({required TimerSpeechResultCallback onResult}) async {
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  void emit(String recognizedWords, {required bool isFinal}) => _onResult?.call(recognizedWords, isFinal);
}

TimerExercise _exercise({int taskCount = 2}) => TimerExercise(
  id: 9,
  title: 'Elevator Pitch Practice',
  order: 1,
  tasks: List.generate(taskCount, (i) => TimerTask(position: i + 1, questionText: 'Task prompt $i?', guide: 'Speak clearly.')),
);

Future<_FakeTimerSpeechService> _pump(
  WidgetTester tester,
  TimerExerciseRepository repo, {
  TimerExerciseRouteArgs? args,
  _FakeTimerSpeechService? speech,
  Size physicalSize = const Size(800, 1400),
}) async {
  final speechService = speech ?? _FakeTimerSpeechService();
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        timerExerciseRepositoryProvider.overrideWithValue(repo),
        timerSpeechServiceProvider.overrideWithValue(speechService),
      ],
      child: MaterialApp(
        home: TimerExerciseScreen(
          exerciseId: 9,
          args: args ?? const TimerExerciseRouteArgs(title: 'Elevator Pitch Practice', order: 1, activityId: 12, subActivityId: 34),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  return speechService;
}

void main() {
  testWidgets('renders the first task prompt, task dots, and a 60-second countdown', (tester) async {
    await _pump(tester, _FakeTimerExerciseRepository(getResult: Success(_exercise())));

    expect(find.textContaining('Task 1: Task prompt 0?'), findsOneWidget);
    expect(find.text('Task 1'), findsOneWidget);
    expect(find.text('Task 2'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('Start Task 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Start begins listening and shows the live transcript as speech is captured', (tester) async {
    final speech = await _pump(tester, _FakeTimerExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('Start Task 1'));
    await tester.pump();

    expect(find.text('Stop Recording'), findsOneWidget);
    expect(find.text('Listening...'), findsOneWidget);

    speech.emit('I woke up early', isFinal: false);
    await tester.pump();

    expect(find.text('I woke up early'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the countdown ticks down once a second while listening', (tester) async {
    await _pump(tester, _FakeTimerExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('Start Task 1'));
    await tester.pump();
    expect(find.text('60'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('57'), findsOneWidget);
  });

  testWidgets('stopping finishes the task and advances to the next task', (tester) async {
    final speech = await _pump(tester, _FakeTimerExerciseRepository(getResult: Success(_exercise())));

    await tester.tap(find.text('Start Task 1'));
    await tester.pump();
    speech.emit('I woke up early today', isFinal: true);
    await tester.pump();
    await tester.tap(find.text('Stop Recording'));
    await tester.pump();

    expect(find.text('5 words recorded'), findsOneWidget);
    expect(find.text('Select Task 2'), findsOneWidget);

    await tester.tap(find.text('Select Task 2'));
    await tester.pump();

    expect(find.textContaining('Task 2: Task prompt 1?'), findsOneWidget);
    expect(find.text('Start Task 2'), findsOneWidget);
  });

  testWidgets('submitting after every task is complete shows the server-returned score', (tester) async {
    const result = TimerSubmissionResult(exerciseId: 9, score: 2, maxScore: 2, percentage: 100, attemptNumber: 1);
    final speech = await _pump(
      tester,
      _FakeTimerExerciseRepository(getResult: Success(_exercise()), submitResult: const Success(result)),
    );

    // Task 1.
    await tester.tap(find.text('Start Task 1'));
    await tester.pump();
    speech.emit('I woke up early today', isFinal: true);
    await tester.pump();
    await tester.tap(find.text('Stop Recording'));
    await tester.pump();
    await tester.tap(find.text('Select Task 2'));
    await tester.pump();

    // Task 2.
    await tester.tap(find.text('Start Task 2'));
    await tester.pump();
    speech.emit('Remote work is flexible', isFinal: true);
    await tester.pump();
    await tester.tap(find.text('Stop Recording'));
    await tester.pump();

    expect(find.text('Submit'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a genuine speech-recognition initialization failure shows a real error, never fake transcript text', (tester) async {
    await _pump(
      tester,
      _FakeTimerExerciseRepository(getResult: Success(_exercise())),
      speech: _FakeTimerSpeechService(initializeSucceeds: false),
    );

    await tester.tap(find.text('Start Task 1'));
    await tester.pump();

    expect(find.textContaining("Speech recognition isn't available"), findsOneWidget);
    expect(find.text('Stop Recording'), findsNothing); // never silently moved to "listening"
  });

  testWidgets('shows a retryable error view for a load failure', (tester) async {
    await _pump(tester, _FakeTimerExerciseRepository(getResult: const Failed(NotFoundFailure())));

    expect(find.text(const NotFoundFailure().message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  group('Batch 10 — Reset and dot-click affordances', () {
    testWidgets('tapping Reset clears the current attempt back to Task 1', (tester) async {
      final speech = await _pump(tester, _FakeTimerExerciseRepository(getResult: Success(_exercise())));

      await tester.tap(find.text('Start Task 1'));
      await tester.pump();
      speech.emit('I woke up early today', isFinal: true);
      await tester.pump();
      await tester.tap(find.text('Stop Recording'));
      await tester.pump();
      expect(find.text('Select Task 2'), findsOneWidget);

      // Tapped via its icon, not its text label: at this test's viewport,
      // the bottom-pinned control row's trailing "Reset" button sits
      // directly under where `BuddyChatbotOverlay`'s floating launcher
      // renders (bottom-right, 110×110) — same as it would on a real
      // device at a similar width. The icon (left side of the button) is
      // clear of the launcher's circle; the label isn't.
      await tester.tap(find.byIcon(Icons.replay));
      await tester.pump();

      expect(find.text('Start Task 1'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the next task\'s dot advances to it, same as "Select Task 2"', (tester) async {
      final speech = await _pump(tester, _FakeTimerExerciseRepository(getResult: Success(_exercise())));

      await tester.tap(find.text('Start Task 1'));
      await tester.pump();
      speech.emit('I woke up early today', isFinal: true);
      await tester.pump();
      await tester.tap(find.text('Stop Recording'));
      await tester.pump();

      await tester.tap(find.text('Task 2')); // the dot, not the "Select Task 2" button
      await tester.pump();

      expect(find.textContaining('Task 2: Task prompt 1?'), findsOneWidget);
      expect(find.text('Start Task 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Batch 9 responsive QA', () {
    for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915), Size(430, 932)]) {
      testWidgets('renders without overflow at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final speech = await _pump(
          tester,
          _FakeTimerExerciseRepository(getResult: Success(_exercise())),
          physicalSize: size,
        );
        expect(tester.takeException(), isNull);

        // Also stress the in-progress state (live transcript + task dots +
        // countdown all visible at once) at this width, not just idle.
        await tester.tap(find.text('Start Task 1'));
        await tester.pump();
        speech.emit('A reasonably long spoken answer to stress-test line wrapping at this width', isFinal: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
