import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/bingo_exercise.dart';
import '../../domain/entities/bingo_submission_result.dart';
import '../../domain/repositories/bingo_exercise_repository.dart';
import '../datasources/bingo_exercise_remote_datasource.dart';

class BingoExerciseRepositoryImpl implements BingoExerciseRepository {
  BingoExerciseRepositoryImpl(this._remote);

  final BingoExerciseRemoteDataSource _remote;

  @override
  Future<Result<BingoExercise>> getBingoExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final data = await _remote.getBingoExercise(exerciseId, title: title, order: order);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<BingoSubmissionResult>> submitBingoExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String target, String chosen})> answers,
  }) async {
    try {
      // Mirrors `answers['w' + (i+1)] = {target, chosen}`
      // (`static/js/exercises.js:584,646`) — persisted verbatim into
      // `UserExerciseResult.answers_json`, not read back by this app, but
      // kept faithful to what the web itself would have sent.
      final encoded = <String, Map<String, String>>{
        for (final entry in answers.entries)
          'w${entry.key}': {'target': entry.value.target, 'chosen': entry.value.chosen},
      };
      final data = await _remote.submit(exerciseId, score: score, maxScore: maxScore, answers: encoded);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
