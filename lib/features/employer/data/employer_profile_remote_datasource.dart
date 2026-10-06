import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/employer_profile_form.dart';
import 'employer_profile_html_parser.dart';

/// `jobs_app.views.employer_profile_edit`/`employer_profile_create` — same
/// template (`employer/profile_form.html`), same `EmployerProfileForm`,
/// different target URL depending on which one the caller is meant to hit
/// (see [ApiEndpoints.employerProfileEdit]/[employerProfileCreate]'s doc
/// comments). GET parses the pre-filled form; POST is
/// `multipart/form-data` (the optional `company_logo` file upload), same
/// 302-success/200-failure convention already proven for the student
/// profile and registration flows.
class EmployerProfileRemoteDataSource {
  EmployerProfileRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static final _fieldErrorPattern = RegExp(r'text-danger small mt-1">\s*<ul class="errorlist"><li>([^<]+)</li>');

  Future<EmployerProfileFormData> getProfileForm({required bool isCreate}) async {
    try {
      final response = await _apiClient.dio.get<String>(
        isCreate ? ApiEndpoints.employerProfileCreate : ApiEndpoints.employerProfileEdit,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parseEmployerProfileFormHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  Future<void> updateProfile(EmployerProfileSubmission data, {required bool isCreate}) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final formData = FormData.fromMap({
        'company_name': data.companyName,
        'company_website': data.companyWebsite,
        'industry': data.industry,
        'company_size': data.companySize,
        'location': data.location,
        'description': data.description,
        'company_address': data.companyAddress,
        'company_gst': data.companyGst,
        'company_pan_tin': data.companyPanTin,
        'hr_contact': data.hrContactE164,
        'hr_mail': data.hrMail,
        'csrfmiddlewaretoken': csrfToken ?? '',
        if (data.companyLogoPath != null) 'company_logo': await MultipartFile.fromFile(data.companyLogoPath!),
      });

      final response = await _apiClient.dio.post(
        isCreate ? ApiEndpoints.employerProfileCreate : ApiEndpoints.employerProfileEdit,
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );

      if (response.statusCode == 302) return;
      if (response.statusCode == 200) {
        final String body = response.data ?? '';
        final message = _fieldErrorPattern.firstMatch(body)?.group(1)?.trim() ??
            'Could not save your company profile — please check your details and try again.';
        throw ValidationException({'form': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
