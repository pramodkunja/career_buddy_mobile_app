import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/timer_exercise.dart';
import '../../domain/entities/timer_submission_result.dart';
import '../../domain/entities/timer_task.dart';
import '../../domain/services/timer_client_scorer.dart';
import '../../domain/services/timer_speech_service.dart';
import '../../domain/services/timer_word_count.dart';
import '../providers/timer_exercise_providers.dart';

/// `DURATION` (`static/js/exercises.js:1114`) — every task gets exactly 60
/// seconds, always, regardless of exercise.
const int timerTaskDurationSeconds = 60;

/// Mirrors `initTimer()`'s own state machine (`static/js/exercises.js:
/// 1113-1360`): each task goes idle → listening (recording+recognizing) →
/// complete, one at a time, either by the 60-second countdown reaching 0
/// (`tick()` → `finishCurrentTask()`) or the user tapping Stop
/// (`finishCurrentTask()` directly) — never simultaneously multi-task like
/// Generic Writing.
enum TimerTaskPhase { idle, listening, taskComplete }

sealed class TimerExerciseState {
  const TimerExerciseState();
}

final class TimerExerciseLoading extends TimerExerciseState {
  const TimerExerciseLoading();
}

final class TimerExerciseLoadFailed extends TimerExerciseState {
  const TimerExerciseLoadFailed(this.failure);
  final Failure failure;
}

final class TimerExerciseInProgress extends TimerExerciseState {
  const TimerExerciseInProgress({
    required this.exercise,
    required this.taskIndex,
    this.phase = TimerTaskPhase.idle,
    this.secondsLeft = timerTaskDurationSeconds,
    this.transcripts = const {},
    this.liveInterim = '',
    this.completed = const {},
    this.isSubmitting = false,
    this.submitError,
    this.speechError,
  });

  final TimerExercise exercise;

  /// 0-based index of the task currently shown — mirrors the web's own
  /// `taskIdx` (`static/js/exercises.js:1117`).
  final int taskIndex;
  final TimerTaskPhase phase;
  final int secondsLeft;

  /// 0-based task index -> its finalized transcript so far. Only tasks
  /// that have actually captured *some* speech ever get an entry here —
  /// matching the web's own `taskTranscripts` object, which is never
  /// pre-seeded with empty strings.
  final Map<int, String> transcripts;

  /// The current interim (not-yet-final) transcript for [taskIndex], live
  /// while [phase] is [TimerTaskPhase.listening] — mirrors the web's own
  /// `taskInterim[taskIdx]`.
  final String liveInterim;

  /// 0-based task indices that have finished their 60-second window (or
  /// been manually stopped) — mirrors the web's own `completedTasks` Set.
  final Set<int> completed;

  final bool isSubmitting;
  final Failure? submitError;

  /// A genuine `TimerSpeechService.initialize()` failure (unsupported
  /// platform, denied permission) — surfaced honestly, never silently
  /// substituted with fake transcript text. Cleared on the next [start]
  /// attempt.
  final String? speechError;

  TimerTask get currentTask => exercise.tasks[taskIndex];
  int get totalTasks => exercise.tasks.length;
  bool get isLastTask => taskIndex == totalTasks - 1;
  bool get currentTaskCompleted => completed.contains(taskIndex);
  bool get allTasksCompleted => totalTasks > 0 && completed.length == totalTasks;

  /// The finalized transcript captured so far for [taskIndex] (excludes
  /// any still-live interim text — see [liveTranscriptFor] for the
  /// display-ready combination of the two).
  String transcriptFor(int index) => transcripts[index] ?? '';
  int get currentWordCount => countTimerWords(transcriptFor(taskIndex));

  /// What the live word-count/transcript display should show for
  /// [taskIndex] right now — the finalized transcript while idle/complete,
  /// or the *live interim* text while still listening (the plugin reports
  /// interim results as the full phrase-so-far, not a delta — see
  /// `TimerSpeechResultCallback`'s doc comment), falling back to the
  /// finalized transcript if no interim has arrived yet this session.
  String get liveTranscript {
    if (phase == TimerTaskPhase.listening && liveInterim.isNotEmpty) return liveInterim;
    return transcriptFor(taskIndex);
  }

  TimerExerciseInProgress copyWith({
    int? taskIndex,
    TimerTaskPhase? phase,
    int? secondsLeft,
    Map<int, String>? transcripts,
    String? liveInterim,
    Set<int>? completed,
    bool? isSubmitting,
    Failure? submitError,
    bool clearSubmitError = false,
    String? speechError,
    bool clearSpeechError = false,
  }) {
    return TimerExerciseInProgress(
      exercise: exercise,
      taskIndex: taskIndex ?? this.taskIndex,
      phase: phase ?? this.phase,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      transcripts: transcripts ?? this.transcripts,
      liveInterim: liveInterim ?? this.liveInterim,
      completed: completed ?? this.completed,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      speechError: clearSpeechError ? null : (speechError ?? this.speechError),
    );
  }
}

final class TimerExerciseSubmitted extends TimerExerciseState {
  const TimerExerciseSubmitted({required this.exercise, required this.transcripts, required this.result});
  final TimerExercise exercise;
  final Map<int, String> transcripts;
  final TimerSubmissionResult result;
}

class TimerExerciseController extends Notifier<TimerExerciseState> {
  TimerExerciseController(this.arg);

  /// (exerciseId, title, order) — same `NotifierProvider.family` pattern as
  /// `GenericWritingController`.
  final (int, String, int) arg;

  int get exerciseId => arg.$1;
  String get title => arg.$2;
  int get order => arg.$3;

  late final TimerSpeechService _speech;
  Timer? _timer;
  bool _speechReady = false;

  @override
  TimerExerciseState build() {
    _speech = ref.read(timerSpeechServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_speech.cancel());
    });
    _load();
    return const TimerExerciseLoading();
  }

  Future<void> _load() async {
    final result = await ref.read(timerExerciseRepositoryProvider).getTimerExercise(exerciseId, title: title, order: order);
    state = switch (result) {
      Success(value: final exercise) => TimerExerciseInProgress(exercise: exercise, taskIndex: 0),
      Failed(failure: final failure) => TimerExerciseLoadFailed(failure),
    };
  }

  Future<void> retryLoad() async {
    state = const TimerExerciseLoading();
    await _load();
  }

  /// Full re-run of the flow — mirrors the web's "Reset"/reload behavior:
  /// re-fetches rather than merely clearing local state, same reasoning as
  /// `GenericWritingController.tryAgain`.
  Future<void> tryAgain() async {
    _timer?.cancel();
    state = const TimerExerciseLoading();
    await _load();
  }

  /// Mirrors the web's `timer-start` button handler
  /// (`static/js/exercises.js:1327-1346`): if the current task is already
  /// completed and another remains, this just advances the view to the
  /// next task instead of starting to listen again
  /// (`completedTasks.has(taskIdx) && taskIdx + 1 < totalTasks`); an
  /// initialization/permission failure surfaces as [TimerExerciseInProgress
  /// .speechError] — never a fabricated transcript.
  Future<void> start() async {
    final current = state;
    if (current is! TimerExerciseInProgress || current.phase == TimerTaskPhase.listening) return;

    if (current.currentTaskCompleted) {
      if (!current.isLastTask) _advanceTo(current.taskIndex + 1);
      return;
    }

    if (!_speechReady) {
      final ok = await _speech.initialize();
      _speechReady = ok;
      if (!ok) {
        final latest = state;
        if (latest is! TimerExerciseInProgress) return;
        state = latest.copyWith(
          speechError:
              "Speech recognition isn't available on this device. "
              'Please allow microphone/speech-recognition permission in your device settings and try again.',
        );
        return;
      }
    }

    final ready = state;
    if (ready is! TimerExerciseInProgress) return;
    state = ready.copyWith(phase: TimerTaskPhase.listening, secondsLeft: timerTaskDurationSeconds, liveInterim: '', clearSpeechError: true);
    await _speech.listen(onResult: _onSpeechResult);
    _startTimer();
  }

  /// Moves the view to [index] without starting to listen — mirrors
  /// `activateTask(index)` (`static/js/exercises.js:1266-1281`), reached
  /// both by [start]'s own "advance" branch and by [goToTask] (the real
  /// web's clickable task dots).
  void _advanceTo(int index) {
    final current = state;
    if (current is! TimerExerciseInProgress) return;
    state = current.copyWith(
      taskIndex: index,
      phase: TimerTaskPhase.idle,
      secondsLeft: timerTaskDurationSeconds,
      liveInterim: '',
      clearSpeechError: true,
    );
  }

  /// Mirrors the real page's clickable `.timer-dot` elements
  /// (`static/js/exercises.js:1291-1296`): `dot.addEventListener('click',
  /// () => { if (index === taskIdx + 1 && completedTasks.has(taskIdx))
  /// activateTask(index); })` — tapping a dot only ever does something for
  /// the single next task, and only once the current one is done; every
  /// other tap (a future task, a past/completed task, or the current one)
  /// is a genuine no-op on the real web too, not a missing feature.
  void goToTask(int index) {
    final current = state;
    if (current is! TimerExerciseInProgress || current.phase == TimerTaskPhase.listening) return;
    if (index == current.taskIndex + 1 && current.currentTaskCompleted) _advanceTo(index);
  }

  /// Mirrors the real page's `resetBtn` handler
  /// (`static/js/exercises.js:1360-1396`): a full **local** reset of the
  /// current attempt back to Task 1 — stop any active recording/timer,
  /// discard every captured transcript, no server round-trip at all
  /// (unlike [tryAgain], which re-fetches; the real "Reset" button never
  /// calls the server either). Hidden by the UI once every task is
  /// already complete, matching `resetBtn.style.display = 'none'` at that
  /// point on the real page.
  Future<void> reset() async {
    final current = state;
    if (current is! TimerExerciseInProgress) return;
    _timer?.cancel();
    await _speech.cancel();
    state = TimerExerciseInProgress(exercise: current.exercise, taskIndex: 0);
  }

  void _onSpeechResult(String recognizedWords, bool isFinal) {
    final current = state;
    if (current is! TimerExerciseInProgress || current.phase != TimerTaskPhase.listening) return;
    if (isFinal) {
      state = current.copyWith(transcripts: {...current.transcripts, current.taskIndex: recognizedWords}, liveInterim: '');
    } else {
      state = current.copyWith(liveInterim: recognizedWords);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! TimerExerciseInProgress || current.phase != TimerTaskPhase.listening) return;
    final next = current.secondsLeft - 1;
    if (next <= 0) {
      unawaited(_finishCurrentTask());
      return;
    }
    state = current.copyWith(secondsLeft: next);
  }

  /// User-initiated stop — mirrors the web's `timer-stop` button
  /// (`finishCurrentTask()` directly, `static/js/exercises.js:1358-1361`).
  Future<void> stop() async {
    final current = state;
    if (current is! TimerExerciseInProgress || current.phase != TimerTaskPhase.listening) return;
    await _finishCurrentTask();
  }

  /// Mirrors `finishTask()`/`finishCurrentTask()`
  /// (`static/js/exercises.js:1240-1300`): stop the countdown and the
  /// recognizer, fold any still-live interim words into the finalized
  /// transcript (`spokenInterim` fold, `:1244-1247`), mark the task
  /// complete, and — once every task is done — leave the exercise ready
  /// for [submit].
  Future<void> _finishCurrentTask() async {
    _timer?.cancel();
    final current = state;
    if (current is! TimerExerciseInProgress) return;
    await _speech.stop();

    final interim = current.liveInterim.trim();
    final finalText = interim.isNotEmpty ? interim : current.transcriptFor(current.taskIndex);

    state = current.copyWith(
      phase: TimerTaskPhase.taskComplete,
      transcripts: finalText.isEmpty ? current.transcripts : {...current.transcripts, current.taskIndex: finalText},
      liveInterim: '',
      completed: {...current.completed, current.taskIndex},
      secondsLeft: 0,
    );
  }

  Future<void> submit() async {
    final current = state;
    if (current is! TimerExerciseInProgress || current.isSubmitting || !current.allTasksCompleted) return;

    state = current.copyWith(isSubmitting: true, clearSubmitError: true);

    // Only tasks with a non-empty transcript get an `answers` entry —
    // mirrors `Object.keys(taskTranscripts).forEach` skipping `!text`
    // tasks entirely (`static/js/exercises.js:1396-1397`).
    final answers = <int, String>{
      for (final task in current.exercise.tasks)
        if (current.transcriptFor(task.position - 1).trim().isNotEmpty) task.position: current.transcriptFor(task.position - 1).trim(),
    };

    final clientScore = computeTimerClientScore(
      totalTasks: current.totalTasks,
      answers: [
        for (final task in current.exercise.tasks)
          TimerTaskAnswer(position: task.position, transcript: current.transcriptFor(task.position - 1), questionText: task.questionText),
      ],
    );

    final result = await ref
        .read(timerExerciseRepositoryProvider)
        .submitTimerExercise(current.exercise.id, score: clientScore.score, maxScore: clientScore.maxScore, answers: answers);

    state = switch (result) {
      Success(value: final submissionResult) => TimerExerciseSubmitted(
        exercise: current.exercise,
        transcripts: current.transcripts,
        result: submissionResult,
      ),
      Failed(failure: final failure) => current.copyWith(isSubmitting: false, submitError: failure),
    };
  }
}

final timerExerciseControllerProvider =
    NotifierProvider.family<TimerExerciseController, TimerExerciseState, (int, String, int)>(TimerExerciseController.new);
