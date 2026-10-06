import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/features/auth/data/datasources/password_reset_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client_adapter.dart';

/// `requestReset` GETs the form page first (to prime the `csrftoken`
/// cookie, exactly like `AuthRemoteDataSource.login`) before POSTing — on
/// the real server that GET always returns 200 (it's just the form page),
/// only the POST can redirect. This adapter reproduces that: any GET gets a
/// plain 200, and only POST gets the test's configured status/body.
class _GetPrimesCsrfAdapter implements HttpClientAdapter {
  _GetPrimesCsrfAdapter({required this.postStatusCode, this.postBody = ''});

  final int postStatusCode;
  final String postBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString('', 200);
    }
    return ResponseBody.fromString(postBody, postStatusCode);
  }

  @override
  void close({bool force = false}) {}
}

/// Phase 1 (web-to-Flutter conversion) — password reset has no JSON API
/// anywhere (`PasswordResetView`/`PasswordResetConfirmView` are plain
/// Django-auth-rendered HTML), so these tests exercise the same
/// redirect-means-success / re-rendered-form-means-failure contract already
/// proven for login, using canned HTML bodies shaped like the real
/// templates.
void main() {
  group('requestReset', () {
    test('completes without throwing on a real 302 (redirect to done page)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _GetPrimesCsrfAdapter(postStatusCode: 302);
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(datasource.requestReset('user@example.com'), completes);
    });

    test('throws ValidationException with the scraped field error on a 200 (invalid email)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _GetPrimesCsrfAdapter(
          postStatusCode: 200,
          postBody: '<div class="text-danger small mt-1">Enter a valid email address.</div>',
        );
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.requestReset('not-an-email'),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Enter a valid email address.')),
      );
    });
  });

  group('checkResetLink', () {
    test('returns true when the page renders the new-password form (valid link)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<input type="password" name="new_password1">',
        );
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.checkResetLink('abc', 'def-token'), isTrue);
    });

    test('returns false when the page renders the invalid-link message', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<h3>Invalid or expired link</h3>',
        );
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.checkResetLink('abc', 'def-token'), isFalse);
    });
  });

  group('confirmReset', () {
    test('completes without throwing on a real 302 (redirect to complete page)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Aa1!aaaa'),
        completes,
      );
    });

    test('throws ValidationException with the scraped error on a 200 (password mismatch)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<div class="text-danger small mt-1">The two password fields didn’t match.</div>',
        );
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Bb2@bbbb'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
