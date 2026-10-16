import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/manual_resume_completeness.dart';
import '../../domain/entities/manual_resume_document.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/manual_resume_preview_outcome.dart';
import '../../domain/validation/manual_resume_validation.dart';
import 'manual_resume_builder_controller.dart';
import '../providers/resume_providers.dart';

/// Phase 27 — submits the current [ManualResumeDraft] to `preview_api` and
/// tracks the result. Deliberately a **separate** controller from
/// [ManualResumeBuilderController] (which owns the draft itself and its
/// local persistence) — the preview is a one-shot, read-only submission
/// that never mutates the draft; keeping it separate means a preview
/// failure can never put the draft/autosave state machine at risk, and
/// vice versa.
sealed class ManualResumePreviewState {
  const ManualResumePreviewState();
}

final class ManualResumePreviewIdle extends ManualResumePreviewState {
  const ManualResumePreviewIdle();
}

final class ManualResumePreviewLoading extends ManualResumePreviewState {
  const ManualResumePreviewLoading();
}

final class ManualResumePreviewReadyState extends ManualResumePreviewState {
  const ManualResumePreviewReadyState({
    required this.document,
    required this.warnings,
    required this.completeness,
    required this.filename,
  });

  final ManualResumeDocument document;
  final List<String> warnings;
  final ManualResumeCompletenessSummary completeness;
  final String filename;
}

/// The server rejected the submission (a genuine validation failure, a
/// rate-limit hit, or an unreadable payload — all three share the same
/// response envelope, see [ManualResumePreviewRejected]'s own doc
/// comment). Never a crash and never a fabricated success.
final class ManualResumePreviewValidationFailed extends ManualResumePreviewState {
  const ManualResumePreviewValidationFailed(this.errors);
  final List<ManualResumeValidationError> errors;
}

/// A genuine transport/server failure (network, timeout, 5xx, or a
/// response that matched neither known shape at all).
final class ManualResumePreviewFailed extends ManualResumePreviewState {
  const ManualResumePreviewFailed(this.failure);
  final Failure failure;
}

class ManualResumePreviewController extends Notifier<ManualResumePreviewState> {
  /// Phase 32 — incremented every time [build] runs, including on a manual
  /// `ref.invalidate()`/`container.invalidate()` (e.g.
  /// `AuthController._invalidateUserScopedProviders()` on logout/account
  /// switch). **Verified directly against the installed `riverpod: 3.4.3`**
  /// that, for a plain (non-`autoDispose`) `NotifierProvider` like this one,
  /// invalidation does *not* unmount `ref` or replace this `Notifier`
  /// instance — it re-runs [build] on the very same object, so `ref.mounted`
  /// stays `true` throughout and can never detect this case (confirmed with
  /// a disposable diagnostic test before writing this fix: `ref.mounted`
  /// printed `true` even after `container.invalidate(...)` immediately
  /// followed by a read that already showed the freshly-rebuilt idle
  /// state — the Phase 31 report's assumption that invalidation disposes
  /// the instance does not hold for this provider shape). Comparing the
  /// generation captured before an `await` against the current one after it
  /// resolves is what actually detects "this request belongs to an account
  /// that has since been logged out of," regardless of object identity.
  int _generation = 0;

  @override
  ManualResumePreviewState build() {
    _generation++;
    return const ManualResumePreviewIdle();
  }

  /// Submits [draft] for preview. A no-op while already loading — the
  /// task's explicit "prevent accidental duplicate submissions" requirement
  /// — rather than queuing or racing a second request.
  Future<void> generate(ManualResumeDraft draft) async {
    if (state is ManualResumePreviewLoading) return;
    final requestGeneration = _generation;
    state = const ManualResumePreviewLoading();
    final result = await ref.read(resumeRepositoryProvider).previewManualResume(draft);
    // `ref.mounted` is kept as a defensive first check (correct and free for
    // a genuine full disposal, e.g. the whole `ProviderContainer` going
    // away) even though — per the doc comment above — it is not what
    // catches the logout/account-switch case; `_generation` is what does.
    if (!ref.mounted || requestGeneration != _generation) return;
    final builder = ref.read(manualResumeBuilderControllerProvider.notifier);
    switch (result) {
      case Success(value: final outcome):
        switch (outcome) {
          case ManualResumePreviewReady(:final document, :final warnings, :final completeness, :final filename):
            builder.clearServerErrors();
            state = ManualResumePreviewReadyState(
              document: document,
              warnings: warnings,
              completeness: completeness,
              filename: filename,
            );
          case ManualResumePreviewRejected(:final errors):
            // Fed into the Builder immediately (not only when the candidate
            // taps a specific "fix this" action) so returning from this
            // screen by any means — a targeted action or the plain back
            // button — already shows the right step with the right fields
            // flagged.
            builder.setServerErrors(errors);
            state = ManualResumePreviewValidationFailed(errors);
        }
      case Failed(failure: final failure):
        state = ManualResumePreviewFailed(failure);
    }
  }

  /// Resubmits the same draft after a transport failure or to refresh a
  /// stale result — the screen always has the draft snapshot it was opened
  /// with (it has no editing capability itself), so a retry is simply
  /// calling [generate] again.
  Future<void> retry(ManualResumeDraft draft) => generate(draft);
}
