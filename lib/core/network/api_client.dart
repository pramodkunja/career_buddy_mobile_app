import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/config/environment.dart';
import 'api_exceptions_interceptor.dart';

/// Central HTTP client. The backend authenticates via a Django session
/// cookie (see ApiEndpoints doc comment), so this behaves like a browser:
/// cookies set by the server are persisted and replayed automatically via
/// [PersistCookieJar]. There is no bearer-token header today — if the
/// backend grows a JWT/DRF API, add a request interceptor here rather than
/// changing every call site.
class ApiClient {
  ApiClient._(this.dio, this._cookieJar);

  /// Test-only: builds an [ApiClient] around a caller-provided [Dio] (e.g.
  /// one with a fake [HttpClientAdapter]), skipping the filesystem-backed
  /// cookie jar `create()` needs — that requires a platform channel
  /// (`path_provider`) that plain `flutter test` doesn't have. [cookieJar]
  /// defaults to a fresh, disconnected in-memory jar (unchanged behavior
  /// for every existing caller); a test specifically exercising real
  /// cookie-persistence-through-a-request behavior can pass its own jar
  /// here and wire a matching `CookieManager` into the same [dio] itself,
  /// exactly like [create] does — see `test/core/network/api_client_test.
  /// dart`'s doc comment for a worked example.
  @visibleForTesting
  factory ApiClient.forTesting(Dio dio, {CookieJar? cookieJar}) => ApiClient._(dio, cookieJar ?? CookieJar());

  final Dio dio;
  final CookieJar _cookieJar;

  static Future<ApiClient> create() async {
    // `path_provider` has no web implementation (MissingPluginException), and
    // on web the browser owns cookies anyway — JS can't set a `Cookie` header
    // or read `Set-Cookie` — so the jar is a disconnected in-memory one there.
    final CookieJar cookieJar;
    if (kIsWeb) {
      cookieJar = CookieJar();
    } else {
      final supportDir = await getApplicationSupportDirectory();
      cookieJar = PersistCookieJar(
        ignoreExpires: false,
        storage: FileStorage('${supportDir.path}/.cookies/'),
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: EnvironmentConfig.baseUrl,
        // Web only (ignored by the native adapter): asks the browser to send
        // and store the Django session cookie on cross-origin requests.
        extra: {'withCredentials': true},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        // Django's CsrfViewMiddleware requires a same-origin `Referer` header
        // on every unsafe-method (POST/PUT/PATCH/DELETE) request whenever the
        // request is HTTPS (`request.is_secure()`) — a check that exists
        // *in addition to* the X-CSRFToken/csrftoken-cookie check below, and
        // rejects the request with 403 even when the CSRF token itself is
        // valid. Dio, unlike a browser, never sends this header on its own.
        // Confirmed live against production: an otherwise-identical login
        // POST goes from 403 ("Referer checking failed - no Referer.") to a
        // successful 302 purely by adding this header. Dev's backend being
        // plain HTTP (where Django skips this check) is why this was never
        // caught before the first real HTTPS/production test.
        headers: {'Referer': EnvironmentConfig.baseUrl},
      ),
    );
    if (!kIsWeb) dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(ApiExceptionsInterceptor());

    return ApiClient._(dio, cookieJar);
  }

  /// Reads a cookie (e.g. Django's `csrftoken`) previously set by the
  /// server for the configured base URL.
  Future<String?> readCookie(String name) async {
    final cookies = await _cookieJar.loadForRequest(
      Uri.parse(EnvironmentConfig.baseUrl),
    );
    for (final cookie in cookies) {
      if (cookie.name == name) return cookie.value;
    }
    return null;
  }

  Future<void> clearCookies() => _cookieJar.deleteAll();

  /// Builds a raw `Cookie:` header value (`name1=value1; name2=value2`) from
  /// every cookie currently held for the configured base URL — exactly what
  /// a browser sends automatically on every request, including a WebSocket's
  /// initial HTTP upgrade request. [Dio]'s [CookieManager] interceptor only
  /// attaches cookies to requests made through `dio.*` itself; a WebSocket
  /// handshake (`package:web_socket_channel`) bypasses Dio entirely, so
  /// Group Discussion's realtime service reads this explicitly and passes it
  /// as a `headers: {'Cookie': ...}` on connect — the same session cookie
  /// Django Channels' `AuthMiddlewareStack` reads to authenticate the socket
  /// (see `ApiEndpoints.gdWebSocketPath`'s doc comment).
  Future<String> buildCookieHeader() async {
    final cookies = await _cookieJar.loadForRequest(
      Uri.parse(EnvironmentConfig.baseUrl),
    );
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }
}
