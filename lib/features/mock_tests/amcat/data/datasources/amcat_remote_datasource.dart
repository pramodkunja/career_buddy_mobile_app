import 'package:dio/dio.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/utils/json_parsing.dart';
import '../../domain/entities/amcat_section.dart';
import '../../domain/entities/amcat_submission_result.dart';
import '../models/amcat_section_model.dart';
import '../models/amcat_submission_result_model.dart';

/// Talks to one "sectioned exam" endpoint pair. Originally built for AMCAT
/// (`GET /activities/amcat/questions/`, `POST /activities/amcat/submit/`,
/// `activities/urls.py:42-43`) and reused for W023 CoCubes
/// (`/activities/cocubes/...`, `activities/urls.py:46-47`) once direct
/// source comparison showed `cocubes_questions`/`cocubes_submit`
/// (`activities/views.py:2369-2429`) share the exact same response shape
/// and semantics as `amcat_questions`/`amcat_submit` — see
/// `AmcatController`'s doc comment for the full comparison. Neither
/// endpoint pair requires authentication, and both submit endpoints are
/// `@csrf_exempt`, so — same reasoning as `MockQuizRemoteDataSource` — this
/// sends no `X-CSRFToken` header.
class AmcatRemoteDataSource {
  AmcatRemoteDataSource(this._apiClient, {required this.questionsPath, required this.submitPath});

  final ApiClient _apiClient;
  final String questionsPath;
  final String submitPath;

  Future<List<AmcatSection>> getSections() async {
    try {
      final response = await _apiClient.dio.get(questionsPath);
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return requireList(data, 'sections').map((e) => AmcatSectionParsing.fromJson(asMap(e, 'sections[]'))).toList();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }

  /// [answers] must include every served question's id across every
  /// section, in one flat map, padded with `-1` for anything unanswered —
  /// see `AmcatRepository.submit`'s doc comment.
  Future<AmcatSubmissionResult> submit(Map<int, int> answers) async {
    try {
      final response = await _apiClient.dio.post(
        submitPath,
        data: {'answers': answers.map((questionId, chosen) => MapEntry(questionId.toString(), chosen))},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();
      return AmcatSubmissionResultParsing.fromJson(data);
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
    } on FormatException {
      throw const UnexpectedResponseException();
    }
  }
}
