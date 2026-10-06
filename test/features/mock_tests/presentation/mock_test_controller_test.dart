import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_test_attempt_history_local_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_attempt_record.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_question.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_question_result.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/repositories/mock_quiz_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/controllers/mock_test_controller.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/providers/mock_test_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<MockTestQuestion> _questions({int count = 3}) => List.generate(
  count,
  (i) => MockTestQuestion(id: 100 + i, questionText: 'Q$i', options: const ['A', 'B', 'C', 'D'], difficulty: 'easy', topic: 'oop'),
);

MockTestSubmissionResult _submissionResult({int score = 2, int total = 3}) => MockTestSubmissionResult(
  score: score,
  total: total,
  results: {100: const MockTestQuestionResult(isCorrect: true, correctAnswerIndex: 0, explanation: 'because')},
);

class _FakeMockQuizRepository implements MockQuizRepository {
  _FakeMockQuizRepository({this.getResult, this.submitResult});

  Result<List<MockTestQuestion>>? getResult;
  Result<MockTestSubmissionResult>? submitResult;
  int submitCallCount = 0;
  Map<int, int>? lastSubmittedAnswers;

  @override
  Future<Result<List<MockTestQuestion>>> getQuestions() async => getResult!;

  @override
  Future<Result<MockTestSubmissionResult>> submitAnswers(Map<int, int> answers) async {
    submitCallCount++;
    lastSubmittedAnswers = answers;
    return submitResult!;
  }
}

/// A minimal fake history datasource (rather than the real
/// `SecureStorageService`, which needs a platform channel), tracking calls
/// so tests can assert the controller records an attempt on success only.
class _FakeAttemptHistoryDataSource implements MockTestAttemptHistoryLocalDataSource {
  final List<MockTestAttemptRecord> recorded = [];

  @override
  Future<List<MockTestAttemptRecord>> getAttempts() async => List.of(recorded);

  @override
  Future<void> recordAttempt(MockTestAttemptRecord attempt) async => recorded.add(attempt);

  @override
  String get storageKey => 'test';
}

ProviderContainer _buildContainer({
  required MockQuizRepository repo,
  MockTestAttemptHistoryLocalDataSource? history,
  Duration examDuration = const Duration(minutes: 60),
}) {
  return ProviderContainer(
    overrides: [
      oopMockQuizRepositoryProvider.overrideWithValue(repo),
      oopMockTestAttemptHistoryProvider.overrideWithValue(history ?? _FakeAttemptHistoryDataSource()),
      mockTestControllerProvider.overrideWith(() => MockTestController(examDuration: examDuration)),
    ],
  );
}

void main() {
  group('MockTestController', () {
    test('starts in MockTestIntro', () async {
      final container = _buildContainer(repo: _FakeMockQuizRepository());
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(mockTestControllerProvider), isA<MockTestIntro>());
    });

    test('start() loads questions into InProgress with a full countdown and no answers', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()));
      final container = _buildContainer(repo: repo, examDuration: const Duration(minutes: 60));
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);

      await notifier.start();

      final state = container.read(mockTestControllerProvider) as MockTestInProgress;
      expect(state.questions, hasLength(3));
      expect(state.answers, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.remainingSeconds, 60 * 60);
    });

    test('start() surfaces LoadFailed on a repository failure', () async {
      final repo = _FakeMockQuizRepository(getResult: const Failed(ServerFailure()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);

      await notifier.start();

      final state = container.read(mockTestControllerProvider);
      expect(state, isA<MockTestLoadFailed>());
      expect((state as MockTestLoadFailed).failure, isA<ServerFailure>());
    });

    test('start() surfaces LoadFailed when the server returns zero questions', () async {
      final repo = _FakeMockQuizRepository(getResult: const Success(<MockTestQuestion>[]));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      await container.read(mockTestControllerProvider.notifier).start();

      expect(container.read(mockTestControllerProvider), isA<MockTestLoadFailed>());
    });

    test('the timer counts down once a second while InProgress', () {
      fakeAsync((async) {
        final repo = _FakeMockQuizRepository(getResult: Success(_questions()));
        final container = _buildContainer(repo: repo, examDuration: const Duration(seconds: 5));
        addTearDown(container.dispose);
        container.read(mockTestControllerProvider.notifier).start();
        async.flushMicrotasks();

        var state = container.read(mockTestControllerProvider) as MockTestInProgress;
        expect(state.remainingSeconds, 5);

        async.elapse(const Duration(seconds: 2));
        state = container.read(mockTestControllerProvider) as MockTestInProgress;
        expect(state.remainingSeconds, 3);
      });
    });

    test('timer expiry auto-submits without requiring a manual submit() call', () {
      fakeAsync((async) {
        final repo = _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(_submissionResult()));
        final container = _buildContainer(repo: repo, examDuration: const Duration(seconds: 2));
        addTearDown(container.dispose);
        container.read(mockTestControllerProvider.notifier).start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(container.read(mockTestControllerProvider), isA<MockTestSubmitted>());
        expect(repo.submitCallCount, 1);
      });
    });

    test('selectAnswer records the choice; free navigation allows jumping to any question unanswered', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();

      notifier.selectAnswer(100, 2);
      notifier.goToQuestion(2); // jump straight to the last question, skipping #2 entirely
      var state = container.read(mockTestControllerProvider) as MockTestInProgress;
      expect(state.currentIndex, 2);
      expect(state.answers, {100: 2});

      notifier.previousQuestion();
      notifier.previousQuestion();
      state = container.read(mockTestControllerProvider) as MockTestInProgress;
      expect(state.currentIndex, 0); // clamped, doesn't go negative
    });

    test('toggleMarkedForReview flips the marked set for that question only', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();

      notifier.toggleMarkedForReview(100);
      var state = container.read(mockTestControllerProvider) as MockTestInProgress;
      expect(state.marked, {100});

      notifier.toggleMarkedForReview(100);
      state = container.read(mockTestControllerProvider) as MockTestInProgress;
      expect(state.marked, isEmpty);
    });

    test('submit() pads every served question id with -1 for anything left unanswered', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(_submissionResult()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();

      notifier.selectAnswer(100, 1); // only the first of 3 questions answered
      await notifier.submit();

      expect(repo.lastSubmittedAnswers, {100: 1, 101: -1, 102: -1});
    });

    test('submit() transitions to Submitted with the server-authoritative result and records local history', () async {
      final history = _FakeAttemptHistoryDataSource();
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(_submissionResult(score: 2, total: 3)));
      final container = _buildContainer(repo: repo, history: history);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();

      notifier.selectAnswer(100, 0);
      await notifier.submit();

      final state = container.read(mockTestControllerProvider);
      expect(state, isA<MockTestSubmitted>());
      expect((state as MockTestSubmitted).result.score, 2);
      expect(history.recorded, hasLength(1));
      expect(history.recorded.single.score, 2);
      expect(history.recorded.single.total, 3);
    });

    test('a failed submit returns to InProgress with submitError, preserving answers (no dead end)', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: const Failed(ServerFailure()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(100, 0);

      await notifier.submit();

      final state = container.read(mockTestControllerProvider);
      expect(state, isA<MockTestInProgress>());
      final inProgress = state as MockTestInProgress;
      expect(inProgress.submitError, isA<ServerFailure>());
      expect(inProgress.isSubmitting, isFalse);
      expect(inProgress.answers, {100: 0});
    });

    test('submit() while already submitting does not fire a second request', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(_submissionResult()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();

      final first = notifier.submit();
      final second = notifier.submit();
      await Future.wait([first, second]);

      expect(repo.submitCallCount, 1);
    });

    test('retakeTest() fetches a fresh set of questions, skipping the intro screen', () async {
      final repo = _FakeMockQuizRepository(getResult: Success(_questions()), submitResult: Success(_submissionResult()));
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockTestControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(100, 0);
      await notifier.submit();
      expect(container.read(mockTestControllerProvider), isA<MockTestSubmitted>());

      await notifier.retakeTest();

      final state = container.read(mockTestControllerProvider) as MockTestInProgress;
      expect(state.answers, isEmpty); // fresh attempt, no carried-over answers
    });
  });
}
