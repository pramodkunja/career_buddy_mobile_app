import 'dart:convert';

import 'package:career_buddy_lms/features/resume/data/manual_resume_pdf_parser.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_pdf_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

final _pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, ...List.filled(20, 0)];
const _rejectedJson = '{"ok": false, "errors": [{"field": "", "step": 0, "message": "Too many requests."}]}';

void main() {
  group('looksLikePdf', () {
    test('recognises the real %PDF- magic signature', () {
      expect(looksLikePdf(_pdfBytes), isTrue);
    });

    test('rejects bytes that do not start with the signature', () {
      expect(looksLikePdf(utf8.encode('{"ok": true}')), isFalse);
    });

    test('rejects a too-short byte list', () {
      expect(looksLikePdf([0x25, 0x50]), isFalse);
    });
  });

  group('sanitizeManualResumePdfFilename', () {
    test('passes through an already-safe name, adding .pdf if missing', () {
      expect(sanitizeManualResumePdfFilename('Anita_Sharma_Resume'), 'Anita_Sharma_Resume.pdf');
    });

    test('keeps an existing .pdf extension, case-insensitively, without duplicating it', () {
      expect(sanitizeManualResumePdfFilename('resume.PDF'), 'resume.PDF');
    });

    test('strips path separators to avoid exposing directory structure', () {
      expect(sanitizeManualResumePdfFilename('../../etc/passwd'), '.._.._etc_passwd.pdf');
      expect(sanitizeManualResumePdfFilename(r'..\..\windows\system32'), '.._.._windows_system32.pdf');
    });

    test('strips control characters', () {
      expect(sanitizeManualResumePdfFilename('resume\u0000\u0007.pdf'), 'resume.pdf');
    });

    test('falls back to resume.pdf for null/empty/whitespace-only input', () {
      expect(sanitizeManualResumePdfFilename(null), 'resume.pdf');
      expect(sanitizeManualResumePdfFilename(''), 'resume.pdf');
      expect(sanitizeManualResumePdfFilename('   '), 'resume.pdf');
    });

    test('falls back to resume.pdf when sanitization empties an all-control-character name', () {
      expect(sanitizeManualResumePdfFilename('\u0000\u0001\u0002'), 'resume.pdf');
    });
  });

  group('parseManualResumePdfResponse — a genuine PDF success', () {
    test('requires both the declared content-type and the real magic signature', () {
      final outcome = parseManualResumePdfResponse(
        bytes: _pdfBytes,
        contentType: 'application/pdf',
        contentDisposition: 'attachment; filename="resume.pdf"',
      );

      expect(outcome, isA<ManualResumePdfReady>());
      expect((outcome as ManualResumePdfReady).bytes, _pdfBytes);
      expect(outcome.filename, 'resume.pdf');
    });

    test('a declared content-type without the real signature is not treated as a success', () {
      final outcome = parseManualResumePdfResponse(
        bytes: utf8.encode('not actually a pdf'),
        contentType: 'application/pdf',
      );

      expect(outcome, isNull);
    });

    test('prefers X-Resume-Filename over Content-Disposition when both are present', () {
      final outcome = parseManualResumePdfResponse(
        bytes: _pdfBytes,
        contentType: 'application/pdf',
        contentDisposition: 'attachment; filename="from-disposition.pdf"',
        xResumeFilenameHeader: 'from-header.pdf',
      );

      expect((outcome as ManualResumePdfReady).filename, 'from-header.pdf');
    });

    test('falls back to Content-Disposition when X-Resume-Filename is absent', () {
      final outcome = parseManualResumePdfResponse(
        bytes: _pdfBytes,
        contentType: 'application/pdf',
        contentDisposition: 'attachment; filename="anita.pdf"',
      );

      expect((outcome as ManualResumePdfReady).filename, 'anita.pdf');
    });

    test('falls back to the safe default filename when no filename header is present at all', () {
      final outcome = parseManualResumePdfResponse(bytes: _pdfBytes, contentType: 'application/pdf');

      expect((outcome as ManualResumePdfReady).filename, 'resume.pdf');
    });

    test('a charset suffix on the content-type header is still recognised', () {
      final outcome = parseManualResumePdfResponse(bytes: _pdfBytes, contentType: 'application/pdf; charset=binary');

      expect(outcome, isA<ManualResumePdfReady>());
    });
  });

  group('parseManualResumePdfResponse — a JSON rejection delivered through the bytes channel', () {
    test('parses a validation/rate-limit rejection even without a PDF content-type', () {
      final outcome = parseManualResumePdfResponse(
        bytes: utf8.encode(_rejectedJson),
        contentType: 'application/json',
      );

      expect(outcome, isA<ManualResumePdfRejected>());
      expect((outcome as ManualResumePdfRejected).errors.single.message, 'Too many requests.');
    });

    test('a missing content-type is still tried as a JSON rejection', () {
      final outcome = parseManualResumePdfResponse(bytes: utf8.encode(_rejectedJson), contentType: null);

      expect(outcome, isA<ManualResumePdfRejected>());
    });

    // Phase 30 (work item 4) — `pdf_download`'s own server-side PDF-
    // rendering-exception branch (`career_app/manual_resume_views.py`,
    // confirmed directly in the Phase 29 audit) returns HTTP 500 with this
    // exact message through the identical `{ok:false, errors:[...]}` JSON
    // envelope as every other rejection — delivered through the *same*
    // `ResponseType.bytes` channel a genuine PDF success also uses. This
    // parser decides success-vs-rejection purely by content-type + the real
    // `%PDF-` signature (never by status code), so a 500 JSON body must
    // parse as a rejection here exactly like a 400/429 one — never crash,
    // and never be mistaken for a corrupt PDF.
    test('a server-side PDF-rendering exception (HTTP 500) parses as a rejection, not a crash or a corrupt PDF', () {
      final body = utf8.encode(
        '{"ok": false, "errors": [{"field": "", "step": 0, '
        '"message": "The PDF could not be generated. Please try again."}]}',
      );

      final outcome = parseManualResumePdfResponse(bytes: body, contentType: 'application/json');

      expect(outcome, isA<ManualResumePdfRejected>());
      final rejected = outcome as ManualResumePdfRejected;
      expect(rejected.errors.single.message, 'The PDF could not be generated. Please try again.');
      expect(rejected.errors.single.field, '');
      expect(rejected.errors.single.step, 0);
    });
  });

  group('parseManualResumePdfResponse — malformed / unexpected responses', () {
    test('empty bytes are unparseable, never a fabricated success', () {
      expect(parseManualResumePdfResponse(bytes: const [], contentType: null), isNull);
      expect(parseManualResumePdfResponse(bytes: const [], contentType: 'application/pdf'), isNull);
    });

    test('non-JSON, non-PDF bytes are unparseable', () {
      final outcome = parseManualResumePdfResponse(bytes: utf8.encode('plain text error page'), contentType: 'text/plain');

      expect(outcome, isNull);
    });

    test('valid JSON that is not a Map is unparseable', () {
      final outcome = parseManualResumePdfResponse(bytes: utf8.encode('[1, 2, 3]'), contentType: 'application/json');

      expect(outcome, isNull);
    });

    test('ok:true JSON (never expected through this path) is unparseable, not treated as a success', () {
      final outcome = parseManualResumePdfResponse(
        bytes: utf8.encode('{"ok": true, "document": {}}'),
        contentType: 'application/json',
      );

      expect(outcome, isNull);
    });

    test('ok:false with an empty/missing errors list is unparseable', () {
      expect(
        parseManualResumePdfResponse(bytes: utf8.encode('{"ok": false}'), contentType: 'application/json'),
        isNull,
      );
      expect(
        parseManualResumePdfResponse(bytes: utf8.encode('{"ok": false, "errors": []}'), contentType: 'application/json'),
        isNull,
      );
    });
  });
}
