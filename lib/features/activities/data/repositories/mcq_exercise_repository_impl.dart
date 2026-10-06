import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/mcq_exercise.dart';
import '../../domain/repositories/mcq_exercise_repository.dart';
import '../datasources/mcq_exercise_remote_datasource.dart';

class McqExerciseRepositoryImpl implements McqExerciseRepository {
  McqExerciseRepositoryImpl(this._remote);

  final McqExerciseRemoteDataSource _remote;

  @override
  Future<Result<McqExercise>> getMcqExercise(int exerciseId) async {
    try {
      final data = await _remote.getMcqExercise(exerciseId);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<McqSubmitEcho>> submitMcqExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    try {
      final data = await _remote.submitMcqExercise(exerciseId, score: score, maxScore: maxScore, answers: answers);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
