import '../domain/entities/manual_resume_completeness.dart';
import '../domain/validation/manual_resume_validation.dart';

/// Small parsing primitives shared by every `manual_resume_*` response
/// parser (`preview_api`, `preview_pages_api`, `pdf_download`'s JSON error
/// branch) — factored out of the original `preview_api`-only parser (Phase
/// 27) once a second, then third, response shape needed the identical
/// `completeness`/`errors` parsing (Phase 28), rather than copying it a
/// third time.
String manualResumeString(Object? value) => value is String ? value : '';

int manualResumeInt(Object? value) => value is int ? value : (value is num ? value.toInt() : 0);

List<String> manualResumeStringList(Object? value) => value is List ? value.whereType<String>().toList() : const [];

ManualResumeCompletenessSummary? parseManualResumeCompleteness(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final rawCategories = value['categories'];
  final categories = <ManualResumeCompletenessCategory>[];
  if (rawCategories is List) {
    for (final entry in rawCategories) {
      if (entry is! Map<String, dynamic>) continue;
      categories.add(
        ManualResumeCompletenessCategory(
          key: manualResumeString(entry['key']),
          label: manualResumeString(entry['label']),
          value: manualResumeInt(entry['value']),
          optional: entry['optional'] == true,
          step: manualResumeInt(entry['step']),
        ),
      );
    }
  }
  return ManualResumeCompletenessSummary(overall: manualResumeInt(value['overall']), categories: categories);
}

List<ManualResumeValidationError> parseManualResumeErrors(Object? value) {
  if (value is! List) return const [];
  final out = <ManualResumeValidationError>[];
  for (final entry in value) {
    if (entry is! Map<String, dynamic>) continue;
    final message = entry['message'];
    if (message is! String) continue;
    out.add(
      ManualResumeValidationError(
        field: manualResumeString(entry['field']),
        step: manualResumeInt(entry['step']),
        message: message,
      ),
    );
  }
  return out;
}
