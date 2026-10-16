import 'dart:typed_data';

import 'create_resume_document.dart';
import 'create_resume_validation_error.dart';

/// `preview_api`'s response — **always** a well-formed document, even with
/// non-empty [errors] (confirmed directly, see
/// `ApiEndpoints.createResumePreview`'s own doc comment for the exact
/// wording in the server's source). There is no "rejected" variant for
/// this endpoint, unlike [CreateResumePdfOutcome]/[CreateResumePagePreviewOutcome]
/// below — a network/auth/server failure is still surfaced as a [Result]
/// `Failed` one layer up, this type only models a well-formed 200 response.
class CreateResumePreviewOutcome {
  const CreateResumePreviewOutcome({
    required this.document,
    required this.errors,
    required this.filename,
  });

  final CreateResumeDocument document;
  final List<CreateResumeValidationError> errors;
  final String filename;
}

/// `pdf_download`'s response — **can** genuinely reject (`_ready_state()`
/// runs full `validate()` first, confirmed directly), unlike the preview
/// endpoint above.
sealed class CreateResumePdfOutcome {
  const CreateResumePdfOutcome();
}

final class CreateResumePdfReady extends CreateResumePdfOutcome {
  const CreateResumePdfReady({required this.bytes, required this.filename});

  /// Already confirmed to start with the real `%PDF-` signature before this
  /// is ever constructed.
  final Uint8List bytes;
  final String filename;
}

final class CreateResumePdfRejected extends CreateResumePdfOutcome {
  const CreateResumePdfRejected(this.errors);
  final List<CreateResumeValidationError> errors;
}

/// `pages_api`'s response — same reject/ready split as [CreateResumePdfOutcome]
/// (confirmed directly: both call `_ready_state()`).
sealed class CreateResumePagePreviewOutcome {
  const CreateResumePagePreviewOutcome();
}

final class CreateResumePagePreviewReady
    extends CreateResumePagePreviewOutcome {
  const CreateResumePagePreviewReady({
    required this.pageImages,
    required this.totalPages,
  });

  /// Decoded PNG bytes, one per page (server sends them as `data:image/
  /// png;base64,...` strings — already decoded before this is constructed).
  final List<Uint8List> pageImages;
  final int totalPages;
}

final class CreateResumePagePreviewRejected
    extends CreateResumePagePreviewOutcome {
  const CreateResumePagePreviewRejected(this.errors);
  final List<CreateResumeValidationError> errors;
}
