import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/create_resume_outcomes.dart';
import 'create_resume_response_parsing.dart';

/// `%PDF-` — every real PDF file starts with this signature (same check as
/// `looksLikePdf` in `manual_resume_pdf_parser.dart`, duplicated rather than
/// imported since that file's own types are unrelated to this feature's).
const List<int> _pdfMagicBytes = [0x25, 0x50, 0x44, 0x46, 0x2D];

bool _looksLikePdf(List<int> bytes) {
  if (bytes.length < _pdfMagicBytes.length) return false;
  for (var i = 0; i < _pdfMagicBytes.length; i++) {
    if (bytes[i] != _pdfMagicBytes[i]) return false;
  }
  return true;
}

String? _filenameFromContentDisposition(String? value) {
  if (value == null) return null;
  final quoted = RegExp(r'filename="([^"]*)"').firstMatch(value);
  if (quoted != null) return quoted.group(1);
  final bare = RegExp(r'filename=([^;]+)').firstMatch(value);
  return bare?.group(1)?.trim();
}

/// Strips path separators/control characters and guarantees a `.pdf`
/// extension — a defensive floor for any string reaching this function,
/// even though `resume_filename()` is itself already ASCII-safe.
String sanitizeCreateResumePdfFilename(String? raw) {
  var name = (raw ?? '').trim();
  name = name.replaceAll(RegExp(r'[\\/]'), '_');
  name = String.fromCharCodes(name.runes.where((r) => r >= 0x20 && r != 0x7F));
  name = name.trim();
  if (name.isEmpty) return 'resume.pdf';
  if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
  return name;
}

/// Parses a `pdf_download` response — a real PDF only when **both** the
/// declared `content-type` says so **and** the bytes start with the real
/// `%PDF-` signature; otherwise tried as the `{ok:false, errors}` JSON
/// rejection envelope. `null` for anything matching neither shape.
CreateResumePdfOutcome? parseCreateResumePdfResponse({
  required List<int> bytes,
  String? contentType,
  String? contentDisposition,
  String? xResumeFilenameHeader,
}) {
  final isPdfContentType = (contentType ?? '').toLowerCase().contains(
    'application/pdf',
  );
  if (isPdfContentType && _looksLikePdf(bytes)) {
    final filename =
        (xResumeFilenameHeader != null &&
            xResumeFilenameHeader.trim().isNotEmpty)
        ? xResumeFilenameHeader
        : _filenameFromContentDisposition(contentDisposition);
    return CreateResumePdfReady(
      bytes: Uint8List.fromList(bytes),
      filename: sanitizeCreateResumePdfFilename(filename),
    );
  }

  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['ok'] != false) return null;
    final errors = parseCreateResumeErrors(decoded['errors']);
    if (errors.isEmpty) return null;
    return CreateResumePdfRejected(errors);
  } on FormatException {
    return null;
  }
}
