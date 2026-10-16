import '../domain/entities/create_resume_document.dart';
import '../domain/entities/create_resume_validation_error.dart';

/// Shared parsing primitives for every `create_resume_*` response — same
/// posture as `manual_resume_response_parsing.dart`: defensive, never
/// throws on an unexpected shape, degrades to an empty/blank value instead.
String createResumeString(Object? value) => value is String ? value : '';

List<String> createResumeStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

List<CreateResumeValidationError> parseCreateResumeErrors(Object? value) {
  if (value is! List) return const [];
  final out = <CreateResumeValidationError>[];
  for (final entry in value) {
    if (entry is! Map<String, dynamic>) continue;
    final message = entry['message'];
    if (message is! String || message.isEmpty) continue;
    out.add(CreateResumeValidationError.fromJson(entry));
  }
  return out;
}

CreateResumeLink? _parseLink(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final href = createResumeString(value['href']);
  if (href.isEmpty) return null;
  return CreateResumeLink(text: createResumeString(value['text']), href: href);
}

CreateResumeContact _parseContact(Object? value) {
  if (value is! Map<String, dynamic>) {
    return const CreateResumeContact(text: '', href: '');
  }
  return CreateResumeContact(
    text: createResumeString(value['text']),
    href: createResumeString(value['href']),
  );
}

CreateResumeNote _parseNote(Map<String, dynamic> value) => CreateResumeNote(
  label: createResumeString(value['label']),
  text: createResumeString(value['text']),
);

CreateResumeBulletGroup _parseGroup(Map<String, dynamic> value) =>
    CreateResumeBulletGroup(
      label: createResumeString(value['label']),
      bullets: createResumeStringList(value['bullets']),
    );

List<T> _parseList<T>(Object? value, T Function(Map<String, dynamic>) each) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(each).toList();
}

CreateResumeEntryItem _parseEntryItem(Map<String, dynamic> value) =>
    CreateResumeEntryItem(
      title: createResumeString(value['title']),
      subtitle: createResumeString(value['subtitle']),
      meta: createResumeString(value['meta']),
      link: _parseLink(value['link']),
      paragraphs: createResumeStringList(value['paragraphs']),
      bullets: createResumeStringList(value['bullets']),
      groups: _parseList(value['groups'], _parseGroup),
      notes: _parseList(value['notes'], _parseNote),
    );

CreateResumeCompactItem _parseCompactItem(Map<String, dynamic> value) =>
    CreateResumeCompactItem(
      title: createResumeString(value['title']),
      text: createResumeString(value['text']),
      detail: createResumeString(value['detail']),
      link: _parseLink(value['link']),
    );

CreateResumeLineItem _parseLineItem(Map<String, dynamic> value) =>
    CreateResumeLineItem(
      label: createResumeString(value['label']),
      text: createResumeString(value['text']),
    );

/// One `sections[]` entry → its typed [CreateResumeSectionBody], switching
/// on `kind` exactly like `build_document()` tags each section (confirmed
/// directly). An unrecognised `kind` degrades to [CreateResumeUnknownBody]
/// rather than throwing.
CreateResumeDocumentSection? _parseSection(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final kind = value['kind'];
  if (kind is! String) return null;
  final heading = createResumeString(value['heading']);
  final key = createResumeString(value['key']);

  final CreateResumeSectionBody body = switch (kind) {
    'text' => CreateResumeTextBody(createResumeString(value['text'])),
    'lines' => CreateResumeLinesBody(
      _parseList(value['items'], _parseLineItem),
    ),
    'entries' => CreateResumeEntriesBody(
      _parseList(value['items'], _parseEntryItem),
    ),
    'items' => CreateResumeItemsBody(
      _parseList(value['items'], _parseCompactItem),
    ),
    _ => CreateResumeUnknownBody(kind),
  };

  return CreateResumeDocumentSection(key: key, heading: heading, body: body);
}

CreateResumeDocument? parseCreateResumeDocument(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final rawSections = value['sections'];
  final sections = <CreateResumeDocumentSection>[];
  if (rawSections is List) {
    for (final entry in rawSections) {
      final parsed = _parseSection(entry);
      if (parsed != null) sections.add(parsed);
    }
  }
  final rawContact = value['contact'];
  final contact = rawContact is List
      ? rawContact.map(_parseContact).toList()
      : <CreateResumeContact>[];
  final rawLinks = value['links'];
  final links = <CreateResumeLink>[];
  if (rawLinks is List) {
    for (final entry in rawLinks) {
      final link = _parseLink(entry);
      if (link != null) links.add(link);
    }
  }
  return CreateResumeDocument(
    template: createResumeString(value['template']),
    name: createResumeString(value['name']),
    title: createResumeString(value['title']),
    contact: contact,
    links: links,
    address: createResumeString(value['address']),
    sections: sections,
  );
}
