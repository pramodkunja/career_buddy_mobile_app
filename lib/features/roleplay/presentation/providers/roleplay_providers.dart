import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../ai_speaking/data/services/audio_recorder_service_impl.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../data/datasources/roleplay_remote_datasource.dart';
import '../../data/repositories/roleplay_repository_impl.dart';
import '../../domain/repositories/roleplay_repository.dart';

final roleplayRemoteDataSourceProvider = Provider<RoleplayRemoteDataSource>((ref) {
  return RoleplayRemoteDataSource(ref.watch(apiClientProvider));
});

final roleplayRepositoryProvider = Provider<RoleplayRepository>((ref) {
  return RoleplayRepositoryImpl(ref.watch(roleplayRemoteDataSourceProvider));
});

/// [AudioRecorderService] is a generic, non-speaking-specific microphone
/// abstraction (see its own doc comment under `ai_speaking/domain/services`)
/// already built and proven by W014 — reused directly here rather than
/// duplicating a second wrapper around `package:record`. A fresh instance
/// per read, same reasoning as `ai_speaking`'s own
/// `audioRecorderServiceProvider`: each holds native platform resource
/// state, so a singleton would be wrong once more than one screen/controller
/// used it concurrently.
final roleplayAudioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return AudioRecorderServiceImpl();
});
