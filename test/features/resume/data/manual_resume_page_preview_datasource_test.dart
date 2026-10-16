import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/resume/data/manual_resume_preview_payload.dart';
import 'package:career_buddy_lms/features/resume/data/resume_remote_datasource.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_page_preview_outcome.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same shape as `manual_resume_preview_datasource_test.dart`'s own private
/// copy — a local adapter is this codebase's established convention
/// (`_JsonPostAdapter` is per-file, not shared) so the POST response can
/// carry a `content-type: application/json` header, required for Dio's
/// default transformer to auto-decode into a `Map`.
class _JsonPostAdapter implements HttpClientAdapter {
  _JsonPostAdapter({required this.postStatusCode, this.postBody = '', this.onPostRequest});

  final int postStatusCode;
  final String postBody;
  final void Function(RequestOptions options)? onPostRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString('', 200);
    }
    onPostRequest?.call(options);
    return ResponseBody.fromString(
      postBody,
      postStatusCode,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _validPngDataUri = 'data:image/png;base64,iVBORw0KGgpmYWtlLXBuZy1ib2R5';

const _successBody = '''
{
  "ok": true,
  "pages": ["$_validPngDataUri"],
  "total": 1,
  "filename": "resume.pdf"
}
''';

const _rejectedBody = '''
{
  "ok": false,
  "errors": [{"field": "personal.name", "step": 1, "message": "Please enter your full name."}],
  "completeness": {"overall": 10, "categories": []}
}
''';

void main() {
  group('getManualResumePagePreview — request shape', () {
    test('reuses the existing CSRF-priming pattern: a GET first, then a JSON POST with X-CSRFToken', () async {
      RequestOptions? capturedPost;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 200,
          postBody: _successBody,
          onPostRequest: (options) => capturedPost = options,
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.getManualResumePagePreview(ManualResumeDraft.blank());

      expect(capturedPost, isNotNull);
      expect(capturedPost!.path, '/resume-builder/manual/pages/');
      expect(capturedPost!.headers.containsKey('X-CSRFToken'), isTrue);
      expect(capturedPost!.contentType, contains('application/json'));
    });

    test('sends the exact same snake_case payload as the document preview', () async {
      RequestOptions? capturedPost;
      final draft = ManualResumeDraft.blank().copyWith(targetTitle: 'Senior QA Engineer');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 200,
          postBody: _successBody,
          onPostRequest: (options) => capturedPost = options,
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.getManualResumePagePreview(draft);

      expect(capturedPost!.data, toManualResumePreviewPayload(draft));
    });
  });

  group('getManualResumePagePreview — response handling', () {
    test('a 200 success parses into ManualResumePagePreviewReady', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(postStatusCode: 200, postBody: _successBody);
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.getManualResumePagePreview(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePagePreviewReady>());
      expect((outcome as ManualResumePagePreviewReady).pages, hasLength(1));
      expect(outcome.filename, 'resume.pdf');
    });

    test('a 400 validation rejection parses into ManualResumePagePreviewRejected, not an exception', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(postStatusCode: 400, postBody: _rejectedBody);
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.getManualResumePagePreview(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePagePreviewRejected>());
      expect((outcome as ManualResumePagePreviewRejected).errors.single.field, 'personal.name');
    });

    test('a 429 rate-limit response also parses into ManualResumePagePreviewRejected', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 429,
          postBody: '{"ok": false, "errors": [{"field": "", "step": 0, "message": "Too many requests."}]}',
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.getManualResumePagePreview(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePagePreviewRejected>());
      expect((outcome as ManualResumePagePreviewRejected).errors.single.message, 'Too many requests.');
    });

    // Phase 30 (work item 4) — `preview_pages_api`'s server-side rendering-
    // exception branch returns HTTP 500 with the same JSON rejection
    // envelope (confirmed directly, Phase 29 audit). `validateStatus: (_) =>
    // true` on this datasource's request means a 500 reaches the parser
    // exactly like any other status would — this confirms end-to-end (not
    // just at the parser level) that it is never treated as a crash or a
    // fabricated empty success.
    test('a 500 server-side rendering exception also parses into ManualResumePagePreviewRejected, not a crash', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 500,
          postBody: '{"ok": false, "errors": [{"field": "", "step": 0, '
              '"message": "Page preview is unavailable. Use Download PDF to view the pages."}]}',
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.getManualResumePagePreview(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePagePreviewRejected>());
      expect(
        (outcome as ManualResumePagePreviewRejected).errors.single.message,
        'Page preview is unavailable. Use Download PDF to view the pages.',
      );
    });

    test('a malformed/unparseable body throws UnexpectedResponseException, never a fabricated success', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(postStatusCode: 200, postBody: '{"unexpected": true}');
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.getManualResumePagePreview(ManualResumeDraft.blank()),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a genuine connection failure surfaces as the mapped AppException, not a crash', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))..httpClientAdapter = _ThrowingAdapter();
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.getManualResumePagePreview(ManualResumeDraft.blank()),
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
