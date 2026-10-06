import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../../ai_speaking/presentation/providers/ai_speaking_providers.dart' show audioRecorderServiceProvider;
import '../../domain/entities/reading_analysis_result.dart';
import '../../domain/entities/reading_passage.dart';
import '../providers/ai_reading_providers.dart';

/// AI Reading's web flow (`reading.html` + `reading.js`, both read in
/// full) is a hybrid: it **records real microphone audio** exactly like
/// Speaking (`AudioRecorderService`, reused directly rather than
/// duplicated — see the import above), but — unlike Speaking, which never
/// locks — a submission **permanently locks** once evaluated
/// (`attemptEvaluated`), matching Listening/Writing's one-shot-then-locked
/// pattern. There is no anti-replay `attempt_token` involved at all
/// (confirmed: `reading-config` has no such field, unlike
/// `listening-config`), so — unlike `AiListeningController` — this
/// controller starts ready immediately, with no loading/token-fetch phase.
///
/// A genuine behavioral difference from Speaking's 5-pause rule: exceeding
/// 5 pauses here **discards the in-progress recording entirely** and
/// returns straight to [ReadingIdle] with a message
/// (`resetReading()` + `showPauseLimitMessage()`), rather than stopping
/// into an inspectable "recorded, pause-limit-exceeded" state the way
/// Speaking's `AiSpeakingRecorded(pauseLimitExceeded: true)` does —
/// confirmed by reading `reading.js`'s pause handler directly rather than
/// assumed identical to Speaking's.
sealed class ReadingState {
  const ReadingState({required this.passage, required this.level});
  final ReadingPassage passage;

  /// `1 | 2 | 3` (Beginner/Intermediate/Advanced).
  final int level;
}

final class ReadingIdle extends ReadingState {
  const ReadingIdle({required super.passage, required super.level, this.micErrorMessage});
  final String? micErrorMessage;
}

/// [maxPauses] mirrors the `pauses > 5` auto-reset rule
/// (`reading.js:966-970`).
final class ReadingRecording extends ReadingState {
  const ReadingRecording({
    required super.passage,
    required super.level,
    required this.elapsedSeconds,
    required this.paused,
    required this.pauseCount,
  });

  final int elapsedSeconds;
  final bool paused;
  final int pauseCount;

  static const int maxPauses = 5;

  ReadingRecording copyWith({int? elapsedSeconds, bool? paused, int? pauseCount}) {
    return ReadingRecording(
      passage: passage,
      level: level,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      paused: paused ?? this.paused,
      pauseCount: pauseCount ?? this.pauseCount,
    );
  }
}

/// Stopped, ready for "Submit for Analysis". Tapping the mic again from
/// here starts a brand-new recording, discarding this one — matches the
/// web's mic-button handler, which always resets `recordedBlob`/transcript
/// state when starting a fresh capture.
final class ReadingRecorded extends ReadingState {
  const ReadingRecorded({
    required super.passage,
    required super.level,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.pauseCount,
  });

  final String audioFilePath;
  final int elapsedSeconds;
  final int pauseCount;
}

final class ReadingSubmitting extends ReadingState {
  const ReadingSubmitting({
    required super.passage,
    required super.level,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.pauseCount,
  });
  final String audioFilePath;
  final int elapsedSeconds;
  final int pauseCount;
}

/// Preserves the recording so `submitForAnalysis` (used as retry too) can
/// resend it without re-recording — a genuine server/network failure never
/// locks the attempt, matching `reading.js`'s catch-block behavior (only
/// the success path sets `attemptEvaluated`).
final class ReadingSubmitFailed extends ReadingState {
  const ReadingSubmitFailed({
    required super.passage,
    required super.level,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.pauseCount,
    required this.failure,
  });
  final String audioFilePath;
  final int elapsedSeconds;
  final int pauseCount;
  final Failure failure;
}

/// Terminal — matches `attemptEvaluated`. No further `submitForAnalysis`
/// call succeeds from here; only `pickNewPassage`/`setLevel` (an actual
/// restart) re-enables recording, the same restriction the web enforces.
final class ReadingResult extends ReadingState {
  const ReadingResult({required super.passage, required super.level, required this.result});
  final ReadingAnalysisResult result;
}

class AiReadingController extends Notifier<ReadingState> {
  AiReadingController(this.exerciseId);

  final int exerciseId;

  late final AudioRecorderService _recorder;
  Timer? _timer;
  final Random _random = Random();
  final Map<int, List<int>> _remainingIndexesByLevel = {1: [], 2: [], 3: []};
  final Map<int, int> _currentIndexByLevel = {1: -1, 2: -1, 3: -1};
  String _language = 'english';

  @override
  ReadingState build() {
    _recorder = ref.read(audioRecorderServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_recorder.cancel());
    });
    final passage = _pickPassage(kReadingDefaultLevel);
    return ReadingIdle(passage: passage, level: kReadingDefaultLevel);
  }

  /// `getNextPassageIndex()` (`reading.js:738-747`) — random pick from the
  /// level's remaining pool, refilling (excluding the current index within
  /// that same level) once exhausted.
  ReadingPassage _pickPassage(int level) {
    var pool = _remainingIndexesByLevel[level] ?? [];
    if (pool.isEmpty) {
      final count = kReadingPassagesByLevel[level]!.length;
      pool = List.generate(count, (i) => i).where((i) => i != _currentIndexByLevel[level]).toList();
    }
    final index = pool.isEmpty ? 0 : pool.removeAt(_random.nextInt(pool.length));
    _remainingIndexesByLevel[level] = pool;
    _currentIndexByLevel[level] = index;
    return kReadingPassagesByLevel[level]![index];
  }

  void setLanguage(String language) => _language = language;

  /// "New" passage button — full reset, same level.
  void pickNewPassage() {
    final level = state.level;
    _timer?.cancel();
    unawaited(_recorder.cancel());
    final passage = _pickPassage(level);
    state = ReadingIdle(passage: passage, level: level);
  }

  /// A Level 1/2/3 button tap — full reset, switches to that level's own
  /// (independently tracked) passage pool.
  void setLevel(int level) {
    _timer?.cancel();
    unawaited(_recorder.cancel());
    final passage = _pickPassage(level);
    state = ReadingIdle(passage: passage, level: level);
  }

  /// "Try Again" (`tryAgainBtn`, `reading.js:1157-1169`) — resets to idle
  /// on the *same* passage, discarding any recording/result. Unlike
  /// `pickNewPassage`, "Try Again" never changes the passage or level.
  void tryAgain() {
    _timer?.cancel();
    unawaited(_recorder.cancel());
    state = ReadingIdle(passage: state.passage, level: state.level);
  }

  Future<void> startRecording() async {
    final current = state;
    if (current is! ReadingIdle && current is! ReadingRecorded) return;
    final granted = await _recorder.hasPermission();
    if (!granted) {
      state = ReadingIdle(
        passage: current.passage,
        level: current.level,
        micErrorMessage: 'Microphone access denied. Please allow microphone access in your device settings and try again.',
      );
      return;
    }
    await _recorder.start();
    state = ReadingRecording(passage: current.passage, level: current.level, elapsedSeconds: 0, paused: false, pauseCount: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! ReadingRecording || current.paused) return;
    state = current.copyWith(elapsedSeconds: current.elapsedSeconds + 1);
  }

  Future<void> pauseRecording() async {
    final current = state;
    if (current is! ReadingRecording || current.paused) return;
    final newPauseCount = current.pauseCount + 1;
    if (newPauseCount > ReadingRecording.maxPauses) {
      // Full reset — the recording is discarded entirely, matching
      // `resetReading()` (not merely "stopped, still submittable" the way
      // Speaking's pause-limit case is).
      _timer?.cancel();
      await _recorder.cancel();
      state = ReadingIdle(
        passage: current.passage,
        level: current.level,
        micErrorMessage: 'You have exceeded the maximum pause count.',
      );
      return;
    }
    await _recorder.pause();
    state = current.copyWith(paused: true, pauseCount: newPauseCount);
  }

  Future<void> resumeRecording() async {
    final current = state;
    if (current is! ReadingRecording || !current.paused) return;
    await _recorder.resume();
    state = current.copyWith(paused: false);
  }

  Future<void> stopRecording() async {
    final current = state;
    if (current is! ReadingRecording) return;
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path == null) {
      state = ReadingIdle(passage: current.passage, level: current.level, micErrorMessage: 'Recording failed. Please try again.');
      return;
    }
    state = ReadingRecorded(
      passage: current.passage,
      level: current.level,
      audioFilePath: path,
      elapsedSeconds: current.elapsedSeconds,
      pauseCount: current.pauseCount,
    );
  }

  /// Also used as retry from [ReadingSubmitFailed]. A no-op from
  /// [ReadingResult] — the attempt is permanently locked once evaluated.
  Future<void> submitForAnalysis() async {
    final current = state;
    final String path;
    final int elapsed;
    final int pauses;
    switch (current) {
      case ReadingRecorded():
        path = current.audioFilePath;
        elapsed = current.elapsedSeconds;
        pauses = current.pauseCount;
      case ReadingSubmitFailed():
        path = current.audioFilePath;
        elapsed = current.elapsedSeconds;
        pauses = current.pauseCount;
      default:
        return;
    }
    final passage = current.passage;
    final level = current.level;

    state = ReadingSubmitting(passage: passage, level: level, audioFilePath: path, elapsedSeconds: elapsed, pauseCount: pauses);
    final result = await ref
        .read(aiReadingRepositoryProvider)
        .analyze(
          exerciseId: exerciseId,
          audioFilePath: path,
          durationSeconds: elapsed.toDouble(),
          pauseCount: pauses,
          language: _language,
          referenceText: passage.text,
        );

    switch (result) {
      case Success(value: final analysis):
        state = ReadingResult(passage: passage, level: level, result: analysis);
      case Failed(failure: final failure):
        state = ReadingSubmitFailed(passage: passage, level: level, audioFilePath: path, elapsedSeconds: elapsed, pauseCount: pauses, failure: failure);
    }
  }
}

final aiReadingControllerProvider = NotifierProvider.family<AiReadingController, ReadingState, int>(
  AiReadingController.new,
);
