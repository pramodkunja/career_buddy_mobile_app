import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/resume/data/manual_resume_preview_payload.dart';
import 'package:career_buddy_lms/features/resume/data/resume_remote_datasource.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_pdf_outcome.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final _pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, ...List.filled(20, 0)];

/// Same per-file private adapter convention as the other
/// `manual_resume_*_datasource_test.dart` files — a GET first (CSRF
/// priming), then whatever bytes/headers the test configures on the POST,
/// which `generateManualResumePdf` always requests as `ResponseType.bytes`
/// regardless of whether the real body turns out to be a PDF or a JSON
/// rejection (confirmed directly, same bytes channel either way).
class _BytesPostAdapter implements HttpClientAdapter {
  _BytesPostAdapter({
    required this.postStatusCode,
    required this.postBodyBytes,
    this.postHeaders = const {},
    this.onPostRequest,
  });

  final int postStatusCode;
  final List<int> postBodyBytes;
  final Map<String, List<String>> postHeaders;
  final void Function(RequestOptions options)? onPostRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString('', 200);
    }
    onPostRequest?.call(options);
    return ResponseBody(Stream.value(Uint8List.fromList(postBodyBytes)), postStatusCode, headers: postHeaders);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('generateManualResumePdf — request shape', () {
    test('reuses the existing CSRF-priming pattern: a GET first, then a JSON POST with X-CSRFToken', () async {
      RequestOptions? capturedPost;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 200,
          postBodyBytes: _pdfBytes,
          postHeaders: const {
            'content-type': ['application/pdf'],
          },
          onPostRequest: (options) => capturedPost = options,
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.generateManualResumePdf(ManualResumeDraft.blank());

      expect(capturedPost, isNotNull);
      expect(capturedPost!.path, '/resume-builder/manual/pdf/');
      expect(capturedPost!.headers.containsKey('X-CSRFToken'), isTrue);
      expect(capturedPost!.contentType, contains('application/json'));
    });

    test('sends the exact same snake_case payload as the document/page previews', () async {
      RequestOptions? capturedPost;
      final draft = ManualResumeDraft.blank().copyWith(targetTitle: 'Senior QA Engineer');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 200,
          postBodyBytes: _pdfBytes,
          postHeaders: const {
            'content-type': ['application/pdf'],
          },
          onPostRequest: (options) => capturedPost = options,
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.generateManualResumePdf(draft);

      expect(capturedPost!.data, toManualResumePreviewPayload(draft));
    });
  });

  group('generateManualResumePdf — response handling', () {
    test('a 200 success with real PDF bytes parses into ManualResumePdfReady', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 200,
          postBodyBytes: _pdfBytes,
          postHeaders: const {
            'content-type': ['application/pdf'],
            'content-disposition': ['attachment; filename="resume.pdf"'],
          },
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.generateManualResumePdf(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePdfReady>());
      expect((outcome as ManualResumePdfReady).bytes, _pdfBytes);
      expect(outcome.filename, 'resume.pdf');
    });

    test('prefers the X-Resume-Filename header over Content-Disposition when both are present', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 200,
          postBodyBytes: _pdfBytes,
          postHeaders: const {
            'content-type': ['application/pdf'],
            'content-disposition': ['attachment; filename="from-disposition.pdf"'],
            'x-resume-filename': ['from-header.pdf'],
          },
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.generateManualResumePdf(ManualResumeDraft.blank());

      expect((outcome as ManualResumePdfReady).filename, 'from-header.pdf');
    });

    test('a 400 validation rejection (JSON through the bytes channel) parses into ManualResumePdfRejected', () async {
      final rejectedJson = utf8.encode(
        '{"ok": false, "errors": [{"field": "personal.name", "step": 1, "message": "Please enter your full name."}]}',
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 400,
          postBodyBytes: rejectedJson,
          postHeaders: const {
            'content-type': ['application/json'],
          },
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.generateManualResumePdf(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePdfRejected>());
      expect((outcome as ManualResumePdfRejected).errors.single.field, 'personal.name');
    });

    test('a 429 rate-limit response also parses into ManualResumePdfRejected', () async {
      final rejectedJson = utf8.encode('{"ok": false, "errors": [{"field": "", "step": 0, "message": "Too many requests."}]}');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 429,
          postBodyBytes: rejectedJson,
          postHeaders: const {
            'content-type': ['application/json'],
          },
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.generateManualResumePdf(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePdfRejected>());
      expect((outcome as ManualResumePdfRejected).errors.single.message, 'Too many requests.');
    });

    // Phase 30 (work item 4) — `pdf_download`'s server-side PDF-rendering-
    // exception branch returns HTTP 500 with the same JSON rejection
    // envelope, delivered through the same `ResponseType.bytes` channel a
    // genuine PDF success also uses (confirmed directly, Phase 29 audit).
    // `validateStatus: (_) => true` on this request means a 500 reaches the
    // parser exactly like any other status would — this confirms end-to-end
    // that it is never treated as a successful (corrupt) PDF.
    test('a 500 server-side rendering exception also parses into ManualResumePdfRejected, never a corrupt PDF', () async {
      final rejectedJson = utf8.encode(
        '{"ok": false, "errors": [{"field": "", "step": 0, '
        '"message": "The PDF could not be generated. Please try again."}]}',
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 500,
          postBodyBytes: rejectedJson,
          postHeaders: const {
            'content-type': ['application/json'],
          },
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.generateManualResumePdf(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePdfRejected>());
      expect(
        (outcome as ManualResumePdfRejected).errors.single.message,
        'The PDF could not be generated. Please try again.',
      );
    });

    test('an empty response body throws UnexpectedResponseException, never a fabricated success', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(postStatusCode: 200, postBodyBytes: const []);
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.generateManualResumePdf(ManualResumeDraft.blank()),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a malformed non-PDF, non-JSON body throws UnexpectedResponseException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _BytesPostAdapter(
          postStatusCode: 500,
          postBodyBytes: utf8.encode('Internal Server Error'),
          postHeaders: const {
            'content-type': ['text/plain'],
          },
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.generateManualResumePdf(ManualResumeDraft.blank()),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a genuine connection failure surfaces as the mapped AppException, not a crash', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))..httpClientAdapter = _ThrowingAdapter();
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.generateManualResumePdf(ManualResumeDraft.blank()),
        throwsA(isA<AppException>()),
      );
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, dynamic requestStream, Future<void>? cancelFuture) async {
    throw const SocketExceptionStub();
  }

  @override
  void close({bool force = false}) {}
}

/// A stand-in for `dart:io`'s `SocketException` — avoids importing `dart:io`
/// in a test that otherwise only needs "some connection error was thrown".
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
