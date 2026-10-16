import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/create_resume_outcomes.dart';
import 'create_resume_response_parsing.dart';

const List<int> _pngMagicBytes = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];

bool _looksLikePng(Uint8List bytes) {
  if (bytes.length < _pngMagicBytes.length) return false;
  for (var i = 0; i < _pngMagicBytes.length; i++) {
    if (bytes[i] != _pngMagicBytes[i]) return false;
  }
  return true;
}

/// Decodes one `pages[]` entry — confirmed directly always a full
/// `data:image/png;base64,<...>` data URI (`pages_api`'s own
/// `'data:image/png;base64,' + base64.b64encode(...)`). Defensive against a
/// malformed entry: dropped (`null`), never a crash or a fabricated blank
/// image standing in for it.
Uint8List? _decodePageImage(Object? value) {
  if (value is! String) return null;
  final commaIndex = value.indexOf(',');
  final body = commaIndex == -1 ? value : value.substring(commaIndex + 1);
  if (body.isEmpty) return null;
  try {
    final bytes = base64Decode(body);
    return _looksLikePng(bytes) ? bytes : null;
  } on FormatException {
    return null;
  }
}

int _int(Object? value) =>
    value is int ? value : (value is num ? value.toInt() : 0);

/// Parses `pages_api`'s response body — a genuine `{ok:true, pages:[],
/// total:0}` (no usable pages) is a real, meaningful result shown honestly,
/// never substituted with placeholder content.
CreateResumePagePreviewOutcome? parseCreateResumePagePreviewResponse(
  dynamic body,
) {
  if (body is! Map<String, dynamic>) return null;
  final ok = body['ok'];
  if (ok is! bool) return null;

  if (ok) {
    final rawPages = body['pages'];
    if (rawPages is! List) return null;
    final pages = <Uint8List>[];
    for (final entry in rawPages) {
      final decoded = _decodePageImage(entry);
      if (decoded != null) pages.add(decoded);
    }
    return CreateResumePagePreviewReady(
      pageImages: pages,
      totalPages: _int(body['total']),
    );
  }

  final errors = parseCreateResumeErrors(body['errors']);
  if (errors.isEmpty) return null;
  return CreateResumePagePreviewRejected(errors);
}
