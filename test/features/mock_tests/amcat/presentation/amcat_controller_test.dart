import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_question.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_section.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/entities/amcat_submission_result.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/domain/repositories/amcat_repository.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/controllers/amcat_controller.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/presentation/providers/amcat_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<AmcatSection> _sections({int sectionCount = 2, int questionsPerSection = 2, int timeSeconds = 5}) => List.generate(
  sectionCount,
  (s) => AmcatSection(
    key: 'sec$s',
    name: 'Section $s',
    timeSeconds: timeSeconds,
    questions: List.generate(
      questionsPerSection,
      (q) => AmcatQuestion(id: s * 100 + q, questionText: 'S$s Q$q', options: const ['A', 'B', 'C', 'D']),
    ),
  ),
);

AmcatSubmissionResult _submissionResult() => const AmcatSubmissionResult(
  score: 2,
  total: 4,
  sectionScores: {
    'sec0': AmcatSectionScore(name: 'Section 0', correct: 1, total: 2),
    'sec1': AmcatSectionScore(name: 'Section 1', correct: 1, total: 2),
  },
  questionResults: {0: AmcatQuestionResult(isCorrect: true, correctAnswerIndex: 0)},
);

class _FakeAmcatRepository implements AmcatRepository {
  _FakeAmcatRepository({this.getResult, this.submitResult});

  Result<List<AmcatSection>>? getResult;
  Result<AmcatSubmissionResult>? submitResult;
  int submitCallCount = 0;
  Map<int, int>? lastSubmittedAnswers;

  @override
  Future<Result<List<AmcatSection>>> getSections() async => getResult!;

  @override
  Future<Result<AmcatSubmissionResult>> submit(Map<int, int> answers) async {
    submitCallCount++;
    lastSubmittedAnswers = answers;
    return submitResult!;
  }
}

ProviderContainer _buildContainer(AmcatRepository repo) {
  return ProviderContainer(overrides: [amcatRepositoryProvider.overrideWithValue(repo)]);
}

void main() {
  group('AmcatController', () {
    test('starts in AmcatLanding', () {
      final container = _buildContainer(_FakeAmcatRepository());
      addTearDown(container.dispose);
      expect(container.read(amcatControllerProvider), isA<AmcatLanding>());
    });

    test('start() loads all sections into the first section, answers initialized to all-null', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections()));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      await container.read(amcatControllerProvider.notifier).start();

      final state = container.read(amcatControllerProvider) as AmcatInSection;
      expect(state.sections, hasLength(2));
      expect(state.sectionIndex, 0);
      expect(state.questionIndex, 0);
      expect(state.remainingSeconds, 5);
      expect(state.answers['sec0'], [null, null]);
      expect(state.answers['sec1'], [null, null]);
    });

    test('start() surfaces LoadFailed on a repository failure', () async {
      final repo = _FakeAmcatRepository(getResult: const Failed(ServerFailure()));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);

      await container.read(amcatControllerProvider.notifier).start();

      expect(container.read(amcatControllerProvider), isA<AmcatLoadFailed>());
    });

    test('selectAnswer records the choice for the current question only', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections()));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();

      notifier.selectAnswer(2);

      final state = container.read(amcatControllerProvider) as AmcatInSection;
      expect(state.answers['sec0'], [2, null]);
    });

    test('free navigation within a section: goToQuestion jumps to any question', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections(questionsPerSection: 3)));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();

      notifier.goToQuestion(2);

      final state = container.read(amcatControllerProvider) as AmcatInSection;
      expect(state.questionIndex, 2);
    });

    test('goForward on the last question blocks with validation if any question in the section is unanswered', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections(questionsPerSection: 2)));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();

      notifier.goToQuestion(1); // jump to the last question, leaving Q0 unanswered
      notifier.goForward(); // attempt to finish the section

      final state = container.read(amcatControllerProvider) as AmcatInSection;
      expect(state.showValidation, isTrue);
      expect(state.questionIndex, 0); // jumped back to the first unanswered question
      expect(state.sectionIndex, 0); // section NOT finished
    });

    test('goForward finishes a non-final section once every question is answered, showing the transition screen', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections(sectionCount: 2, questionsPerSection: 2)));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();

      notifier.selectAnswer(0);
      notifier.goForward(); // -> Q1
      notifier.selectAnswer(1);
      notifier.goForward(); // all answered -> finishes section 0

      final state = container.read(amcatControllerProvider);
      expect(state, isA<AmcatSectionTransition>());
      final transition = state as AmcatSectionTransition;
      expect(transition.finishedSectionIndex, 0);
      expect(transition.completedSectionKeys, {'sec0'});
    });

    test('"Skip" and "Next" are behaviorally identical — both call goForward', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections(questionsPerSection: 3)));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();

      notifier.goForward(); // "Skip" or "Next" — identical call on the web too
      final state = container.read(amcatControllerProvider) as AmcatInSection;
      expect(state.questionIndex, 1);
    });

    test('beginNextSection only advances on explicit call — the next section never starts itself', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections(sectionCount: 2, questionsPerSection: 1)));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(0);
      notifier.goForward();
      expect(container.read(amcatControllerProvider), isA<AmcatSectionTransition>());

      notifier.beginNextSection();

      final state = container.read(amcatControllerProvider) as AmcatInSection;
      expect(state.sectionIndex, 1);
      expect(state.questionIndex, 0);
      expect(state.remainingSeconds, 5); // fresh timer for the new section
      expect(state.completedSectionKeys, {'sec0'});
    });

    test('finishing the LAST section submits directly, skipping the transition screen', () async {
      final repo = _FakeAmcatRepository(
        getResult: Success(_sections(sectionCount: 1, questionsPerSection: 1)),
        submitResult: Success(_submissionResult()),
      );
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(0);
      notifier.goForward();

      // Submitting is async; let the microtask queue drain.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(amcatControllerProvider), isA<AmcatSubmitted>());
      expect(repo.submitCallCount, 1);
    });

    test('a timed-out final section still submits every question id, padded with -1 where unanswered', () {
      fakeAsync((async) {
        final repo = _FakeAmcatRepository(
          getResult: Success(_sections(sectionCount: 1, questionsPerSection: 2, timeSeconds: 3)),
          submitResult: Success(_submissionResult()),
        );
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(amcatControllerProvider.notifier);

        notifier.start();
        async.flushMicrotasks();
        notifier.selectAnswer(2); // only Q0 answered; Q1 left null

        async.elapse(const Duration(seconds: 4)); // section times out -> submits directly (only section)
        async.flushMicrotasks();

        expect(repo.submitCallCount, 1);
        expect(repo.lastSubmittedAnswers, {0: 2, 1: -1}); // ids 0 and 1 from sec0's two questions
        expect(container.read(amcatControllerProvider), isA<AmcatSubmitted>());
      });
    });

    test('a section timing out finishes it immediately, even with unanswered questions left', () {
      fakeAsync((async) {
        final repo = _FakeAmcatRepository(getResult: Success(_sections(sectionCount: 2, questionsPerSection: 2, timeSeconds: 3)));
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(amcatControllerProvider.notifier);

        notifier.start();
        async.flushMicrotasks();
        notifier.selectAnswer(0); // only Q0 of 2 answered

        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();

        // Section 0 timed out with Q1 unanswered — still finished (goes to
        // the transition screen for section 1), no validation block.
        expect(container.read(amcatControllerProvider), isA<AmcatSectionTransition>());
      });
    });

    test('the timer counts down once a second while a section is active', () {
      fakeAsync((async) {
        final repo = _FakeAmcatRepository(getResult: Success(_sections(timeSeconds: 10)));
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        container.read(amcatControllerProvider.notifier).start();
        async.flushMicrotasks();

        var state = container.read(amcatControllerProvider) as AmcatInSection;
        expect(state.remainingSeconds, 10);

        async.elapse(const Duration(seconds: 3));
        state = container.read(amcatControllerProvider) as AmcatInSection;
        expect(state.remainingSeconds, 7);
      });
    });

    test('a failed submit preserves every answer and allows retrySubmit', () async {
      final repo = _FakeAmcatRepository(
        getResult: Success(_sections(sectionCount: 1, questionsPerSection: 1)),
        submitResult: const Failed(ServerFailure()),
      );
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(0);
      notifier.goForward();
      await Future<void>.delayed(Duration.zero);

      final failedState = container.read(amcatControllerProvider);
      expect(failedState, isA<AmcatSubmitFailed>());
      expect((failedState as AmcatSubmitFailed).answers['sec0'], [0]);

      repo.submitResult = Success(_submissionResult());
      await notifier.retrySubmit();

      expect(container.read(amcatControllerProvider), isA<AmcatSubmitted>());
    });

    test('exitTest fully resets to AmcatLanding, discarding all progress', () async {
      final repo = _FakeAmcatRepository(getResult: Success(_sections()));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(0);

      notifier.exitTest();

      expect(container.read(amcatControllerProvider), isA<AmcatLanding>());
    });

    test('backToLanding from a submitted result returns to AmcatLanding, not straight into a new exam', () async {
      final repo = _FakeAmcatRepository(
        getResult: Success(_sections(sectionCount: 1, questionsPerSection: 1)),
        submitResult: Success(_submissionResult()),
      );
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(amcatControllerProvider.notifier);
      await notifier.start();
      notifier.selectAnswer(0);
      notifier.goForward();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(amcatControllerProvider), isA<AmcatSubmitted>());

      notifier.backToLanding();

      expect(container.read(amcatControllerProvider), isA<AmcatLanding>());
    });
  });
}
