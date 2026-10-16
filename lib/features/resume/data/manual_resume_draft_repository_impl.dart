import '../../../core/errors/failures.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/manual_resume_draft.dart';
import '../domain/repositories/manual_resume_draft_repository.dart';
import 'manual_resume_draft_local_datasource.dart';

/// Thin adapter: [ManualResumeDraftLocalDataSource] already returns `null`
/// for "no draft" and never throws for corrupt/mismatched-schema data (it
/// treats both as "no draft" itself). The only failure this layer needs to
/// guard against is a genuine platform/storage exception (e.g. the keystore
/// itself being unavailable) — anything else is a bug, not a [Failure].
class ManualResumeDraftRepositoryImpl implements ManualResumeDraftRepository {
  ManualResumeDraftRepositoryImpl(this._localDataSource);

  final ManualResumeDraftLocalDataSource _localDataSource;

  @override
  Future<Result<ManualResumeDraft?>> loadDraft(String username) async {
    try {
      final draft = await _localDataSource.getDraft(username);
      return Success(draft);
    } catch (_) {
      return const Failed(UnexpectedFailure('Could not load your saved resume draft.'));
    }
  }

  @override
  Future<Result<void>> saveDraft(String username, ManualResumeDraft draft) async {
    try {
      await _localDataSource.saveDraft(username, draft);
      return const Success(null);
    } catch (_) {
      return const Failed(UnexpectedFailure('Could not save your resume draft.'));
    }
  }

  @override
  Future<Result<void>> clearDraft(String username) async {
    try {
      await _localDataSource.clearDraft(username);
      return const Success(null);
    } catch (_) {
      return const Failed(UnexpectedFailure('Could not clear your resume draft.'));
    }
  }
}
