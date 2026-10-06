import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/aria_voice_playback_service.dart';

class AriaVoicePlaybackServiceImpl implements AriaVoicePlaybackService {
  AriaVoicePlaybackServiceImpl({AudioPlayer? player, FlutterTts? tts})
    : _player = player ?? AudioPlayer(),
      _tts = tts ?? FlutterTts() {
    _player.onPlayerComplete.listen((_) => _onComplete?.call());
    _tts.setCompletionHandler(() => _onComplete?.call());
  }

  final AudioPlayer _player;
  final FlutterTts _tts;
  void Function()? _onComplete;

  @override
  Future<bool> playAudioBytes(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      await _player.play(BytesSource(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speakDeviceVoice(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  @override
  void setOnComplete(void Function() callback) => _onComplete = callback;
}
