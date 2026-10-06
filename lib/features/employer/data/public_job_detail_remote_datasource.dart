import 'package:dio/dio.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/entities/public_job_detail.dart';
import 'public_job_detail_html_parser.dart';

/// `jobs_app.views.job_detail` — GET parses the public job page; POST
/// submits an application. Two distinct 200-failure shapes exist (both
/// re-render the same page, no redirect): a per-field validation error
/// (`{{ field.errors }}`), or a duplicate-application flash message
/// (`messages.error`, rendered by `base.html`'s shared `.alert` markup) —
/// the real view swallows the actual duplicate-key exception and always
/// shows the same generic "You have already applied for this job."
/// regardless of cause (`jobs_app/views.py:468-473`).
class PublicJobDetailRemoteDataSource {
  PublicJobDetailRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static final _fieldErrorPattern = RegExp(r'invalid-feedback[^"]*">\s*<ul class="errorlist"><li>([^<]+)</li>|text-danger small mt-1">\s*<ul class="errorlist"><li>([^<]+)</li>');
  static final _flashErrorPattern = RegExp(r'alert alert-(?:error|danger)[^"]*"[^>]*>\s*(?:<i[^>]*></i>\s*)?([\s\S]*?)\s*<button');

  Future<PublicJobDetail> getJobDetail(int pk) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.publicJobDetail(pk),
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      if (response.statusCode != 200) throw ServerException(response.statusCode);
      return parsePublicJobDetailHtml(response.data ?? '');
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  Future<void> apply(int jobId, PublicJobApplicationSubmission data) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final formData = FormData.fromMap({
        'applicant_name': data.name,
        'applicant_email': data.email,
        'applicant_phone': data.phoneE164,
        'cover_letter': data.coverLetter,
        'applicant_skills': data.skills,
        if (data.yearsExperience != null) 'years_experience': data.yearsExperience.toString(),
        'current_company': data.currentCompany,
        if (data.currentSalary != null) 'current_salary': data.currentSalary.toString(),
        if (data.expectedSalary != null) 'expected_salary': data.expectedSalary.toString(),
        'csrfmiddlewaretoken': csrfToken ?? '',
        if (data.resumePath != null) 'resume': await MultipartFile.fromFile(data.resumePath!),
      });

      final response = await _apiClient.dio.post(
        ApiEndpoints.publicJobDetail(jobId),
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
        final fieldError = _fieldErrorPattern.firstMatch(body);
        if (fieldError != null) {
          final message = (fieldError.group(1) ?? fieldError.group(2))!.trim();
          throw ValidationException({'form': [message]}, message);
        }
        final flashError = _flashErrorPattern.firstMatch(body);
        final message = flashError?.group(1)?.trim() ?? 'Could not submit your application — please try again.';
        throw ValidationException({'form': [message]}, message);
      }
      throw ServerException(response.statusCode);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
