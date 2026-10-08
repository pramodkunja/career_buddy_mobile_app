import 'package:dio/dio.dart';

import '../errors/exceptions.dart';
import '../network/api_client.dart';

/// Downloads a session-cookie-protected file — a student's own resume, an
/// employer's view of a candidate's resume, or an AI mock-interview
/// recording (`core/media_views.py:serve_protected_media` on the real
/// backend, an SR-04 security fix gating these three categories behind
/// `@login_required` + per-user ownership checks instead of Django's
/// unauthenticated `static()` media serving) — through this app's own
/// authenticated Dio client.
///
/// This matters because the device's external browser does NOT share this
/// app's Dio cookie jar: opening one of these URLs there bounces the user
/// to a login prompt instead of showing the file, exactly the problem
/// `CertificateDownloadController` already solves for certificates. This
/// generalizes that same technique so Resume History, Employer Application
/// Detail, and Candidate Search can all reuse it instead of three separate
/// copies.
class ProtectedMediaRemoteDataSource {
  ProtectedMediaRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// [resolvedUrl] — see `resolveMediaUrl` — may be absolute or
  /// `ApiClient`'s own `baseUrl`-relative; Dio resolves either correctly
  /// against its configured `baseUrl`.
  Future<List<int>> downloadBytes(String resolvedUrl) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        resolvedUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
