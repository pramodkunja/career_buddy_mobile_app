import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/listening_analysis_result.dart';
import '../../domain/entities/listening_story.dart';
import '../../domain/services/listening_duration.dart';
import '../../domain/services/listening_tts_service.dart';
import '../../domain/services/listening_validation.dart';
import '../providers/ai_listening_providers.dart';

/// AI Listening's web flow (`listening.html` + `listening.js`, both read
/// in full) is a hybrid of Speaking's and Writing's: playback is a
/// discrete state machine (Ready → Playing → Paused/Completed →
/// Terminated) like Speaking's recorder, but the comprehension answer box
/// stays visible the whole time like Writing's textarea — and, unique to
/// this module, a submission **permanently locks** once evaluated
/// (`attemptEvaluated`), unlike Writing's freely-resubmittable flow.
///
/// The "audio" is on-device text-to-speech reading the fixed story text
/// aloud — there is no server-provided audio file anywhere in this
/// feature, on the web or here (`ListeningTtsService`, backed by
/// `package:flutter_tts`, is the mobile equivalent of the browser's
/// `window.speechSynthesis`).
///
/// The anti-replay `attemptToken` is fetched once, up front, from the
/// existing `exercise_detail` HTML page (see
/// `AiListeningRepository.fetchAttemptToken`'s doc comment) — this
/// controller starts in [ListeningLoading] while that fetch is in flight,
/// a state neither `AiSpeakingController` nor `AiWritingController` need
/// since both start ready synchronously.
sealed class ListeningState {
  const ListeningState();
}

final class ListeningLoading extends ListeningState {
  const ListeningLoading();
}

final class ListeningLoadFailed extends ListeningState {
  const ListeningLoadFailed(this.failure);
  final Failure failure;
}

enum PlaybackStatus { ready, playing, paused, completed, terminated }

sealed class SubmissionPhase {
  const SubmissionPhase();
}

final class SubmissionIdle extends SubmissionPhase {
  const SubmissionIdle();
}

final class SubmissionInFlight extends SubmissionPhase {
  const SubmissionInFlight();
}

final class SubmissionSucceeded extends SubmissionPhase {
  const SubmissionSucceeded(this.result);
  final ListeningAnalysisResult result;
}

final class SubmissionFailed extends SubmissionPhase {
  const SubmissionFailed(this.failure);
  final Failure failure;
}

final class ListeningActive extends ListeningState {
  const ListeningActive({
    required this.story,
    required this.level,
    required this.speed,
    required this.attemptToken,
    required this.status,
    required this.elapsedSeconds,
    required this.durationSeconds,
    required this.pauseCount,
    required this.storyRevealed,
    required this.submission,
  });

  final ListeningStory story;

  /// `'beginner' | 'intermediate'`.
  final String level;

  /// `0.8 | 1.0 | 1.2`.
  final double speed;
  final String attemptToken;
  final PlaybackStatus status;
  final double elapsedSeconds;
  final int durationSeconds;
  final int pauseCount;

  /// The story text is hidden until Play is first tapped, matching the
  /// web's `storyTextBox`/`d-none` toggle (`listening.html`'s inline
  /// "show story text when Play is clicked" patch script).
  final bool storyRevealed;
  final SubmissionPhase submission;

  static const int maxPauses = 5;

  ListeningActive copyWith({
    ListeningStory? story,
    String? level,
    double? speed,
    PlaybackStatus? status,
    double? elapsedSeconds,
    int? durationSeconds,
    int? pauseCount,
    bool? storyRevealed,
    SubmissionPhase? submission,
  }) {
    return ListeningActive(
      story: story ?? this.story,
      level: level ?? this.level,
      speed: speed ?? this.speed,
      attemptToken: attemptToken,
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pauseCount: pauseCount ?? this.pauseCount,
      storyRevealed: storyRevealed ?? this.storyRevealed,
      submission: submission ?? this.submission,
    );
  }
}

class AiListeningController extends Notifier<ListeningState> {
  AiListeningController(this.exerciseId);

  final int exerciseId;

  late final ListeningTtsService _tts;
  Timer? _timer;
  final Random _random = Random();
  final Map<String, List<int>> _remainingIndexesByLevel = {'beginner': [], 'intermediate': []};
  final Map<String, int> _currentIndexByLevel = {'beginner': -1, 'intermediate': -1};
  String _language = 'english';

  @override
  ListeningState build() {
    _tts = ref.read(listeningTtsServiceProvider);
    _tts.setOnStart(_handlePlaybackStarted);
    _tts.setOnComplete(_handlePlaybackCompleted);
    _tts.setOnError(_handlePlaybackError);
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_tts.stop());
    });
    Future.microtask(_load);
    return const ListeningLoading();
  }

  Future<void> _load() async {
    final result = await ref.read(aiListeningRepositoryProvider).fetchAttemptToken(exerciseId);
    switch (result) {
      case Success(value: final token):
        final story = _pickStory(kListeningDefaultLevel);
        state = ListeningActive(
          story: story,
          level: kListeningDefaultLevel,
          speed: 1.0,
          attemptToken: token,
          status: PlaybackStatus.ready,
          elapsedSeconds: 0,
          durationSeconds: estimateListeningDuration(story.text, 1.0),
          pauseCount: 0,
          storyRevealed: false,
          submission: const SubmissionIdle(),
        );
      case Failed(failure: final failure):
        state = ListeningLoadFailed(failure);
    }
  }

  /// `getNextStoryIndex()` (`listening.js:404-414`) — random pick from the
  /// level's remaining pool, refilling (excluding the current index) once
  /// exhausted.
  ListeningStory _pickStory(String level) {
    var pool = _remainingIndexesByLevel[level] ?? [];
    if (pool.isEmpty) {
      final count = kListeningStoriesByLevel[level]!.length;
      pool = List.generate(count, (i) => i).where((i) => i != _currentIndexByLevel[level]).toList();
    }
    final index = pool.isEmpty ? 0 : pool.removeAt(_random.nextInt(pool.length));
    _remainingIndexesByLevel[level] = pool;
    _currentIndexByLevel[level] = index;
    return kListeningStoriesByLevel[level]![index];
  }

  /// Re-fetches a fresh `attempt_token` — the equivalent of the user
  /// reloading the page, which is exactly what mints a new one server-side.
  void retry() {
    state = const ListeningLoading();
    Future.microtask(_load);
  }

  void setLanguage(String language) => _language = language;

  /// "New Story" (`pickStory()` via `newStoryBtn`) — full reset: new
  /// story, playback back to Ready, and the answer/analysis cleared
  /// (`resetAnalysisView()`).
  void pickNewStory() {
    final current = state;
    if (current is! ListeningActive) return;
    _timer?.cancel();
    unawaited(_tts.stop());
    final story = _pickStory(current.level);
    state = ListeningActive(
      story: story,
      level: current.level,
      speed: current.speed,
      attemptToken: current.attemptToken,
      status: PlaybackStatus.ready,
      elapsedSeconds: 0,
      durationSeconds: estimateListeningDuration(story.text, current.speed),
      pauseCount: 0,
      storyRevealed: false,
      submission: const SubmissionIdle(),
    );
  }

  /// `storyLevel`'s `change` handler — also calls `pickStory()` directly,
  /// the same full reset as "New Story", just from the new level's own
  /// (independently tracked) pool.
  void setLevel(String level) {
    final current = state;
    if (current is! ListeningActive) return;
    _timer?.cancel();
    unawaited(_tts.stop());
    final story = _pickStory(level);
    state = ListeningActive(
      story: story,
      level: level,
      speed: current.speed,
      attemptToken: current.attemptToken,
      status: PlaybackStatus.ready,
      elapsedSeconds: 0,
      durationSeconds: estimateListeningDuration(story.text, current.speed),
      pauseCount: 0,
      storyRevealed: false,
      submission: const SubmissionIdle(),
    );
  }

  /// `speedSelect`'s `change` handler — unlike New Story/Level, this only
  /// resets *playback* (`stopSpeechPlayback(true)`); the answer/analysis
  /// is deliberately left untouched (`resetAnalysisView()` is **not**
  /// called) — confirmed by reading the two handlers side by side, not
  /// assumed identical.
  void setSpeed(double speed) {
    final current = state;
    if (current is! ListeningActive) return;
    _timer?.cancel();
    unawaited(_tts.stop());
    state = current.copyWith(
      speed: speed,
      durationSeconds: estimateListeningDuration(current.story.text, speed),
      status: PlaybackStatus.ready,
      elapsedSeconds: 0,
    );
  }

  Future<void> play() async {
    final current = state;
    if (current is! ListeningActive) return;
    if (current.status == PlaybackStatus.paused) {
      await resumeNarration();
      return;
    }
    if (current.status == PlaybackStatus.playing) return;
    state = current.copyWith(status: PlaybackStatus.playing, elapsedSeconds: 0, storyRevealed: true);
    _startTimer();
    await _tts.speak(current.story.text, rate: current.speed);
  }

  /// "Pause"/"Resume" toggle (`pauseStory()`, `listening.js:492-525`) —
  /// exceeding 5 pauses auto-terminates the session entirely
  /// (`showPauseLimitMessage()` + `resetAnalysisView()`), matching
  /// Speaking's identical 5-pause rule.
  Future<void> pause() async {
    final current = state;
    if (current is! ListeningActive || current.status != PlaybackStatus.playing) return;
    final newPauseCount = current.pauseCount + 1;
    _timer?.cancel();
    if (newPauseCount > ListeningActive.maxPauses) {
      await _tts.stop();
      state = current.copyWith(
        status: PlaybackStatus.terminated,
        pauseCount: newPauseCount,
        submission: const SubmissionIdle(),
      );
      return;
    }
    await _tts.pause();
    state = current.copyWith(status: PlaybackStatus.paused, pauseCount: newPauseCount);
  }

  /// See `ListeningTtsServiceImpl`'s doc comment: restarts narration from
  /// the beginning rather than an exact resume-from-position, a
  /// documented, honest simplification given platform TTS limitations.
  Future<void> resumeNarration() async {
    final current = state;
    if (current is! ListeningActive || current.status != PlaybackStatus.paused) return;
    state = current.copyWith(status: PlaybackStatus.playing, elapsedSeconds: 0);
    _startTimer();
    await _tts.speak(current.story.text, rate: current.speed);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! ListeningActive || current.status != PlaybackStatus.playing) return;
    final next = current.elapsedSeconds + 0.2;
    final capped = next > current.durationSeconds ? current.durationSeconds.toDouble() : next;
    state = current.copyWith(elapsedSeconds: capped);
  }

  void _handlePlaybackStarted() {
    final current = state;
    if (current is! ListeningActive || current.status == PlaybackStatus.playing) return;
    state = current.copyWith(status: PlaybackStatus.playing);
  }

  void _handlePlaybackCompleted() {
    _timer?.cancel();
    final current = state;
    if (current is! ListeningActive) return;
    state = current.copyWith(status: PlaybackStatus.completed, elapsedSeconds: current.durationSeconds.toDouble());
  }

  void _handlePlaybackError(String message) {
    _timer?.cancel();
    final current = state;
    if (current is! ListeningActive) return;
    state = current.copyWith(status: PlaybackStatus.ready);
  }

  /// Also usable as retry after a genuine failure — the web's own catch
  /// block re-enables the form on error (only a *successful* evaluation
  /// permanently locks it, via `attemptEvaluated`).
  Future<void> submit(String text) async {
    final current = state;
    if (current is! ListeningActive) return;
    if (current.submission is SubmissionSucceeded || current.submission is SubmissionInFlight) return;

    if (current.status == PlaybackStatus.terminated) {
      // `analyzeText()`'s `sessionTerminated` branch shows the pause-limit
      // message locally and returns — no server call is ever made.
      state = current.copyWith(
        submission: const SubmissionFailed(ValidationFailure({}, 'You have exceeded the maximum pause count.')),
      );
      return;
    }
    if (!hasMeaningfulText(text)) {
      // `analyzeText()`'s `!lv.hasMeaningfulText(text)` branch — shown
      // locally, no server call, and (unlike Writing's live-disabled
      // Submit button) this module's button starts enabled and only
      // validates on tap.
      state = current.copyWith(
        submission: const SubmissionFailed(
          ValidationFailure({}, 'Write your listening summary first, then click Analyze to see highlighted mistakes.'),
        ),
      );
      return;
    }

    state = current.copyWith(submission: const SubmissionInFlight());
    final result = await ref
        .read(aiListeningRepositoryProvider)
        .analyze(
          exerciseId: exerciseId,
          text: text,
          referenceText: current.story.text,
          durationSeconds: current.elapsedSeconds.round(),
          pauseCount: current.pauseCount,
          attemptToken: current.attemptToken,
          language: _language,
        );

    switch (result) {
      case Success(value: final analysis):
        state = current.copyWith(submission: SubmissionSucceeded(analysis));
      case Failed(failure: final failure):
        state = current.copyWith(submission: SubmissionFailed(failure));
    }
  }
}

final aiListeningControllerProvider = NotifierProvider.family<AiListeningController, ListeningState, int>(
  AiListeningController.new,
);
