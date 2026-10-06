import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../ai_speaking/data/services/audio_recorder_service_impl.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../data/datasources/aria_remote_datasource.dart';
import '../../data/services/aria_voice_playback_service_impl.dart';
import '../../domain/services/aria_voice_playback_service.dart';

final ariaRemoteDataSourceProvider = Provider<AriaRemoteDataSource>((ref) {
  return AriaRemoteDataSource(ref.watch(apiClientProvider));
});

/// Reuses [AudioRecorderServiceImpl] unmodified — see its doc comment for
/// why the same `.m4a` output is accepted by the server regardless of which
/// feature recorded it (not format-specific server-side). Same pattern as
/// `jamAudioRecorderServiceProvider`.
final ariaAudioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return AudioRecorderServiceImpl();
});

final ariaVoicePlaybackServiceProvider = Provider<AriaVoicePlaybackService>((ref) {
  return AriaVoicePlaybackServiceImpl();
});
