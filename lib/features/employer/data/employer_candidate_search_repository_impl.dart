import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/employer_candidate_search.dart';
import '../domain/repositories/employer_candidate_search_repository.dart';
import 'employer_candidate_search_remote_datasource.dart';

class EmployerCandidateSearchRepositoryImpl implements EmployerCandidateSearchRepository {
  EmployerCandidateSearchRepositoryImpl(this._remote);

  final EmployerCandidateSearchRemoteDataSource _remote;

  @override
  Future<Result<List<EmployerCandidateSearchResult>>> search({
    String query = '',
    String location = '',
    String experience = '',
  }) async {
    try {
      return Success(await _remote.search(query: query, location: location, experience: experience));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<List<int>>> downloadCsvBytes({
    String query = '',
    String location = '',
    String experience = '',
  }) async {
    try {
      return Success(await _remote.downloadCsvBytes(query: query, location: location, experience: experience));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
