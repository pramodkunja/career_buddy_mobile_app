import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/job_posting_remote_datasource.dart';
import '../../data/job_posting_repository_impl.dart';
import '../../domain/repositories/job_posting_repository.dart';

final jobPostingRemoteDataSourceProvider = Provider<JobPostingRemoteDataSource>((ref) {
  return JobPostingRemoteDataSource(ref.watch(apiClientProvider));
});

final jobPostingRepositoryProvider = Provider<JobPostingRepository>((ref) {
  return JobPostingRepositoryImpl(ref.watch(jobPostingRemoteDataSourceProvider));
});
