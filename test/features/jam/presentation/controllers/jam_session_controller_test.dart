import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_session_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  _FakeAudioRecorderService({this.permissionGranted = true, this.stopPath = '/tmp/jam.m4a'});

  bool permissionGranted;
  String? stopPath;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async => startCount++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async {
    stopCount++;
    return stopPath;
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

JamSessionStart _session({int id = 1}) =>
    JamSessionStart(sessionId: id, topicTitle: 'My Family', topicDescription: 'Talk about family.', topicDifficulty: 'easy');

JamSessionResult _result({int sessionId = 1}) => JamSessionResult(
  sessionId: sessionId,
  topicTitle: 'My Family',
  topicDifficulty: 'easy',
  durationDisplay: '40s',
  confidenceScore: 4,
  fluencyScore: 3,
  languageScore: 4,
  pronunciationScore: 3,
  timeManagementScore: 4,
  overallScore: 18,
  transcript: 'Some transcript.',
  aiFeedback: 'Nice job.',
  improvementTips: 'Keep practicing.',
  audioUrl: null,
  createdAtDisplay: 'Feb 10 2026',
);

class _FakeJamRepository implements JamRepository {
  Result<JamSessionStart>? startResult;
  Result<void>? saveAudioResult;
  Result<JamSessionResult>? completeResult;

  int startCallCount = 0;
  int saveAudioCallCount = 0;
  int completeCallCount = 0;
  String? lastAudioFilePath;
  int? lastDurationSeconds;
  String? lastLanguage;

  @override
  Future<Result<List<JamTopic>>> getTopics() async => const Success([]);

  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) async {
    startCallCount++;
    return startResult!;
  }

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) async {
    saveAudioCallCount++;
    lastAudioFilePath = audioFilePath;
    lastDurationSeconds = durationSeconds;
    lastLanguage = language;
    return saveAudioResult!;
  }

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) async {
    completeCallCount++;
    return completeResult!;
  }
}

ProviderContainer _buildContainer({_FakeAudioRecorderService? recorder, _FakeJamRepository? repo}) {
  return ProviderContainer(
    overrides: [
      jamAudioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
      jamRepositoryProvider.overrideWithValue(repo ?? _FakeJamRepository()),
    ],
  );
}

void main() {
  group('JamSessionController', () {
    test('starts in JamSessionInitial', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      expect(container.read(jamSessionControllerProvider), isA<JamSessionInitial>());
    });

    test('startSession moves to JamReady with the started session on success', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = Success(_session());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);

        notifier.startSession(topicId: 3);
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReady;
        expect(state.session.sessionId, 1);
        expect(state.session.topicTitle, 'My Family');
        expect(repo.startCallCount, 1);
      });
    });

    test('startSession moves to JamStartFailed on failure', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = const Failed(ServerFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);

        notifier.startSession();
        async.flushMicrotasks();

        expect(container.read(jamSessionControllerProvider), isA<JamStartFailed>());
      });
    });

    test('startRecording denies with a mic error message when permission is refused', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = Success(_session());
        final recorder = _FakeAudioRecorderService(permissionGranted: false);
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReady;
        expect(state.micErrorMessage, isNotNull);
        expect(recorder.startCount, 0);
      });
    });

    test('startRecording moves to JamRecordingInProgress at 0 elapsed seconds', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = Success(_session());
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamRecordingInProgress;
        expect(state.elapsedSeconds, 0);
        expect(recorder.startCount, 1);
      });
    });

    test('the timer counts elapsed seconds once per second while recording', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = Success(_session());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));

        final state = container.read(jamSessionControllerProvider) as JamRecordingInProgress;
        expect(state.elapsedSeconds, 5);
      });
    });

    test('auto-stops and uploads at the 60-second JAM cap', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()
          ..startResult = Success(_session())
          ..saveAudioResult = const Success(null);
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/full.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReadyForFeedback;
        // The cap fires as soon as the *next* tick would reach 60 (same
        // off-by-one as `AiSpeakingController`'s own 90s cap) — the state
        // is stopped at the last tick *before* crossing the threshold, 59.
        expect(state.elapsedSeconds, 59);
        expect(recorder.stopCount, 1);
        expect(repo.saveAudioCallCount, 1);
        expect(repo.lastAudioFilePath, '/tmp/full.m4a');
        expect(repo.lastDurationSeconds, 59);
      });
    });

    test('stopping before 2 seconds elapsed moves to JamRecordingTooShort without uploading', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = Success(_session());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        notifier.stopRecording();
        async.flushMicrotasks();

        expect(container.read(jamSessionControllerProvider), isA<JamRecordingTooShort>());
        expect(repo.saveAudioCallCount, 0);
      });
    });

    test('startRecording after JamRecordingTooShort re-records the same session', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()..startResult = Success(_session(id: 9));
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        notifier.stopRecording();
        async.flushMicrotasks();
        expect(container.read(jamSessionControllerProvider), isA<JamRecordingTooShort>());

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamRecordingInProgress;
        expect(state.session.sessionId, 9);
      });
    });

    test('a normal stop (>= 2s) uploads and moves to JamReadyForFeedback on success', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()
          ..startResult = Success(_session())
          ..saveAudioResult = const Success(null);
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        notifier.stopRecording();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamReadyForFeedback;
        expect(state.elapsedSeconds, 10);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
      });
    });

    test('a failed upload moves to JamUploadFailed, preserving the recording for retry', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()
          ..startResult = Success(_session())
          ..saveAudioResult = const Failed(ServerFailure());
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        notifier.stopRecording();
        async.flushMicrotasks();

        final failedState = container.read(jamSessionControllerProvider) as JamUploadFailed;
        expect(failedState.failure, isA<ServerFailure>());
        expect(failedState.audioFilePath, '/tmp/take1.m4a');

        repo.saveAudioResult = const Success(null);
        notifier.retryUpload();
        async.flushMicrotasks();

        expect(container.read(jamSessionControllerProvider), isA<JamReadyForFeedback>());
        expect(repo.saveAudioCallCount, 2);
      });
    });

    test('getFeedback moves to JamResultReady with the parsed result on success', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()
          ..startResult = Success(_session(id: 7))
          ..saveAudioResult = const Success(null)
          ..completeResult = Success(_result(sessionId: 7));
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.getFeedback();
        async.flushMicrotasks();

        final state = container.read(jamSessionControllerProvider) as JamResultReady;
        expect(state.result.sessionId, 7);
        expect(state.result.overallScore, 18);
        expect(repo.completeCallCount, 1);
      });
    });

    test('getFeedback failure moves to JamCompleteFailed, and retrying calls completeSession again', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()
          ..startResult = Success(_session())
          ..saveAudioResult = const Success(null)
          ..completeResult = const Failed(ServerFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.getFeedback();
        async.flushMicrotasks();
        expect(container.read(jamSessionControllerProvider), isA<JamCompleteFailed>());

        repo.completeResult = Success(_result());
        notifier.getFeedback();
        async.flushMicrotasks();

        expect(container.read(jamSessionControllerProvider), isA<JamResultReady>());
        expect(repo.completeCallCount, 2);
      });
    });

    test('setLanguage changes the language sent on the next upload', () {
      fakeAsync((async) {
        final repo = _FakeJamRepository()
          ..startResult = Success(_session())
          ..saveAudioResult = const Success(null);
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(jamSessionControllerProvider.notifier);
        notifier.setLanguage('arabic');
        notifier.startSession();
        async.flushMicrotasks();
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        notifier.stopRecording();
        async.flushMicrotasks();

        expect(repo.lastLanguage, 'arabic');
      });
    });
  });
}
