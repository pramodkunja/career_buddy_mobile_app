import 'package:flutter_tts/flutter_tts.dart';

import '../domain/services/gd_tts_service.dart';

/// See `GdTtsService`'s doc comment. Same `flutter_tts` wrapper shape as
/// `GrammarTtsServiceImpl`, kept as its own small class per this codebase's
/// one-service-per-feature convention rather than shared.
class GdTtsServiceImpl implements GdTtsService {
  GdTtsServiceImpl([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text) async {
    await _tts.setSpeechRate(0.475);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  void setOnComplete(void Function() callback) => _tts.setCompletionHandler(callback);
}
