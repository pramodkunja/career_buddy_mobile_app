import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/manual_resume_pdf_outcome.dart';
import 'manual_resume_response_parsing.dart';

/// `%PDF-` — every real PDF file starts with this signature. Checked
/// before ever treating a response as a successful PDF, so a response
/// that merely claims `content-type: application/pdf` but isn't actually
/// one (a misconfigured proxy, a truncated body) is never handed to the
/// file-save/open flow as if it were real.
const List<int> _pdfMagicBytes = [0x25, 0x50, 0x44, 0x46, 0x2D];

bool looksLikePdf(List<int> bytes) {
  if (bytes.length < _pdfMagicBytes.length) return false;
  for (var i = 0; i < _pdfMagicBytes.length; i++) {
    if (bytes[i] != _pdfMagicBytes[i]) return false;
  }
  return true;
}

/// Extracts `filename="..."` (or an unquoted `filename=...`) from a
/// `Content-Disposition` header value — matches
/// `response['Content-Disposition'] = f'{"inline"|"attachment"}; filename="{filename}"'`
/// (confirmed directly, `career_app/manual_resume_views.py:154`).
String? _filenameFromContentDisposition(String? value) {
  if (value == null) return null;
  final quoted = RegExp(r'filename="([^"]*)"').firstMatch(value);
  if (quoted != null) return quoted.group(1);
  final bare = RegExp(r'filename=([^;]+)').firstMatch(value);
  return bare?.group(1)?.trim();
}

/// Strips path separators and control characters a server-provided name
/// could (in principle) carry, and guarantees a `.pdf` extension — never
/// trusts the raw header value as a safe on-disk filename outright, even
/// though `resume_filename()` is itself confirmed ASCII-safe
/// (`[A-Za-z0-9_]` only, `resume_document.py:665-672`); this sanitization
/// is a defensive floor for *any* string reaching this function, not a
/// comment on that function's own correctness.
String sanitizeManualResumePdfFilename(String? raw) {
  var name = (raw ?? '').trim();
  name = name.replaceAll(RegExp(r'[\\/]'), '_');
  name = String.fromCharCodes(name.runes.where((r) => r >= 0x20 && r != 0x7F));
  name = name.trim();
  if (name.isEmpty) return 'resume.pdf';
  if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
  return name;
}

/// Parses a `pdf_download` response. [bytes] must already be the raw
/// response body (however the caller obtained it — `ResponseType.bytes`
/// is the datasource's own choice). A response is only ever treated as a
/// real PDF when **both** its declared `content-type` says so **and** its
/// own bytes start with the real `%PDF-` signature (see [looksLikePdf]) —
/// confirmed directly this app never attempts to parse PDF bytes as JSON
/// on a genuine success. Anything else is tried as the JSON rejection
/// envelope every other `manual_resume_*` endpoint uses; a response that
/// matches neither shape returns `null` (an unparseable/unexpected
/// response), which the repository maps to a real failure.
ManualResumePdfOutcome? parseManualResumePdfResponse({
  required List<int> bytes,
  String? contentType,
  String? contentDisposition,
  String? xResumeFilenameHeader,
}) {
  final isPdfContentType = (contentType ?? '').toLowerCase().contains('application/pdf');
  if (isPdfContentType && looksLikePdf(bytes)) {
    final filename = (xResumeFilenameHeader != null && xResumeFilenameHeader.trim().isNotEmpty)
        ? xResumeFilenameHeader
        : _filenameFromContentDisposition(contentDisposition);
    return ManualResumePdfReady(
      bytes: Uint8List.fromList(bytes),
      filename: sanitizeManualResumePdfFilename(filename),
    );
  }

  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) return null;
    final ok = decoded['ok'];
    if (ok != false) return null;
    final errors = parseManualResumeErrors(decoded['errors']);
    if (errors.isEmpty) return null;
    return ManualResumePdfRejected(errors);
  } on FormatException {
    return null;
  }
}
