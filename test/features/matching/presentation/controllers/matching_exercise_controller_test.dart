import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_exercise.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_pair.dart';
import 'package:career_buddy_lms/features/matching/domain/entities/matching_submission_result.dart';
import 'package:career_buddy_lms/features/matching/domain/repositories/matching_exercise_repository.dart';
import 'package:career_buddy_lms/features/matching/presentation/controllers/matching_exercise_controller.dart';
import 'package:career_buddy_lms/features/matching/presentation/providers/matching_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MatchingExercise _exercise({int pairCount = 3}) => MatchingExercise(
  id: 7,
  title: 'Abbreviations',
  order: 1,
  pairs: List.generate(pairCount, (i) => MatchingPair(position: i + 1, leftText: 'L${i + 1}', rightText: 'R${i + 1}')),
);

class _FakeMatchingExerciseRepository implements MatchingExerciseRepository {
  _FakeMatchingExerciseRepository({this.getResult, this.submitResult});

  Result<MatchingExercise>? getResult;
  Result<MatchingSubmissionResult>? submitResult;
  int submitCallCount = 0;
  int? lastScore;
  int? lastMaxScore;
  Map<int, int>? lastMatches;

  @override
  Future<Result<MatchingExercise>> getMatchingExercise(int exerciseId, {required String title, required int order}) async =>
      getResult!;

  @override
  Future<Result<MatchingSubmissionResult>> submitMatchingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, int> matches,
  }) async {
    submitCallCount++;
    lastScore = score;
    lastMaxScore = maxScore;
    lastMatches = matches;
    return submitResult!;
  }
}

Future<ProviderContainer> _readyContainer(MatchingExerciseRepository repo, {String title = 'Abbreviations', int order = 1}) async {
  final container = ProviderContainer(overrides: [matchingExerciseRepositoryProvider.overrideWithValue(repo)]);
  container.read(matchingExerciseControllerProvider((7, title, order)));
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  group('MatchingExerciseController', () {
    test('resolves to InProgress with no matches and a full permutation right order on a successful load', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);

      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)));
      expect(state, isA<MatchingExerciseInProgress>());
      final inProgress = state as MatchingExerciseInProgress;
      expect(inProgress.matches, isEmpty);
      expect(inProgress.rightOrder.toSet(), {1, 2, 3});
      expect(inProgress.allMatched, isFalse);
    });

    test('resolves to LoadFailed on a failed load', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: const Failed(NotFoundFailure())));
      addTearDown(container.dispose);

      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)));
      expect(state, isA<MatchingExerciseLoadFailed>());
    });

    test('tapping a left item then a right item creates a match and clears the selection', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      var state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.selectedLeft, 1);

      notifier.tapRight(2);
      state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.matches, {1: 2});
      expect(state.selectedLeft, isNull);
      expect(state.selectedRight, isNull);
    });

    test('tapping right then left (opposite order) also creates a match', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapRight(3);
      notifier.tapLeft(2);
      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.matches, {2: 3});
    });

    test('tapping an already-matched left item unmatches it (mobile adaptation of the web double-click)', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(1);
      var state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.matches, {1: 1});

      notifier.tapLeft(1);
      state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.matches, isEmpty);
    });

    test('tapping an already-matched right item unmatches its pair too', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(2);
      notifier.tapRight(2);
      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.matches, isEmpty);
    });

    test('allMatched flips true once every pair has a match', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(1);
      notifier.tapLeft(2);
      notifier.tapRight(2);
      notifier.tapLeft(3);
      notifier.tapRight(3);

      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.allMatched, isTrue);
    });

    test('reset() clears every match without reshuffling the right order', () async {
      final container = await _readyContainer(_FakeMatchingExerciseRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(1);
      final before = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      final orderBefore = before.rightOrder;

      notifier.reset();
      final after = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(after.matches, isEmpty);
      expect(after.rightOrder, orderBefore);
    });

    test('submit() is a no-op until every pair is matched', () async {
      final repo = _FakeMatchingExerciseRepository(getResult: Success(_exercise()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(1); // only 1 of 3 matched
      await notifier.submit();

      expect(repo.submitCallCount, 0);
      expect(container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))), isA<MatchingExerciseInProgress>());
    });

    test('submit() sends the exact locally-computed score/maxScore to the repository', () async {
      final repo = _FakeMatchingExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          MatchingSubmissionResult(exerciseId: 7, score: 2, maxScore: 3, percentage: 67, attemptNumber: 5),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      // 1<->1 correct, 2<->2 correct, 3<->... needs a right position; only
      // 3 remains once 1 and 2 are taken, so 3<->3 is also forced correct
      // by the fixed-size fixture — use a 4-pair fixture instead so a
      // genuine wrong pairing is possible.
      notifier.tapLeft(1);
      notifier.tapRight(1);
      notifier.tapLeft(2);
      notifier.tapRight(3);
      notifier.tapLeft(3);
      notifier.tapRight(2);
      await notifier.submit();

      expect(repo.submitCallCount, 1);
      expect(repo.lastScore, 1); // only 1<->1 is correct
      expect(repo.lastMaxScore, 3);
      expect(repo.lastMatches, {1: 1, 2: 3, 3: 2});

      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)));
      expect(state, isA<MatchingExerciseSubmitted>());
      expect((state as MatchingExerciseSubmitted).result.attemptNumber, 5);
    });

    test('a failed submit keeps the matches and surfaces submitError, without resetting to loading', () async {
      final repo = _FakeMatchingExerciseRepository(
        getResult: Success(_exercise()),
        submitResult: const Failed(ServerFailure()),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(1);
      notifier.tapLeft(2);
      notifier.tapRight(2);
      notifier.tapLeft(3);
      notifier.tapRight(3);
      await notifier.submit();

      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)));
      expect(state, isA<MatchingExerciseInProgress>());
      final inProgress = state as MatchingExerciseInProgress;
      expect(inProgress.submitError, isA<ServerFailure>());
      expect(inProgress.isSubmitting, isFalse);
      expect(inProgress.matches, hasLength(3));
    });

    test('tryAgain() reloads the exercise fresh, resetting matches back to empty', () async {
      final repo = _FakeMatchingExerciseRepository(getResult: Success(_exercise()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1)).notifier);

      notifier.tapLeft(1);
      notifier.tapRight(1);
      await notifier.tryAgain();

      final state = container.read(matchingExerciseControllerProvider((7, 'Abbreviations', 1))) as MatchingExerciseInProgress;
      expect(state.matches, isEmpty);
    });
  });
}
