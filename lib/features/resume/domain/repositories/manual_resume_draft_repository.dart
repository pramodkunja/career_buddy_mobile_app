import '../../../../core/utils/result.dart';
import '../entities/manual_resume_draft.dart';

/// Local-only persistence for the Manual Resume Builder's draft (Phase 25)
/// — confirmed in the Phase 24 audit that the real `manual_resume_*`
/// endpoints never store anything server-side, so there is no remote
/// counterpart to this repository at all, unlike every other repository in
/// this feature. [username] namespaces each operation so one account can
/// never read or overwrite another's draft (see
/// `ManualResumeDraftLocalDataSource`'s own doc comment for exactly how).
abstract class ManualResumeDraftRepository {
  /// `null` (inside a [Success]) means "no saved draft yet" — a normal,
  /// expected first-time state, never an error. A [Failed] means the
  /// local storage layer itself could not be read (e.g. a platform/keystore
  /// failure) — genuinely different from "no draft found," and from
  /// corrupt/unsupported serialized data, which is also treated as "no
  /// draft" (`Success(null)`), never a crash or a [Failed].
  Future<Result<ManualResumeDraft?>> loadDraft(String username);

  /// Overwrites whatever draft [username] already had, if any — there is
  /// only ever one in-progress draft per account, matching the real web's
  /// own one-draft-at-a-time model (confirmed, Phase 24).
  Future<Result<void>> saveDraft(String username, ManualResumeDraft draft);

  /// Explicit, user-initiated removal only — never called automatically on
  /// logout or session expiry (see this repository's own account-isolation
  /// doc comment at the datasource level for why that distinction matters).
  Future<Result<void>> clearDraft(String username);
}
