import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

/// Django's email-based password reset (`users/urls.py`, Django's built-in
/// `PasswordResetView`/`PasswordResetConfirmView` with project-styled
/// templates — see `ApiEndpoints.passwordReset`'s doc comment). There is no
/// JSON API anywhere in this flow. `requestReset` follows the same
/// GET-primes-CSRF, POST-with-followRedirects-false, 302-means-success
/// convention as `AuthRemoteDataSource.login`. `checkResetLink` and
/// `confirmReset` are *not* a single GET/POST to one URL — Django's own
/// `PasswordResetConfirmView` splits token-checking and form-processing
/// across two different URLs reached via a session-carried redirect (see
/// `ApiEndpoints.passwordResetConfirm`'s doc comment for the exact
/// mechanism, confirmed by reading Django's source directly) — so both
/// methods make the same real-token-then-set-password request sequence.
/// Every 200 response is scraped for field errors the same way
/// resume history/JAM/GD parsing does elsewhere in this app — there is no
/// more structured contract available for a plain Django auth view.
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

  /// Mirrors the real two-step mechanism exactly (see
  /// `ApiEndpoints.passwordResetConfirm`'s doc comment for the Django
  /// source citation): GET the real-token URL first — a 200 here means
  /// Django rejected the token outright (invalid/expired/already-used),
  /// no form was ever rendered. A 302 means the token was valid *and*
  /// Django has now stored it in the session; only then do we load the
  /// actual form at [ApiEndpoints.passwordResetSetPassword] and confirm it
  /// really rendered (handles the case where the session cookie set by
  /// the first response didn't make it onto the second request — a known
  /// Dio+cookie-manager risk across an internally-followed redirect, which
  /// is exactly why `followRedirects: false` plus a deliberate second
  /// request is used here instead of letting Dio auto-follow).
  Future<bool> checkResetLink(String uidb64, String token) async {
    try {
      final tokenResponse = await _apiClient.dio.get<String>(
        ApiEndpoints.passwordResetConfirm(uidb64, token),
        options: Options(followRedirects: false, validateStatus: (_) => true, responseType: ResponseType.plain),
      );
      if (tokenResponse.statusCode == 200) return false;
      if (tokenResponse.statusCode != 302) throw ServerException(tokenResponse.statusCode);

      final formResponse = await _apiClient.dio.get<String>(
        ApiEndpoints.passwordResetSetPassword(uidb64),
        options: Options(validateStatus: (_) => true, responseType: ResponseType.plain),
      );
      if (formResponse.statusCode != 200) throw ServerException(formResponse.statusCode);
      return (formResponse.data ?? '').contains('new_password1');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// Submits the new password to the one URL that actually processes it
  /// (see `ApiEndpoints.passwordResetConfirm`'s doc comment — posting to
  /// the real-token URL, this method's previous behavior, was silently
  /// ignored by Django before any form was ever looked at, so a 302 there
  /// never meant the password had changed). This re-validates the token
  /// itself first rather than assuming a prior [checkResetLink] call in
  /// the same process already did so and the session still reflects it —
  /// the same real-token-GET-then-set-password-GET sequence as
  /// [checkResetLink], so this method is safe to call on its own. Only a
  /// 302 from the final POST means Django's `form_valid` actually ran
  /// (`PasswordResetConfirmView.form_valid` only redirects to
  /// `success_url` after `form.save()`), which is the one and only
  /// condition under which this reports success.
  Future<void> confirmReset({
    required String uidb64,
    required String token,
    required String password1,
    required String password2,
  }) async {
    try {
      final tokenResponse = await _apiClient.dio.get<String>(
        ApiEndpoints.passwordResetConfirm(uidb64, token),
        options: Options(followRedirects: false, validateStatus: (_) => true, responseType: ResponseType.plain),
      );
      if (tokenResponse.statusCode == 200) {
        throw const ValidationException({}, 'This password reset link is no longer valid. Please request a new one.');
      }
      if (tokenResponse.statusCode != 302) throw ServerException(tokenResponse.statusCode);

      final formResponse = await _apiClient.dio.get<String>(
        ApiEndpoints.passwordResetSetPassword(uidb64),
        options: Options(validateStatus: (_) => true, responseType: ResponseType.plain),
      );
      if (formResponse.statusCode == 200 && !(formResponse.data ?? '').contains('new_password1')) {
        throw const ValidationException({}, 'This password reset link is no longer valid. Please request a new one.');
      }
      if (formResponse.statusCode != 200) throw ServerException(formResponse.statusCode);

      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post<String>(
        ApiEndpoints.passwordResetSetPassword(uidb64),
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
