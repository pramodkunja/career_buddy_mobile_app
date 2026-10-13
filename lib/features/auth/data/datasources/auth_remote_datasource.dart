import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/django_bool.dart';
import '../../../../core/utils/html_unescape.dart';
import '../../domain/entities/student_registration_data.dart';

/// Talks to the Django session-auth login view directly (there is no JSON
/// login API — see `ApiEndpoints` and `ARCHITECTURE.md`). Verified against
/// `users/views.py:login_view` and `users/forms.py:LoginForm`:
///
/// - GET `/login/` first, to receive the `csrftoken` cookie.
/// - POST form-encoded `{username, password, csrfmiddlewaretoken}` with the
///   CSRF token repeated in the `X-CSRFToken` header (Django accepts
///   either).
/// - Redirects must NOT be auto-followed: a successful login responds with
///   a 302; a failed one re-renders the same form with a 200. Auto-follow
///   would turn both into a 200 on the destination page, making them
///   indistinguishable.
/// - **Phase 14**: a failed login's 200 response actually renders a real,
///   specific, safe-to-show error — `login()` now scrapes it instead of
///   reporting one hardcoded generic string for every failure. Two real,
///   distinct cases exist (`users/views.py:222-244`, re-read this phase):
///   (1) `LoginForm.clean()` (`users/forms.py:575-583`) raises
///   "Employer accounts cannot log in through the student portal." when the
///   submitted credentials belong to an employer account — rendered inside
///   `login.html:49-65`'s own `.alert.alert-danger` block, found by
///   [_parseFormErrorAlert]. (2) A 5-failed-attempts/15-minute lockout
///   (`LOGIN_FAILURE_LIMIT`/`LOGIN_LOCKOUT_SECONDS`, `users/views.py:195-
///   196`, checked *before* form validation, so it never populates
///   `form.errors` at all) instead flashes "Too many failed login attempts.
///   Please try again in a few minutes." via Django's `messages` framework
///   — the same shared `.messages-container` (`base.html:224-235`) every
///   other flashed error in this app already uses, found by
///   [_parseFlashedMessage]. Both are checked, in that priority order
///   (form-level first, since it's the more specific signal when present);
///   if neither matches, [_genericLoginFailureMessage] is used — never a
///   guess, and never anything that would reveal whether a given username
///   exists (Django's own default "wrong credentials" wording, which this
///   client only ever surfaces verbatim via [_parseFormErrorAlert], never
///   paraphrases or infers from the status code alone).
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static const _genericLoginFailureMessage =
      'Invalid username or password, or this account cannot sign in here.';

  /// `login.html:49-65`'s own `<div class="alert alert-danger py-2
  /// rounded-3 small mb-4" ...>` — every `form.errors` entry Django
  /// rendered (the login form's `clean()` raises at most one, so a single
  /// match is expected, but this still scans every error this exact block
  /// contains rather than assuming there's only one). The web page's own
  /// `me-1` icon margin on this specific block (vs. `base.html`'s flashed
  /// messages, which use `me-2`) is incidental, but happens to keep the two
  /// patterns from ever cross-matching the wrong block even without
  /// scoping to the outer div first.
  static final _loginFormErrorPattern = RegExp(
    r'<i class="fas fa-exclamation-circle me-1"></i>\s*([\s\S]*?)\s*</div>',
  );

  /// `base.html:224-235`'s shared flashed-message container — the same
  /// `role="alert"` signal already established elsewhere in this app (e.g.
  /// `resume_html_parser.dart`'s `parseFlashedErrorMessage`) as this
  /// codebase's generic "a Django `messages.error(...)` was flashed" scrape.
  /// Re-declared here (not imported) per this codebase's own convention of
  /// keeping each feature's regexes file-local rather than sharing them
  /// across unrelated features.
  static final _flashedMessagePattern = RegExp(
    r'class="alert alert-[a-z]+[^"]*"[^>]*role="alert">\s*(?:<i[^>]*></i>\s*)?([^<]*)',
  );

  static String _unescape(String value) => unescapeHtmlEntities(value);

  /// Returns the real error Django rendered for a failed login, or `null`
  /// if neither known pattern matched (never a guess — callers fall back to
  /// [_genericLoginFailureMessage]).
  static String? _parseLoginFailureMessage(String html) {
    final formError = _loginFormErrorPattern.firstMatch(html)?.group(1)?.trim();
    if (formError != null && formError.isNotEmpty) return _unescape(formError);
    final flashed = _flashedMessagePattern.firstMatch(html)?.group(1)?.trim();
    if (flashed != null && flashed.isNotEmpty) return _unescape(flashed);
    return null;
  }

  Future<String> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      await _apiClient.dio.get(ApiEndpoints.login);
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
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

  Future<void> logout() async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      await _apiClient.dio.post(
        ApiEndpoints.logout,
        options: Options(
          headers: {'X-CSRFToken': csrfToken ?? ''},
          // A real, successful logout responds 302 (same
          // redirect-on-success convention as `login()` above), which
          // falls outside Dio's default 200-299 `validateStatus` range.
          // Confirmed live against production: without this, a genuinely
          // successful logout was thrown as a DioException, mapped to
          // UnexpectedFailure by ApiExceptionsInterceptor, and shown to the
          // user as "Something unexpected happened" right after a correct
          // logout (cookies were still cleared either way by the `finally`
          // below, so only the displayed message was wrong).
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } finally {
      await _apiClient.clearCookies();
    }
  }

  /// Email OTP send/verify (`users/urls.py:'register/send-otp/'`/
  /// `'verify-otp/'`) — the exact same shared endpoints
  /// `EmployerAuthRemoteDataSource.sendOtp`/`verifyOtp` already call; see
  /// that class's doc comment for the full request-shape rationale.
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
      'Registration failed — please check your details (including your email OTP '
      'verification) and try again.';

  /// `register.html`'s per-field error blocks — `{% if form.X.errors %}
  /// <div class="invalid-feedback d-block">{{ form.X.errors.0 }}</div>
  /// {% endif %}`, confirmed present for every field this form has (e.g.
  /// `register.html:189` for `email`, covering both the "this email ID is
  /// already in use" and "verify this email address" branches
  /// `users/views.py:161-171` adds via `form.add_error('email', ...)`, not
  /// just ordinary field-validation failures). Exactly the same markup
  /// convention `ProfileRemoteDataSource`'s own `_fieldErrorPattern` already
  /// scrapes — re-declared here per this codebase's file-local-regex
  /// convention, not shared, since Django renders no field name alongside
  /// each error (only inside the stripped `{% if %}` tag itself), so
  /// (consistent with that existing precedent) only the message text is
  /// recoverable, never which field it belongs to.
  static final _registerFieldErrorPattern = RegExp(r'invalid-feedback d-block">([^<]+)<');

  /// `register.html:520-528`'s whole-form error block — `{% for error in
  /// form.non_field_errors %}<i class="fas fa-exclamation-circle
  /// me-1"></i>{{ error }}<br>{% endfor %}`. `RegisterForm` itself never
  /// raises a non-field `ValidationError` today (confirmed: no `clean()`
  /// override exists on it), so this is expected to never actually match in
  /// practice — scanned anyway so a future server-side change that does add
  /// one is not silently dropped.
  static final _registerNonFieldErrorPattern = RegExp(
    r'<i class="fas fa-exclamation-circle me-1"></i>([^<]*)<br>',
  );

  /// Every real, specific error Django rendered for a failed registration
  /// (field errors, then any whole-form error), joined one per line — or
  /// `null` if nothing recognizable was found (never a guess; callers fall
  /// back to [_genericRegisterFailureMessage]).
  static String? _parseRegisterFailureMessage(String html) {
    final messages = [
      for (final m in _registerFieldErrorPattern.allMatches(html)) m.group(1)!.trim(),
      for (final m in _registerNonFieldErrorPattern.allMatches(html)) m.group(1)!.trim(),
    ].where((m) => m.isNotEmpty).map(_unescape).toSet().toList();
    return messages.isEmpty ? null : messages.join('\n');
  }

  /// `users/views.py:register_view` — `multipart/form-data` (the resume
  /// upload requires it), same 302-success/200-failure convention as
  /// [login]. The server independently re-checks the email against the
  /// *session's* verified-emails list (`is_email_verified`) — this relies
  /// on [sendOtp]/[verifyOtp] having already run against this same cookie
  /// jar, matching the web's own session-based flow.
  Future<String> register(StudentRegistrationData data) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final formData = FormData.fromMap({
        'first_name': data.firstName,
        'last_name': data.lastName,
        'email': data.email,
        'username': data.username,
        'password1': data.password,
        'password2': data.passwordConfirm,
        'gender': data.gender,
        'mobile': data.mobile,
        'alternate_mobile': data.alternateMobile,
        'blood_group': data.bloodGroup,
        'languages_known': data.languagesKnown,
        'aadhar_number': data.aadharNumber,
        'pan_number': data.panNumber,
        'passport_number': data.passportNumber,
        'education_level': data.educationLevel,
        if (data.passedOutYear != null) 'passed_out_year': data.passedOutYear.toString(),
        'iti_diploma_specialization': data.itiDiplomaSpecialization,
        'higher_education_degree': data.higherEducationDegree,
        'education_level_2': data.educationLevel2,
        if (data.passedOutYear2 != null) 'passed_out_year_2': data.passedOutYear2.toString(),
        'iti_diploma_specialization_2': data.itiDiplomaSpecialization2,
        'higher_education_degree_2': data.higherEducationDegree2,
        // `has_experience`/`has_abroad_experience` need Python's `str(bool)`
        // convention (`"True"`/`"False"`), not Dart's lowercase
        // `bool.toString()` — see `djangoBool`'s doc comment.
        if (data.hasExperience != null) 'has_experience': djangoBool(data.hasExperience!),
        if (data.experienceYears != null) 'experience_years': data.experienceYears.toString(),
        'company_name': data.companyName,
        'contact_person_role': data.contactPersonRole,
        'contact_person_mobile': data.contactPersonMobile,
        'contact_person_email': data.contactPersonEmail,
        'industry': data.industry,
        'skills': data.skills,
        if (data.currentCtc != null) 'current_ctc': data.currentCtc.toString(),
        if (data.expectedCtc != null) 'expected_ctc': data.expectedCtc.toString(),
        'certification': data.certification,
        'current_location': data.currentLocation,
        'preferred_location': data.preferredLocation,
        if (data.hasAbroadExperience != null) 'has_abroad_experience': djangoBool(data.hasAbroadExperience!),
        if (data.abroadYears != null) 'abroad_years': data.abroadYears.toString(),
        'abroad_country': data.abroadCountry,
        'abroad_industry': data.abroadIndustry,
        'abroad_skills': data.abroadSkills,
        'csrfmiddlewaretoken': csrfToken ?? '',
        'resume': await MultipartFile.fromFile(data.resumeFilePath, filename: data.resumeFileName),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
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

  /// Same reasoning as `EmployerAuthRemoteDataSource._ensureCsrfCookie` —
  /// `sendOtp`/`register` are themselves POSTs, so they need an explicit
  /// priming GET first if nothing has set the `csrftoken` cookie yet this
  /// session (e.g. the user opened the register screen directly).
  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.register);
  }
}
