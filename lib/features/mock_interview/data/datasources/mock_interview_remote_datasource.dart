import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/answer_submission_result.dart';
import '../../domain/entities/interview_analytics.dart';
import '../../domain/entities/interview_question.dart';
import '../../domain/entities/malpractice.dart';
import '../../domain/entities/next_question_outcome.dart';
import 'mock_interview_html_parser.dart';

/// `career_app.views` — AI Mock Interview. See `ApiEndpoints`'s doc comment
/// on the endpoints used here for exactly what was verified against source
/// and why `resume_transcribe_answer`/`resume_interview_chat` are
/// deliberately not called by this client.
class MockInterviewRemoteDataSource {
  MockInterviewRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `resume_start_interview`, following its redirect chain (see
  /// `ApiEndpoints.resumeStartInterview`'s doc comment).
  Future<void> startInterview() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.resumeStartInterview,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      final html = response.data ?? '';
      if (isMockInterviewSessionHtml(html)) return;
      final message = parseMockInterviewFlashedMessage(html) ??
          'AI Mock Interview is not available right now. Please make sure your resume has been '
              'analyzed and your plan includes this feature.';
      throw ValidationException({'interview': [message]}, message);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_camera_verified` (`@require_POST`).
  Future<void> confirmCameraLive() async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.resumeCameraVerified,
        data: FormData.fromMap({'csrfmiddlewaretoken': csrfToken ?? ''}),
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}, validateStatus: (_) => true),
      );
      if (response.statusCode == 200 && response.data?['ok'] == true) return;
      throw const UnexpectedResponseException();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_get_next_question` (`@require_GET`). [advance] is the
  /// `?next=true` flag.
  Future<NextQuestionOutcome> getNextQuestion({required bool advance}) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.resumeGetNextQuestion,
        queryParameters: advance ? {'next': 'true'} : null,
        options: Options(validateStatus: (_) => true),
      );
      final data = response.data ?? const <String, dynamic>{};
      _throwKnownErrors(response.statusCode, data);
      if (response.statusCode != 200) throw _mapStatus(response.statusCode);

      if (data['status'] == 'completed') return const InterviewCompleted();

      return NextQuestionReady(
        InterviewQuestion(
          id: data['id'] as int,
          text: (data['text'] as String?) ?? '',
          topic: (data['topic'] as String?) ?? 'General',
          difficulty: (data['difficulty'] as String?) ?? 'Easy',
          isCoding: (data['is_coding'] as bool?) ?? false,
          questionType: (data['question_type'] as String?) ?? 'theory',
          progress: (data['progress'] as String?) ?? '1/20',
          timeLimitSeconds: (data['time_limit'] as num?)?.toInt() ?? 30,
          timeRemainingSeconds: (data['time_remaining'] as num?)?.toInt() ?? 30,
        ),
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_submit_answer` (`@require_POST`).
  Future<AnswerSubmissionResult> submitAnswer({required int questionId, required String answerText}) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.resumeSubmitAnswer,
        data: FormData.fromMap({
          'question_id': questionId.toString(),
          'answer_text': answerText,
          'csrfmiddlewaretoken': csrfToken ?? '',
        }),
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}, validateStatus: (_) => true),
      );
      final data = response.data ?? const <String, dynamic>{};
      _throwKnownErrors(response.statusCode, data);
      if (response.statusCode != 200) throw _mapStatus(response.statusCode);

      return AnswerSubmissionResult(
        score: (data['score'] as num?)?.toInt() ?? 0,
        feedback: (data['feedback'] as String?) ?? '',
        timedOut: (data['timed_out'] as bool?) ?? false,
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_violation_state` (`@require_GET`).
  Future<ViolationState> getViolationState() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(ApiEndpoints.resumeViolationState);
      final data = response.data ?? const <String, dynamic>{};
      return ViolationState(
        count: (data['count'] as num?)?.toInt() ?? 0,
        status: MalpracticeStatusApi.fromApi(data['status'] as String?),
        flagThreshold: (data['flag_threshold'] as num?)?.toInt() ?? 3,
        terminateThreshold: (data['terminate_threshold'] as num?)?.toInt() ?? 5,
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_record_violation` (`@require_POST`).
  Future<ViolationRecordResult> recordViolation({required ViolationType type, double? durationSeconds}) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final fields = <String, String>{'type': type.apiValue, 'csrfmiddlewaretoken': csrfToken ?? ''};
      if (durationSeconds != null) fields['duration_seconds'] = durationSeconds.toString();

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.resumeRecordViolation,
        data: FormData.fromMap(fields),
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final data = response.data ?? const <String, dynamic>{};
      return ViolationRecordResult(
        count: (data['count'] as num?)?.toInt() ?? 0,
        status: MalpracticeStatusApi.fromApi(data['status'] as String?),
        action: ViolationActionApi.fromApi(data['action'] as String?),
        typeOccurrenceNumber: (data['type_occurrence_number'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_upload_interview_video` (`@require_POST`, multipart `video`) —
  /// see `MockInterviewRepositoryImpl.uploadInterviewVideo`'s doc comment
  /// for why this is best-effort and never surfaces as a blocking failure.
  Future<bool> uploadInterviewVideo(String filePath, {String filename = 'interview.mp4'}) async {
    try {
      await _ensureCsrfCookie();
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        ApiEndpoints.resumeUploadInterviewVideo,
        data: FormData.fromMap({
          'video': await MultipartFile.fromFile(filePath, filename: filename),
          'csrfmiddlewaretoken': csrfToken ?? '',
        }),
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}, validateStatus: (_) => true),
      );
      return response.statusCode == 200 && response.data?['stored'] == true;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `resume_analytics` — plain HTML, no JSON sibling.
  Future<InterviewAnalyticsResult> getAnalytics() async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.resumeAnalytics,
        options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
      );
      final html = response.data ?? '';
      if (!isInterviewAnalyticsHtml(html)) {
        throw const NotFoundException('No completed interview results were found.');
      }
      return parseInterviewAnalyticsHtml(html);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  /// `career_app/views.py:1191-1199`/`1323-1332` — both `resume_get_next_
  /// question` and `resume_submit_answer` return this exact 403 shape.
  /// Thrown here (with `validateStatus: (_) => true` in effect, so no
  /// [DioException] is raised for a 403) rather than left to
  /// [ApiExceptionsInterceptor]'s generic [ForbiddenException], so the
  /// caller can tell these two specific, actionable outcomes apart from an
  /// ordinary permission error.
  void _throwKnownErrors(int? statusCode, Map<String, dynamic> data) {
    if (statusCode == 403 && data['error'] == 'camera_required') {
      throw CameraRequiredException(
        (data['message'] as String?) ??
            'Camera access is required to attend the interview. Please allow camera access and try again.',
      );
    }
    if (statusCode == 403 && data['error'] == 'malpractice_terminated') {
      throw MalpracticeTerminatedException(
        (data['message'] as String?) ?? 'This interview was ended due to repeated malpractice violations.',
      );
    }
  }

  /// Mirrors `ApiExceptionsInterceptor._fromStatusCode` — needed here
  /// because `validateStatus: (_) => true` (required so [_throwKnownErrors]
  /// can read a non-2xx body) bypasses the interceptor's own status-code
  /// mapping for any status this method doesn't itself recognize.
  AppException _mapStatus(int? statusCode) {
    switch (statusCode) {
      case 401:
        return const UnauthorizedException();
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 429:
        return const RateLimitException();
      default:
        if (statusCode != null && statusCode >= 500) return ServerException(statusCode);
        return const UnexpectedResponseException();
    }
  }

  /// Django's CSRF cookie is only set on a response to a GET of a page that
  /// renders `{% csrf_token %}` — [startInterview]'s successful response
  /// (`resume_interview.html:635`) already primes it, but this is a
  /// defensive fallback for any call site reached without that having run
  /// first, same technique as `ResumeRemoteDataSource._ensureCsrfCookie`.
  Future<void> _ensureCsrfCookie() async {
    if (await _apiClient.readCookie('csrftoken') != null) return;
    await _apiClient.dio.get(ApiEndpoints.resumeBuilderHome);
  }
}
