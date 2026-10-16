import 'dart:convert';

import 'package:career_buddy_lms/features/resume/data/create_resume_pdf_parser.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_outcomes.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _jsonBody(Map<String, dynamic> body) => utf8.encode(jsonEncode(body));

void main() {
  group('parseCreateResumePdfResponse', () {
    test(
      'a real PDF (content-type + %PDF- signature) parses as CreateResumePdfReady',
      () {
        final bytes = [
          0x25,
          0x50,
          0x44,
          0x46,
          0x2D,
          0x31,
          0x2E,
          0x34,
        ]; // "%PDF-1.4"
        final outcome = parseCreateResumePdfResponse(
          bytes: bytes,
          contentType: 'application/pdf',
          contentDisposition: 'attachment; filename="Asha_Rao_Resume.pdf"',
          xResumeFilenameHeader: null,
        );

        expect(outcome, isA<CreateResumePdfReady>());
        expect(
          (outcome as CreateResumePdfReady).filename,
          'Asha_Rao_Resume.pdf',
        );
        expect(outcome.bytes, bytes);
      },
    );

    test(
      'the X-Resume-Filename header takes priority over Content-Disposition when both are present',
      () {
        final bytes = [0x25, 0x50, 0x44, 0x46, 0x2D];
        final outcome = parseCreateResumePdfResponse(
          bytes: bytes,
          contentType: 'application/pdf',
          contentDisposition: 'attachment; filename="from-disposition.pdf"',
          xResumeFilenameHeader: 'from-header.pdf',
        );
        expect((outcome as CreateResumePdfReady).filename, 'from-header.pdf');
      },
    );

    test(
      'a claimed PDF content-type whose bytes don\'t start with %PDF- is never treated as a real PDF',
      () {
        final outcome = parseCreateResumePdfResponse(
          bytes: _jsonBody({
            'ok': false,
            'errors': [
              {
                'field': '',
                'section': '',
                'message': 'The PDF could not be generated. Please try again.',
              },
            ],
          }),
          contentType: 'application/pdf',
        );
        expect(outcome, isA<CreateResumePdfRejected>());
      },
    );

    test(
      'a validation rejection (HTTP 400, ok:false) parses as CreateResumePdfRejected with the real errors',
      () {
        final outcome = parseCreateResumePdfResponse(
          bytes: _jsonBody({
            'ok': false,
            'errors': [
              {
                'field': 'personal.name',
                'section': 'personal',
                'message': 'Please enter your full name.',
              },
              {
                'field': 'experience.0.company',
                'section': 'experience',
                'message': 'Company name is required.',
              },
            ],
          }),
          contentType: 'application/json',
        );

        expect(outcome, isA<CreateResumePdfRejected>());
        final errors = (outcome as CreateResumePdfRejected).errors;
        expect(errors, hasLength(2));
        expect(errors.first.field, 'personal.name');
      },
    );

    test(
      'returns null for an unparseable body that is neither a real PDF nor valid JSON',
      () {
        final outcome = parseCreateResumePdfResponse(
          bytes: [0xFF, 0xFE, 0x00],
          contentType: 'text/plain',
        );
        expect(outcome, isNull);
      },
    );

    test(
      'returns null for a well-formed JSON body that is not the expected {ok:false, errors} rejection shape',
      () {
        final outcome = parseCreateResumePdfResponse(
          bytes: _jsonBody({'ok': true}),
          contentType: 'application/json',
        );
        expect(outcome, isNull);
      },
    );
  });
}
