import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/mock_test_attempt_history_local_datasource.dart';
import '../../domain/entities/mock_test_attempt_record.dart';
import '../../domain/entities/mock_test_question.dart';
import '../../domain/entities/mock_test_submission_result.dart';
import '../../domain/repositories/mock_quiz_repository.dart';
import '../providers/mock_test_providers.dart';

/// Same reasoning as `McqExerciseController`: this screen has in-flight
/// state (the timer, free navigation between questions, marked-for-review
/// flags, an independently loading/failing submit) that plain `AsyncValue`
/// doesn't model, so a custom sealed state makes each phase explicit.
///
/// Unlike MCQ's linear, gated flow, OOP Mastery's web behaviour is **free
/// navigation** — any question is jumpable at any time via the palette, with
/// no "answer this one before moving on" rule (`005 oop-mastery.html:2380-
/// 2816`) — so this state has no `allQuestionsAnswered`-gated submit; submit
/// is always available, matching the web's own confirm-dialog-warns-but-
/// doesn't-block behaviour for an incomplete attempt.
sealed class MockTestState {
  const MockTestState();
}

/// Matches the web's splash/intro screen — rules shown, nothing fetched yet.
/// [history] is this device's local attempt log (see
/// `MockTestAttemptHistoryLocalDataSource`), loaded eagerly so it's ready to
/// show before the user even starts.
final class MockTestIntro extends MockTestState {
  const MockTestIntro({this.history = const []});
  final List<MockTestAttemptRecord> history;
}

final class MockTestLoading extends MockTestState {
  const MockTestLoading();
}

final class MockTestLoadFailed extends MockTestState {
  const MockTestLoadFailed(this.failure);
  final Failure failure;
}

/// The exam is live: [remainingSeconds] counts down once a second, entirely
/// client-side — `oop_quiz_submit` accepts no timestamp/duration in its
/// request body at all (`activities/views.py:2158-2193`, confirmed by direct
/// read), so there is nothing server-side to synchronise against, exactly
/// mirroring the web's own `EXAM_SECONDS = 60*60` client timer.
final class MockTestInProgress extends MockTestState {
  const MockTestInProgress({
    required this.questions,
    required this.answers,
    required this.marked,
    required this.currentIndex,
    required this.remainingSeconds,
    this.isSubmitting = false,
    this.submitError,
  });

  final List<MockTestQuestion> questions;

  /// questionId -> chosen option index (0-3).
  final Map<int, int> answers;

  /// questionIds marked-for-review, purely a local UI aid (matches the
  /// web's own — it's never sent to the server).
  final Set<int> marked;

  final int currentIndex;
  final int remainingSeconds;
  final bool isSubmitting;
  final Failure? submitError;

  MockTestQuestion get currentQuestion => questions[currentIndex];
  int get answeredCount => answers.length;
  int get unansweredCount => questions.length - answers.length;
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get isFirstQuestion => currentIndex == 0;

  MockTestInProgress copyWith({
    Map<int, int>? answers,
    Set<int>? marked,
    int? currentIndex,
    int? remainingSeconds,
    bool? isSubmitting,
    Failure? submitError,
    bool clearSubmitError = false,
  }) {
    return MockTestInProgress(
      questions: questions,
      answers: answers ?? this.answers,
      marked: marked ?? this.marked,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

final class MockTestSubmitted extends MockTestState {
  const MockTestSubmitted({required this.questions, required this.answers, required this.result});
  final List<MockTestQuestion> questions;
  final Map<int, int> answers;
  final MockTestSubmissionResult result;
}

class MockTestController extends Notifier<MockTestState> {
  MockTestController({this.subject, this.examDuration = const Duration(minutes: 60)});

  /// Which backend endpoint pair (and which local attempt-history key) this
  /// instance talks to, so one class serves both W020 and W021:
  /// - `null` (the default): W020's dedicated OOP Mastery provider
  ///   (`oopMockQuizRepositoryProvider`/`oopMockTestAttemptHistoryProvider`,
  ///   unchanged since W020 — its own `/activities/oop-quiz/...` endpoint
  ///   pair, not one of the 24 generic subjects).
  /// - a subject slug (e.g. `'dsa'`): W021's subject-keyed family providers
  ///   (`subjectQuizRepositoryProvider(subject)` /
  ///   `subjectQuizAttemptHistoryProvider(subject)`), which construct the
  ///   exact same `MockQuizRepositoryImpl`/`MockTestAttemptHistoryLocalDataSource`
  ///   classes against `/activities/quiz/<subject>/...` instead.
  final String? subject;

  /// Injectable so tests aren't forced to wait out a real 60-minute timer.
  /// Matches the web's `EXAM_SECONDS = 60*60` (`005 oop-mastery.html:2411`,
  /// confirmed identical across every subject's own quiz page for W021).
  final Duration examDuration;

  Timer? _timer;

  MockQuizRepository get _repository =>
      subject == null ? ref.read(oopMockQuizRepositoryProvider) : ref.read(subjectQuizRepositoryProvider(subject!));

  MockTestAttemptHistoryLocalDataSource get _history => subject == null
      ? ref.read(oopMockTestAttemptHistoryProvider)
      : ref.read(subjectQuizAttemptHistoryProvider(subject!));

  @override
  MockTestState build() {
    ref.onDispose(() => _timer?.cancel());
    unawaited(_loadHistory());
    return const MockTestIntro();
  }

  Future<void> _loadHistory() async {
    final history = await _history.getAttempts();
    if (state is MockTestIntro) {
      state = MockTestIntro(history: history);
    }
  }

  /// Starts (or restarts, for "Take another test" — which skips the intro
  /// rules screen and jumps straight to a fresh fetch, matching the web's
  /// own retry handler) a fresh attempt.
  Future<void> start() async {
    state = const MockTestLoading();
    final result = await _repository.getQuestions();
    switch (result) {
      case Success(value: final questions):
        if (questions.isEmpty) {
          state = const MockTestLoadFailed(UnexpectedFailure());
          return;
        }
        state = MockTestInProgress(
          questions: questions,
          answers: const {},
          marked: const {},
          currentIndex: 0,
          remainingSeconds: examDuration.inSeconds,
        );
        _startTimer();
      case Failed(failure: final failure):
        state = MockTestLoadFailed(failure);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! MockTestInProgress) {
      _timer?.cancel();
      return;
    }
    if (current.remainingSeconds <= 1) {
      _timer?.cancel();
      state = current.copyWith(remainingSeconds: 0);
      unawaited(submit());
      return;
    }
    state = current.copyWith(remainingSeconds: current.remainingSeconds - 1);
  }

  void selectAnswer(int questionId, int optionIndex) {
    final current = state;
    if (current is! MockTestInProgress || current.isSubmitting) return;
    state = current.copyWith(answers: {...current.answers, questionId: optionIndex}, clearSubmitError: true);
  }

  void toggleMarkedForReview(int questionId) {
    final current = state;
    if (current is! MockTestInProgress) return;
    final marked = {...current.marked};
    if (!marked.remove(questionId)) marked.add(questionId);
    state = current.copyWith(marked: marked);
  }

  void goToQuestion(int index) {
    final current = state;
    if (current is! MockTestInProgress || current.isSubmitting) return;
    if (index < 0 || index >= current.questions.length) return;
    state = current.copyWith(currentIndex: index);
  }

  void nextQuestion() {
    final current = state;
    if (current is! MockTestInProgress || current.isLastQuestion) return;
    goToQuestion(current.currentIndex + 1);
  }

  void previousQuestion() {
    final current = state;
    if (current is! MockTestInProgress || current.isFirstQuestion) return;
    goToQuestion(current.currentIndex - 1);
  }

  /// Submits every served question's id, padding any unanswered one with
  /// `-1` — see `MockQuizRemoteDataSource.submitAnswers`'s doc comment for
  /// why this padding (not simply sending the sparse `answers` map) is
  /// required for the server's `total` to come back correct.
  ///
  /// On failure, deliberately returns to `MockTestInProgress` with
  /// `submitError` set and the timer still running (rather than the web's
  /// own dead-end "Could not grade the test" screen with no way back) —
  /// matching this app's own established resilience pattern for a failed
  /// submission (`McqExerciseController.submit`), which is more defensible
  /// than reproducing a confirmed web bug.
  Future<void> submit() async {
    final current = state;
    if (current is! MockTestInProgress || current.isSubmitting) return;

    _timer?.cancel();
    state = current.copyWith(isSubmitting: true, clearSubmitError: true);

    final paddedAnswers = {for (final q in current.questions) q.id: current.answers[q.id] ?? -1};
    final result = await _repository.submitAnswers(paddedAnswers);

    switch (result) {
      case Success(value: final submissionResult):
        await _history.recordAttempt(
          MockTestAttemptRecord(score: submissionResult.score, total: submissionResult.total, completedAt: DateTime.now()),
        );
        state = MockTestSubmitted(questions: current.questions, answers: current.answers, result: submissionResult);
      case Failed(failure: final failure):
        state = current.copyWith(isSubmitting: false, submitError: failure);
        _startTimer();
    }
  }

  /// "Take another test" — skips the intro splash entirely and fetches a
  /// fresh set of questions, matching the web's own retry handler
  /// (`005 oop-mastery.html`'s "Take another test" button calls `startExam()`
  /// directly, not the intro screen's `Start Test` flow).
  Future<void> retakeTest() => start();

  /// "Close" from the result screen — returns to the intro/rules screen with
  /// the just-recorded attempt reflected in [MockTestIntro.history].
  Future<void> backToIntro() async {
    state = const MockTestIntro();
    await _loadHistory();
  }
}

final mockTestControllerProvider = NotifierProvider<MockTestController, MockTestState>(MockTestController.new);

/// W021 — one independent controller instance per subject slug, so
/// switching subjects (or having two in memory at once) never shares
/// state. Reuses this exact same [MockTestController] class — see its
/// [MockTestController.subject] doc comment.
final subjectQuizControllerProvider = NotifierProvider.family<MockTestController, MockTestState, String>(
  (subject) => MockTestController(subject: subject),
);
