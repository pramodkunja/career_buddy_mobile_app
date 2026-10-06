import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/listening_tts_service.dart';

/// Wraps `package:flutter_tts` — the on-device equivalent of the web's
/// `window.speechSynthesis`. `pause()`/resume support is a documented,
/// honest simplification: `AiListeningController.resumeNarration` restarts
/// speaking the full story text from the beginning rather than claiming an
/// exact resume-from-position, since platform TTS pause/resume isn't
/// reliably available across every Android API level (unlike every modern
/// desktop/mobile browser's `speechSynthesis.resume()`, which the web
/// relies on) — see `docs/W016_AI_LISTENING.md`.
class ListeningTtsServiceImpl implements ListeningTtsService {
  ListeningTtsServiceImpl([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, {required double rate}) async {
    // flutter_tts's setSpeechRate is normalised to roughly 0.0-1.0 on most
    // platforms rather than the Web Speech API's ~0.1-10 "rate" scale; 0.5
    // is each platform's approximate "normal" speed, so map the web's
    // 0.8/1.0/1.2 multipliers onto that same normal point.
    await _tts.setSpeechRate(0.5 * rate);
    await _tts.speak(text);
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> stop() => _tts.stop();

  @override
  void setOnStart(void Function() callback) => _tts.setStartHandler(callback);

  @override
  void setOnComplete(void Function() callback) => _tts.setCompletionHandler(callback);

  @override
  void setOnError(void Function(String message) callback) => _tts.setErrorHandler((msg) => callback(msg.toString()));
}
