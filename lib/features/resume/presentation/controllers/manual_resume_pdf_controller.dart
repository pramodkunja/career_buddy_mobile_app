import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/manual_resume_pdf_outcome.dart';
import '../../domain/validation/manual_resume_validation.dart';
import '../providers/resume_providers.dart';

/// Phase 28, Part B. Reuses the exact same temp-file-then-`open_file`
/// technique `ProtectedMediaDownloadController`
/// (`lib/core/media/protected_media_download_controller.dart`) already
/// uses for every other in-app file download — deliberately **not**
/// extended/reused directly, since that controller is GET-by-URL and keyed
/// by a `.family<..., String>` provider (one independent state per
/// resolved URL), whereas this flow is a POST with the current draft as
/// its body and there is only ever one "current" PDF at a time (a plain
/// `Notifier`, matching every other controller in this feature). The
/// `ResultType`→message mapping is intentionally duplicated rather than
/// extracted into that unrelated, already-tested file, to avoid any risk
/// to its own existing callers.
sealed class ManualResumePdfState {
  const ManualResumePdfState();
}

final class ManualResumePdfIdle extends ManualResumePdfState {
  const ManualResumePdfIdle();
}

final class ManualResumePdfGenerating extends ManualResumePdfState {
  const ManualResumePdfGenerating();
}

final class ManualResumePdfValidationFailed extends ManualResumePdfState {
  const ManualResumePdfValidationFailed(this.errors);
  final List<ManualResumeValidationError> errors;
}

final class ManualResumePdfFailed extends ManualResumePdfState {
  const ManualResumePdfFailed(this.failure);
  final Failure failure;
}

class ManualResumePdfController extends Notifier<ManualResumePdfState> {
  /// Phase 32 — see `ManualResumePreviewController._generation`'s doc
  /// comment for the full reasoning: verified directly against the
  /// installed `riverpod: 3.4.3` that invalidating a plain (non-
  /// `autoDispose`) `NotifierProvider` like this one re-runs [build] on the
  /// *same* instance rather than unmounting `ref` — so `ref.mounted` alone
  /// cannot detect "this request belongs to an account that has since
  /// logged out." Comparing the generation captured before `generateAndOpen`'s
  /// first `await` against the current one, at every subsequent resume point
  /// (including inside [_saveAndOpen]), does.
  int _generation = 0;

  @override
  ManualResumePdfState build() {
    _generation++;
    return const ManualResumePdfIdle();
  }

  /// A no-op while already generating — duplicate-submit prevention, same
  /// as every other preview/submission controller in this feature.
  Future<void> generateAndOpen(ManualResumeDraft draft) async {
    if (state is ManualResumePdfGenerating) return;
    final requestGeneration = _generation;
    state = const ManualResumePdfGenerating();

    final result = await ref.read(resumeRepositoryProvider).generateManualResumePdf(draft);
    // `ref.mounted` is kept as a defensive first check (correct and free for
    // a genuine full disposal) even though `_generation` is what actually
    // catches the real logout/account-switch case — see the doc comment
    // above. A no-op return is correct here: nothing reads this stale
    // instance again, and no file has been written yet.
    if (!ref.mounted || requestGeneration != _generation) return;
    switch (result) {
      case Failed(failure: final failure):
        state = ManualResumePdfFailed(failure);
        return;
      case Success(value: final outcome):
        switch (outcome) {
          case ManualResumePdfRejected(:final errors):
            ref.read(manualResumeBuilderControllerProvider.notifier).setServerErrors(errors);
            state = ManualResumePdfValidationFailed(errors);
            return;
          case ManualResumePdfReady(:final bytes, :final filename):
            ref.read(manualResumeBuilderControllerProvider.notifier).clearServerErrors();
            await _saveAndOpen(bytes: bytes, filename: filename, requestGeneration: requestGeneration);
        }
    }
  }

  Future<void> _saveAndOpen({
    required List<int> bytes,
    required String filename,
    required int requestGeneration,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      // Phase 32 — same generation guard as `generateAndOpen`'s own,
      // repeated after each `await` in this method: the file write and the
      // OpenFile call both yield control back to the event loop, during
      // which this controller can be invalidated (logout/account switch).
      // The file is still saved either way (a real file on disk is
      // harmless to leave behind, same as `ProtectedMediaDownloadController`'s
      // own download does) — only the subsequent `state =`/`OpenFile.open`
      // steps, which would be visible to no one, are skipped.
      if (!ref.mounted || requestGeneration != _generation) return;
      state = const ManualResumePdfIdle();
      final result = await OpenFile.open(file.path);
      if (!ref.mounted || requestGeneration != _generation) return;
      if (result.type != ResultType.done) {
        // A real, reachable case (confirmed for the identical pattern in
        // `ProtectedMediaDownloadController`): the file saved fine but this
        // device has no app registered to open a PDF.
        state = ManualResumePdfFailed(UnexpectedFailure(_openFileFailureMessage(result.type)));
      }
    } on Object {
      // Local file-save/open failure (disk, or no viewer app installed) —
      // not a network/server error, mapped through the same generic path
      // `ProtectedMediaDownloadController` uses for the identical case.
      // Guarded the same way as every other write in this method — a
      // genuine file-system exception can legitimately occur after this
      // controller has already become stale.
      if (!ref.mounted || requestGeneration != _generation) return;
      state = ManualResumePdfFailed(ExceptionMapper.map(const UnexpectedResponseException()));
    }
  }

  /// Resets to [ManualResumePdfIdle] — used after a failure is dismissed so
  /// the candidate can retry cleanly without a stale error lingering.
  void reset() {
    if (state is! ManualResumePdfGenerating) state = const ManualResumePdfIdle();
  }
}

String _openFileFailureMessage(ResultType type) => switch (type) {
  ResultType.noAppToOpen =>
    'No app installed on this device can open a PDF. Install a compatible viewer and try again.',
  ResultType.fileNotFound => 'The generated PDF could not be found.',
  ResultType.permissionDenied => 'Permission denied while trying to open the PDF.',
  _ => 'Something unexpected happened. Please try again.',
};
