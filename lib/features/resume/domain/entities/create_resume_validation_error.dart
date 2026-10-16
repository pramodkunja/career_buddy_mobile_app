/// One error from `create_resume.validate()`'s own `_err(field, section,
/// message)` shape (confirmed directly) — e.g. `{field: 'personal.email',
/// section: 'personal', message: 'Enter a valid email address...'}`. Used
/// as-is from every endpoint that returns errors (`preview`/`pages`/`pdf`/
/// `draft_save` can all 400 with this same envelope via `_bad()`), never
/// re-derived client-side — this app has no separate client-only validator
/// for Create Resume (see the Phase 39 report for why that's a deliberate
/// scope decision, not an oversight).
class CreateResumeValidationError {
  const CreateResumeValidationError({
    required this.field,
    required this.section,
    required this.message,
  });

  final String field;
  final String section;
  final String message;

  factory CreateResumeValidationError.fromJson(Map<String, dynamic> json) =>
      CreateResumeValidationError(
        field: json['field'] as String? ?? '',
        section: json['section'] as String? ?? '',
        message:
            json['message'] as String? ??
            'Something went wrong. Please try again.',
      );
}
