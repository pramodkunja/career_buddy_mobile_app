import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/matching_exercise.dart';
import '../../domain/entities/matching_submission_result.dart';
import '../../domain/repositories/matching_exercise_repository.dart';
import '../datasources/matching_exercise_remote_datasource.dart';

class MatchingExerciseRepositoryImpl implements MatchingExerciseRepository {
  MatchingExerciseRepositoryImpl(this._remote);

  final MatchingExerciseRemoteDataSource _remote;

  @override
  Future<Result<MatchingExercise>> getMatchingExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final data = await _remote.getMatchingExercise(exerciseId, title: title, order: order);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<MatchingSubmissionResult>> submitMatchingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, int> matches,
  }) async {
    try {
      final answers = <String, Map<String, String>>{};
      for (final position in matches.keys) {
        // Mirrors `exercises.js`'s own `answers[id] = {result: 'correct'}`
        // / `{result: 'wrong', paired}` shape (`static/js/exercises.js:399,
        // 405`) — persisted verbatim into `UserExerciseResult.answers_json`,
        // not read back by this app, but kept faithful to what the web
        // itself would have sent for the same matches.
        final paired = matches[position]!;
        answers[position.toString()] = paired == position
            ? const {'result': 'correct'}
            : {'result': 'wrong', 'paired': paired.toString()};
      }
      final data = await _remote.submit(exerciseId, score: score, maxScore: maxScore, answers: answers);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
