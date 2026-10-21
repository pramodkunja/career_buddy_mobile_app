import '../../../../core/utils/result.dart';
import '../entities/create_resume_state.dart';

/// Phase 42. Local-only persistence for a Create Resume draft started
/// before signing in — the guest-save counterpart to
/// `CreateResumeRepository`, which only ever reaches the real server and
/// explicitly has no local-only path of its own. Kept as a separate
/// interface (mirroring `ManualResumeDraftRepository`'s own separation from
/// the server-backed resume repositories) so a guest draft can never be
/// confused with, or silently promoted into, a real saved server draft.
abstract class CreateResumeGuestDraftRepository {
  /// `null` (inside a [Success]) means "no saved guest draft yet" — a
  /// normal, expected state, never an error. A [Failed] means the local
  /// storage layer itself could not be read.
  Future<Result<CreateResumeFormState?>> loadDraft();

  /// Overwrites whatever guest draft this device already had, if any.
  Future<Result<void>> saveDraft(CreateResumeFormState form);

  Future<Result<void>> clearDraft();
}
