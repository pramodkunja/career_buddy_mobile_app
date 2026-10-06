import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/employer_all_applications_remote_datasource.dart';
import '../../data/employer_all_applications_repository_impl.dart';
import '../../domain/repositories/employer_all_applications_repository.dart';

final employerAllApplicationsRemoteDataSourceProvider = Provider<EmployerAllApplicationsRemoteDataSource>((ref) {
  return EmployerAllApplicationsRemoteDataSource(ref.watch(apiClientProvider));
});

final employerAllApplicationsRepositoryProvider = Provider<EmployerAllApplicationsRepository>((ref) {
  return EmployerAllApplicationsRepositoryImpl(ref.watch(employerAllApplicationsRemoteDataSourceProvider));
});
