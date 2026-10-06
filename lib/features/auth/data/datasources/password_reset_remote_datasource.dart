import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

/// Django's email-based password reset (`users/urls.py`, Django's built-in
/// `PasswordResetView`/`PasswordResetConfirmView` with project-styled
/// templates — see `ApiEndpoints.passwordReset`'s doc comment). There is no
/// JSON API anywhere in this flow; every method here follows the same
/// GET-primes-CSRF, POST-with-followRedirects-false, 302-means-success
/// convention as `AuthRemoteDataSource.login`, and scrapes field errors out
/// of the re-rendered HTML on a 200 (matching the same HTML-scrape pattern
/// already used for resume history/JAM/GD parsing elsewhere in this app —
/// there is no more structured contract available for a plain Django auth
/// view).
class PasswordResetRemoteDataSource {
  PasswordResetRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `PasswordResetView` — always 302s to `password_reset_done` on a
  /// syntactically valid POST, *regardless* of whether the email actually
  /// has an account (Django's own anti-account-enumeration behavior), so a
  /// 200 response here only ever means a field-level error (e.g. malformed
  /// email), never "no such account."
  Future<void> requestReset(String email) async {
    try {
      await _apiClient.dio.get(ApiEndpoints.passwordReset);
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post(
        ApiEndpoints.passwordReset,
        data: {
          'email': email,
          'csrfmiddlewaretoken': csrfToken ?? '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        final message = _firstFieldError(response.data ?? '') ?? 'Enter a valid email address.';
        throw ValidationException({'email': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `PasswordResetConfirmView`'s GET — the same URL renders either the
  /// new-password form (valid, unused link) or an "invalid/expired" message
  /// (already-used, malformed, or expired link) depending server-side on
  /// `token_generator.check_token`. Detected here by the presence of the
  /// `new_password1` field name, which only the valid-link branch of
  /// `password_reset_confirm.html` renders.
  Future<bool> checkResetLink(String uidb64, String token) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.passwordResetConfirm(uidb64, token),
        options: Options(validateStatus: (_) => true, responseType: ResponseType.plain),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      final String body = response.data ?? '';
      return body.contains('new_password1');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `PasswordResetConfirmView`'s POST — 302 to `password_reset_complete`
  /// on success; a 200 re-renders the same form with field errors (password
  /// mismatch, fails `PasswordComplexityValidator`, etc.).
  Future<void> confirmReset({
    required String uidb64,
    required String token,
    required String password1,
    required String password2,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.passwordResetConfirm(uidb64, token),
        data: {
          'new_password1': password1,
          'new_password2': password2,
          'csrfmiddlewaretoken': csrfToken ?? '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        final message = _firstFieldError(response.data ?? '') ?? 'Please check your new password and try again.';
        throw ValidationException({'password': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  static final _fieldErrorPattern = RegExp(r'text-danger small mt-1">([^<]+)<');

  String? _firstFieldError(String html) => _fieldErrorPattern.firstMatch(html)?.group(1)?.trim();
}
