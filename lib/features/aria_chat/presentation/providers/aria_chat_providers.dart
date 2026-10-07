import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart' show AudioEncoder;

import '../../../../core/providers/core_providers.dart';
import '../../../ai_speaking/data/services/audio_recorder_service_impl.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../data/datasources/aria_remote_datasource.dart';
import '../../data/services/aria_voice_playback_service_impl.dart';
import '../../domain/services/aria_voice_playback_service.dart';

final ariaRemoteDataSourceProvider = Provider<AriaRemoteDataSource>((ref) {
  return AriaRemoteDataSource(ref.watch(apiClientProvider));
});

/// Records to `.wav`, not [AudioRecorderServiceImpl]'s default `.m4a` —
/// see that class's doc comment: confirmed live that the real
/// `/api/voice/transcribe/` Sarvam call rejects this plugin's AAC-LC
/// output but transcribes WAV correctly, so ARIA voice input needs its own
/// encoder choice. The paired `mimeType: 'audio/wav'` sent in
/// `AriaChatController.stopRecordingAndSend` must be kept in sync with
/// this.
final ariaAudioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return AudioRecorderServiceImpl(null, AudioEncoder.wav, 'wav');
});

final ariaVoicePlaybackServiceProvider = Provider<AriaVoicePlaybackService>((ref) {
  return AriaVoicePlaybackServiceImpl();
});
