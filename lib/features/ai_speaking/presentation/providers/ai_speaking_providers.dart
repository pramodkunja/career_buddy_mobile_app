import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_ai_speaking_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ai_speaking_remote_datasource.dart';
import '../../data/repositories/ai_speaking_repository_impl.dart';
import '../../data/services/audio_recorder_service_impl.dart';
import '../../domain/repositories/ai_speaking_repository.dart';
import '../../domain/services/audio_recorder_service.dart';

final aiSpeakingRemoteDataSourceProvider = Provider<AiSpeakingRemoteDataSource>((ref) {
  return AiSpeakingRemoteDataSource(ref.watch(apiClientProvider));
});

final aiSpeakingRepositoryProvider = Provider<AiSpeakingRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoAiSpeakingRepository();
  return AiSpeakingRepositoryImpl(ref.watch(aiSpeakingRemoteDataSourceProvider));
});

/// A new recorder instance per read — each holds native platform resource
/// state, so a fresh one per controller build (rather than a singleton) is
/// simplest correct behavior. Overridden with a fake in tests.
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return AudioRecorderServiceImpl();
});
