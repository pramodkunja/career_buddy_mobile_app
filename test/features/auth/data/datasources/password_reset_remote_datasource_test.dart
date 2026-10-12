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

/// Returns one canned response per call, in order — needed because
/// `checkResetLink`/`confirmReset` each make a real *sequence* of requests
/// (re-verified against Django's own `PasswordResetConfirmView.dispatch`,
/// `django/contrib/auth/views.py:256-298`): a GET to the real-token URL
/// (302 if the token is valid, 200 "invalid/expired" otherwise), then a GET
/// to the session-dependent `.../set-password/` URL to load the actual
/// form, and — for `confirmReset` only — a final POST to that same URL
/// (302 only once Django's `form_valid` really ran). A single fixed
/// response (the old `FakeHttpClientAdapter`) can't represent that
/// sequence, which is exactly the gap that let the original bug (treating
/// a 302 from the *first* request as "password changed") go unnoticed.
class _SequencedAdapter implements HttpClientAdapter {
  _SequencedAdapter(this.responses);

  final List<({int statusCode, String body})> responses;
  int _callIndex = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final response = responses[_callIndex];
    _callIndex = _callIndex + 1 < responses.length ? _callIndex + 1 : _callIndex;
    return ResponseBody.fromString(response.body, response.statusCode);
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
///
/// Phase 3 — `checkResetLink`/`confirmReset` were rewritten to follow the
/// real 2-URL mechanism (see `_SequencedAdapter`'s own doc comment); the
/// tests below were updated to match, not weakened — every case that
/// previously asserted a (wrong) single-request outcome now asserts the
/// correct multi-request one, and two entirely new cases were added for
/// the specific defect this phase fixed (a 302 from the real-token URL
/// alone must never be treated as "password changed").
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
    test('returns true when the real-token URL 302s and the set-password form renders', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _SequencedAdapter([
          (statusCode: 302, body: ''),
          (statusCode: 200, body: '<input type="password" name="new_password1">'),
        ]);
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.checkResetLink('abc', 'def-token'), isTrue);
    });

    test('returns false when the real-token URL itself rejects the token (200, invalid/expired)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '<h3>Invalid or expired link</h3>',
        );
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.checkResetLink('abc', 'def-token'), isFalse);
    });

    test('returns false when the token 302s but the session did not carry over to the set-password page', () async {
      // The documented Dio+cookie-manager risk: the first response's
      // Set-Cookie never reaches the second request, so Django renders
      // its own "invalid/expired" page at the set-password URL too.
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _SequencedAdapter([
          (statusCode: 302, body: ''),
          (statusCode: 200, body: '<h3>Invalid or expired link</h3>'),
        ]);
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      expect(await datasource.checkResetLink('abc', 'def-token'), isFalse);
    });
  });

  group('confirmReset', () {
    test('completes without throwing only once the token 302s, the form renders, AND the final POST 302s', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _SequencedAdapter([
          (statusCode: 302, body: ''), // real-token URL accepts the token
          (statusCode: 200, body: '<input type="password" name="new_password1">'), // set-password form loads
          (statusCode: 302, body: ''), // the actual password-change POST
        ]);
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Aa1!aaaa'),
        completes,
      );
    });

    test(
      'REGRESSION (the confirmed Phase 2 defect): a 302 from only the real-token URL must NOT be '
      'reported as success — the password is never processed there, confirmed directly from '
      "Django's own PasswordResetConfirmView.dispatch",
      () async {
        // A single-response-forever fake reproduces exactly the old,
        // broken code path: every request (including the real POST) gets
        // the same 302 the real-token URL itself always returns for a
        // valid token — if this ever again passes, the datasource has
        // regressed to treating that first redirect as a password change.
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 302, body: '');
        final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

        // The set-password GET (the 2nd call) also returns 302 under this
        // adapter, which is not a 200 — the datasource must treat that as
        // a server error rather than silently proceeding to POST and
        // reporting success, so this must NOT complete.
        await expectLater(
          datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Aa1!aaaa'),
          throwsA(isA<AppException>()),
        );
      },
    );

    test('throws a ValidationException when the real-token URL itself rejects the token (expired/reused)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(statusCode: 200, body: '<h3>Invalid or expired link</h3>');
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Aa1!aaaa'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException with the scraped error on a 200 from the final POST (password mismatch)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _SequencedAdapter([
          (statusCode: 302, body: ''),
          (statusCode: 200, body: '<input type="password" name="new_password1">'),
          (statusCode: 200, body: '<div class="text-danger small mt-1">The two password fields didn’t match.</div>'),
        ]);
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Bb2@bbbb'),
        throwsA(
          isA<ValidationException>().having((e) => e.message, 'message', 'The two password fields didn’t match.'),
        ),
      );
    });

    test('throws a ServerException on a genuine server error from the final POST', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = _SequencedAdapter([
          (statusCode: 302, body: ''),
          (statusCode: 200, body: '<input type="password" name="new_password1">'),
          (statusCode: 500, body: ''),
        ]);
      final datasource = PasswordResetRemoteDataSource(ApiClient.forTesting(dio));

      await expectLater(
        datasource.confirmReset(uidb64: 'abc', token: 'def', password1: 'Aa1!aaaa', password2: 'Aa1!aaaa'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
