import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/exercise_hero_meta.dart';
import '../../domain/entities/bingo_exercise.dart';
import '../../domain/entities/bingo_submission_result.dart';
import '../models/bingo_exercise_model.dart';
import '../models/bingo_submission_result_model.dart';

/// Talks to the same two existing, already-public endpoints the web page
/// itself uses for a Bingo exercise — `exerciseDetailPage` (read, via
/// embedded JSON extraction) and `submitExercise` (write, the exact same
/// generic endpoint Matching/W008 reuses). No new backend endpoint exists
/// or is created for this.
class BingoExerciseRemoteDataSource {
  BingoExerciseRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// [title]/[order] are supplied by the caller — same reasoning as
  /// `MatchingExerciseRemoteDataSource.getMatchingExercise`.
  Future<BingoExercise> getBingoExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final response = await _apiClient.dio.get<String>(
        ApiEndpoints.exerciseDetailPage(exerciseId),
        options: Options(responseType: ResponseType.plain),
      );
      final html = response.data;
      if (html is! String) throw const UnexpectedResponseException();

      final bingoJson = extractEmbeddedJsonList(html, 'bingo-data');
      if (bingoJson == null || bingoJson.isEmpty) {
        // Most commonly: the activity is locked and the server redirected
        // to the Activities list instead (`_locked_redirect()`), which has
        // no such tag — surfaced honestly rather than a confusing parse
        // error. Same reasoning as `MatchingExerciseRemoteDataSource`.
        throw const ValidationException(
          {},
          "Couldn't start this bingo exercise. It may require an upgrade, or the page format has changed.",
        );
      }

      final exercise = BingoExerciseParsing.fromBingoJson(
        exerciseId: exerciseId,
        title: title,
        order: order,
        bingoJson: bingoJson,
        heroMeta: extractExerciseHeroMeta(html),
      );
      if (exercise.cards.isEmpty) throw const UnexpectedResponseException();
      return exercise;
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    }
  }

  Future<BingoSubmissionResult> submit(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<String, Map<String, String>> answers,
  }) async {
    try {
      // The csrftoken cookie is already set by the time a user reaches this
      // screen (established at login) — no extra GET needed first, same
      // reasoning as `MatchingExerciseRemoteDataSource.submit`.
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.submitExercise(exerciseId),
        data: {'score': score, 'max_score': maxScore, 'answers': answers},
        options: Options(headers: {'X-CSRFToken': csrfToken ?? ''}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return BingoSubmissionResultParsing.fromJson(
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
