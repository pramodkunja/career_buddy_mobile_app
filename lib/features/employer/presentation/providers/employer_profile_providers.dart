import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/employer_profile_remote_datasource.dart';
import '../../data/employer_profile_repository_impl.dart';
import '../../domain/repositories/employer_profile_repository.dart';

final employerProfileRemoteDataSourceProvider = Provider<EmployerProfileRemoteDataSource>((ref) {
  return EmployerProfileRemoteDataSource(ref.watch(apiClientProvider));
});

final employerProfileRepositoryProvider = Provider<EmployerProfileRepository>((ref) {
  return EmployerProfileRepositoryImpl(ref.watch(employerProfileRemoteDataSourceProvider));
});
