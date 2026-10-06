import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/speaking_analysis_result.dart';
import '../../domain/entities/speaking_topic.dart';
import '../../domain/services/audio_recorder_service.dart';
import '../../domain/services/speaking_quick_tip.dart';
import '../providers/ai_speaking_providers.dart';

/// AI Speaking's actual web flow (`speaking.html` + `speaking.js`, read in
/// full) is a single page with in-place state transitions — Topic (idle) →
/// Recording → Recorded (ready to submit) → Submitting → Result — driven
/// entirely client-side except the one server round-trip
/// (`analyze_speaking`). This mirrors that.
///
/// Deliberately does **not** reproduce two web behaviors:
/// - The 4-language cosmetic label overlay (Vietnamese/Arabic/Russian
///   translations of static UI text) — `language` is still a real,
///   functional field sent to the server (it does affect the AI's actual
///   feedback text, `analyze_text_with_sarvam_chat`'s `language` param),
///   only the decorative client-side re-labelling of buttons/headers is
///   skipped.
/// - The catch-block's local, client-computed fallback score
///   (`estimateLocalScores`/`computeSpeakingScore` in `speaking.js`) when
///   the server call fails — that is Flutter inventing a score the server
///   never authorised, which this app's own conventions (and this task)
///   explicitly avoid; a real submission failure instead surfaces a
///   retryable error, preserving the recording (same resilience pattern as
///   `AmcatController.submit`/`MockTestController.submit`).
sealed class AiSpeakingState {
  const AiSpeakingState({required this.topic});
  final String topic;
}

final class AiSpeakingIdle extends AiSpeakingState {
  const AiSpeakingIdle({required super.topic, this.micErrorMessage});
  final String? micErrorMessage;
}

/// [maxSeconds]/[maxPauses] mirror `MAX_RECORD_SECONDS` (90s — the
/// `isElevatorPitchTimed` 60s special case for one specific
/// activity/sub-activity/exercise combo is not reproduced, see
/// `AiSpeakingScreen`'s doc comment) and the `pauseCount > 5` auto-stop
/// rule (`speaking.js:630-633`).
final class AiSpeakingRecording extends AiSpeakingState {
  const AiSpeakingRecording({required super.topic, required this.elapsedSeconds, required this.paused, required this.pauseCount});

  final int elapsedSeconds;
  final bool paused;
  final int pauseCount;

  static const int maxSeconds = 90;
  static const int maxPauses = 5;

  AiSpeakingRecording copyWith({int? elapsedSeconds, bool? paused, int? pauseCount}) {
    return AiSpeakingRecording(
      topic: topic,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      paused: paused ?? this.paused,
      pauseCount: pauseCount ?? this.pauseCount,
    );
  }
}

/// Stopped, ready for "Submit for Analysis". [timeLimitReached]/
/// [pauseLimitExceeded] are purely informational (the web still lets you
/// analyze either way — `handleTimeLimitReached`/`handlePauseLimitExceeded`
/// both fall through to the normal "recording ready" flow).
final class AiSpeakingRecorded extends AiSpeakingState {
  const AiSpeakingRecorded({
    required super.topic,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.pauseCount,
    this.timeLimitReached = false,
    this.pauseLimitExceeded = false,
  });

  final String audioFilePath;
  final int elapsedSeconds;
  final int pauseCount;
  final bool timeLimitReached;
  final bool pauseLimitExceeded;
}

final class AiSpeakingSubmitting extends AiSpeakingState {
  const AiSpeakingSubmitting({
    required super.topic,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.pauseCount,
  });
  final String audioFilePath;
  final int elapsedSeconds;
  final int pauseCount;
}

/// Preserves the recording so `submitForAnalysis` (used as retry too) can
/// resend the exact same file without re-recording.
final class AiSpeakingSubmitFailed extends AiSpeakingState {
  const AiSpeakingSubmitFailed({
    required super.topic,
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

final class AiSpeakingResult extends AiSpeakingState {
  const AiSpeakingResult({required super.topic, required this.result, required this.quickTip});
  final SpeakingAnalysisResult result;

  /// Computed client-side via `computeSpeakingQuickTip` — see this class's
  /// doc comment for why this (not `result`'s own unused `quick_tip`
  /// field) is what the web actually displays.
  final String quickTip;
}

class AiSpeakingController extends Notifier<AiSpeakingState> {
  AiSpeakingController(this.exerciseId);

  final int exerciseId;

  late final AudioRecorderService _recorder;
  Timer? _timer;
  final Random _random = Random();
  List<String> _remainingTopics = [];
  String _language = 'english';

  @override
  AiSpeakingState build() {
    _recorder = ref.read(audioRecorderServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_recorder.cancel());
    });
    return const AiSpeakingIdle(topic: kSpeakingInitialTopic);
  }

  void setLanguage(String language) => _language = language;

  /// "New Topic" (`getNextUniqueTopic()`/`refillTopicPool()`,
  /// `speaking.js:893-918`) — picks a random not-yet-seen topic from the
  /// pool, refilling (excluding the current one) once exhausted, and
  /// resets any in-progress recording (`resetAll()`).
  void pickNewTopic() {
    final currentTopic = state.topic;
    if (_remainingTopics.isEmpty) {
      _remainingTopics = kSpeakingTopics.where((t) => t != currentTopic).toList();
    }
    if (_remainingTopics.isEmpty) {
      state = AiSpeakingIdle(topic: currentTopic);
      return;
    }
    final next = _remainingTopics.removeAt(_random.nextInt(_remainingTopics.length));
    _timer?.cancel();
    state = AiSpeakingIdle(topic: next);
  }

  /// "Try Again" from the result screen (`resetAll()`,
  /// `speaking.js:836-891`) — keeps the same topic, discards the
  /// recording/result. Unlike `pickNewTopic`, the web's own "Try Again"
  /// never changes the topic.
  void tryAgain() {
    _timer?.cancel();
    state = AiSpeakingIdle(topic: state.topic);
  }

  Future<void> startRecording() async {
    final current = state;
    if (current is! AiSpeakingIdle && current is! AiSpeakingRecorded) return;
    final granted = await _recorder.hasPermission();
    if (!granted) {
      state = AiSpeakingIdle(
        topic: current.topic,
        micErrorMessage: "Microphone access denied. Please allow microphone access in your device settings and try again.",
      );
      return;
    }
    await _recorder.start();
    state = AiSpeakingRecording(topic: current.topic, elapsedSeconds: 0, paused: false, pauseCount: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! AiSpeakingRecording || current.paused) return;
    final nextElapsed = current.elapsedSeconds + 1;
    if (nextElapsed >= AiSpeakingRecording.maxSeconds) {
      unawaited(stopRecording(timeLimitReached: true));
      return;
    }
    state = current.copyWith(elapsedSeconds: nextElapsed);
  }

  /// "Pause"/"Resume" (`handlePauseResumeToggle`, `speaking.js:621-641`) —
  /// exceeding 5 pauses auto-stops the recording entirely (matching
  /// `handlePauseLimitExceeded`), rather than allowing a 6th pause.
  Future<void> pauseRecording() async {
    final current = state;
    if (current is! AiSpeakingRecording || current.paused) return;
    final newPauseCount = current.pauseCount + 1;
    if (newPauseCount > AiSpeakingRecording.maxPauses) {
      state = current.copyWith(pauseCount: newPauseCount);
      await stopRecording(pauseLimitExceeded: true);
      return;
    }
    await _recorder.pause();
    state = current.copyWith(paused: true, pauseCount: newPauseCount);
  }

  Future<void> resumeRecording() async {
    final current = state;
    if (current is! AiSpeakingRecording || !current.paused) return;
    await _recorder.resume();
    state = current.copyWith(paused: false);
  }

  Future<void> stopRecording({bool timeLimitReached = false, bool pauseLimitExceeded = false}) async {
    final current = state;
    if (current is! AiSpeakingRecording) return;
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path == null) {
      state = AiSpeakingIdle(topic: current.topic, micErrorMessage: 'Recording failed. Please try again.');
      return;
    }
    state = AiSpeakingRecorded(
      topic: current.topic,
      audioFilePath: path,
      elapsedSeconds: current.elapsedSeconds,
      pauseCount: current.pauseCount,
      timeLimitReached: timeLimitReached,
      pauseLimitExceeded: pauseLimitExceeded,
    );
  }

  /// Also used as retry from [AiSpeakingSubmitFailed] — resends the exact
  /// same recording rather than requiring the user to record again.
  Future<void> submitForAnalysis() async {
    final current = state;
    final String topic;
    final String path;
    final int elapsed;
    final int pauses;
    switch (current) {
      case AiSpeakingRecorded():
        topic = current.topic;
        path = current.audioFilePath;
        elapsed = current.elapsedSeconds;
        pauses = current.pauseCount;
      case AiSpeakingSubmitFailed():
        topic = current.topic;
        path = current.audioFilePath;
        elapsed = current.elapsedSeconds;
        pauses = current.pauseCount;
      default:
        return;
    }

    state = AiSpeakingSubmitting(topic: topic, audioFilePath: path, elapsedSeconds: elapsed, pauseCount: pauses);
    final result = await ref
        .read(aiSpeakingRepositoryProvider)
        .analyze(
          exerciseId: exerciseId,
          audioFilePath: path,
          durationSeconds: elapsed.toDouble(),
          pauseCount: pauses,
          language: _language,
          referenceText: topic,
        );

    switch (result) {
      case Success(value: final analysis):
        final quickTip = computeSpeakingQuickTip(
          transcript: analysis.transcript,
          issues: analysis.issues,
          scores: analysis.scores,
          elapsedSeconds: elapsed,
          pauseCount: pauses,
        );
        state = AiSpeakingResult(topic: topic, result: analysis, quickTip: quickTip);
      case Failed(failure: final failure):
        state = AiSpeakingSubmitFailed(topic: topic, audioFilePath: path, elapsedSeconds: elapsed, pauseCount: pauses, failure: failure);
    }
  }
}

final aiSpeakingControllerProvider = NotifierProvider.family<AiSpeakingController, AiSpeakingState, int>(
  AiSpeakingController.new,
);
