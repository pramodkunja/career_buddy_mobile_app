import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/exercise_hero_meta.dart';
import '../../domain/entities/matching_exercise.dart';
import '../../domain/entities/matching_submission_result.dart';
import '../models/matching_exercise_model.dart';
import '../models/matching_submission_result_model.dart';

/// Talks to the same two existing, already-public endpoints the web page
/// itself uses for a Matching exercise — `exerciseDetailPage` (read, via
/// embedded JSON extraction) and `submitExercise` (write). No new backend
/// endpoint exists or is created for this — see
/// `docs/EXERCISE_FEASIBILITY_AUDIT.md` §W008.
class MatchingExerciseRemoteDataSource {
  MatchingExerciseRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// [title]/[order] are supplied by the caller (already known from the
  /// `ExerciseSummary` the user tapped to get here — see
  /// `MatchingRouteArgs`) rather than scraped from the HTML: the page's
  /// title only appears as visible markup (`<h2>`/breadcrumb text), not in
  /// any embedded JSON, so reading it back out of that HTML would be far
  /// more fragile than the one script-tag extraction this class already
  /// depends on.
  Future<MatchingExercise> getMatchingExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.exerciseDetailPage(exerciseId),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();

      final questionsJson = extractEmbeddedJsonList(html, 'questions-data');
      if (questionsJson == null || questionsJson.isEmpty) {
        // Most commonly: the activity is locked and the server redirected
        // to the Activities list instead (`_locked_redirect()`), which has
        // no such tag — surfaced honestly rather than a confusing parse
        // error. Same reasoning as `AiListeningRemoteDataSource`.
        throw const ValidationException(
          {},
          "Couldn't start this matching exercise. It may require an upgrade, or the page format has changed.",
        );
      }

      final exercise = MatchingExerciseParsing.fromQuestionsJson(
        exerciseId: exerciseId,
        title: title,
        order: order,
        questionsJson: questionsJson,
        heroMeta: extractExerciseHeroMeta(html),
      );
      if (exercise.pairs.isEmpty) throw const UnexpectedResponseException();
      return exercise;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  Future<MatchingSubmissionResult> submit(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<String, Map<String, String>> answers,
  }) async {
    try {
      // The csrftoken cookie is already set by the time a user reaches this
      // screen (established at login) — no extra GET needed first, same
      // reasoning as `McqExerciseRemoteDataSource.submitMcqExercise`.
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.submitExercise(exerciseId),
        data: {'score': score, 'max_score': maxScore, 'answers': answers},
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return MatchingSubmissionResultParsing.fromJson(
        data,
        exerciseId: exerciseId,
        fallbackScore: score,
        fallbackMaxScore: maxScore,
      );
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
