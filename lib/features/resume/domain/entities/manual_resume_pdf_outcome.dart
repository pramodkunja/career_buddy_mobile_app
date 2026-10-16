import 'dart:typed_data';

import '../validation/manual_resume_validation.dart';

/// What a well-formed `pdf_download` response means. Confirmed directly
/// that, for a JSON request (this app always sends one — see
/// `ResumeRemoteDataSource.generateManualResumePdf`'s own doc comment), a
/// validation/rate-limit/unreadable-payload failure comes back as the same
/// `{ok:false, errors:[...]}` JSON envelope every other `manual_resume_*`
/// endpoint uses — the real view's plain-text error branch only fires for
/// the web's own non-JSON Print-button form POST, never for this client.
/// `errors` is reused from [ManualResumeValidationError] verbatim, same as
/// the other two preview outcomes.
sealed class ManualResumePdfOutcome {
  const ManualResumePdfOutcome();
}

final class ManualResumePdfReady extends ManualResumePdfOutcome {
  const ManualResumePdfReady({required this.bytes, required this.filename});

  /// Raw PDF bytes — already confirmed to start with the real `%PDF-`
  /// signature by the parser before this is ever constructed.
  final Uint8List bytes;

  /// Already sanitized (no path separators/control characters) and
  /// guaranteed to end in `.pdf` — safe to use directly as a file name.
  final String filename;
}

final class ManualResumePdfRejected extends ManualResumePdfOutcome {
  const ManualResumePdfRejected(this.errors);
  final List<ManualResumeValidationError> errors;
}
