import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_assessment_repository.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_session_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same shape as `jam_session_controller_test.dart`'s own fake recorder —
/// duplicated here (rather than shared) since that file's helper is
/// private to it; kept intentionally minimal.
class _FakeAudioRecorderService implements AudioRecorderService {
  final String? stopPath = '/tmp/jam.m4a';

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => stopPath;

  @override
  Future<void> cancel() async {}
}

JamSessionStart _stageSession({required int sessionId, required int stage, String difficulty = 'easy'}) =>
    JamSessionStart(sessionId: sessionId, topicTitle: 'Topic $sessionId', topicDescription: '', topicDifficulty: difficulty, stage: stage);

/// This flow never calls the plain (non-assessment) `JamRepository` at all
/// once started via `startAssessment` — only `saveAudio` (shared by both
/// flows) and, through `JamAssessmentRepository`, `startAssessment`/
/// `completeAssessmentStage`. `getTopics`/`startSession`/`completeSession`
/// are never exercised here and throw if accidentally called.
class _UnusedJamRepository implements JamRepository {
  @override
  Future<Result<List<JamTopic>>> getTopics() => throw UnimplementedError();

  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) => throw UnimplementedError();

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) async => const Success(null);

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) => throw UnimplementedError();
}

class _FakeJamAssessmentRepository implements JamAssessmentRepository {
  Result<JamSessionStart>? startResult;
  final List<Result<JamAssessmentStageOutcome>> completeResults = [];
  int completeCallCount = 0;
  final List<int> completedSessionIds = [];

  @override
  Future<Result<List<JamPracticeSessionSummary>>> getHistory() async => const Success([]);

  @override
  Future<Result<JamSessionStart>> startAssessment() async => startResult!;

  @override
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId) async {
    completedSessionIds.add(sessionId);
    return completeResults[completeCallCount++];
  }
}

ProviderContainer _buildContainer({required _FakeJamAssessmentRepository assessmentRepo, _FakeAudioRecorderService? recorder}) {
  return ProviderContainer(
    overrides: [
      jamAudioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
      jamRepositoryProvider.overrideWithValue(_UnusedJamRepository()),
      jamAssessmentRepositoryProvider.overrideWithValue(assessmentRepo),
    ],
  );
}

JamAssessmentResult _finalResult() => const JamAssessmentResult(
  level: 'Advanced',
  averageDurationSeconds: 50,
  averageFluency: 4.5,
  totalScore: 65,
  stages: [
    JamAssessmentStageSummary(difficulty: 'easy', topicTitle: 'My Family', overallScore: 22),
    JamAssessmentStageSummary(difficulty: 'medium', topicTitle: 'Climate Change', overallScore: 21),
    JamAssessmentStageSummary(difficulty: 'hard', topicTitle: 'AI Ethics', overallScore: 22),
  ],
  reportText: 'Great work across all 3 stages.',
);

/// Drives the controller through a full recording cycle for whatever
/// session is currently in `JamReady`, stopping at 5 elapsed seconds (well
/// past the `>= 2s` "too short" guard) and landing on `JamReadyForFeedback`.
void _recordAndUpload(FakeAsync async, JamSessionController notifier) {
  notifier.startRecording();
  async.flushMicrotasks();
  async.elapse(const Duration(seconds: 5));
  notifier.stopRecording();
  async.flushMicrotasks();
}

void main() {
  group('JamSessionController — Assessment flow', () {
    test('startAssessment lands on JamReady with stage 1', () {
      fakeAsync((async) {
        final assessmentRepo = _FakeJamAssessmentRepository()..startResult = Success(_stageSession(sessionId: 501, stage: 1));
        final container = _buildContainer(assessmentRepo: assessmentRepo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);

        notifier.startAssessment();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReady;
        expect(state.session.sessionId, 501);
        expect(state.session.stage, 1);
      });
    });

    test('stage 1 complete → JamReady with stage 2 (no navigation, same running flow)', () {
      fakeAsync((async) {
        final assessmentRepo = _FakeJamAssessmentRepository()
          ..startResult = Success(_stageSession(sessionId: 501, stage: 1))
          ..completeResults.add(Success(JamAssessmentNextStage(_stageSession(sessionId: 502, stage: 2, difficulty: 'medium'))));
        final container = _buildContainer(assessmentRepo: assessmentRepo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startAssessment();
        async.flushMicrotasks();
        _recordAndUpload(async, notifier);

        notifier.getFeedback();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReady;
        expect(state.session.sessionId, 502);
        expect(state.session.stage, 2);
        expect(assessmentRepo.completedSessionIds, [501]);
      });
    });

    test('stage 2 complete → JamReady with stage 3', () {
      fakeAsync((async) {
        final assessmentRepo = _FakeJamAssessmentRepository()
          ..startResult = Success(_stageSession(sessionId: 501, stage: 1))
          ..completeResults.addAll([
            Success(JamAssessmentNextStage(_stageSession(sessionId: 502, stage: 2, difficulty: 'medium'))),
            Success(JamAssessmentNextStage(_stageSession(sessionId: 503, stage: 3, difficulty: 'hard'))),
          ]);
        final container = _buildContainer(assessmentRepo: assessmentRepo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startAssessment();
        async.flushMicrotasks();
        _recordAndUpload(async, notifier); // stage 1
        notifier.getFeedback();
        async.flushMicrotasks(); // now stage 2, JamReady
        _recordAndUpload(async, notifier); // stage 2

        notifier.getFeedback();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReady;
        expect(state.session.sessionId, 503);
        expect(state.session.stage, 3);
        expect(assessmentRepo.completedSessionIds, [501, 502]);
      });
    });

    test('stage 3 complete → JamAssessmentResultReady with the final diagnostic report', () {
      fakeAsync((async) {
        final assessmentRepo = _FakeJamAssessmentRepository()
          ..startResult = Success(_stageSession(sessionId: 503, stage: 3, difficulty: 'hard'))
          ..completeResults.add(Success(JamAssessmentFinished(_finalResult())));
        final container = _buildContainer(assessmentRepo: assessmentRepo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startAssessment();
        async.flushMicrotasks();
        _recordAndUpload(async, notifier);

        notifier.getFeedback();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamAssessmentResultReady;
        expect(state.result.level, 'Advanced');
        expect(state.result.totalScore, 65);
        expect(state.result.stages, hasLength(3));
        expect(assessmentRepo.completedSessionIds, [503]);
      });
    });

    test('a failed completeAssessmentStage call moves to JamCompleteFailed, retryable via getFeedback', () {
      fakeAsync((async) {
        final assessmentRepo = _FakeJamAssessmentRepository()
          ..startResult = Success(_stageSession(sessionId: 501, stage: 1))
          ..completeResults.addAll([
            const Failed(ServerFailure()),
            Success(JamAssessmentNextStage(_stageSession(sessionId: 502, stage: 2, difficulty: 'medium'))),
          ]);
        final container = _buildContainer(assessmentRepo: assessmentRepo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startAssessment();
        async.flushMicrotasks();
        _recordAndUpload(async, notifier);

        notifier.getFeedback();
        async.flushMicrotasks();
        expect(container.read(jamSessionControllerProvider), isA<JamCompleteFailed>());

        notifier.getFeedback();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReady;
        expect(state.session.sessionId, 502);
        expect(assessmentRepo.completedSessionIds, [501, 501]);
      });
    });

    test('an ordinary (non-assessment) session never touches JamAssessmentRepository.completeAssessmentStage', () {
      fakeAsync((async) {
        // `jamRepositoryProvider` is overridden with `_UnusedJamRepository`,
        // whose `startSession`/`completeSession` throw if called — proving
        // this path is exercised instead of the assessment one whenever
        // `session.stage` is null. Uses `startSession`, not
        // `startAssessment`, so this exercises the *other* branch: a
        // regular repository that actually implements `startSession`/
        // `completeSession`.
        final normalRepo = _RecordingNormalJamRepository();
        final assessmentRepo = _FakeJamAssessmentRepository();
        final container = ProviderContainer(
          overrides: [
            jamAudioRecorderServiceProvider.overrideWithValue(_FakeAudioRecorderService()),
            jamRepositoryProvider.overrideWithValue(normalRepo),
            jamAssessmentRepositoryProvider.overrideWithValue(assessmentRepo),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);

        notifier.startSession();
        async.flushMicrotasks();
        _recordAndUpload(async, notifier);
        notifier.getFeedback();
        async.flushMicrotasks();

        expect(container.read(jamSessionControllerProvider), isA<JamResultReady>());
        expect(normalRepo.completeCallCount, 1);
        expect(assessmentRepo.completeCallCount, 0);
      });
    });
  });
}

class _RecordingNormalJamRepository implements JamRepository {
  int completeCallCount = 0;

  @override
  Future<Result<List<JamTopic>>> getTopics() async => const Success([]);

  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) async =>
      const Success(JamSessionStart(sessionId: 1, topicTitle: 'My Family', topicDescription: '', topicDifficulty: 'easy'));

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) async => const Success(null);

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) async {
    completeCallCount++;
    return const Success(
      JamSessionResult(
        sessionId: 1,
        topicTitle: 'My Family',
        topicDifficulty: 'easy',
        durationDisplay: '5s',
        confidenceScore: 3,
        fluencyScore: 3,
        languageScore: 3,
        pronunciationScore: 3,
        timeManagementScore: 3,
        overallScore: 15,
        transcript: '',
        aiFeedback: '',
        improvementTips: '',
        audioUrl: null,
        createdAtDisplay: '',
      ),
    );
  }
}
