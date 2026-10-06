import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/fill_blank_exercise.dart';
import '../../domain/entities/fill_blank_submission_result.dart';
import '../../domain/repositories/fill_blank_exercise_repository.dart';
import '../datasources/fill_blank_exercise_remote_data_source.dart';

class FillBlankExerciseRepositoryImpl implements FillBlankExerciseRepository {
  FillBlankExerciseRepositoryImpl(this._remote);

  final FillBlankExerciseRemoteDataSource _remote;

  @override
  Future<Result<FillBlankExercise>> getFillBlankExercise(int exerciseId, {required String title, required int order}) async {
    try {
      final data = await _remote.getFillBlankExercise(exerciseId, title: title, order: order);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<FillBlankSubmissionResult>> submitFillBlankExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String given, String correct, bool isCorrect})> answers,
  }) async {
    try {
      // Mirrors `answers[q] = {given, correct, result}`
      // (`static/js/exercises.js:226,236,244`) — persisted verbatim into
      // `UserExerciseResult.answers_json`, not read back by this app, but
      // kept faithful to what the web itself would have sent.
      final encoded = <String, Map<String, dynamic>>{
        for (final entry in answers.entries)
          entry.key.toString(): {
            'given': entry.value.given,
            'correct': entry.value.correct,
            'result': entry.value.isCorrect ? 'correct' : 'wrong',
          },
      };
      final data = await _remote.submit(exerciseId, score: score, maxScore: maxScore, answers: encoded);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
