import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/employer_candidate_search.dart';
import '../providers/employer_candidate_search_providers.dart';

/// `jobs_app.views.search_candidates` always computes `results` — even
/// with no `q`/`location`/`experience` at all, it falls back to
/// `search_registered_candidates('', '', '')` (`jobs_app/views.py:
/// 1077-1082`), so this loads on first build the same way the web's first
/// GET does, not waiting for an explicit search.
class EmployerCandidateSearchController extends AsyncNotifier<List<EmployerCandidateSearchResult>> {
  String _query = '';
  String _location = '';
  String _experience = '';

  String get query => _query;
  String get location => _location;
  String get experience => _experience;
  bool get hasFilters => _query.isNotEmpty || _location.isNotEmpty || _experience.isNotEmpty;

  @override
  Future<List<EmployerCandidateSearchResult>> build() async {
    final result = await ref
        .read(employerCandidateSearchRepositoryProvider)
        .search(query: _query, location: _location, experience: _experience);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> search({required String query, required String location, required String experience}) async {
    _query = query;
    _location = location;
    _experience = experience;
    ref.invalidateSelf();
    await future;
  }
}

final employerCandidateSearchControllerProvider =
    AsyncNotifierProvider<EmployerCandidateSearchController, List<EmployerCandidateSearchResult>>(
      EmployerCandidateSearchController.new,
      retry: (retryCount, error) => null,
    );
