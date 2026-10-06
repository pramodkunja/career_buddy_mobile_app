import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/listening_analysis_result.dart';
import '../models/listening_analysis_result_model.dart';
import '../models/listening_page_config.dart';

/// See `ApiEndpoints.exerciseDetailPage`/`analyzeListening`'s doc comments
/// for the full, independently-verified contract of each request this
/// class makes.
class AiListeningRemoteDataSource {
  AiListeningRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /activities/exercise/<id>/` — the existing, plain HTML
  /// `exercise_detail` view. Reads the fresh `attempt_token` the server
  /// mints on every page render out of the embedded
  /// `<script type="application/json" id="listening-config">` blob. This
  /// is the *only* way to obtain a valid token — there is no JSON
  /// endpoint for it — and it is the same request a browser makes when
  /// opening this exercise, authenticated by the same session cookie this
  /// app's `ApiClient` already persists.
  Future<String> fetchAttemptToken(int exerciseId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.exerciseDetailPage(exerciseId),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();

      final config = extractEmbeddedJsonConfig(html, 'listening-config');
      if (config == null) {
        // Most commonly: the activity is locked and the server redirected
        // to the Activities list instead (`_locked_redirect()`), which has
        // no such tag — surfaced honestly rather than a confusing parse
        // error.
        throw const ValidationException(
          {},
          "Couldn't start this listening exercise. It may require an upgrade, or the page format has changed.",
        );
      }
      final token = config['attemptToken'];
      if (token is! String || token.isEmpty) throw const UnexpectedResponseException();
      return token;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  Future<ListeningAnalysisResult> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({
        'text': text,
        'reference_text': referenceText,
        'duration_seconds': durationSeconds.toString(),
        'pause_count': pauseCount.toString(),
        'attempt_token': attemptToken,
        'language': language,
      });
      final response = await _apiClient.dio.post(
        ApiEndpoints.analyzeListening(exerciseId),
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) throw const UnexpectedResponseException();

      final success = body['success'];
      if (success != true) {
        final message = body['error'] is String ? body['error'] as String : 'Listening analysis failed.';
        throw ValidationException(const {}, message);
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return ListeningAnalysisResultParsing.fromJson(data);
    } on DioException catch (e) {
      // A missing/reused attempt_token is a genuine 409 (not the usual
      // 200-with-success:false contract Speaking/Writing use) — verified
      // directly against `analyze_listening`. The shared
      // `ApiExceptionsInterceptor` maps any non-2xx it has no specific
      // case for to `UnexpectedResponseException`, the same uniform
      // handling already relied on for Writing's 400/403 cases — not a
      // W016-specific gap.
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }
}
