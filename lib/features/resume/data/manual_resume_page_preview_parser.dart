import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/manual_resume_page_preview_outcome.dart';
import 'manual_resume_response_parsing.dart';

/// PNG's own magic-number signature (`\x89PNG\r\n\x1a\n`) — confirmed
/// directly that `render_page_images` always encodes PNG
/// (`career_app/resume_pdf.py`'s own `'data:image/png;base64,'` prefix).
/// Checked before ever handing bytes to `Image.memory`, so a genuinely
/// corrupt/truncated entry is dropped here rather than surfacing as a
/// runtime image-decode crash deep in the widget tree.
const List<int> _pngMagicBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

bool _looksLikePng(Uint8List bytes) {
  if (bytes.length < _pngMagicBytes.length) return false;
  for (var i = 0; i < _pngMagicBytes.length; i++) {
    if (bytes[i] != _pngMagicBytes[i]) return false;
  }
  return true;
}

/// Decodes one `pages[]` entry — confirmed directly it is always a full
/// `data:image/png;base64,<...>` data URI, never bare base64
/// (`preview_pages_api`'s own `'data:image/png;base64,' + base64.b64encode(...)`).
/// Still defensive against a missing prefix, malformed base64, or bytes
/// that don't actually start with the PNG signature — any of those make
/// this single page `null` (dropped), never a crash or a fabricated blank
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

/// Parses `preview_pages_api`'s response body. Unlike the document
/// preview, `ok:true` with zero usable pages (every entry malformed, or a
/// genuinely empty `pages` list) is **not** treated as unparseable — it
/// is a real, meaningful "no pages available" result the screen shows
/// honestly, never silently substituted with placeholder content.
ManualResumePagePreviewOutcome? parseManualResumePagePreviewResponse(dynamic body) {
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
    return ManualResumePagePreviewReady(
      pages: pages,
      total: manualResumeInt(body['total']),
      filename: manualResumeString(body['filename']),
    );
  }

  final errors = parseManualResumeErrors(body['errors']);
  if (errors.isEmpty) return null;
  return ManualResumePagePreviewRejected(errors: errors, completeness: parseManualResumeCompleteness(body['completeness']));
}
