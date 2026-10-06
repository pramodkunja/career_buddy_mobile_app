import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/timer_exercise.dart';
import '../../domain/entities/timer_submission_result.dart';
import '../../domain/repositories/timer_exercise_repository.dart';
import '../datasources/timer_exercise_remote_datasource.dart';

class TimerExerciseRepositoryImpl implements TimerExerciseRepository {
  TimerExerciseRepositoryImpl(this._remote);

  final TimerExerciseRemoteDataSource _remote;

  @override
  Future<Result<TimerExercise>> getTimerExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final data = await _remote.getTimerExercise(exerciseId, title: title, order: order);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<TimerSubmissionResult>> submitTimerExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    try {
      // Mirrors `answers[Number(idx)+1] = text`
      // (`static/js/exercises.js:1408-1409`) — persisted verbatim into
      // `UserExerciseResult.answers_json`, not read back by this app, but
      // kept faithful to what the web itself would have sent.
      final encoded = <String, String>{for (final entry in answers.entries) entry.key.toString(): entry.value};
      final data = await _remote.submit(exerciseId, score: score, maxScore: maxScore, answers: encoded);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
