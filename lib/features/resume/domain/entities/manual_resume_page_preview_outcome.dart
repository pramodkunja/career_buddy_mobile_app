import 'dart:typed_data';

import '../validation/manual_resume_validation.dart';
import 'manual_resume_completeness.dart';

/// What a well-formed `preview_pages_api` response means, regardless of
/// its HTTP status — mirrors [ManualResumePreviewOutcome]'s own design
/// (same `_prepare()` envelope, verified directly) but kept as its own,
/// separate type: page-image preview is a distinct feature from the
/// native structured-document preview (Phase 27), with its own failure
/// modes (a page-rendering exception the document preview never has), so
/// the two are never conflated.
sealed class ManualResumePagePreviewOutcome {
  const ManualResumePagePreviewOutcome();
}

final class ManualResumePagePreviewReady extends ManualResumePagePreviewOutcome {
  const ManualResumePagePreviewReady({required this.pages, required this.total, required this.filename});

  /// Decoded PNG bytes, one per page — already validated (PNG magic bytes
  /// checked) and malformed entries dropped by the parser; never raw/
  /// unvalidated base64 by the time this reaches the UI.
  final List<Uint8List> pages;

  /// The resume's true page count (`resume_pdf.py`'s own `total`) — can
  /// exceed `pages.length` when the real PDF has more than the server's
  /// own 6-page preview cap; the UI must show both numbers honestly
  /// rather than implying `pages.length` is the whole document.
  final int total;
  final String filename;
}

final class ManualResumePagePreviewRejected extends ManualResumePagePreviewOutcome {
  const ManualResumePagePreviewRejected({required this.errors, this.completeness});

  final List<ManualResumeValidationError> errors;
  final ManualResumeCompletenessSummary? completeness;
}
