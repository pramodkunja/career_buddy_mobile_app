import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/html_unescape.dart';
import '../../domain/entities/employer_registration_data.dart';

/// Talks to the Employer Portal's session-auth login view directly — the
/// same GET-for-CSRF / POST-form-encoded / don't-follow-redirects technique
/// as [AuthRemoteDataSource], reused because it's the same underlying
/// mechanism (Django's `LoginView`), but pointed at a genuinely different
/// view/form: `accounts_app.views.EmployerLoginView` (`EmployerLoginForm`,
/// an `AuthenticationForm` subclass that additionally rejects any user
/// without an `employer_profile`, `accounts_app/views.py:32-41`) — not the
/// same code path as student login, per the project brief's explicit
/// instruction not to assume the two are identical.
///
/// - A successful login also sets `request.session['portal'] = 'employer'`
///   server-side (`accounts_app/views.py:92`) — this client doesn't need to
///   read that back; it already knows the session is an employer one
///   because this is the datasource that established it.
/// - Same 302-success / 200-failure distinction as student login.
///   **Phase 14**: the 200 response's own rendered page carries a real,
///   specific, safe error — `login()` now scrapes it instead of reporting
///   one hardcoded generic string. `templates/employer_login/login.html:84-
///   99` renders every `form.errors` entry inside its own `.alert.alert-
///   danger` block, which is either Django's own "wrong credentials" text
///   (template-overridden to a clean "Invalid username or password.") or
///   `EmployerLoginForm.clean()`'s own distinct "Student accounts cannot
///   log in through the employer portal." (`accounts_app/views.py:32-41`).
///   Unlike student login, `EmployerLoginView` is a bare Django
///   `auth_views.LoginView` with no lockout logic and no flashed-message
///   fallback to also check (confirmed: no `messages.error` call anywhere
///   on this path) — if the form-error block doesn't match, this falls back
///   to the existing generic message rather than guessing.
class EmployerAuthRemoteDataSource {
  EmployerAuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static const _genericLoginFailureMessage =
      'Invalid username or password, or this account cannot sign in through the employer portal.';

  /// `employer_login/login.html:84-99`'s own `<div class="alert alert-
  /// danger" style="border-radius: 12px; font-size: 0.85rem; padding:
  /// 12px;">` block, anchored on its distinctive inline style (not just the
  /// inner icon, which here is `me-2` — the same margin class `base.html`'s
  /// own flashed messages use elsewhere in this app, so anchoring on the
  /// icon alone could cross-match a flashed message on a page that happened
  /// to carry one too). Captures the first error item's text, which in
  /// practice is the only one `EmployerLoginForm.clean()`/Django's own
  /// `AuthenticationForm` ever raises for this form.
  static final _loginFormErrorPattern = RegExp(
    r'alert alert-danger" style="border-radius: 12px; font-size: 0\.85rem; padding: 12px;">'
    r'[\s\S]*?<i class="fas fa-exclamation-circle me-2"></i>\s*([\s\S]*?)\s*</div>',
  );

  static String _unescape(String value) => unescapeHtmlEntities(value);

  /// Returns the real error Django rendered for a failed employer login, or
  /// `null` if the known pattern didn't match (never a guess — callers fall
  /// back to [_genericLoginFailureMessage]).
  static String? _parseLoginFailureMessage(String html) {
    final item = _loginFormErrorPattern.firstMatch(html)?.group(1)?.trim();
    if (item == null || item.isEmpty) return null;
    return _unescape(item);
  }

  Future<String> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      await _apiClient.dio.get(ApiEndpoints.employerLogin);
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post(
        ApiEndpoints.employerLogin,
        data: {
          'username': usernameOrEmail,
          'password': password,
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

      if (response.statusCode == 302) {
        return usernameOrEmail;
      }
      if (response.statusCode == 200) {
        final html = (response.data as String?) ?? '';
        final message = _parseLoginFailureMessage(html) ?? _genericLoginFailureMessage;
        throw ValidationException({'form': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `users.views.send_email_otp` (`ApiEndpoints.sendEmailOtp`) — always
  /// JSON, never a redirect, so this doesn't need the 302/200 dance
  /// `login`/`register` use. `validateStatus: (_) => true` so a 400/429
  /// body (which carries the real, user-facing `error` string) can be read
  /// directly instead of being collapsed into a generic mapped
  /// [AppException] by [ApiExceptionsInterceptor] (which has no way to
  /// know this particular 400/429 body is meant to be shown verbatim).
  Future<String> sendOtp(String email) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.sendEmailOtp,
        data: {'email': email},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (_) => true,
          headers: {'X-CSRFToken': csrfToken ?? '', 'X-Requested-With': 'XMLHttpRequest'},
        ),
      );
      final body = response.data;
      if (response.statusCode == 200 && body is Map && body['ok'] == true) {
        return (body['message'] as String?) ?? 'A verification code has been sent.';
      }
      final errorMessage = body is Map ? body['error'] as String? : null;
      if (response.statusCode == 429) {
        throw RateLimitException(errorMessage ?? 'Too many verification requests. Please try again later.');
      }
      throw ValidationException(
        {'email': [errorMessage ?? 'Could not send the code.']},
        errorMessage ?? 'Could not send the code.',
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `users.views.verify_email_otp` (`ApiEndpoints.verifyEmailOtp`) — same
  /// JSON-always shape as [sendOtp]. Success marks `email` verified in the
  /// *server-side session* (`_mark_email_verified`), which is what
  /// [register] ultimately relies on — this call's return value is purely
  /// UI feedback, not something this client needs to track itself.
  Future<String> verifyOtp({required String email, required String code}) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.verifyEmailOtp,
        data: {'email': email, 'otp': code},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (_) => true,
          headers: {'X-CSRFToken': csrfToken ?? '', 'X-Requested-With': 'XMLHttpRequest'},
        ),
      );
      final body = response.data;
      if (response.statusCode == 200 && body is Map && body['ok'] == true) {
        return (body['message'] as String?) ?? 'Verified.';
      }
      final errorMessage = body is Map ? body['error'] as String? : null;
      throw ValidationException(
        {'otp': [errorMessage ?? 'Incorrect code.']},
        errorMessage ?? 'Incorrect code.',
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  static const _genericRegisterFailureMessage =
      'Registration failed — please check your details (including both email OTP '
      'verifications) and try again.';

  /// `signup.html`'s per-field error blocks — the exact same `<div
  /// class="invalid-feedback d-block">{{ form.X.errors.0 }}</div>`
  /// convention `AuthRemoteDataSource.register`'s own
  /// `_registerFieldErrorPattern` already scrapes for the student form (and
  /// `ProfileRemoteDataSource`'s before that) — covers both the unverified-
  /// email branch (`accounts_app/views.py:58-64`, `form.add_error('email',
  /// ...)`/`form.add_error('hr_mail', ...)`) and ordinary field-validation
  /// failures. Re-declared here per this codebase's file-local-regex
  /// convention rather than shared.
  static final _registerFieldErrorPattern = RegExp(r'invalid-feedback d-block">([^<]+)<');

  /// `signup.html:291-298`'s whole-form error block — same markup as
  /// `AuthRemoteDataSource.register`'s own `_registerNonFieldErrorPattern`.
  /// `EmployerRegisterForm` has no `clean()` override today (confirmed), so
  /// this is expected to never actually match — scanned anyway so a future
  /// non-field error isn't silently dropped.
  static final _registerNonFieldErrorPattern = RegExp(
    r'<i class="fas fa-exclamation-circle me-1"></i>([^<]*)<br>',
  );

  /// Every real, specific error Django rendered for a failed employer
  /// registration, joined one per line — or `null` if nothing recognizable
  /// was found (never a guess; callers fall back to
  /// [_genericRegisterFailureMessage]).
  static String? _parseRegisterFailureMessage(String html) {
    final messages = [
      for (final m in _registerFieldErrorPattern.allMatches(html)) m.group(1)!.trim(),
      for (final m in _registerNonFieldErrorPattern.allMatches(html)) m.group(1)!.trim(),
    ].where((m) => m.isNotEmpty).map(_unescape).toSet().toList();
    return messages.isEmpty ? null : messages.join('\n');
  }

  /// `accounts_app.views.employer_register` — a `multipart/form-data` POST
  /// (`enctype="multipart/form-data"`, `signup.html:134`, needed for the
  /// optional `company_logo` file), same 302-success/200-failure contract
  /// as [login]. The server independently re-checks both emails against
  /// the *session's* verified-emails list (`is_email_verified`,
  /// `accounts_app/views.py:54-64`) — this call relies on [sendOtp]/
  /// [verifyOtp] having already run against this same cookie jar, exactly
  /// as the web's own JS/session flow does; there is nothing extra this
  /// client needs to send to prove it.
  Future<String> register(EmployerRegistrationData data) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final formData = FormData.fromMap({
        'username': data.username,
        'password1': data.password,
        'password2': data.passwordConfirm,
        'email': data.email,
        'first_name': data.firstName,
        'last_name': data.lastName,
        'company_name': data.companyName,
        'company_gst': data.companyGst,
        'company_pan_tin': data.companyPanTin,
        'company_address': data.companyAddress,
        'industry': data.industry,
        'hr_contact': data.hrContactE164,
        'hr_mail': data.hrMail,
        'csrfmiddlewaretoken': csrfToken ?? '',
        if (data.companyLogoPath != null)
          'company_logo': await MultipartFile.fromFile(data.companyLogoPath!),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.employerRegister,
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) {
        return data.username;
      }
      if (response.statusCode == 200) {
        final html = (response.data as String?) ?? '';
        final message = _parseRegisterFailureMessage(html) ?? _genericRegisterFailureMessage;
        throw ValidationException({'form': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// Django's CSRF cookie is only set on a response to a GET of a page
  /// that renders `{% csrf_token %}` (or any view using
  /// `ensure_csrf_cookie`) — `sendOtp`/`register` are themselves POSTs, so
  /// unlike `login` (which always GETs its own page first) they need this
  /// explicit check first if nothing has primed the cookie jar yet this
  /// session (e.g. the user opened the register screen directly, without
  /// visiting the login screen first).
  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.employerRegister);
  }
}
