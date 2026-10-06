import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/providers/core_providers.dart';
import '../../data/datasources/amcat_remote_datasource.dart';
import '../../data/repositories/amcat_repository_impl.dart';
import '../../domain/repositories/amcat_repository.dart';

final amcatRemoteDataSourceProvider = Provider<AmcatRemoteDataSource>((ref) {
  return AmcatRemoteDataSource(
    ref.watch(apiClientProvider),
    questionsPath: ApiEndpoints.amcatQuestions,
    submitPath: ApiEndpoints.amcatSubmit,
  );
});

final amcatRepositoryProvider = Provider<AmcatRepository>((ref) {
  return AmcatRepositoryImpl(ref.watch(amcatRemoteDataSourceProvider));
});

/// W023 — reuses [AmcatRemoteDataSource]/[AmcatRepositoryImpl] pointed at
/// CoCubes's own endpoint pair — see `AmcatRemoteDataSource`'s doc comment
/// for why this is a safe, verified reuse rather than a forced one.
final cocubesRemoteDataSourceProvider = Provider<AmcatRemoteDataSource>((ref) {
  return AmcatRemoteDataSource(
    ref.watch(apiClientProvider),
    questionsPath: ApiEndpoints.cocubesQuestions,
    submitPath: ApiEndpoints.cocubesSubmit,
  );
});

final cocubesRepositoryProvider = Provider<AmcatRepository>((ref) {
  return AmcatRepositoryImpl(ref.watch(cocubesRemoteDataSourceProvider));
});
