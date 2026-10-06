import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/resume_remote_datasource.dart';
import '../../data/resume_repository_impl.dart';
import '../../domain/entities/resume_history_item.dart';
import '../../domain/repositories/resume_repository.dart';
import '../controllers/resume_builder_controller.dart';
import '../controllers/resume_history_controller.dart';

final resumeRemoteDataSourceProvider = Provider<ResumeRemoteDataSource>((ref) {
  return ResumeRemoteDataSource(ref.watch(apiClientProvider));
});

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  return ResumeRepositoryImpl(ref.watch(resumeRemoteDataSourceProvider));
});

final resumeBuilderControllerProvider = NotifierProvider<ResumeBuilderController, ResumeBuilderState>(
  ResumeBuilderController.new,
);

final resumeHistoryControllerProvider = AsyncNotifierProvider<ResumeHistoryController, List<ResumeHistoryItem>>(
  ResumeHistoryController.new,
  retry: (retryCount, error) => null,
);
