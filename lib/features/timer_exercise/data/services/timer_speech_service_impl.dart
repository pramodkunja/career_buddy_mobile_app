import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/services/timer_speech_service.dart';

/// Wraps `package:speech_to_text`'s [SpeechToText] — the on-device native
/// equivalent of the web's browser `SpeechRecognition` API
/// (`initTimer()`, `static/js/exercises.js:1141-1163`). Never invents
/// transcript text: [initialize] genuinely returns `false` (surfaced
/// honestly by `TimerExerciseController.start` as a real error state) when
/// the platform has no speech recognizer, or the user has denied
/// microphone/speech permission — this class does not swallow that into a
/// fake success.
class TimerSpeechServiceImpl implements TimerSpeechService {
  TimerSpeechServiceImpl([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<bool> initialize() async {
    if (_speech.isAvailable) return true;
    try {
      return await _speech.initialize();
    } catch (_) {
      // A genuine platform/permission failure — never treated as success.
      return false;
    }
  }

  @override
  Future<void> listen({required TimerSpeechResultCallback onResult}) {
    // `listenFor`/`pauseFor` are generous (matching this exercise's own
    // 60-second task duration) so the native session doesn't cut itself
    // off mid-task on a brief pause — `TimerExerciseController`'s own Dart
    // `Timer` is what actually enforces the 60-second cutoff (calling
    // [stop] itself), not this plugin's own timeout. `ListenMode.dictation`
    // is the closest match to the web's `continuous`/`interimResults`
    // long-form speech setting.
    return _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        pauseFor: Duration(seconds: 60),
        listenFor: Duration(seconds: 60),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
