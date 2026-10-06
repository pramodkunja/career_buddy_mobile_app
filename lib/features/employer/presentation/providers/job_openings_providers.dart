import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/job_openings_remote_datasource.dart';
import '../../data/job_openings_repository_impl.dart';
import '../../domain/repositories/job_openings_repository.dart';

final jobOpeningsRemoteDataSourceProvider = Provider<JobOpeningsRemoteDataSource>((ref) {
  return JobOpeningsRemoteDataSource(ref.watch(apiClientProvider));
});

final jobOpeningsRepositoryProvider = Provider<JobOpeningsRepository>((ref) {
  return JobOpeningsRepositoryImpl(ref.watch(jobOpeningsRemoteDataSourceProvider));
});
