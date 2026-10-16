import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/manual_resume_draft.dart';
import '../../domain/entities/manual_resume_page_preview_outcome.dart';
import '../../domain/validation/manual_resume_validation.dart';
import 'manual_resume_builder_controller.dart';
import '../providers/resume_providers.dart';

/// Phase 28, Part A — submits the current draft to `preview_pages_api` and
/// tracks the page-image result. Deliberately separate from both
/// [ManualResumeBuilderController] (owns the draft/local persistence) and
/// `ManualResumePreviewController` (the native structured-document preview,
/// Phase 27) — page-image preview is its own distinct feature with its own
/// failure mode (a page-rendering exception the document preview never
/// has), so a failure in one can never affect the others, and each can be
/// diagnosed independently.
sealed class ManualResumePagePreviewState {
  const ManualResumePagePreviewState();
}

final class ManualResumePagePreviewIdle extends ManualResumePagePreviewState {
  const ManualResumePagePreviewIdle();
}

final class ManualResumePagePreviewLoading extends ManualResumePagePreviewState {
  const ManualResumePagePreviewLoading();
}

final class ManualResumePagePreviewReadyState extends ManualResumePagePreviewState {
  const ManualResumePagePreviewReadyState({required this.pages, required this.total, required this.filename});
  final List<Uint8List> pages;
  final int total;
  final String filename;
}

final class ManualResumePagePreviewValidationFailed extends ManualResumePagePreviewState {
  const ManualResumePagePreviewValidationFailed(this.errors);
  final List<ManualResumeValidationError> errors;
}

final class ManualResumePagePreviewFailed extends ManualResumePagePreviewState {
  const ManualResumePagePreviewFailed(this.failure);
  final Failure failure;
}

class ManualResumePagePreviewController extends Notifier<ManualResumePagePreviewState> {
  /// Phase 32 — see `ManualResumePreviewController._generation`'s doc
  /// comment for the full reasoning: verified directly against the
  /// installed `riverpod: 3.4.3` that invalidating a plain (non-
  /// `autoDispose`) `NotifierProvider` like this one re-runs [build] on the
  /// *same* instance rather than unmounting `ref` — so `ref.mounted` alone
  /// cannot detect "this request belongs to an account that has since
  /// logged out." Comparing the generation captured before an `await`
  /// against the current one after it resolves does.
  int _generation = 0;

  @override
  ManualResumePagePreviewState build() {
    _generation++;
    return const ManualResumePagePreviewIdle();
  }

  /// A no-op while already loading — the task's explicit "prevent
  /// accidental duplicate submissions" requirement, same as the document
  /// preview controller.
  Future<void> generate(ManualResumeDraft draft) async {
    if (state is ManualResumePagePreviewLoading) return;
    final requestGeneration = _generation;
    state = const ManualResumePagePreviewLoading();
    final result = await ref.read(resumeRepositoryProvider).getManualResumePagePreview(draft);
    // `ref.mounted` is kept as a defensive first check (correct and free for
    // a genuine full disposal) even though `_generation` is what actually
    // catches the real logout/account-switch case — see the doc comment
    // above.
    if (!ref.mounted || requestGeneration != _generation) return;
    final builder = ref.read(manualResumeBuilderControllerProvider.notifier);
    switch (result) {
      case Success(value: final outcome):
        switch (outcome) {
          case ManualResumePagePreviewReady(:final pages, :final total, :final filename):
            builder.clearServerErrors();
            state = ManualResumePagePreviewReadyState(pages: pages, total: total, filename: filename);
          case ManualResumePagePreviewRejected(:final errors):
            builder.setServerErrors(errors);
            state = ManualResumePagePreviewValidationFailed(errors);
        }
      case Failed(failure: final failure):
        state = ManualResumePagePreviewFailed(failure);
    }
  }

  Future<void> retry(ManualResumeDraft draft) => generate(draft);
}
