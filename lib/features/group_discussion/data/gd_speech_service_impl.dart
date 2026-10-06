import 'package:speech_to_text/speech_to_text.dart';

import '../domain/services/gd_speech_service.dart';

/// See `GdSpeechService`'s doc comment. Wraps `package:speech_to_text`
/// directly — this is a real, on-device capture, not a fake/stubbed
/// transcript: [initialize] genuinely fails (returns `false`) when the
/// platform has no recognizer or the user has denied microphone/speech
/// permission, and callers must treat that as a real error state.
class GdSpeechServiceImpl implements GdSpeechService {
  GdSpeechServiceImpl([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  @override
  Future<bool> initialize() async {
    _initialized = await _speech.initialize();
    return _initialized;
  }

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> startListening({
    required void Function(String partialText) onPartialResult,
    required void Function(String finalText) onFinalResult,
  }) async {
    if (!_initialized) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onFinalResult(result.recognizedWords);
        } else {
          onPartialResult(result.recognizedWords);
        }
      },
    );
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
