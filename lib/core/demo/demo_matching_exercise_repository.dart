import '../../features/matching/domain/entities/matching_exercise.dart';
import '../../features/matching/domain/entities/matching_pair.dart';
import '../../features/matching/domain/entities/matching_submission_result.dart';
import '../../features/matching/domain/repositories/matching_exercise_repository.dart';
import 'demo_progress_store.dart';
import '../errors/failures.dart';
import '../utils/result.dart';

/// The demo exercise/sub-activity ids this repository serves — match
/// `kDemoActivities`'s "Vocabulary Matching" fixture.
const _kDemoMatchingExerciseId = 9206;
const _kDemoMatchingSubActivityId = 9109;

const _kDemoPairs = [
  MatchingPair(position: 1, leftText: 'ASAP', rightText: 'As soon as possible'),
  MatchingPair(position: 2, leftText: 'FYI', rightText: 'For your information'),
  MatchingPair(position: 3, leftText: 'Deadline', rightText: 'The time by which something must be finished'),
  MatchingPair(position: 4, leftText: 'Touch base', rightText: 'To make brief contact with someone'),
  MatchingPair(position: 5, leftText: 'Circle back', rightText: 'To return to a topic or task later'),
];

/// `MatchingExerciseRepository` backed by a fixed, five-pair in-memory
/// exercise. Scoring is computed by the same controller logic real
/// exercises use (this repository never grades — see
/// `MatchingExerciseRepository`'s doc comment); it only serves fixed
/// content and records the resulting attempt, purely to make the
/// interaction flow usable for manual UI testing. Never wired into
/// production/API code paths — see `demo_mode.dart` for how this gets
/// swapped in.
class DemoMatchingExerciseRepository implements MatchingExerciseRepository {
  static const _networkDelay = Duration(milliseconds: 200);

  @override
  Future<Result<MatchingExercise>> getMatchingExercise(int exerciseId, {required String title, required int order}) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoMatchingExerciseId) return const Failed(NotFoundFailure());
    return const Success(
      MatchingExercise(id: _kDemoMatchingExerciseId, title: 'Workplace Abbreviations Matching', order: 1, pairs: _kDemoPairs),
    );
  }

  @override
  Future<Result<MatchingSubmissionResult>> submitMatchingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, int> matches,
  }) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoMatchingExerciseId) return const Failed(NotFoundFailure());

    DemoProgressStore.instance.recordAttempt(exerciseId, score: score, maxScore: maxScore);
    DemoProgressStore.instance.markSubActivityComplete(_kDemoMatchingSubActivityId);
    final attemptNumber = DemoProgressStore.instance.lastAttemptFor(exerciseId)!.attemptNumber;
    final percentage = maxScore == 0 ? 0 : ((score / maxScore) * 100).round();

    return Success(
      MatchingSubmissionResult(
        exerciseId: exerciseId,
        score: score,
        maxScore: maxScore,
        percentage: percentage,
        attemptNumber: attemptNumber,
      ),
    );
  }
}
