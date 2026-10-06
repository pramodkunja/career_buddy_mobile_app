import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/employer_job_applications_remote_datasource.dart';
import '../../data/employer_job_applications_repository_impl.dart';
import '../../domain/repositories/employer_job_applications_repository.dart';

final employerJobApplicationsRemoteDataSourceProvider = Provider<EmployerJobApplicationsRemoteDataSource>((ref) {
  return EmployerJobApplicationsRemoteDataSource(ref.watch(apiClientProvider));
});

final employerJobApplicationsRepositoryProvider = Provider<EmployerJobApplicationsRepository>((ref) {
  return EmployerJobApplicationsRepositoryImpl(ref.watch(employerJobApplicationsRemoteDataSourceProvider));
});
