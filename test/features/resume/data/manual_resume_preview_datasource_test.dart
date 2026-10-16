import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/resume/data/manual_resume_preview_payload.dart';
import 'package:career_buddy_lms/features/resume/data/resume_remote_datasource.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_preview_outcome.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same GET-primes-then-POST shape as the shared `GetPrimesCsrfAdapter`
/// (`test/support/fake_http_client_adapter.dart`), with a local copy here
/// (matching this codebase's own established convention of per-file
/// private copies, e.g. `password_reset_remote_datasource_test.dart`) so
/// the POST response can carry a `content-type: application/json` header —
/// required for Dio's default transformer to auto-decode the body into a
/// `Map`, confirmed directly against `resume_remote_datasource_test.dart`'s
/// own working `getRoles()` tests.
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

const _successBody = '''
{
  "ok": true,
  "document": {
    "name": "Anita Sharma",
    "title": "QA Engineer",
    "contact": [],
    "level": "1-3",
    "level_label": "1–3 Years",
    "role": "QA Engineer",
    "sections": []
  },
  "warnings": [],
  "completeness": {"overall": 50, "categories": []},
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
  group('previewManualResume — request shape', () {
    test('reuses the existing CSRF-priming pattern: a GET first, then a JSON POST with X-CSRFToken', () async {
      RequestOptions? capturedPost;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 200,
          postBody: _successBody,
          onPostRequest: (options) => capturedPost = options,
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.previewManualResume(ManualResumeDraft.blank());

      expect(capturedPost, isNotNull);
      expect(capturedPost!.path, '/resume-builder/manual/preview/');
      expect(capturedPost!.headers.containsKey('X-CSRFToken'), isTrue);
      expect(capturedPost!.contentType, contains('application/json'));
    });

    test('sends the exact snake_case payload for the given draft', () async {
      RequestOptions? capturedPost;
      final draft = ManualResumeDraft.blank().copyWith(targetTitle: 'Senior QA Engineer');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 200,
          postBody: _successBody,
          onPostRequest: (options) => capturedPost = options,
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await datasource.previewManualResume(draft);

      expect(capturedPost!.data, toManualResumePreviewPayload(draft));
    });
  });

  group('previewManualResume — response handling', () {
    test('a 200 success parses into ManualResumePreviewReady', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(postStatusCode: 200, postBody: _successBody);
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.previewManualResume(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePreviewReady>());
      expect((outcome as ManualResumePreviewReady).document.name, 'Anita Sharma');
    });

    test('a 400 validation rejection parses into ManualResumePreviewRejected, not an exception', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(postStatusCode: 400, postBody: _rejectedBody);
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.previewManualResume(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePreviewRejected>());
      expect((outcome as ManualResumePreviewRejected).errors.single.field, 'personal.name');
    });

    test('a 429 rate-limit response also parses into ManualResumePreviewRejected', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(
          postStatusCode: 429,
          postBody: '{"ok": false, "errors": [{"field": "", "step": 0, "message": "Too many requests."}]}',
        );
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      final outcome = await datasource.previewManualResume(ManualResumeDraft.blank());

      expect(outcome, isA<ManualResumePreviewRejected>());
      expect((outcome as ManualResumePreviewRejected).errors.single.message, 'Too many requests.');
    });

    test('a malformed/unparseable body throws UnexpectedResponseException, never a fabricated success', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _JsonPostAdapter(postStatusCode: 200, postBody: '{"unexpected": true}');
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.previewManualResume(ManualResumeDraft.blank()),
        throwsA(isA<UnexpectedResponseException>()),
      );
    });

    test('a genuine connection failure surfaces as the mapped AppException, not a crash', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _ThrowingAdapter();
      final datasource = ResumeRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.previewManualResume(ManualResumeDraft.blank()), throwsA(isA<AppException>()));
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
