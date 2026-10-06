import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_exercise.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_submission_result.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/entities/timer_task.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/repositories/timer_exercise_repository.dart';
import 'package:career_buddy_lms/features/timer_exercise/domain/services/timer_speech_service.dart';
import 'package:career_buddy_lms/features/timer_exercise/presentation/controllers/timer_exercise_controller.dart';
import 'package:career_buddy_lms/features/timer_exercise/presentation/providers/timer_exercise_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TimerExercise _exercise({int taskCount = 2}) => TimerExercise(
  id: 9,
  title: 'Elevator Pitch Practice',
  order: 1,
  tasks: List.generate(taskCount, (i) => TimerTask(position: i + 1, questionText: 'Task prompt $i?', guide: 'Speak clearly.')),
);

class _FakeTimerExerciseRepository implements TimerExerciseRepository {
  _FakeTimerExerciseRepository({this.getResult, this.submitResult});

  Result<TimerExercise>? getResult;
  Result<TimerSubmissionResult>? submitResult;
  int submitCallCount = 0;
  int? lastScore;
  int? lastMaxScore;
  Map<int, String>? lastAnswers;

  @override
  Future<Result<TimerExercise>> getTimerExercise(int exerciseId, {required String title, required int order}) async => getResult!;

  @override
  Future<Result<TimerSubmissionResult>> submitTimerExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    submitCallCount++;
    lastScore = score;
    lastMaxScore = maxScore;
    lastAnswers = answers;
    return submitResult!;
  }
}

/// A controllable fake standing in for the platform's real
/// `speech_to_text` plugin — lets tests drive `onResult` callbacks and
/// simulate a genuine initialization failure without any real
/// microphone/plugin, per `TimerSpeechService`'s own doc comment.
class _FakeTimerSpeechService implements TimerSpeechService {
  _FakeTimerSpeechService({this.initializeSucceeds = true});

  bool initializeSucceeds;
  int initializeCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
  TimerSpeechResultCallback? _onResult;

  @override
  Future<bool> initialize() async {
    initializeCallCount++;
    return initializeSucceeds;
  }

  @override
  Future<void> listen({required TimerSpeechResultCallback onResult}) async {
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount++;
  }

  /// Test helper — simulates the plugin reporting a new interim or final
  /// transcript for the currently active `listen()` session.
  void emit(String recognizedWords, {required bool isFinal}) {
    _onResult?.call(recognizedWords, isFinal);
  }
}

ProviderContainer _buildContainer({TimerExerciseRepository? repo, _FakeTimerSpeechService? speech}) {
  return ProviderContainer(
    overrides: [
      timerExerciseRepositoryProvider.overrideWithValue(repo ?? _FakeTimerExerciseRepository(getResult: Success(_exercise()))),
      timerSpeechServiceProvider.overrideWithValue(speech ?? _FakeTimerSpeechService()),
    ],
  );
}

const _providerArg = (9, 'Elevator Pitch Practice', 1);

void main() {
  group('TimerExerciseController — load', () {
    test('resolves to InProgress at task 0, idle, with a fresh 60-second countdown', () async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      container.read(timerExerciseControllerProvider(_providerArg));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
      expect(state.taskIndex, 0);
      expect(state.phase, TimerTaskPhase.idle);
      expect(state.secondsLeft, timerTaskDurationSeconds);
      expect(state.totalTasks, 2);
    });

    test('resolves to LoadFailed on a failed load', () async {
      final container = _buildContainer(repo: _FakeTimerExerciseRepository(getResult: const Failed(NotFoundFailure())));
      addTearDown(container.dispose);
      container.read(timerExerciseControllerProvider(_providerArg));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(timerExerciseControllerProvider(_providerArg)), isA<TimerExerciseLoadFailed>());
    });
  });

  group('TimerExerciseController — starting and speech capture', () {
    test('start() surfaces a real speechError (never fake transcript text) when initialize() fails', () {
      fakeAsync((async) {
        final container = _buildContainer(speech: _FakeTimerSpeechService(initializeSucceeds: false));
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.speechError, isNotNull);
        expect(state.phase, TimerTaskPhase.idle); // never silently moved to "listening"
      });
    });

    test('start() moves to listening and begins the 60-second countdown', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();

        var state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.phase, TimerTaskPhase.listening);
        expect(state.secondsLeft, 60);

        async.elapse(const Duration(seconds: 5));
        state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.secondsLeft, 55);
      });
    });

    test('interim speech results update liveTranscript live, without marking the task complete', () {
      fakeAsync((async) {
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();
        notifier.start();
        async.flushMicrotasks();

        speech.emit('I woke up', isFinal: false);
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.liveTranscript, 'I woke up');
        expect(state.phase, TimerTaskPhase.listening);
        expect(state.currentTaskCompleted, isFalse);
      });
    });

    test('a final speech result is stored as the task transcript', () {
      fakeAsync((async) {
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();
        notifier.start();
        async.flushMicrotasks();

        speech.emit('I woke up and made coffee', isFinal: true);
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.transcriptFor(0), 'I woke up and made coffee');
      });
    });
  });

  group('TimerExerciseController — task completion', () {
    test('the countdown reaching 0 auto-finishes the task, folding any live interim text into the transcript', () {
      fakeAsync((async) {
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();
        notifier.start();
        async.flushMicrotasks();

        speech.emit('I woke up and made coffee', isFinal: false); // never finalized before time runs out
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.phase, TimerTaskPhase.taskComplete);
        expect(state.secondsLeft, 0);
        expect(state.completed, contains(0));
        expect(state.transcriptFor(0), 'I woke up and made coffee'); // interim folded in
        expect(speech.stopCallCount, 1);
      });
    });

    test('stop() manually finishes the task before the countdown reaches 0', () {
      fakeAsync((async) {
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();
        notifier.start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        notifier.stop();
        async.flushMicrotasks();

        var state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.phase, TimerTaskPhase.taskComplete);
        expect(state.completed, contains(0));

        // The timer must actually be cancelled — elapsing further must not
        // somehow re-trigger completion logic or throw.
        async.elapse(const Duration(seconds: 60));
        state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.phase, TimerTaskPhase.taskComplete);
      });
    });

    test('start() after completing a task advances to the next task instead of listening again', () {
      fakeAsync((async) {
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();
        notifier.start();
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        notifier.start(); // "Select Task 2" tap
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 1);
        expect(state.phase, TimerTaskPhase.idle);
        expect(state.secondsLeft, timerTaskDurationSeconds);
      });
    });

    test('allTasksCompleted is true only once every task has been finished', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();
        var state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.allTasksCompleted, isFalse);

        notifier.start(); // advance to task 2
        async.flushMicrotasks();
        notifier.start(); // start listening on task 2
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.allTasksCompleted, isTrue);
      });
    });
  });

  group('TimerExerciseController — submission', () {
    test('submit() is a no-op until every task is completed', () {
      fakeAsync((async) {
        final repo = _FakeTimerExerciseRepository(getResult: Success(_exercise()));
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.submit();
        async.flushMicrotasks();

        expect(repo.submitCallCount, 0);
        expect(container.read(timerExerciseControllerProvider(_providerArg)), isA<TimerExerciseInProgress>());
      });
    });

    test('submit() sends only non-empty transcripts keyed by position, and prefers the server score over the client one', () {
      fakeAsync((async) {
        final repo = _FakeTimerExerciseRepository(
          getResult: Success(_exercise()),
          submitResult: const Success(TimerSubmissionResult(exerciseId: 9, score: 2, maxScore: 2, percentage: 100, attemptNumber: 4)),
        );
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(repo: repo, speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        // Task 1: says something.
        notifier.start();
        async.flushMicrotasks();
        speech.emit('I woke up early today', isFinal: true);
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        // Task 2: never says anything (started, then immediately stopped).
        notifier.start(); // advance to task 2
        async.flushMicrotasks();
        notifier.start(); // begin listening
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        notifier.submit();
        async.flushMicrotasks();

        expect(repo.submitCallCount, 1);
        expect(repo.lastAnswers, {1: 'I woke up early today'}); // task 2 has no entry at all
        expect(repo.lastMaxScore, 2); // totalTasks, from computeTimerClientScore

        final state = container.read(timerExerciseControllerProvider(_providerArg));
        expect(state, isA<TimerExerciseSubmitted>());
        expect((state as TimerExerciseSubmitted).result.score, 2); // the server's value, not the client's own guess
        expect(state.result.attemptNumber, 4);
      });
    });

    test('a failed submit keeps the transcripts and surfaces submitError, without resetting to loading', () {
      fakeAsync((async) {
        final repo = _FakeTimerExerciseRepository(getResult: Success(_exercise(taskCount: 1)), submitResult: const Failed(ServerFailure()));
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        notifier.submit();
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.submitError, isA<ServerFailure>());
        expect(state.isSubmitting, isFalse);
        expect(state.completed, contains(0));
      });
    });
  });

  group('TimerExerciseController — Batch 10: dot-click navigation (goToTask)', () {
    test('tapping the next task\'s dot after the current one is done advances to it, mirroring the real "activateTask" gate', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        notifier.goToTask(1);
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 1);
        expect(state.phase, TimerTaskPhase.idle);
        expect(state.secondsLeft, timerTaskDurationSeconds);
      });
    });

    test('tapping a task dot before the current task is done is a silent no-op, exactly like the real page', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.goToTask(1); // task 0 is not completed yet
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 0);
      });
    });

    test('tapping any dot other than the immediate next task is a silent no-op', () {
      fakeAsync((async) {
        final container = _buildContainer(repo: _FakeTimerExerciseRepository(getResult: Success(_exercise(taskCount: 3))));
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        notifier.stop(); // task 0 done
        async.flushMicrotasks();

        notifier.goToTask(2); // not the immediate next task (1) — real web ignores this too
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 0);
      });
    });

    test('tapping a dot while actively listening is a no-op (matches the real page never wiring dot clicks during recording)', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();

        notifier.goToTask(1);
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.phase, TimerTaskPhase.listening);
        expect(state.taskIndex, 0);
      });
    });
  });

  group('TimerExerciseController — Batch 10: Reset (local, no re-fetch)', () {
    test('reset() clears every captured transcript and returns to task 0, without calling the repository again', () {
      fakeAsync((async) {
        final repo = _FakeTimerExerciseRepository(getResult: Success(_exercise()));
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(repo: repo, speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        speech.emit('some spoken answer', isFinal: true);
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();
        notifier.start(); // advance to task 2
        async.flushMicrotasks();

        var state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 1);
        expect(state.completed, contains(0));

        notifier.reset();
        async.flushMicrotasks();

        state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 0);
        expect(state.completed, isEmpty);
        expect(state.transcriptFor(0), isEmpty);
        expect(state.secondsLeft, timerTaskDurationSeconds);
        expect(state.phase, TimerTaskPhase.idle);
        // The real web's Reset never calls the server — only the initial load did.
        expect(repo.submitCallCount, 0);
      });
    });

    test('reset() while actively listening stops the recognizer and the countdown', () {
      fakeAsync((async) {
        final speech = _FakeTimerSpeechService();
        final container = _buildContainer(speech: speech);
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        expect(speech.cancelCallCount, 0);

        notifier.reset();
        async.flushMicrotasks();

        expect(speech.cancelCallCount, 1);
        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.phase, TimerTaskPhase.idle);

        // The cancelled timer must not still be ticking in the background.
        async.elapse(const Duration(seconds: 60));
        final after = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(after.secondsLeft, timerTaskDurationSeconds);
        expect(after.phase, TimerTaskPhase.idle);
      });
    });
  });

  group('TimerExerciseController — retry', () {
    test('tryAgain() re-fetches and fully resets to task 0', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timerExerciseControllerProvider(_providerArg).notifier);
        async.flushMicrotasks();

        notifier.start();
        async.flushMicrotasks();
        notifier.stop();
        async.flushMicrotasks();

        notifier.tryAgain();
        async.flushMicrotasks();

        final state = container.read(timerExerciseControllerProvider(_providerArg)) as TimerExerciseInProgress;
        expect(state.taskIndex, 0);
        expect(state.completed, isEmpty);
      });
    });
  });
}
