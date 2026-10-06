import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
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
/// - Same 302-success / 200-failure distinction as student login, and the
///   same reason for one generic error message: the login page
///   (`templates/employer_login/login.html:84-99`) renders Django's
///   per-field form errors, one of which is the employer-profile check's
///   own message ("Student accounts cannot log in through the employer
///   portal.") and another the generic "wrong credentials" one — the
///   200-vs-302 HTTP-status contract doesn't expose which, so (consistent
///   with [AuthRemoteDataSource]) this reports one message that covers
///   both rather than scraping the rendered HTML for the exact text.
class EmployerAuthRemoteDataSource {
  EmployerAuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

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
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) {
        return usernameOrEmail;
      }
      if (response.statusCode == 200) {
        const message =
            'Invalid username or password, or this account cannot sign in through the employer portal.';
        throw const ValidationException({'form': [message]}, message);
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
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) {
        return data.username;
      }
      if (response.statusCode == 200) {
        const message =
            'Registration failed — please check your details (including both email OTP '
            'verifications) and try again.';
        throw const ValidationException({'form': [message]}, message);
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
