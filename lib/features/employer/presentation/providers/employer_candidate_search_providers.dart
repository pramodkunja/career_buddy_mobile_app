import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/employer_candidate_search_remote_datasource.dart';
import '../../data/employer_candidate_search_repository_impl.dart';
import '../../domain/repositories/employer_candidate_search_repository.dart';

final employerCandidateSearchRemoteDataSourceProvider = Provider<EmployerCandidateSearchRemoteDataSource>((ref) {
  return EmployerCandidateSearchRemoteDataSource(ref.watch(apiClientProvider));
});

final employerCandidateSearchRepositoryProvider = Provider<EmployerCandidateSearchRepository>((ref) {
  return EmployerCandidateSearchRepositoryImpl(ref.watch(employerCandidateSearchRemoteDataSourceProvider));
});
