import '../../../../core/utils/result.dart';
import '../entities/employer_candidate_search.dart';

abstract class EmployerCandidateSearchRepository {
  Future<Result<List<EmployerCandidateSearchResult>>> search({
    String query = '',
    String location = '',
    String experience = '',
  });
}
