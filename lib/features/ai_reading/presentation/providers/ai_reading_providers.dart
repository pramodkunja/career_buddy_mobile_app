import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_ai_reading_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ai_reading_remote_datasource.dart';
import '../../data/repositories/ai_reading_repository_impl.dart';
import '../../domain/repositories/ai_reading_repository.dart';

final aiReadingRemoteDataSourceProvider = Provider<AiReadingRemoteDataSource>((ref) {
  return AiReadingRemoteDataSource(ref.watch(apiClientProvider));
});

final aiReadingRepositoryProvider = Provider<AiReadingRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoAiReadingRepository();
  return AiReadingRepositoryImpl(ref.watch(aiReadingRemoteDataSourceProvider));
});

// Microphone recording reuses AI Speaking's `AudioRecorderService`/
// `audioRecorderServiceProvider` directly (`features/ai_speaking/...`) —
// it's a generic platform-capability abstraction over `package:record`,
// not anything Speaking-specific, so duplicating it here would violate
// the "don't duplicate shared infrastructure" rule. See
// `AiReadingController`'s doc comment.
