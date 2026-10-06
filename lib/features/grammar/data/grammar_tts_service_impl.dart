import 'package:flutter_tts/flutter_tts.dart';

import '../domain/services/grammar_tts_service.dart';

class GrammarTtsServiceImpl implements GrammarTtsService {
  GrammarTtsServiceImpl([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text) async {
    // `.speak(text)` at rate 0.95 (`detail.html`'s SpeechSynthesisUtterance
    // rate) — flutter_tts's 0.0-1.0 scale puts "normal" speed near 0.5, so
    // 0.475 (0.5 * 0.95) is the equivalent point on this platform's scale.
    await _tts.setSpeechRate(0.475);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  void setOnComplete(void Function() callback) => _tts.setCompletionHandler(callback);
}
