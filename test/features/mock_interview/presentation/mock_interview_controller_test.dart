import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/answer_submission_result.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_analytics.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_question.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/malpractice.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/next_question_outcome.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/repositories/mock_interview_repository.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/controllers/mock_interview_controller.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/providers/mock_interview_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

InterviewQuestion _question({int id = 1, String progress = '1/20', int timeRemaining = 30}) => InterviewQuestion(
  id: id,
  text: 'Tell me about yourself.',
  topic: 'Behavioural',
  difficulty: 'Easy',
  isCoding: false,
  questionType: 'theory',
  progress: progress,
  timeLimitSeconds: 30,
  timeRemainingSeconds: timeRemaining,
);

const _analytics = InterviewAnalyticsResult(
  totalScore: 80,
  isPassed: true,
  avgScore: 4.0,
  answeredCount: 20,
  totalQuestions: 20,
  yearsExperience: 2.0,
  questionResults: [],
);

/// A fully scriptable fake — each method reads from (and, for
/// `getNextQuestion`, advances through) a queue/config the test sets up
/// beforehand, and records what was actually called so tests can assert on
/// call counts/arguments (e.g. exactly which `ViolationType` was reported).
class _FakeMockInterviewRepository implements MockInterviewRepository {
  Result<void>? startResult;
  Result<void>? cameraResult;
  final List<Result<NextQuestionOutcome>> nextQuestionQueue = [];
  Result<AnswerSubmissionResult>? submitResult;
  Result<InterviewAnalyticsResult>? analyticsResult;
  final List<Result<ViolationRecordResult>> violationQueue = [];
  Result<ViolationState>? violationStateResult;
  int violationStateCallCount = 0;

  int submitCallCount = 0;
  int nextQuestionCallCount = 0;
  final List<bool> advanceCalls = [];
  final List<ViolationType> reportedViolationTypes = [];
  String? lastSubmittedAnswerText;

  @override
  Future<Result<void>> startInterview() async => startResult ?? const Success(null);

  @override
  Future<Result<void>> confirmCameraLive() async => cameraResult ?? const Success(null);

  @override
  Future<Result<NextQuestionOutcome>> getNextQuestion({required bool advance}) async {
    advanceCalls.add(advance);
    final index = nextQuestionCallCount++;
    return index < nextQuestionQueue.length ? nextQuestionQueue[index] : const Success(InterviewCompleted());
  }

  @override
  Future<Result<AnswerSubmissionResult>> submitAnswer({required int questionId, required String answerText}) async {
    submitCallCount++;
    lastSubmittedAnswerText = answerText;
    return submitResult ?? const Success(AnswerSubmissionResult(score: 3, feedback: 'ok', timedOut: false));
  }

  @override
  Future<Result<ViolationState>> getViolationState() async {
    violationStateCallCount++;
    return violationStateResult ??
        const Success(ViolationState(count: 0, status: MalpracticeStatus.clean, flagThreshold: 2, terminateThreshold: 3));
  }

  @override
  Future<Result<ViolationRecordResult>> recordViolation({required ViolationType type, double? durationSeconds}) async {
    reportedViolationTypes.add(type);
    final index = reportedViolationTypes.length - 1;
    return index < violationQueue.length
        ? violationQueue[index]
        : const Success(ViolationRecordResult(count: 1, status: MalpracticeStatus.clean, action: ViolationAction.warn, typeOccurrenceNumber: 1));
  }

  int uploadVideoCallCount = 0;
  String? lastUploadedVideoPath;

  @override
  Future<Result<bool>> uploadInterviewVideo(String filePath) async {
    uploadVideoCallCount++;
    lastUploadedVideoPath = filePath;
    return const Success(true);
  }

  @override
  Future<Result<InterviewAnalyticsResult>> getAnalytics() async => analyticsResult ?? const Success(_analytics);
}

ProviderContainer _buildContainer(_FakeMockInterviewRepository repo) {
  return ProviderContainer(overrides: [mockInterviewRepositoryProvider.overrideWithValue(repo)]);
}

void main() {
  group('MockInterviewController', () {
    test('starts in MockInterviewIdle', () {
      final container = _buildContainer(_FakeMockInterviewRepository());
      addTearDown(container.dispose);
      expect(container.read(mockInterviewControllerProvider), isA<MockInterviewIdle>());
    });

    test('start() moves to the camera gate on success', () async {
      final repo = _FakeMockInterviewRepository();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      await container.read(mockInterviewControllerProvider.notifier).start();
      expect(container.read(mockInterviewControllerProvider), isA<MockInterviewCameraGate>());
    });

    test('start() surfaces a failure (e.g. no Premium plan) as MockInterviewStartFailed', () async {
      final repo = _FakeMockInterviewRepository()..startResult = const Failed(ForbiddenFailure());
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      await container.read(mockInterviewControllerProvider.notifier).start();
      expect(container.read(mockInterviewControllerProvider), isA<MockInterviewStartFailed>());
    });

    test('confirmCameraLive() loads the first question with the server-seeded timer', () async {
      final repo = _FakeMockInterviewRepository()..nextQuestionQueue.add(Success(NextQuestionReady(_question(timeRemaining: 25))));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.start();
      await notifier.confirmCameraLive();

      final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
      expect(state.question.id, 1);
      expect(state.secondsRemaining, 25);
      expect(repo.advanceCalls.single, isFalse); // the very first fetch must not send ?next=true
    });

    test('progresses through all 20 questions to results, advance=true after the first', () async {
      final repo = _FakeMockInterviewRepository()
        ..nextQuestionQueue.addAll([
          Success(NextQuestionReady(_question(id: 1, progress: '1/20'))),
          Success(NextQuestionReady(_question(id: 2, progress: '2/20'))),
          const Success(InterviewCompleted()),
        ]);
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.start();
      await notifier.confirmCameraLive(); // question 1
      await notifier.submitAnswer(); // -> question 2
      await notifier.submitAnswer(); // -> completed -> results

      expect(container.read(mockInterviewControllerProvider), isA<MockInterviewResults>());
      expect(repo.submitCallCount, 2);
      expect(repo.advanceCalls, [false, true, true]);
    });

    test('a completed outcome loads real results from resume_analytics', () async {
      final repo = _FakeMockInterviewRepository()..nextQuestionQueue.add(const Success(InterviewCompleted()));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.start();
      await notifier.confirmCameraLive();

      final state = container.read(mockInterviewControllerProvider) as MockInterviewResults;
      expect(state.analytics.totalScore, 80);
      expect(state.analytics.isPassed, isTrue);
    });

    test('a malpractice_terminated failure while fetching a question ends the interview and loads results', () async {
      final repo = _FakeMockInterviewRepository()
        ..nextQuestionQueue.add(const Failed(MalpracticeTerminatedFailure('Terminated for real.')));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.start();
      await notifier.confirmCameraLive();

      expect(container.read(mockInterviewControllerProvider), isA<MockInterviewTerminated>());
    });

    test('a camera_required failure sends the candidate back to the camera gate', () async {
      final repo = _FakeMockInterviewRepository()
        ..nextQuestionQueue.add(const Failed(CameraRequiredFailure('Camera access is required.')));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.start();
      await notifier.confirmCameraLive();

      final state = container.read(mockInterviewControllerProvider) as MockInterviewCameraGate;
      expect(state.error, isA<CameraRequiredFailure>());
    });

    test('the 30s timer ticks down once a second', () {
      fakeAsync((async) {
        final repo = _FakeMockInterviewRepository()..nextQuestionQueue.add(Success(NextQuestionReady(_question(timeRemaining: 5))));
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        notifier.start();
        async.flushMicrotasks();
        notifier.confirmCameraLive();
        async.flushMicrotasks();

        var state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
        expect(state.secondsRemaining, 5);

        async.elapse(const Duration(seconds: 2));
        state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
        expect(state.secondsRemaining, 3);
      });
    });

    test('timer expiry auto-submits whatever text exists — even none — without a manual submit() call', () {
      fakeAsync((async) {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.addAll([
            Success(NextQuestionReady(_question(id: 1, timeRemaining: 2))),
            const Success(InterviewCompleted()),
          ]);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        notifier.start();
        async.flushMicrotasks();
        notifier.confirmCameraLive();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(repo.submitCallCount, 1);
        expect(repo.lastSubmittedAnswerText, ''); // nothing was typed before time ran out
        expect(container.read(mockInterviewControllerProvider), isA<MockInterviewResults>());
      });
    });

    test('updateAnswerText is submitted verbatim (trimmed) when the timer expires', () {
      fakeAsync((async) {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.addAll([
            Success(NextQuestionReady(_question(id: 1, timeRemaining: 2))),
            const Success(InterviewCompleted()),
          ]);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        notifier.start();
        async.flushMicrotasks();
        notifier.confirmCameraLive();
        async.flushMicrotasks();
        notifier.updateAnswerText('  a partial answer  ');

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(repo.lastSubmittedAnswerText, 'a partial answer');
      });
    });

    test(
      'REGRESSION (Phase 10): a manual submit() with a short typed answer succeeds — '
      'no client-side minimum-word restriction exists (approved Phase 9/10 decision: '
      'do not introduce one)',
      () async {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.addAll([
            Success(NextQuestionReady(_question(id: 1))),
            const Success(InterviewCompleted()),
          ]);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        await notifier.start();
        await notifier.confirmCameraLive();
        notifier.updateAnswerText('Yes.');
        await notifier.submitAnswer();

        expect(repo.submitCallCount, 1);
        expect(repo.lastSubmittedAnswerText, 'Yes.');
        expect(container.read(mockInterviewControllerProvider), isA<MockInterviewResults>());
      },
    );

    test('reportViolation is a no-op when no question is active (mirrors interviewIsActive() on the web)', () async {
      final repo = _FakeMockInterviewRepository();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.reportViolation(ViolationType.tabSwitch);

      expect(repo.reportedViolationTypes, isEmpty);
    });

    test('reportViolation records a warning on the active question state', () async {
      final repo = _FakeMockInterviewRepository()
        ..nextQuestionQueue.add(Success(NextQuestionReady(_question())))
        ..violationQueue.add(
          const Success(ViolationRecordResult(count: 1, status: MalpracticeStatus.clean, action: ViolationAction.warn, typeOccurrenceNumber: 1)),
        );
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);
      await notifier.start();
      await notifier.confirmCameraLive();

      await notifier.reportViolation(ViolationType.tabSwitch);

      expect(repo.reportedViolationTypes, [ViolationType.tabSwitch]);
      final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
      expect(state.violationCount, 1);
      expect(state.activeWarning, isNotNull);
    });

    test('reportViolation ends the interview once the server escalates to terminated', () async {
      final repo = _FakeMockInterviewRepository()
        ..nextQuestionQueue.add(Success(NextQuestionReady(_question())))
        ..violationQueue.add(
          const Success(
            ViolationRecordResult(count: 5, status: MalpracticeStatus.terminated, action: ViolationAction.terminated, typeOccurrenceNumber: null),
          ),
        );
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);
      await notifier.start();
      await notifier.confirmCameraLive();

      await notifier.reportViolation(ViolationType.windowBlur);

      expect(container.read(mockInterviewControllerProvider), isA<MockInterviewTerminated>());
    });

    test('acknowledgeWarning clears the active warning without changing the question', () async {
      final repo = _FakeMockInterviewRepository()
        ..nextQuestionQueue.add(Success(NextQuestionReady(_question())))
        ..violationQueue.add(
          const Success(ViolationRecordResult(count: 1, status: MalpracticeStatus.clean, action: ViolationAction.warn, typeOccurrenceNumber: 1)),
        );
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);
      await notifier.start();
      await notifier.confirmCameraLive();
      await notifier.reportViolation(ViolationType.tabSwitch);

      notifier.acknowledgeWarning();

      final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
      expect(state.activeWarning, isNull);
      expect(state.question.id, 1);
    });

    group('REGRESSION (Phase 17) — terminateThreshold is read dynamically, never hardcoded', () {
      test('the real server-provided terminate_threshold (3) flows into the active question state', () async {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.add(Success(NextQuestionReady(_question())))
          ..violationStateResult = const Success(
            ViolationState(count: 0, status: MalpracticeStatus.clean, flagThreshold: 2, terminateThreshold: 3),
          );
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        await notifier.start();
        await notifier.confirmCameraLive();

        final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
        expect(state.terminateThreshold, 3);
      });

      test('a different configured terminate_threshold (5) flows through identically — proves this is never a baked-in number', () async {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.add(Success(NextQuestionReady(_question())))
          ..violationStateResult = const Success(
            ViolationState(count: 0, status: MalpracticeStatus.clean, flagThreshold: 3, terminateThreshold: 5),
          );
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        await notifier.start();
        await notifier.confirmCameraLive();

        final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
        expect(state.terminateThreshold, 5);
      });

      test('getViolationState is fetched once per interview, not re-fetched on every subsequent question', () async {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.addAll([
            Success(NextQuestionReady(_question(id: 1))),
            Success(NextQuestionReady(_question(id: 2))),
          ]);
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);
        await notifier.start();
        await notifier.confirmCameraLive();
        expect(repo.violationStateCallCount, 1);

        notifier.updateAnswerText('Yes.');
        await notifier.submitAnswer();

        final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
        expect(state.question.id, 2);
        expect(state.terminateThreshold, 3); // carried forward, not lost on the next question
        expect(repo.violationStateCallCount, 1); // still only ever fetched once
      });

      test('a failed getViolationState leaves terminateThreshold null rather than guessing a number', () async {
        final repo = _FakeMockInterviewRepository()
          ..nextQuestionQueue.add(Success(NextQuestionReady(_question())))
          ..violationStateResult = const Failed(ServerFailure());
        final container = _buildContainer(repo);
        addTearDown(container.dispose);
        final notifier = container.read(mockInterviewControllerProvider.notifier);

        await notifier.start();
        await notifier.confirmCameraLive();

        final state = container.read(mockInterviewControllerProvider) as MockInterviewQuestionActive;
        expect(state.terminateThreshold, isNull);
      });
    });
  });

  group('Batch 10 — uploadRecordedVideo', () {
    test('calls the real resume_upload_interview_video repository method with the given local file path', () async {
      final repo = _FakeMockInterviewRepository();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(mockInterviewControllerProvider.notifier);

      await notifier.uploadRecordedVideo('/tmp/interview_recording.mp4');

      expect(repo.uploadVideoCallCount, 1);
      expect(repo.lastUploadedVideoPath, '/tmp/interview_recording.mp4');
    });
  });
}
