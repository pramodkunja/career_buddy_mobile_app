import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/writing_analysis_result.dart';
import '../models/writing_analysis_result_model.dart';

/// `POST /activities/exercise/<id>/analyze/writing/`
/// (`activities/views.py:1690-1767`) — see `ApiEndpoints.analyzeWriting`'s
/// doc comment for the full contract, including the confirmed `score_25`
/// placement difference from `analyzeSpeaking`. Not `@csrf_exempt`, so —
/// mirroring `AiSpeakingRemoteDataSource` — this reads the `csrftoken`
/// cookie and sends it as `X-CSRFToken`.
///
/// The web's `formData.append("module", "writing")` is deliberately not
/// sent here — confirmed by reading `analyze_writing` line by line that it
/// never calls `request.POST.get('module', ...)` at all; it is a vestigial
/// field the view does not consume.
class AiWritingRemoteDataSource {
  AiWritingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<WritingAnalysisResult> analyze({
    required int exerciseId,
    required String text,
    required String language,
    required String referenceText,
    String? previousImprovedPassage,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final formData = FormData.fromMap({
        'text': text,
        'language': language,
        'reference_text': referenceText,
        if (previousImprovedPassage != null && previousImprovedPassage.isNotEmpty)
          'previous_improved_passage': previousImprovedPassage,
      });
      final response = await _apiClient.dio.post(
        ApiEndpoints.analyzeWriting(exerciseId),
        data: formData,
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) throw const UnexpectedResponseException();

      // Same contract as analyzeSpeaking: a rejected submission (e.g. too
      // short/too long) still comes back as HTTP 200 — `"success"` in the
      // body, not the HTTP status, is authoritative here.
      final success = body['success'];
      if (success != true) {
        final message = body['error'] is String ? body['error'] as String : 'Writing analysis failed.';
        throw ValidationException(const {}, message);
      }

      return WritingAnalysisResultParsing.fromJson(body);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
