import '../../features/bingo/domain/entities/bingo_card.dart';
import '../../features/bingo/domain/entities/bingo_exercise.dart';
import '../../features/bingo/domain/entities/bingo_submission_result.dart';
import '../../features/bingo/domain/repositories/bingo_exercise_repository.dart';
import 'demo_progress_store.dart';
import '../errors/failures.dart';
import '../utils/result.dart';

/// The demo exercise/sub-activity ids this repository serves — match
/// `kDemoActivities`'s "Vocabulary Bingo" fixture.
const _kDemoBingoExerciseId = 9207;
const _kDemoBingoSubActivityId = 9110;

/// 16 cards — deliberately fewer than the 25-cell board size, so the demo
/// board renders a partial (4-row) grid exactly as the real web does for
/// any exercise with <25 `BingoCard` rows, and so a genuine 5-in-a-row
/// BINGO is reachable (a >25-card exercise can never bingo-line at all,
/// since `BingoExercise.board` only ever shows the first 25 — see that
/// class's doc comment).
const _kDemoCards = [
  BingoCard(word: 'ASAP', definition: 'As soon as possible'),
  BingoCard(word: 'FYI', definition: 'For your information'),
  BingoCard(word: 'Deadline', definition: 'The time by which something must be finished'),
  BingoCard(word: 'Touch base', definition: 'To make brief contact with someone'),
  BingoCard(word: 'Circle back', definition: 'To return to a topic or task later'),
  BingoCard(word: 'Synergy', definition: 'The combined effect of people working together'),
  BingoCard(word: 'Bandwidth', definition: 'The time or capacity available to take on work'),
  BingoCard(word: 'Stakeholder', definition: 'A person with an interest or concern in something'),
  BingoCard(word: 'Onboard', definition: 'To integrate a new employee into an organization'),
  BingoCard(word: 'Leverage', definition: 'To use something to maximum advantage'),
  BingoCard(word: 'Benchmark', definition: 'A standard used for comparison'),
  BingoCard(word: 'Escalate', definition: 'To raise an issue to a higher level of authority'),
  BingoCard(word: 'Agenda', definition: 'A list of items to be discussed at a meeting'),
  BingoCard(word: 'Feedback', definition: 'Information given about performance for improvement'),
  BingoCard(word: 'Milestone', definition: 'A significant point in a project timeline'),
  BingoCard(word: 'Proactive', definition: 'Acting in advance to deal with an expected difficulty'),
];

/// `BingoExerciseRepository` backed by a fixed, 16-card in-memory
/// exercise. Grading itself happens in the controller (client-authoritative,
/// same as the web) — this repository only persists whatever score/maxScore
/// it's given and returns the server-echo shape, same division of
/// responsibility as `DemoMatchingExerciseRepository`. Never wired into
/// production/API code paths — see `demo_mode.dart` for how this gets
/// swapped in.
class DemoBingoExerciseRepository implements BingoExerciseRepository {
  static const _networkDelay = Duration(milliseconds: 200);

  @override
  Future<Result<BingoExercise>> getBingoExercise(int exerciseId, {required String title, required int order}) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoBingoExerciseId) return const Failed(NotFoundFailure());
    return const Success(
      BingoExercise(id: _kDemoBingoExerciseId, title: 'Workplace Vocabulary Bingo', order: 1, cards: _kDemoCards),
    );
  }

  @override
  Future<Result<BingoSubmissionResult>> submitBingoExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String target, String chosen})> answers,
  }) async {
    await Future<void>.delayed(_networkDelay);
    if (exerciseId != _kDemoBingoExerciseId) return const Failed(NotFoundFailure());

    DemoProgressStore.instance.recordAttempt(exerciseId, score: score, maxScore: maxScore);
    DemoProgressStore.instance.markSubActivityComplete(_kDemoBingoSubActivityId);
    final attemptNumber = DemoProgressStore.instance.lastAttemptFor(exerciseId)!.attemptNumber;
    final percentage = maxScore == 0 ? 0 : ((score / maxScore) * 100).round();

    return Success(
      BingoSubmissionResult(
        exerciseId: exerciseId,
        score: score,
        maxScore: maxScore,
        percentage: percentage,
        attemptNumber: attemptNumber,
      ),
    );
  }
}
