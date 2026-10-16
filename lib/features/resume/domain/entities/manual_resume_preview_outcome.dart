import '../validation/manual_resume_validation.dart';
import 'manual_resume_completeness.dart';
import 'manual_resume_document.dart';

/// What a well-formed `preview_api` response means, regardless of its HTTP
/// status — confirmed directly that a validation failure, a rate-limit
/// hit, and an unreadable-payload rejection all share the exact same
/// `{ok:false, errors:[{field,step,message}], completeness?}` envelope
/// (`career_app/manual_resume_views.py`'s `_prepare()`), just with
/// different HTTP status codes (400/429/400) and `completeness` only
/// present for a genuine validation failure. This type unifies all three
/// as [ManualResumePreviewRejected] — a real, meaningful, user-facing
/// response, never an exception — so the UI shows whatever message the
/// server actually sent either way. [ManualResumeValidationError] (Phase
/// 26's own client-side validator) is reused verbatim here since the
/// server's own error shape is identical, letting a server error jump to
/// the same step/field machinery a client-side error already does.
sealed class ManualResumePreviewOutcome {
  const ManualResumePreviewOutcome();
}

final class ManualResumePreviewReady extends ManualResumePreviewOutcome {
  const ManualResumePreviewReady({
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

final class ManualResumePreviewRejected extends ManualResumePreviewOutcome {
  const ManualResumePreviewRejected({required this.errors, this.completeness});

  final List<ManualResumeValidationError> errors;

  /// `null` for the rate-limit/unreadable-payload branches, which never
  /// include it (confirmed directly) — distinct from an empty summary.
  final ManualResumeCompletenessSummary? completeness;
}
