import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/create_resume_draft_summary.dart';
import '../providers/resume_providers.dart';

/// `AsyncNotifier` — same reasoning as `ResumeHistoryController`: nothing
/// here needs a bespoke state machine beyond loading/data/error/retry, and
/// [deleteDraft] reuses [AsyncValue.guard] to re-fetch the authoritative
/// list after a successful delete rather than optimistically removing the
/// row itself, so a delete that actually failed server-side never leaves
/// the list showing something that isn't true.
///
/// This screen's route requires authentication already (not in
/// `publicRoutes`/`universalRoutes`); if a session expires while this
/// screen is open, `drafts_list`'s own 401 surfaces as `UnauthorizedFailure`
/// like any other authenticated call in this app, shown via the existing
/// `AppErrorView`/retry — no bespoke "please sign in again" handling is
/// added here beyond what every other authenticated list screen already
/// does.
class CreateResumeDraftsController
    extends AsyncNotifier<List<CreateResumeDraftSummary>> {
  @override
  Future<List<CreateResumeDraftSummary>> build() async {
    final result = await ref.read(createResumeRepositoryProvider).listDrafts();
    return switch (result) {
      Success(value: final drafts) => drafts,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  /// Returns `true` on success. The caller (the screen) is responsible for
  /// the confirmation dialog before calling this — matches this app's
  /// existing "confirm, then act" convention (e.g.
  /// `confirmRemoveEntry`/`ProtectedMediaDownloadController`'s own callers).
  Future<bool> deleteDraft(int id) async {
    final result = await ref
        .read(createResumeRepositoryProvider)
        .deleteDraft(id);
    if (result is Failed) return false;
    ref.invalidateSelf();
    await future;
    return true;
  }
}
