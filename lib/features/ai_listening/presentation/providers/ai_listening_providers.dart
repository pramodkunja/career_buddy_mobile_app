import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_ai_listening_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ai_listening_remote_datasource.dart';
import '../../data/repositories/ai_listening_repository_impl.dart';
import '../../data/services/listening_tts_service_impl.dart';
import '../../domain/repositories/ai_listening_repository.dart';
import '../../domain/services/listening_tts_service.dart';

final aiListeningRemoteDataSourceProvider = Provider<AiListeningRemoteDataSource>((ref) {
  return AiListeningRemoteDataSource(ref.watch(apiClientProvider));
});

final aiListeningRepositoryProvider = Provider<AiListeningRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoAiListeningRepository();
  return AiListeningRepositoryImpl(ref.watch(aiListeningRemoteDataSourceProvider));
});

/// A new TTS instance per read, overridden with a fake in tests — same
/// reasoning as `audioRecorderServiceProvider`.
final listeningTtsServiceProvider = Provider<ListeningTtsService>((ref) {
  return ListeningTtsServiceImpl();
});
