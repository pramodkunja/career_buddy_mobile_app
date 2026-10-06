import 'package:camera/camera.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/answer_submission_result.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_analytics.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/interview_question.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/malpractice.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/entities/next_question_outcome.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/repositories/mock_interview_repository.dart';
import 'package:career_buddy_lms/features/mock_interview/domain/services/interview_camera_service.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/controllers/mock_interview_controller.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/providers/mock_interview_providers.dart';
import 'package:career_buddy_lms/features/mock_interview/presentation/screens/mock_interview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Never touches real camera hardware — `start()` just reports whether a
/// "live" preview would be showing, matching `InterviewCameraService`'s own
/// self-attestation contract; `controller` stays `null` so the widget falls
/// back to its placeholder box instead of trying to build a real
/// `CameraPreview`.
/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly avoids that without this file's own
/// tests needing to care about auth at all.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async =>
      throw UnimplementedError();
}

class _FakeInterviewCameraService implements InterviewCameraService {
  _FakeInterviewCameraService({this.startResult = true});
  final bool startResult;
  bool _live = false;
  bool recordingStarted = false;
  String? stopReturnsPath = '/tmp/fake_interview.mp4';

  @override
  Future<bool> start() async {
    _live = startResult;
    return _live;
  }

  @override
  CameraController? get controller => null;

  @override
  bool get isLive => _live;

  @override
  Future<void> startVideoRecording() async => recordingStarted = true;

  @override
  Future<String?> stopVideoRecording() async => stopReturnsPath;

  @override
  Future<void> dispose() async {}
}

/// Starts a [MockInterviewController] straight in a given state, so each
/// widget test can render one phase in isolation without re-driving the
/// whole async start → camera → question flow (already covered by
/// `mock_interview_controller_test.dart`).
class _SeededMockInterviewController extends MockInterviewController {
  _SeededMockInterviewController(this._initial);
  final MockInterviewState _initial;

  @override
  MockInterviewState build() => _initial;
}

InterviewQuestion _question() => const InterviewQuestion(
  id: 9,
  text: 'Describe a time you resolved a conflict with a teammate.',
  topic: 'Behavioural',
  difficulty: 'Easy',
  isCoding: false,
  questionType: 'theory',
  progress: '3/20',
  timeLimitSeconds: 30,
  timeRemainingSeconds: 22,
);

const _analytics = InterviewAnalyticsResult(
  totalScore: 84,
  isPassed: true,
  avgScore: 4.2,
  answeredCount: 20,
  totalQuestions: 20,
  yearsExperience: 3.0,
  questionResults: [
    InterviewQuestionResult(
      topic: 'Python',
      difficulty: 'Easy',
      question: 'What is a list comprehension?',
      answer: 'A concise way to build lists.',
      score: 5,
      feedback: 'Excellent, precise answer.',
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  MockInterviewState state, {
  InterviewCameraService? cameraService,
  Size physicalSize = const Size(400, 2600),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      mockInterviewControllerProvider.overrideWith(
        () => _SeededMockInterviewController(state),
      ),
      interviewCameraServiceFactoryProvider.overrideWithValue(
        () => cameraService ?? _FakeInterviewCameraService(),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MockInterviewScreen()),
    ),
  );
  await tester.pump();
  return container;
}

/// Batch 10 — a minimal, fully-scriptable fake driving the REAL
/// `MockInterviewController` (not `_SeededMockInterviewController`) through
/// its actual start → camera gate → one question → results state machine,
/// so the screen's own video-recording start/stop/upload wiring (which
/// depends on genuine `previous`/`next` state transitions firing through
/// `ref.listen`, not a state seeded directly) can be exercised end-to-end.
class _OneQuestionMockInterviewRepository implements MockInterviewRepository {
  int uploadCallCount = 0;
  String? lastUploadedPath;

  @override
  Future<Result<void>> startInterview() async => const Success(null);

  @override
  Future<Result<void>> confirmCameraLive() async => const Success(null);

  @override
  Future<Result<NextQuestionOutcome>> getNextQuestion({
    required bool advance,
  }) async {
    if (advance) return const Success(InterviewCompleted());
    return const Success(
      NextQuestionReady(
        InterviewQuestion(
          id: 1,
          text: 'Tell me about yourself.',
          topic: 'Behavioural',
          difficulty: 'Easy',
          isCoding: false,
          questionType: 'theory',
          progress: '1/1',
          timeLimitSeconds: 30,
          timeRemainingSeconds: 30,
        ),
      ),
    );
  }

  @override
  Future<Result<AnswerSubmissionResult>> submitAnswer({
    required int questionId,
    required String answerText,
  }) async => const Success(
    AnswerSubmissionResult(
      score: 5,
      feedback: 'Great answer.',
      timedOut: false,
    ),
  );

  @override
  Future<Result<ViolationState>> getViolationState() async => const Success(
    ViolationState(
      count: 0,
      status: MalpracticeStatus.clean,
      flagThreshold: 3,
      terminateThreshold: 5,
    ),
  );

  @override
  Future<Result<ViolationRecordResult>> recordViolation({
    required ViolationType type,
    double? durationSeconds,
  }) async => const Success(
    ViolationRecordResult(
      count: 1,
      status: MalpracticeStatus.clean,
      action: ViolationAction.warn,
      typeOccurrenceNumber: 1,
    ),
  );

  @override
  Future<Result<bool>> uploadInterviewVideo(String filePath) async {
    uploadCallCount++;
    lastUploadedPath = filePath;
    return const Success(true);
  }

  @override
  Future<Result<InterviewAnalyticsResult>> getAnalytics() async =>
      const Success(_analytics);
}

void main() {
  group('MockInterviewScreen — Batch 10: video recording wiring', () {
    testWidgets(
      'starts recording once the candidate leaves the camera gate, and stops + uploads it once results load',
      (tester) async {
        final repo = _OneQuestionMockInterviewRepository();
        final camera = _FakeInterviewCameraService();

        tester.view.physicalSize = const Size(400, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockInterviewRepositoryProvider.overrideWithValue(repo),
              interviewCameraServiceFactoryProvider.overrideWithValue(
                () => camera,
              ),
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            ],
            child: const MaterialApp(home: MockInterviewScreen()),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        // Camera gate: enable camera, then start.
        await tester.tap(find.text('Enable Camera'));
        // Never pumpAndSettle() once `BuddyChatbotOverlay` is in the tree —
        // its launcher's float animation repeats forever and would hang this.
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }
        expect(camera.recordingStarted, isFalse); // not yet — still on the gate

        await tester.tap(find.text('Start Interview'));
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }
        expect(
          camera.recordingStarted,
          isTrue,
        ); // real transition away from the camera gate

        // Answer the one question and let the interview complete.
        await tester.enterText(
          find.byKey(const Key('answer-text-field')),
          'My real answer.',
        );
        await tester.tap(find.text('Submit Answer'));
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        expect(
          find.text('84'),
          findsOneWidget,
        ); // MockInterviewResultsView rendered — see `_analytics` above
        expect(repo.uploadCallCount, 1);
        expect(repo.lastUploadedPath, camera.stopReturnsPath);
      },
    );
  });

  group('MockInterviewScreen — camera gate', () {
    testWidgets(
      'renders the mandatory camera-check UI before a live preview is confirmed',
      (tester) async {
        await _pump(
          tester,
          const MockInterviewCameraGate(),
          cameraService: _FakeInterviewCameraService(),
        );

        expect(find.text('Camera Access Required'), findsOneWidget);
        expect(find.text('Enable Camera'), findsOneWidget);
        // "Start Interview" must not be reachable until the camera is live.
        expect(find.text('Start Interview'), findsNothing);
      },
    );

    testWidgets(
      'reveals "Start Interview" once the fake camera reports a live preview',
      (tester) async {
        await _pump(
          tester,
          const MockInterviewCameraGate(),
          cameraService: _FakeInterviewCameraService(startResult: true),
        );

        await tester.tap(find.text('Enable Camera'));
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        expect(find.text('Start Interview'), findsOneWidget);
        expect(find.textContaining('Camera connected'), findsOneWidget);
      },
    );
  });

  group('MockInterviewScreen — question view', () {
    testWidgets(
      'renders the current question, the countdown timer, and a submit action',
      (tester) async {
        final state = MockInterviewQuestionActive(
          question: _question(),
          secondsRemaining: 22,
          answerText: '',
        );
        await _pump(tester, state);

        expect(find.text(_question().text), findsOneWidget);
        expect(find.text('Question 3/20'), findsOneWidget);
        expect(find.text('22s'), findsOneWidget);
        expect(find.text('Submit Answer'), findsOneWidget);
        expect(find.byKey(const Key('answer-text-field')), findsOneWidget);
      },
    );

    testWidgets('typing an answer updates the controller state', (
      tester,
    ) async {
      final state = MockInterviewQuestionActive(
        question: _question(),
        secondsRemaining: 22,
        answerText: '',
      );
      final container = await _pump(tester, state);

      await tester.enterText(
        find.byKey(const Key('answer-text-field')),
        'My real answer to this question.',
      );
      await tester.pump();

      final current =
          container.read(mockInterviewControllerProvider)
              as MockInterviewQuestionActive;
      expect(current.answerText, 'My real answer to this question.');
    });
  });

  group('MockInterviewScreen — results', () {
    testWidgets(
      'renders the real final score, pass/fail state, and per-question feedback',
      (tester) async {
        await _pump(tester, const MockInterviewResults(_analytics));

        expect(find.text('84'), findsOneWidget);
        expect(find.text('Qualified Candidate'), findsOneWidget);
        expect(find.text('20/20'), findsOneWidget);
        expect(find.text('4.2/5'), findsOneWidget);
        expect(find.text('What is a list comprehension?'), findsOneWidget);
        expect(find.text('Excellent, precise answer.'), findsOneWidget);
        expect(find.text('5/5'), findsOneWidget);
      },
    );
  });

  group('MockInterviewScreen — terminated', () {
    testWidgets('shows the real termination message', (tester) async {
      await _pump(
        tester,
        const MockInterviewTerminated(
          'This interview was ended due to repeated malpractice violations.',
        ),
      );

      expect(find.text('Interview Terminated'), findsOneWidget);
      expect(
        find.textContaining('repeated malpractice violations'),
        findsOneWidget,
      );
    });
  });

  group('Batch 9 responsive QA', () {
    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
    ]) {
      testWidgets(
        'camera gate + question view render without overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await _pump(
            tester,
            const MockInterviewCameraGate(),
            physicalSize: size,
          );
          expect(tester.takeException(), isNull);

          final state = MockInterviewQuestionActive(
            question: _question(),
            secondsRemaining: 22,
            answerText: '',
          );
          await _pump(tester, state, physicalSize: size);
          expect(tester.takeException(), isNull);

          await _pump(
            tester,
            const MockInterviewResults(_analytics),
            physicalSize: size,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
