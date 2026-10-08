import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/django_bool.dart';
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
/// - The backend renders one generic error for both "wrong credentials"
///   and "employer account used on the student portal" — the JSON contract
///   doesn't expose which, so this reports one generic
///   [ValidationException] rather than scraping the rendered HTML for the
///   exact message.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

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
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) {
        return usernameOrEmail;
      }
      if (response.statusCode == 200) {
        const message = 'Invalid username or password, or this account cannot sign in here.';
        throw const ValidationException({'form': [message]}, message);
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
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) {
        return data.username;
      }
      if (response.statusCode == 200) {
        const message =
            'Registration failed — please check your details (including your email OTP '
            'verification) and try again.';
        throw const ValidationException({'form': [message]}, message);
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
