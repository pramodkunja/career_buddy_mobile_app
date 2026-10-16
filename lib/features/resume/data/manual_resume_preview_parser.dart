import '../domain/entities/manual_resume_completeness.dart';
import '../domain/entities/manual_resume_document.dart';
import '../domain/entities/manual_resume_preview_outcome.dart';
import 'manual_resume_response_parsing.dart';

String _string(Object? value) => manualResumeString(value);
List<String> _stringList(Object? value) => manualResumeStringList(value);

ManualResumeContact _parseContact(Object? value) {
  if (value is! Map<String, dynamic>) return const ManualResumeContact(text: '', href: '');
  return ManualResumeContact(text: _string(value['text']), href: _string(value['href']));
}

ManualResumeWorkItem _parseWorkItem(Map<String, dynamic> value) => ManualResumeWorkItem(
  title: _string(value['title']),
  subtitle: _string(value['subtitle']),
  location: _string(value['location']),
  dates: _string(value['dates']),
  duration: _string(value['duration']),
  bullets: _stringList(value['bullets']),
  tech: _string(value['tech']),
);

ManualResumeSkillGroup _parseSkillGroup(Map<String, dynamic> value) =>
    ManualResumeSkillGroup(label: _string(value['label']), items: _stringList(value['items']));

ManualResumeCompactItem _parseCompactItem(Map<String, dynamic> value) => ManualResumeCompactItem(
  title: _string(value['title']),
  subtitle: _string(value['subtitle']),
  dates: _string(value['dates']),
);

ManualResumeEducationItem _parseEducationItem(Map<String, dynamic> value) =>
    ManualResumeEducationItem(title: _string(value['title']), meta: _string(value['meta']));

List<T> _parseList<T>(Object? value, T Function(Map<String, dynamic>) each) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(each).toList();
}

/// One `sections[]` entry → its typed [ManualResumeSectionBody], switching
/// on `kind` exactly like the real builder's own `docHTML()` does
/// (verified directly, `landing.html:8950-8974`). An unrecognised `kind`
/// (none currently exist, but admin-extensible server code could add one)
/// degrades to [ManualResumeUnknownBody] rather than throwing — a single
/// unexpected section must never hide the rest of a real, readable preview.
ManualResumeDocumentSection? _parseSection(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final kind = value['kind'];
  if (kind is! String) return null;
  final heading = _string(value['heading']);
  final key = _string(value['key']);

  final ManualResumeSectionBody body = switch (kind) {
    'text' => ManualResumeTextBody(_string(value['text'])),
    'bullets' => ManualResumeBulletsBody(_stringList(value['items'])),
    'jobs' => ManualResumeJobsBody(_parseList(value['items'], _parseWorkItem)),
    'projects' => ManualResumeProjectsBody(_parseList(value['items'], _parseWorkItem)),
    'skills' => ManualResumeSkillsBody(_parseList(value['groups'], _parseSkillGroup)),
    'compact' => ManualResumeCompactBody(_parseList(value['items'], _parseCompactItem)),
    'education' => ManualResumeEducationBody(_parseList(value['items'], _parseEducationItem)),
    'declaration' => ManualResumeDeclarationSectionBody(
        ManualResumeDeclarationBody(
          text: _string(value['text']),
          place: _string(value['place']),
          date: _string(value['date']),
          name: _string(value['name']),
        ),
      ),
    _ => ManualResumeUnknownBody(kind),
  };

  return ManualResumeDocumentSection(key: key, heading: heading, body: body);
}

ManualResumeDocument? _parseDocument(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final rawSections = value['sections'];
  final sections = <ManualResumeDocumentSection>[];
  if (rawSections is List) {
    for (final entry in rawSections) {
      final parsed = _parseSection(entry);
      if (parsed != null) sections.add(parsed);
    }
  }
  final rawContact = value['contact'];
  final contact = rawContact is List ? rawContact.map(_parseContact).toList() : <ManualResumeContact>[];
  return ManualResumeDocument(
    name: _string(value['name']),
    title: _string(value['title']),
    contact: contact,
    level: _string(value['level']),
    levelLabel: _string(value['level_label']),
    role: _string(value['role']),
    sections: sections,
  );
}

/// Parses `preview_api`'s response body, verified directly against
/// `career_app/manual_resume_views.py`: a success body always has
/// `'ok': true` plus `document`/`warnings`/`completeness`/`filename`; every
/// rejection branch (validation failure, rate limit, unreadable payload)
/// has `'ok': false` plus `errors` (and `completeness` only for a genuine
/// validation failure). Returns `null` for anything that doesn't match
/// either shape — a malformed/unexpected response the repository maps to
/// a real failure, never silently treated as success.
ManualResumePreviewOutcome? parseManualResumePreviewResponse(dynamic body) {
  if (body is! Map<String, dynamic>) return null;
  final ok = body['ok'];
  if (ok is! bool) return null;

  if (ok) {
    final document = _parseDocument(body['document']);
    if (document == null) return null;
    return ManualResumePreviewReady(
      document: document,
      warnings: _stringList(body['warnings']),
      completeness: parseManualResumeCompleteness(body['completeness']) ?? const ManualResumeCompletenessSummary(overall: 0, categories: []),
      filename: _string(body['filename']),
    );
  }

  final errors = parseManualResumeErrors(body['errors']);
  if (errors.isEmpty) return null;
  return ManualResumePreviewRejected(errors: errors, completeness: parseManualResumeCompleteness(body['completeness']));
}
