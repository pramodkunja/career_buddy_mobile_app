import '../../../core/errors/failures.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/create_resume_state.dart';
import '../domain/repositories/create_resume_guest_draft_repository.dart';
import 'create_resume_guest_draft_local_datasource.dart';

/// Thin adapter, mirroring `ManualResumeDraftRepositoryImpl` exactly:
/// [CreateResumeGuestDraftLocalDataSource] already returns `null` for "no
/// draft" and never throws for corrupt/mismatched-schema data, so the only
/// failure this layer needs to guard against is a genuine platform/storage
/// exception.
class CreateResumeGuestDraftRepositoryImpl
    implements CreateResumeGuestDraftRepository {
  CreateResumeGuestDraftRepositoryImpl(this._localDataSource);

  final CreateResumeGuestDraftLocalDataSource _localDataSource;

  @override
  Future<Result<CreateResumeFormState?>> loadDraft() async {
    try {
      final draft = await _localDataSource.getDraft();
      return Success(draft);
    } catch (_) {
      return const Failed(
        UnexpectedFailure('Could not load the resume draft saved on this device.'),
      );
    }
  }

  @override
  Future<Result<void>> saveDraft(CreateResumeFormState form) async {
    try {
      await _localDataSource.saveDraft(form);
      return const Success(null);
    } catch (_) {
      return const Failed(
        UnexpectedFailure('Could not save the resume draft on this device.'),
      );
    }
  }

  @override
  Future<Result<void>> clearDraft() async {
    try {
      await _localDataSource.clearDraft();
      return const Success(null);
    } catch (_) {
      return const Failed(
        UnexpectedFailure('Could not clear the resume draft saved on this device.'),
      );
    }
  }
}
