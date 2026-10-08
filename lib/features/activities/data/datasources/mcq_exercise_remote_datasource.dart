import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/exercise_hero_meta.dart';
import '../../../../core/utils/html_unescape.dart';
import '../../domain/entities/mcq_exercise.dart';
import '../../domain/repositories/mcq_exercise_repository.dart';
import '../models/mcq_exercise_html_parser.dart';

/// Talks to the same two existing, already-public endpoints the web page
/// itself uses for an MCQ exercise — `exerciseDetailPage` (read, via
/// embedded JSON extraction) and `submitExercise` (write). The earlier
/// dedicated `mcqExercise`/`submitMcqExercise` JSON endpoints are confirmed
/// not deployed to production (same "documented but undeployed" pattern
/// as the dashboard/activities-list fixes this session) — this mirrors
/// `MatchingExerciseRemoteDataSource`'s exact approach, the established
/// fix for that bug class.
class McqExerciseRemoteDataSource {
  McqExerciseRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<McqExercise> getMcqExercise(int exerciseId) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.exerciseDetailPage(exerciseId),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();

      final questionsJson = extractMcqQuestionsJson(html);
      if (questionsJson == null || questionsJson.isEmpty) {
        // Most commonly: the activity is locked and the server redirected
        // to the Activities list instead (`_locked_redirect()`), which has
        // no such tag — surfaced honestly rather than a confusing parse
        // error. Same reasoning as `MatchingExerciseRemoteDataSource`.
        throw const ValidationException(
          {},
          "Couldn't start this exercise. It may require an upgrade, or the page format has changed.",
        );
      }

      // `exercise.html:98` — `<h2 class="text-white mb-0">{{ exercise.title }}</h2>`,
      // the hero's own title. Matching deliberately avoids scraping this
      // same markup (preferring a caller-supplied title instead — see
      // `MatchingExercise`'s doc comment) because its screen already
      // receives one via `MatchingRouteArgs`; `McqExerciseScreen` takes no
      // such route args (it never needed one before this fix, having
      // relied on the now-confirmed-undeployed JSON API's own `title`
      // field instead), so this is the only source available.
      final titleMatch = RegExp('class="text-white mb-0">([^<]*)</h2>').firstMatch(html);

      final exercise = McqExerciseParsing.fromQuestionsJson(
        exerciseId: exerciseId,
        title: _unescape(titleMatch?.group(1)?.trim() ?? 'Exercise'),
        questionsJson: questionsJson,
        heroMeta: extractExerciseHeroMeta(html),
      );
      if (exercise.questions.isEmpty) throw const UnexpectedResponseException();
      return exercise;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  Future<McqSubmitEcho> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    try {
      // The csrftoken cookie is already set by the time a user reaches this
      // screen (established at login) — no extra GET needed first, same
      // reasoning as `MatchingExerciseRemoteDataSource.submit`.
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.submitExercise(exerciseId),
        data: {
          'score': score,
          'max_score': maxScore,
          'answers': answers.map((questionId, letter) => MapEntry(questionId.toString(), letter)),
        },
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();

      // Prefers the server's own echoed values, falling back to the
      // client's submitted ones if a field is missing/malformed — same
      // reasoning as `MatchingSubmissionResultParsing.fromJson`'s
      // `fallbackScore`/`fallbackMaxScore`.
      final echoedScore = data['score'] is int ? data['score'] as int : score;
      final echoedMaxScore = data['max_score'] is int ? data['max_score'] as int : maxScore;
      final echoedPercentage = data['percentage'] is num
          ? (data['percentage'] as num).round()
          : (echoedMaxScore > 0 ? (echoedScore / echoedMaxScore * 100).round() : 0);
      final echoedAttempt = data['attempt'] is int ? data['attempt'] as int : 1;

      return (score: echoedScore, maxScore: echoedMaxScore, percentage: echoedPercentage, attemptNumber: echoedAttempt);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }

  String _unescape(String value) => unescapeHtmlEntities(value);
}
