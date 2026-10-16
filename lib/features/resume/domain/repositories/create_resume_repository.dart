import '../../../../core/utils/result.dart';
import '../entities/create_resume_draft_summary.dart';
import '../entities/create_resume_outcomes.dart';
import '../entities/create_resume_state.dart';

/// Phase 39 — the free-form Create Resume builder's real, server-backed
/// contract (`career_app/create_resume_views.py`). Distinct from
/// `ManualResumeDraftRepository`: every method here reaches a real endpoint,
/// there is no local-only persistence, and draft methods require the caller
/// to already be authenticated (the route this screen lives behind is not
/// in `publicRoutes`/`universalRoutes` — see `CreateResumeDraftsController`'s
/// own doc comment for what happens if a session expires mid-screen anyway).
abstract class CreateResumeRepository {
  Future<Result<CreateResumePreviewOutcome>> preview(
    CreateResumeFormState state,
  );

  Future<Result<CreateResumePagePreviewOutcome>> pagePreview(
    CreateResumeFormState state,
  );

  Future<Result<CreateResumePdfOutcome>> generatePdf(
    CreateResumeFormState state,
  );

  /// Every saved draft belonging to the signed-in account, newest first
  /// (matches `ResumeDraft.Meta.ordering`, confirmed directly).
  Future<Result<List<CreateResumeDraftSummary>>> listDrafts();

  /// The full form state for one saved draft — `NotFoundFailure` for an id
  /// that doesn't exist or belongs to another account (the server answers
  /// both cases identically, confirmed directly: `get_object_or_404(...,
  /// user=request.user)`).
  Future<Result<CreateResumeFormState>> loadDraft(int id);

  /// Creates a new draft when [state]'s own `draftId` is `null`, otherwise
  /// updates that existing draft. Returns the saved draft's id (unchanged
  /// from [state].draftId on an update) so the caller can record it for
  /// every subsequent save.
  Future<Result<int>> saveDraft(CreateResumeFormState state);

  Future<Result<void>> deleteDraft(int id);
}
