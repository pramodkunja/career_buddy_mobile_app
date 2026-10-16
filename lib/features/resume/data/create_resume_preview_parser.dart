import '../domain/entities/create_resume_outcomes.dart';
import 'create_resume_response_parsing.dart';

/// Parses `preview_api`'s response body. Confirmed directly
/// (`career_app/create_resume_views.py:65-75`): every well-formed response
/// here has `'ok': true` — this endpoint never returns the `{ok:false,
/// errors}` rejection envelope its siblings ([createResumePdf]/
/// [createResumePages]) can. Returns `null` for anything that doesn't match
/// the expected shape (the repository maps that to a real failure, never
/// silent success).
CreateResumePreviewOutcome? parseCreateResumePreviewResponse(dynamic body) {
  if (body is! Map<String, dynamic>) return null;
  if (body['ok'] != true) return null;
  final document = parseCreateResumeDocument(body['document']);
  if (document == null) return null;
  return CreateResumePreviewOutcome(
    document: document,
    errors: parseCreateResumeErrors(body['errors']),
    filename: createResumeString(body['filename']),
  );
}
