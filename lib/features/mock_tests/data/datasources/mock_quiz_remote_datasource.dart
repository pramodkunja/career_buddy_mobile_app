import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/mock_test_question.dart';
import '../../domain/entities/mock_test_submission_result.dart';
import '../models/mock_test_question_model.dart';
import '../models/mock_test_submission_result_model.dart';

/// Talks to one "mock quiz" endpoint pair (see `MockQuizRepository`'s doc
/// comment for why OOP Mastery and the generic Subject Quiz can share this
/// one class, constructed with different [questionsPath]/[submitPath]
/// values).
///
/// Neither endpoint needs the `X-CSRFToken` handling every other write
/// action in this app requires: `oop_quiz_submit`/`quiz_submit` are
/// decorated `@csrf_exempt` (`activities/views.py:2158-2159,2231-2232`) —
/// confirmed directly from source, not assumed — so this deliberately sends
/// no CSRF header at all rather than one that isn't needed. Neither
/// endpoint requires authentication either (`@require_GET`/`@require_POST`
/// only, no `@login_required`); the session cookie this app's `ApiClient`
/// already carries is attached automatically regardless, so a logged-in
/// attempt is still recorded server-side as the user's own.
class MockQuizRemoteDataSource {
  MockQuizRemoteDataSource(this._apiClient, {required this.questionsPath, required this.submitPath});

  final ApiClient _apiClient;
  final String questionsPath;
  final String submitPath;

  Future<List<MockTestQuestion>> getQuestions() async {
    try {
      final response = await _apiClient.dio.get(questionsPath);
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return requireList(
        data,
        'questions',
      ).map((e) => MockTestQuestionParsing.fromJson(asMap(e, 'questions[]'))).toList();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }

  /// [answers] maps question id -> chosen option index, and **must include
  /// every served question's id**, using `-1` (or any value outside
  /// `0-3`) for one left unanswered — mirrors the web's own payload
  /// exactly (`005 oop-mastery.html:2737-2738`,
  /// `payload.answers[it.id] = (it.id in answers) ? answers[it.id] : -1`).
  /// This matters beyond just "don't reveal the answer": the server's
  /// `total` is incremented once per id actually present in this map
  /// (`activities/views.py:2169-2177`) — an id silently *omitted* rather
  /// than sent as `-1` would never be counted at all, undercounting
  /// `total` against the true question count. Building this full,
  /// zero-gap map is `MockTestController`'s responsibility (it has both
  /// the served question list and the sparse answers), not this
  /// datasource's.
  Future<MockTestSubmissionResult> submitAnswers(Map<int, int> answers) async {
    try {
      final response = await _apiClient.dio.post(
        submitPath,
        data: {'answers': answers.map((questionId, chosen) => MapEntry(questionId.toString(), chosen))},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return MockTestSubmissionResultParsing.fromJson(data);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
