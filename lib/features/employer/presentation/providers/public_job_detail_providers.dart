import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/public_job_detail_remote_datasource.dart';
import '../../data/public_job_detail_repository_impl.dart';
import '../../domain/repositories/public_job_detail_repository.dart';

final publicJobDetailRemoteDataSourceProvider = Provider<PublicJobDetailRemoteDataSource>((ref) {
  return PublicJobDetailRemoteDataSource(ref.watch(apiClientProvider));
});

final publicJobDetailRepositoryProvider = Provider<PublicJobDetailRepository>((ref) {
  return PublicJobDetailRepositoryImpl(ref.watch(publicJobDetailRemoteDataSourceProvider));
});
