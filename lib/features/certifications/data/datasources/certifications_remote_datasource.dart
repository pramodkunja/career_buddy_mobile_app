import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/certification_subject.dart';
import '../../domain/entities/certifications_status.dart';
import '../models/certification_subject_model.dart';
import '../models/certifications_status_model.dart';

/// `skillup_assessment`'s JSON API — see `ApiEndpoints`'s Certifications
/// doc comment for the exact verified paths/methods.
class CertificationsRemoteDataSource {
  CertificationsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GET api_certifications_status`.
  Future<CertificationsStatus> getStatus() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.certificationsStatus);
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        // A redirect-to-login (followed automatically) or any other
        // non-JSON response lands here — never treated as valid data.
        throw const UnexpectedResponseException();
      }
      return CertificationsStatusParsing.fromJson(body);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }

  /// `POST api_certificate_generate` — first-time generation.
  Future<CertificationSubject> generateCertificate({required String subject, required String name}) =>
      _submitCertificateName(ApiEndpoints.certificateGenerate(subject), name);

  /// `POST api_certificate_regenerate` — edits the printed name on an
  /// already-generated certificate and re-renders the PDF.
  Future<CertificationSubject> regenerateCertificate({required String subject, required String name}) =>
      _submitCertificateName(ApiEndpoints.certificateRegenerate(subject), name);

  /// Both `api_certificate_generate`/`api_certificate_regenerate` are
  /// `@require_http_methods(["POST"])`, **not** `@csrf_exempt`, and read
  /// `request.POST.get("certificate_name", "")` — a form-encoded field, not
  /// a JSON body — then respond `{"subject": {...full updated subject...}}`
  /// on success (`skillup_assessment/views.py:369`/`394`), or
  /// `{"error": "..."}` with a non-2xx status (403 not eligible, 400 an
  /// invalid name) on failure. Same `FormData` + CSRF-cookie-priming
  /// technique as `ResumeRemoteDataSource.uploadAndAnalyze`.
  Future<CertificationSubject> _submitCertificateName(String path, String name) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');

      final response = await _apiClient.dio.post(
        path,
        data: FormData.fromMap({
          'csrfmiddlewaretoken': csrfToken ?? '',
          'certificate_name': name,
        }),
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const UnexpectedResponseException();
      }
      return CertificationSubjectParsing.fromJson(requireMap(body, 'subject'));
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }

  /// `GET certificate_download` — the generated PDF as raw bytes. Fetched
  /// through this app's own authenticated Dio client (the endpoint is
  /// `@login_required` and serves a binary `FileResponse`), the same
  /// technique `GrammarMediaDataSource.fetchSlideImage` already uses.
  Future<Uint8List> downloadCertificateBytes(String subject) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        ApiEndpoints.certificateDownload(subject),
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// Django's CSRF cookie is only set on a response to a GET of a page that
  /// renders `{% csrf_token %}` — primes it from the Certifications hub
  /// page itself if nothing has set it yet this session (e.g. it should
  /// already be set from the login page, but this is defensive, same as
  /// `ResumeRemoteDataSource._ensureCsrfCookie`).
  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.certificationsHub);
  }
}
