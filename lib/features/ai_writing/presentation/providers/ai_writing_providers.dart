import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_ai_writing_repository.dart';
import '../../../../core/demo/demo_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/ai_writing_remote_datasource.dart';
import '../../data/repositories/ai_writing_repository_impl.dart';
import '../../domain/repositories/ai_writing_repository.dart';

final aiWritingRemoteDataSourceProvider = Provider<AiWritingRemoteDataSource>((ref) {
  return AiWritingRemoteDataSource(ref.watch(apiClientProvider));
});

final aiWritingRepositoryProvider = Provider<AiWritingRepository>((ref) {
  if (ref.watch(demoModeActiveProvider)) return DemoAiWritingRepository();
  return AiWritingRepositoryImpl(ref.watch(aiWritingRemoteDataSourceProvider));
});
