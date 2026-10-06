import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_test_attempt_history_local_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_attempt_record.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_question.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/repositories/mock_quiz_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/controllers/mock_test_controller.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/providers/mock_test_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// W021 — verifies `MockTestController` correctly serves the subject-keyed
/// family (`subjectQuizControllerProvider`), reusing the exact same
/// controller class W020's tests already cover for timer/navigation/submit
/// logic — this file's job is only the NEW behavior: per-subject provider
/// wiring and state independence between subjects, which W020 (a single
/// fixed OOP endpoint) never needed to prove.
List<MockTestQuestion> _questions(String label, {int count = 3}) => List.generate(
  count,
  (i) => MockTestQuestion(id: 100 + i, questionText: '$label Q$i', options: const ['A', 'B', 'C', 'D'], difficulty: '', topic: ''),
);

class _FakeMockQuizRepository implements MockQuizRepository {
  _FakeMockQuizRepository({this.getResult});

  Result<List<MockTestQuestion>>? getResult;
  int getQuestionsCallCount = 0;

  @override
  Future<Result<List<MockTestQuestion>>> getQuestions() async {
    getQuestionsCallCount++;
    return getResult!;
  }

  @override
  Future<Result<MockTestSubmissionResult>> submitAnswers(Map<int, int> answers) async => throw UnimplementedError();
}

class _FakeAttemptHistoryDataSource implements MockTestAttemptHistoryLocalDataSource {
  final List<MockTestAttemptRecord> recorded = [];

  @override
  Future<List<MockTestAttemptRecord>> getAttempts() async => List.of(recorded);

  @override
  Future<void> recordAttempt(MockTestAttemptRecord attempt) async => recorded.add(attempt);

  @override
  String get storageKey => 'test';
}

void main() {
  test('the subject family reads from subjectQuizRepositoryProvider(subject), not the OOP-specific provider', () async {
    final dsaRepo = _FakeMockQuizRepository(getResult: Success(_questions('dsa')));
    final oopRepo = _FakeMockQuizRepository(getResult: Success(_questions('oop-should-not-be-used')));
    final container = ProviderContainer(
      overrides: [
        subjectQuizRepositoryProvider('dsa').overrideWithValue(dsaRepo),
        subjectQuizAttemptHistoryProvider('dsa').overrideWithValue(_FakeAttemptHistoryDataSource()),
        // A distinct fake wired to the OOP-specific provider, so the test
        // fails loudly if the subject controller ever reads the wrong one.
        oopMockQuizRepositoryProvider.overrideWithValue(oopRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(subjectQuizControllerProvider('dsa').notifier).start();

    final state = container.read(subjectQuizControllerProvider('dsa')) as MockTestInProgress;
    expect(state.questions.first.questionText, 'dsa Q0');
    expect(dsaRepo.getQuestionsCallCount, 1);
    expect(oopRepo.getQuestionsCallCount, 0);
  });

  test('two different subjects have fully independent state (different questions, answers, progress)', () async {
    final dsaRepo = _FakeMockQuizRepository(getResult: Success(_questions('dsa')));
    final pythonRepo = _FakeMockQuizRepository(getResult: Success(_questions('python')));
    final container = ProviderContainer(
      overrides: [
        subjectQuizRepositoryProvider('dsa').overrideWithValue(dsaRepo),
        subjectQuizRepositoryProvider('python').overrideWithValue(pythonRepo),
        subjectQuizAttemptHistoryProvider('dsa').overrideWithValue(_FakeAttemptHistoryDataSource()),
        subjectQuizAttemptHistoryProvider('python').overrideWithValue(_FakeAttemptHistoryDataSource()),
      ],
    );
    addTearDown(container.dispose);

    final dsaNotifier = container.read(subjectQuizControllerProvider('dsa').notifier);
    final pythonNotifier = container.read(subjectQuizControllerProvider('python').notifier);
    await dsaNotifier.start();
    await pythonNotifier.start();

    dsaNotifier.selectAnswer(100, 2);

    final dsaState = container.read(subjectQuizControllerProvider('dsa')) as MockTestInProgress;
    final pythonState = container.read(subjectQuizControllerProvider('python')) as MockTestInProgress;

    expect(dsaState.questions.first.questionText, 'dsa Q0');
    expect(pythonState.questions.first.questionText, 'python Q0');
    expect(dsaState.answers, {100: 2});
    expect(pythonState.answers, isEmpty); // answering DSA must not leak into Python's state
  });

  test('a failed load for one subject does not affect an already-loaded sibling subject', () async {
    final dsaRepo = _FakeMockQuizRepository(getResult: Success(_questions('dsa')));
    final pythonRepo = _FakeMockQuizRepository(getResult: const Failed(ServerFailure()));
    final container = ProviderContainer(
      overrides: [
        subjectQuizRepositoryProvider('dsa').overrideWithValue(dsaRepo),
        subjectQuizRepositoryProvider('python').overrideWithValue(pythonRepo),
        subjectQuizAttemptHistoryProvider('dsa').overrideWithValue(_FakeAttemptHistoryDataSource()),
        subjectQuizAttemptHistoryProvider('python').overrideWithValue(_FakeAttemptHistoryDataSource()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(subjectQuizControllerProvider('dsa').notifier).start();
    await container.read(subjectQuizControllerProvider('python').notifier).start();

    expect(container.read(subjectQuizControllerProvider('dsa')), isA<MockTestInProgress>());
    expect(container.read(subjectQuizControllerProvider('python')), isA<MockTestLoadFailed>());
  });
}
