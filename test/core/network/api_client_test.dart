import 'package:career_buddy_lms/app/config/environment.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

/// Batch 11 — release-readiness smoke tests for the app's real session-
/// cookie mechanics (Django session auth, see `ApiClient`'s own doc
/// comment). `ApiClient.forTesting`'s default jar is a fresh, disconnected
/// one (unchanged for every other test in this codebase); here we pass our
/// own jar and wire a `CookieManager` against it ourselves, exactly like
/// the real `ApiClient.create()` does, so these tests exercise the real
/// persist-then-replay behavior, not just the jar's own bookkeeping.
///
/// `ApiClient.readCookie`/`buildCookieHeader` deliberately look the jar up
/// by `EnvironmentConfig.baseUrl` (the same single source of truth every
/// real request already uses — see `create()`), not by whatever a given
/// `Dio` instance's own `baseUrl` happens to be — so this test's fake `Dio`
/// must be built against that exact same value too, or the jar's real
/// host-matching logic (correctly) treats them as two different sites.
void main() {
  final testBaseUrl = EnvironmentConfig.baseUrl;


  group('ApiClient — session cookie persistence (Batch 11)', () {
    test('a Set-Cookie response header is captured and later readable via readCookie', () async {
      final cookieJar = CookieJar();
      final dio = Dio(BaseOptions(baseUrl: testBaseUrl))
        ..interceptors.add(CookieManager(cookieJar))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '{}',
          headers: {
            'content-type': ['application/json'],
            'set-cookie': ['sessionid=abc123; Path=/; HttpOnly'],
          },
        );
      final client = ApiClient.forTesting(dio, cookieJar: cookieJar);

      await client.dio.get<void>('/some-endpoint/');

      expect(await client.readCookie('sessionid'), 'abc123');
    });

    test('buildCookieHeader joins every persisted cookie as a real Cookie: header value', () async {
      final cookieJar = CookieJar();
      final dio = Dio(BaseOptions(baseUrl: testBaseUrl))
        ..interceptors.add(CookieManager(cookieJar))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '{}',
          headers: {
            'content-type': ['application/json'],
            'set-cookie': ['sessionid=abc123; Path=/', 'csrftoken=xyz789; Path=/'],
          },
        );
      final client = ApiClient.forTesting(dio, cookieJar: cookieJar);
      await client.dio.get<void>('/some-endpoint/');

      final header = await client.buildCookieHeader();

      expect(header, contains('sessionid=abc123'));
      expect(header, contains('csrftoken=xyz789'));
    });

    test('clearCookies (the real logout call site\'s finally block) actually empties the jar', () async {
      final cookieJar = CookieJar();
      final dio = Dio(BaseOptions(baseUrl: testBaseUrl))
        ..interceptors.add(CookieManager(cookieJar))
        ..httpClientAdapter = FakeHttpClientAdapter(
          statusCode: 200,
          body: '{}',
          headers: {
            'content-type': ['application/json'],
            'set-cookie': ['sessionid=abc123; Path=/'],
          },
        );
      final client = ApiClient.forTesting(dio, cookieJar: cookieJar);
      await client.dio.get<void>('/some-endpoint/');
      expect(await client.readCookie('sessionid'), 'abc123');

      await client.clearCookies();

      expect(await client.readCookie('sessionid'), isNull);
      expect(await client.buildCookieHeader(), isEmpty);
    });

    test('readCookie returns null for a cookie that was never set (no session yet)', () async {
      final client = ApiClient.forTesting(Dio(BaseOptions(baseUrl: testBaseUrl)));
      expect(await client.readCookie('sessionid'), isNull);
    });
  });

  group('ApiClient — Referer header (Current-task production-login investigation)', () {
    test(
      'a Dio built the same way ApiClient.create() builds it sends a same-origin '
      'Referer on every request',
      () async {
        // ApiClient.create() itself can't be called from a plain `flutter
        // test` (it needs path_provider's platform channel for the cookie
        // jar's storage directory — see the class doc comment), so this
        // mirrors its exact BaseOptions construction instead. Confirmed live
        // against production: without this header, Django's
        // CsrfViewMiddleware rejects every unsafe-method (POST/PUT/PATCH/
        // DELETE) HTTPS request with 403 ("Referer checking failed - no
        // Referer."), even with a valid CSRF token — a check that only
        // triggers for HTTPS, which is why it was invisible against the
        // (HTTP) dev backend through every prior batch.
        RequestOptions? captured;
        final dio = Dio(
          BaseOptions(
            baseUrl: testBaseUrl,
            headers: {'Referer': testBaseUrl},
            validateStatus: (_) => true,
          ),
        )..httpClientAdapter = FakeHttpClientAdapter(
            statusCode: 302,
            onRequest: (options) => captured = options,
          );

        await dio.post<void>('/users/login/');

        expect(captured, isNotNull);
        expect(captured!.headers['Referer'], testBaseUrl);
      },
    );
  });
}
