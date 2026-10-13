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
        // **Phase 16 correction**: `activities/grading.py`'s `matching`
        // branch (confirmed by direct source read) now re-grades every
        // submission server-side, checking
        // `_answer(answers, i).get('paired') == str(i)` — it reads
        // `paired` for EVERY pair, correct or wrong, never `result` (that
        // key is accepted but ignored by grading; kept here only because
        // the real web page still sends it too). The previous code below
        // omitted `paired` entirely on a correct match (relying on a
        // stale belief that only the wrong case needed it) — re-verified
        // directly against the current `exercises.js` (lines ~401/407):
        // both branches build `{result, paired}`, including when correct,
        // where `paired` just happens to equal `position` itself. Omitting
        // it meant the server's `_answer()` always saw a dict without a
        // `paired` key for every CORRECT match, scoring it as wrong.
        final paired = matches[position]!;
        answers[position.toString()] = {
          'result': paired == position ? 'correct' : 'wrong',
          'paired': paired.toString(),
        };
      }
      final data = await _remote.submit(exerciseId, score: score, maxScore: maxScore, answers: answers);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
