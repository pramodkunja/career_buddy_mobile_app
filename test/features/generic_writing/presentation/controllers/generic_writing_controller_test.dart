import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_exercise.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/generic_writing_submission_result.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/entities/writing_prompt.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/repositories/generic_writing_repository.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/controllers/generic_writing_controller.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/providers/generic_writing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _words(int start, int count) => List.generate(count, (i) => 'word${start + i}').join(' ');

GenericWritingExercise _exercise({int promptCount = 2}) => GenericWritingExercise(
  id: 7,
  title: 'Negotiation Outcome Reflection',
  order: 1,
  prompts: List.generate(
    promptCount,
    (i) => WritingPrompt(position: i + 1, questionText: 'Prompt $i?', guide: 'Aim for 10-500 words.'),
  ),
);

class _FakeGenericWritingRepository implements GenericWritingRepository {
  _FakeGenericWritingRepository({this.getResult, this.submitResult});

  Result<GenericWritingExercise>? getResult;
  Result<GenericWritingSubmissionResult>? submitResult;
  int submitCallCount = 0;
  int? lastScore;
  int? lastMaxScore;
  Map<int, String>? lastAnswers;

  @override
  Future<Result<GenericWritingExercise>> getGenericWritingExercise(int exerciseId, {required String title, required int order}) async =>
      getResult!;

  @override
  Future<Result<GenericWritingSubmissionResult>> submitGenericWritingExercise(
    int exerciseId, {
    required int score,
    required int maxScore,
    required Map<int, String> answers,
  }) async {
    submitCallCount++;
    lastScore = score;
    lastMaxScore = maxScore;
    lastAnswers = answers;
    return submitResult!;
  }
}

Future<ProviderContainer> _readyContainer(
  GenericWritingRepository repo, {
  String title = 'Negotiation Outcome Reflection',
  int order = 1,
}) async {
  final container = ProviderContainer(overrides: [genericWritingRepositoryProvider.overrideWithValue(repo)]);
  container.read(genericWritingControllerProvider((7, title, order)));
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  final providerArg = (7, 'Negotiation Outcome Reflection', 1);

  group('GenericWritingController — load', () {
    test('resolves to InProgress with empty drafts on a successful load', () async {
      final container = await _readyContainer(_FakeGenericWritingRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);

      final state = container.read(genericWritingControllerProvider(providerArg));
      expect(state, isA<GenericWritingInProgress>());
      final inProgress = state as GenericWritingInProgress;
      expect(inProgress.drafts, isEmpty);
      expect(inProgress.allValid, isFalse); // nothing typed yet
    });

    test('resolves to LoadFailed on a failed load', () async {
      final container = await _readyContainer(_FakeGenericWritingRepository(getResult: const Failed(NotFoundFailure())));
      addTearDown(container.dispose);

      expect(container.read(genericWritingControllerProvider(providerArg)), isA<GenericWritingLoadFailed>());
    });
  });

  group('GenericWritingController — drafting and validation', () {
    test('updateDraft tracks live text per position and word count follows it', () async {
      final container = await _readyContainer(_FakeGenericWritingRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 10)); // below the 10-500 minimum? exactly 10, valid
      final state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;

      expect(state.draftFor(1), _words(1, 10));
      expect(state.wordCountFor(1), 10);
    });

    test('allValid is false until every prompt satisfies its own word-count range', () async {
      final container = await _readyContainer(_FakeGenericWritingRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 10)); // valid (>=10, <=500)
      var state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;
      expect(state.allValid, isFalse); // prompt 2 still empty

      notifier.updateDraft(2, _words(1, 10));
      state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;
      expect(state.allValid, isTrue);
    });

    test('too few words leaves allValid false; too many (over the guide\'s max) also leaves it false', () async {
      final container = await _readyContainer(_FakeGenericWritingRepository(getResult: Success(_exercise())));
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 5)); // below min 10
      notifier.updateDraft(2, _words(1, 10));
      var state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;
      expect(state.allValid, isFalse);

      notifier.updateDraft(1, _words(1, 600)); // above max 500
      state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;
      expect(state.allValid, isFalse);
    });

    test('an exercise with no prompts is never valid', () async {
      final container = await _readyContainer(_FakeGenericWritingRepository(getResult: Success(_exercise(promptCount: 0))));
      addTearDown(container.dispose);

      final state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;
      expect(state.allValid, isFalse);
    });
  });

  group('GenericWritingController — submit gating', () {
    test('submit() is a no-op until every prompt is valid', () async {
      final repo = _FakeGenericWritingRepository(getResult: Success(_exercise()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 10)); // only 1 of 2 valid
      await notifier.submit();

      expect(repo.submitCallCount, 0);
      expect(container.read(genericWritingControllerProvider(providerArg)), isA<GenericWritingInProgress>());
    });
  });

  group('GenericWritingController — submission', () {
    test('submit() sends a client-computed score, trimmed answers keyed by position, and transitions to Submitted', () async {
      final repo = _FakeGenericWritingRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          GenericWritingSubmissionResult(exerciseId: 7, score: 85, maxScore: 100, percentage: 85, attemptNumber: 3),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, '  ${_words(1, 10)}  '); // untrimmed draft
      notifier.updateDraft(2, _words(1, 10));
      await notifier.submit();

      expect(repo.submitCallCount, 1);
      expect(repo.lastMaxScore, 100);
      expect(repo.lastAnswers![1], _words(1, 10)); // trimmed before submission
      expect(repo.lastAnswers![2], _words(1, 10));
      expect(repo.lastScore, isNotNull);

      final state = container.read(genericWritingControllerProvider(providerArg));
      expect(state, isA<GenericWritingSubmitted>());
      expect((state as GenericWritingSubmitted).result.attemptNumber, 3);
    });

    test('the server-returned score/percentage is what the result view uses — the client score is only the submission payload', () async {
      final repo = _FakeGenericWritingRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          GenericWritingSubmissionResult(exerciseId: 7, score: 62, maxScore: 100, percentage: 62, attemptNumber: 1),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 10));
      notifier.updateDraft(2, _words(1, 10));
      await notifier.submit();

      final state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingSubmitted;
      expect(state.result.score, 62); // server value, even though the client's own heuristic likely computed 100
    });

    test('a failed submit keeps the drafts and surfaces submitError, without resetting to loading', () async {
      final repo = _FakeGenericWritingRepository(getResult: Success(_exercise()), submitResult: const Failed(ServerFailure()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 10));
      notifier.updateDraft(2, _words(1, 10));
      await notifier.submit();

      final state = container.read(genericWritingControllerProvider(providerArg));
      expect(state, isA<GenericWritingInProgress>());
      final inProgress = state as GenericWritingInProgress;
      expect(inProgress.submitError, isA<ServerFailure>());
      expect(inProgress.isSubmitting, isFalse);
      expect(inProgress.drafts, hasLength(2));
    });

    test('submit() while already submitting does not fire a second request', () async {
      final repo = _FakeGenericWritingRepository(
        getResult: Success(_exercise()),
        submitResult: const Success(
          GenericWritingSubmissionResult(exerciseId: 7, score: 100, maxScore: 100, percentage: 100, attemptNumber: 1),
        ),
      );
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);
      notifier.updateDraft(1, _words(1, 10));
      notifier.updateDraft(2, _words(1, 10));

      final first = notifier.submit();
      final second = notifier.submit(); // should be a no-op — already submitting
      await Future.wait([first, second]);

      expect(repo.submitCallCount, 1);
    });
  });

  group('GenericWritingController — retry', () {
    test('tryAgain() re-fetches and fully resets drafts and errors', () async {
      final repo = _FakeGenericWritingRepository(getResult: Success(_exercise()));
      final container = await _readyContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(genericWritingControllerProvider(providerArg).notifier);

      notifier.updateDraft(1, _words(1, 10));
      await notifier.tryAgain();

      final state = container.read(genericWritingControllerProvider(providerArg)) as GenericWritingInProgress;
      expect(state.drafts, isEmpty);
      expect(state.submitError, isNull);
    });
  });
}
