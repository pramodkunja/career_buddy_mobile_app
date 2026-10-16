import 'package:career_buddy_lms/features/resume/data/manual_resume_page_preview_parser.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_page_preview_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG magic bytes (0x89 'P' 'N' 'G' \r \n 0x1A \n) followed by an arbitrary
// body, base64-encoded — enough for `_looksLikePng`'s signature check
// without needing a real decodable image.
const _validPngBase64 = 'iVBORw0KGgpmYWtlLXBuZy1ib2R5';
const _validPngDataUri = 'data:image/png;base64,$_validPngBase64';

// Valid base64 that decodes to bytes NOT starting with the PNG signature.
const _notPngBase64 = 'bm90LWEtcG5nLWJvZHk=';

void main() {
  group('a successful response', () {
    test('decodes a single data-URI page and keeps total/filename', () {
      final body = {
        'ok': true,
        'pages': [_validPngDataUri],
        'total': 1,
        'filename': 'Anita_Sharma_Resume.pdf',
      };

      final outcome = parseManualResumePagePreviewResponse(body);

      expect(outcome, isA<ManualResumePagePreviewReady>());
      final ready = outcome as ManualResumePagePreviewReady;
      expect(ready.pages, hasLength(1));
      expect(ready.total, 1);
      expect(ready.filename, 'Anita_Sharma_Resume.pdf');
    });

    test('decodes multiple pages in order', () {
      final body = {
        'ok': true,
        'pages': [_validPngDataUri, _validPngDataUri, _validPngDataUri],
        'total': 3,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(3));
    });

    test('also accepts bare base64 without the data-URI prefix', () {
      final body = {
        'ok': true,
        'pages': [_validPngBase64],
        'total': 1,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(1));
    });

    test('drops an entry with malformed base64 rather than crashing', () {
      final body = {
        'ok': true,
        'pages': [_validPngDataUri, 'data:image/png;base64,not-valid-base64!!!'],
        'total': 2,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(1));
    });

    test('drops an entry whose decoded bytes do not start with the PNG signature', () {
      final body = {
        'ok': true,
        'pages': [_validPngDataUri, 'data:image/png;base64,$_notPngBase64'],
        'total': 2,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(1));
    });

    test('drops a non-string entry', () {
      final body = {
        'ok': true,
        'pages': [_validPngDataUri, 123, null, <String, dynamic>{}],
        'total': 4,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(1));
    });

    test('an empty-string entry is dropped, not treated as a decode crash', () {
      final body = {
        'ok': true,
        'pages': ['', _validPngDataUri],
        'total': 2,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(1));
    });

    test('a genuinely empty pages list is a real, valid "no pages" result, not unparseable', () {
      final body = {'ok': true, 'pages': <dynamic>[], 'total': 0, 'filename': ''};

      final outcome = parseManualResumePagePreviewResponse(body);

      expect(outcome, isA<ManualResumePagePreviewReady>());
      expect((outcome as ManualResumePagePreviewReady).pages, isEmpty);
    });

    test('total exceeding pages.length (server page cap) is preserved verbatim', () {
      final body = {
        'ok': true,
        'pages': [_validPngDataUri],
        'total': 9,
        'filename': 'resume.pdf',
      };

      final ready = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewReady;

      expect(ready.pages, hasLength(1));
      expect(ready.total, 9);
    });
  });

  group('a validation-rejection response', () {
    test('parses field/step/message errors and the accompanying completeness', () {
      final body = {
        'ok': false,
        'errors': [
          {'field': 'personal.name', 'step': 1, 'message': 'Please enter your full name.'},
        ],
        'completeness': {'overall': 20, 'categories': []},
      };

      final outcome = parseManualResumePagePreviewResponse(body);

      expect(outcome, isA<ManualResumePagePreviewRejected>());
      final rejected = outcome as ManualResumePagePreviewRejected;
      expect(rejected.errors.single.field, 'personal.name');
      expect(rejected.completeness?.overall, 20);
    });

    test('a rate-limit response (no completeness key) parses fine', () {
      final body = {
        'ok': false,
        'errors': [
          {'field': '', 'step': 0, 'message': 'Too many requests. Please wait a few minutes and try again.'},
        ],
      };

      final rejected = parseManualResumePagePreviewResponse(body) as ManualResumePagePreviewRejected;

      expect(rejected.completeness, isNull);
    });

    // Phase 30 (work item 4) — `preview_pages_api`'s own server-side
    // rendering-exception branch (`career_app/manual_resume_views.py`'s
    // `preview_pages_api`, confirmed directly in the Phase 29 audit)
    // returns HTTP 500 with this exact message, through the identical
    // `{ok:false, errors:[...]}` envelope as every other rejection — this
    // parser never looks at the HTTP status code at all (that's the
    // datasource's job, see `manual_resume_page_preview_datasource_test.dart`),
    // so it must parse this exactly like any other rejection, never as a
    // fabricated success.
    test('a server-side page-rendering exception (HTTP 500) parses as a rejection, not a success', () {
      final body = {
        'ok': false,
        'errors': [
          {'field': '', 'step': 0, 'message': 'Page preview is unavailable. Use Download PDF to view the pages.'},
        ],
      };

      final outcome = parseManualResumePagePreviewResponse(body);

      expect(outcome, isA<ManualResumePagePreviewRejected>());
      final rejected = outcome as ManualResumePagePreviewRejected;
      expect(rejected.errors.single.message, 'Page preview is unavailable. Use Download PDF to view the pages.');
      expect(rejected.errors.single.field, '');
      expect(rejected.errors.single.step, 0);
      expect(rejected.completeness, isNull);
    });
  });

  group('malformed / unexpected responses', () {
    test('a non-map body is unparseable', () {
      expect(parseManualResumePagePreviewResponse('not a map'), isNull);
      expect(parseManualResumePagePreviewResponse(null), isNull);
      expect(parseManualResumePagePreviewResponse([1, 2, 3]), isNull);
    });

    test('a missing/non-bool "ok" key is unparseable', () {
      expect(parseManualResumePagePreviewResponse({'pages': []}), isNull);
      expect(parseManualResumePagePreviewResponse({'ok': 'yes'}), isNull);
    });

    test('ok:true with a missing/malformed "pages" is unparseable, never a fabricated empty result', () {
      expect(parseManualResumePagePreviewResponse({'ok': true}), isNull);
      expect(parseManualResumePagePreviewResponse({'ok': true, 'pages': 'not a list'}), isNull);
    });

    test('ok:false with an empty/missing errors list is unparseable', () {
      expect(parseManualResumePagePreviewResponse({'ok': false}), isNull);
      expect(parseManualResumePagePreviewResponse({'ok': false, 'errors': []}), isNull);
    });
  });
}
