import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/generic_writing_exercise.dart';
import '../../domain/entities/generic_writing_submission_result.dart';
import '../../domain/repositories/generic_writing_repository.dart';
import '../datasources/generic_writing_remote_datasource.dart';

class GenericWritingRepositoryImpl implements GenericWritingRepository {
  GenericWritingRepositoryImpl(this._remote);

  final GenericWritingRemoteDataSource _remote;

  @override
  Future<Result<GenericWritingExercise>> getGenericWritingExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final data = await _remote.getGenericWritingExercise(exerciseId, title: title, order: order);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<GenericWritingSubmissionResult>> submitGenericWritingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    try {
      // Mirrors `answers[q] = text` (`static/js/exercises.js:850`) —
      // persisted verbatim into `UserExerciseResult.answers_json`, not
      // read back by this app, but kept faithful to what the web itself
      // would have sent.
      final encoded = <String, String>{for (final entry in answers.entries) entry.key.toString(): entry.value};
      final data = await _remote.submit(exerciseId, score: score, maxScore: maxScore, answers: encoded);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
