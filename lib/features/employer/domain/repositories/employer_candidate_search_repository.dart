import '../../../../core/utils/result.dart';
import '../entities/employer_candidate_search.dart';

abstract class EmployerCandidateSearchRepository {
  Future<Result<List<EmployerCandidateSearchResult>>> search({
    String query = '',
    String location = '',
    String experience = '',
  });

  /// `jobs_app.views.download_candidates_csv` — see
  /// `EmployerCandidateSearchRemoteDataSource.downloadCsvBytes`'s doc
  /// comment.
  Future<Result<List<int>>> downloadCsvBytes({
    String query = '',
    String location = '',
    String experience = '',
  });
}
