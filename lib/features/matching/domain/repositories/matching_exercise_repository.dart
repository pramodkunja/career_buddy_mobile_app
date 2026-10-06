import '../../../../core/utils/result.dart';
import '../entities/matching_exercise.dart';
import '../entities/matching_submission_result.dart';

abstract class MatchingExerciseRepository {
  /// [title]/[order] are supplied by the caller — there is no JSON API
  /// response to read them back from (see
  /// `MatchingExerciseRemoteDataSource.getMatchingExercise`'s doc comment).
  Future<Result<MatchingExercise>> getMatchingExercise(int exerciseId, {required String title, required int order});

  /// [matches] maps each pair's `position` to the right-column position the
  /// user paired it with. [score]/[maxScore] are computed by the caller
  /// (`MatchingExerciseController`, from [matches] against
  /// `MatchingExercise.pairs`) — this exercise type is client-authoritative
  /// on the web itself (see `MatchingSubmissionResult`'s doc comment), so
  /// this repository is not hiding a grading step the web doesn't have
  /// either; it is not, however, permitted to invent its own score
  /// independent of what the caller already graded.
  Future<Result<MatchingSubmissionResult>> submitMatchingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, int> matches,
  });
}
