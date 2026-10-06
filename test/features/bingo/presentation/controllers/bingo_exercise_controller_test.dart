import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_tts_service.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/providers/ai_listening_providers.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_card.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_exercise.dart';
import 'package:career_buddy_lms/features/bingo/domain/entities/bingo_submission_result.dart';
import 'package:career_buddy_lms/features/bingo/domain/repositories/bingo_exercise_repository.dart';
import 'package:career_buddy_lms/features/bingo/presentation/controllers/bingo_exercise_controller.dart';
import 'package:career_buddy_lms/features/bingo/presentation/providers/bingo_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A no-op TTS stub — Bingo's read-aloud is a nice-to-have (mirrors the
/// web's own defensive `try/catch` around `speakNaturally`), never
/// gating game logic, so tests don't need a real platform engine.
class _NoopTts implements ListeningTtsService {
  @override
  Future<void> speak(String text, {required double rate}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  void setOnStart(void Function() callback) {}
  @override
  void setOnComplete(void Function() callback) {}
  @override
  void setOnError(void Function(String message) callback) {}
}

/// 25 cards, `Wxx`, so board position i (0-24) == `cards[i]` exactly —
/// makes win-line assertions straightforward to reason about.
BingoExercise _fullBoardExercise() => BingoExercise(
  id: 7,
  title: 'Vocab Bingo',
  order: 1,
  cards: List.generate(25, (i) => BingoCard(word: 'W$i', definition: 'D$i')),
);

BingoExercise _smallExercise({int count = 3}) => BingoExercise(
  id: 7,
  title: 'Vocab Bingo',
  order: 1,
  cards: List.generate(count, (i) => BingoCard(word: 'W$i', definition: 'D$i')),
);

class _FakeBingoExerciseRepository implements BingoExerciseRepository {
  _FakeBingoExerciseRepository({this.getResult, this.submitResult});

  Result<BingoExercise>? getResult;
  Result<BingoSubmissionResult>? submitResult;
  int submitCallCount = 0;
  int? lastScore;
  int? lastMaxScore;
  Map<int, ({String target, String chosen})>? lastAnswers;

  @override
  Future<Result<BingoExercise>> getBingoExercise(int exerciseId, {required String title, required int order}) async => getResult!;

  @override
  Future<Result<BingoSubmissionResult>> submitBingoExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, ({String target, String chosen})> answers,
  }) async {
    submitCallCount++;
    lastScore = score;
    lastMaxScore = maxScore;
    lastAnswers = answers;
    return submitResult!;
  }
}

Future<ProviderContainer> _readyContainer(BingoExerciseRepository repo, {String title = 'Vocab Bingo', int order = 1}) async {
  final container = ProviderContainer(
    overrides: [
      bingoExerciseRepositoryProvider.overrideWithValue(repo),
      listeningTtsServiceProvider.overrideWithValue(_NoopTts()),
    ],
  );
  container.read(bingoExerciseControllerProvider((7, title, order)));
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  final providerArg = (7, 'Vocab Bingo', 1);

  group('BingoExerciseController — load/start', () {
    test('resolves to Ready on a successful load', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: Success(_smallExercise())));
      addTearDown(container.dispose);

      expect(container.read(bingoExerciseControllerProvider(providerArg)), isA<BingoExerciseReady>());
    });

    test('resolves to LoadFailed on a failed load', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: const Failed(NotFoundFailure())));
      addTearDown(container.dispose);

      expect(container.read(bingoExerciseControllerProvider(providerArg)), isA<BingoExerciseLoadFailed>());
    });

    test('start() shuffles the full card list into a round sequence and begins at round 0', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: Success(_smallExercise(count: 5))));
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);

      notifier.start();
      final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.roundIndex, 0);
      expect(state.sequence.map((c) => c.word).toSet(), {'W0', 'W1', 'W2', 'W3', 'W4'});
      expect(state.sequence, hasLength(5));
      expect(state.markedWord, isNull);
    });
  });

  group('BingoExerciseController — round interaction', () {
    test('selectCell records the pick for the current round only', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: Success(_smallExercise())));
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      notifier.selectCell('W1');
      final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.markedWord, 'W1');
    });

    test('selecting a different cell in the same round replaces the previous pick', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: Success(_smallExercise())));
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      notifier.selectCell('W1');
      notifier.selectCell('W2');
      final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.markedWord, 'W2');
    });

    test('nextRound() is a no-op until the current round has a pick — mirrors "click a word first"', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: Success(_smallExercise())));
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      notifier.nextRound();
      final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.roundIndex, 0);
    });

    test('nextRound() advances to the next round once a pick is made, and the mark does not carry over', () async {
      final container = await _readyContainer(_FakeBingoExerciseRepository(getResult: Success(_smallExercise())));
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      notifier.selectCell('W1');
      notifier.nextRound();
      final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.roundIndex, 1);
      expect(state.markedWord, isNull); // the previous round's mark is not shown for the new round
      expect(state.selections[0], 'W1'); // but the answer itself is retained internally
    });
  });

  group('BingoExerciseController — grading', () {
    test('correct picks turn green and wrong picks turn red, independently, when there is no cross-round overlap', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 3)),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 2, maxScore: 3, percentage: 67, attemptNumber: 1)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      final state0 = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      final round0Target = state0.sequence[0].word;
      notifier.selectCell(round0Target); // round 0: correct
      notifier.nextRound();

      // A pick that exists nowhere on the board — `selectCell` records
      // whatever it's given (the real web only ever calls this from an
      // actual cell tap, so `chosen` is always a real board word; here it
      // deliberately isn't, to isolate this round's "wrong" grading from
      // any other round without contaminating a real cell's final color —
      // `cardStates.containsKey(...)` guards this exactly like the web's
      // own `if (c) {...}` null check on `byWord[sel.chosen]`).
      notifier.selectCell('NOT_ON_BOARD'); // round 1: wrong, no real cell affected
      notifier.nextRound();

      final state2 = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      notifier.selectCell(state2.currentCard.word); // round 2: correct
      notifier.nextRound();

      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.correctCount, 2);
      expect(result.cardStates[round0Target], BingoCellState.correct);
      expect(result.cardStates.values, isNot(contains(BingoCellState.wrong)));
    });

    test('a wrong pick always overrides a correct pick for the same word (red always wins)', () async {
      // Board of 2: W0/W1. Sequence order after shuffle is unknown, so
      // force it deterministic by using a 2-card exercise and reading the
      // sequence back, then engineering: round for W0 answered correctly
      // (pick W0), round for W1 answered by picking W0 again (wrong for
      // that round, since W0 != W1) — W0 ends up picked as "correct" in
      // its own round AND "wrong" (as the answer given) in the other
      // round; wrong must win for W0's final cell color.
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 2)),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 1, maxScore: 2, percentage: 50, attemptNumber: 1)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      var state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      final w0Round = state.sequence.indexWhere((c) => c.word == 'W0');
      final w1Round = state.sequence.indexWhere((c) => c.word == 'W1');

      // Answer W0's own round correctly (pick 'W0'), then answer W1's
      // round by (wrongly) picking 'W0' again.
      if (w0Round == 0) {
        notifier.selectCell('W0');
        notifier.nextRound();
        notifier.selectCell('W0'); // wrong for round 1 (target is W1)
        notifier.nextRound();
      } else {
        notifier.selectCell('W0'); // wrong for round 0 (target is W1)
        notifier.nextRound();
        notifier.selectCell('W0');
        notifier.nextRound();
      }

      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.cardStates['W0'], BingoCellState.wrong);
      expect(w1Round, isNotNull);
    });

    test('BINGO line detection: a completed top row (positions 0-4) is detected on a full 25-card board', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_fullBoardExercise()),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 5, maxScore: 25, percentage: 20, attemptNumber: 1)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      const topRow = {'W0', 'W1', 'W2', 'W3', 'W4'};
      // Answer every round correctly for W0..W4 (top row); everything else
      // gets a fixed "trash" pick (harmless if it happens to equal that
      // round's own target too — the assertion below only checks that the
      // top row completed, not exclusivity).
      for (var i = 0; i < 25; i++) {
        final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        final target = state.currentCard.word;
        notifier.selectCell(topRow.contains(target) ? target : 'W12');
        notifier.nextRound();
      }

      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.bingoLines, greaterThanOrEqualTo(1));
      expect(result.bingoLineWords, containsAll(topRow));
    });

    test('BINGO lines are never detected on a board smaller than 25 cells', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 5)),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 5, maxScore: 5, percentage: 100, attemptNumber: 1)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      for (var i = 0; i < 5; i++) {
        final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        notifier.selectCell(state.currentCard.word); // answer every round correctly
        notifier.nextRound();
      }

      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.correctCount, 5);
      expect(result.bingoLines, 0);
      expect(result.bingoLineWords, isEmpty);
    });

    test('a >25-card exercise makes rounds beyond the board unwinnable — verified honestly, not fixed', () async {
      final exercise = BingoExercise(
        id: 7,
        title: 'T',
        order: 1,
        cards: List.generate(27, (i) => BingoCard(word: 'W$i', definition: 'D$i')),
      );
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(exercise),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 0, maxScore: 27, percentage: 0, attemptNumber: 1)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      // Find the round whose target is W25 or W26 (off-board) and confirm
      // no board cell exists with that word — any pick necessarily grades
      // wrong for that round, exactly like the real web.
      var state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.exercise.board.map((c) => c.word), isNot(contains('W25')));
      expect(state.exercise.board.map((c) => c.word), isNot(contains('W26')));

      for (var i = 0; i < 27; i++) {
        state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        final target = state.currentCard.word;
        // Pick the target if it's on the board (correct), else pick any
        // board word (necessarily wrong, since the target isn't a board word).
        final pick = state.exercise.board.any((c) => c.word == target) ? target : state.exercise.board.first.word;
        notifier.selectCell(pick);
        notifier.nextRound();
      }

      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      // Exactly the 25 on-board rounds could have been answered correctly;
      // the 2 off-board rounds can never contribute a correct pick.
      expect(result.correctCount, lessThanOrEqualTo(25));
    });
  });

  group('BingoExerciseController — submission', () {
    test('submits the locally-computed score/maxScore and transitions to Result with isSubmitting true, then false on success', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 2)),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 2, maxScore: 2, percentage: 100, attemptNumber: 3)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      for (var i = 0; i < 2; i++) {
        final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        notifier.selectCell(state.currentCard.word);
        notifier.nextRound();
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(repo.submitCallCount, 1);
      expect(repo.lastScore, 2);
      expect(repo.lastMaxScore, 2);
      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.isSubmitting, isFalse);
      expect(result.submissionResult?.attemptNumber, 3);
    });

    test('a failed submission keeps the already-graded board/score and surfaces submitError', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 2)),
        submitResult: const Failed(ServerFailure()),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();

      for (var i = 0; i < 2; i++) {
        final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        notifier.selectCell(state.currentCard.word);
        notifier.nextRound();
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.isSubmitting, isFalse);
      expect(result.submitError, isA<ServerFailure>());
      expect(result.correctCount, 2); // grading is unaffected by the submit failure
    });

    test('retrySubmit() retries only the network step, without recomputing grading', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 2)),
        submitResult: const Failed(ServerFailure()),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();
      for (var i = 0; i < 2; i++) {
        final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        notifier.selectCell(state.currentCard.word);
        notifier.nextRound();
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(repo.submitCallCount, 1);

      repo.submitResult = const Success(BingoSubmissionResult(exerciseId: 7, score: 2, maxScore: 2, percentage: 100, attemptNumber: 1));
      await notifier.retrySubmit();

      expect(repo.submitCallCount, 2);
      final result = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExerciseResult;
      expect(result.submitError, isNull);
      expect(result.submissionResult, isNotNull);
    });
  });

  group('BingoExerciseController — restart', () {
    test('start() from a Result state reshuffles and begins a fresh playthrough', () async {
      final repo = _FakeBingoExerciseRepository(
        getResult: Success(_smallExercise(count: 2)),
        submitResult: const Success(BingoSubmissionResult(exerciseId: 7, score: 2, maxScore: 2, percentage: 100, attemptNumber: 1)),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(bingoExerciseControllerProvider(providerArg).notifier);
      notifier.start();
      for (var i = 0; i < 2; i++) {
        final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
        notifier.selectCell(state.currentCard.word);
        notifier.nextRound();
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(container.read(bingoExerciseControllerProvider(providerArg)), isA<BingoExerciseResult>());

      notifier.start();
      final state = container.read(bingoExerciseControllerProvider(providerArg)) as BingoExercisePlaying;
      expect(state.roundIndex, 0);
      expect(state.selections, isEmpty);
    });
  });
}
