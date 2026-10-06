import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/employer_application_detail_remote_datasource.dart';
import '../../data/employer_application_detail_repository_impl.dart';
import '../../domain/repositories/employer_application_detail_repository.dart';

final employerApplicationDetailRemoteDataSourceProvider = Provider<EmployerApplicationDetailRemoteDataSource>((ref) {
  return EmployerApplicationDetailRemoteDataSource(ref.watch(apiClientProvider));
});

final employerApplicationDetailRepositoryProvider = Provider<EmployerApplicationDetailRepository>((ref) {
  return EmployerApplicationDetailRepositoryImpl(ref.watch(employerApplicationDetailRemoteDataSourceProvider));
});
