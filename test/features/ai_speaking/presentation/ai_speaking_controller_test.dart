import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_topic.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/repositories/ai_speaking_repository.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/controllers/ai_speaking_controller.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/providers/ai_speaking_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  _FakeAudioRecorderService({this.permissionGranted = true, this.stopPath = '/tmp/rec.m4a'});

  bool permissionGranted;
  String? stopPath;
  int startCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async => startCount++;

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> resume() async => resumeCount++;

  @override
  Future<String?> stop() async {
    stopCount++;
    return stopPath;
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

SpeakingAnalysisResult _analysisResult({int score25 = 20}) => SpeakingAnalysisResult(
  transcript: 'A transcript.',
  issues: const [],
  improvedPassage: 'An improved passage.',
  feedback: 'Good job.',
  scores: const {'fluency': 90, 'pronunciation': 90, 'confidence': 90},
  score25: score25,
  durationSeconds: 10,
  pauseCount: 0,
);

class _FakeAiSpeakingRepository implements AiSpeakingRepository {
  Result<SpeakingAnalysisResult>? analyzeResult;
  int analyzeCallCount = 0;
  String? lastAudioFilePath;
  double? lastDurationSeconds;
  int? lastPauseCount;
  String? lastLanguage;
  String? lastReferenceText;

  @override
  Future<Result<SpeakingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    analyzeCallCount++;
    lastAudioFilePath = audioFilePath;
    lastDurationSeconds = durationSeconds;
    lastPauseCount = pauseCount;
    lastLanguage = language;
    lastReferenceText = referenceText;
    return analyzeResult!;
  }
}

ProviderContainer _buildContainer({_FakeAudioRecorderService? recorder, _FakeAiSpeakingRepository? repo}) {
  return ProviderContainer(
    overrides: [
      audioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
      aiSpeakingRepositoryProvider.overrideWithValue(repo ?? _FakeAiSpeakingRepository()),
    ],
  );
}

void main() {
  group('AiSpeakingController', () {
    test('starts in AiSpeakingIdle with the hardcoded initial topic', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final state = container.read(aiSpeakingControllerProvider(1));

      expect(state, isA<AiSpeakingIdle>());
      expect(state.topic, kSpeakingInitialTopic);
    });

    test('pickNewTopic switches to a topic from the pool, never repeating the current one immediately', () {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiSpeakingControllerProvider(1).notifier);

      notifier.pickNewTopic();

      final state = container.read(aiSpeakingControllerProvider(1));
      expect(state, isA<AiSpeakingIdle>());
      expect(kSpeakingTopics.contains(state.topic), isTrue);
    });

    test('pickNewTopic never repeats a topic before the whole pool (minus current) is exhausted', () {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiSpeakingControllerProvider(1).notifier);

      final seen = <String>{};
      for (var i = 0; i < kSpeakingTopics.length - 1; i++) {
        notifier.pickNewTopic();
        final topic = container.read(aiSpeakingControllerProvider(1)).topic;
        expect(seen.contains(topic), isFalse, reason: 'topic "$topic" repeated before the pool was exhausted');
        seen.add(topic);
      }
    });

    test('startRecording denies with a mic error message when permission is refused, without starting the recorder', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(permissionGranted: false);
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingIdle;
        expect(state.micErrorMessage, isNotNull);
        expect(recorder.startCount, 0);
      });
    });

    test('startRecording moves to AiSpeakingRecording at 0 elapsed seconds and starts the platform recorder', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingRecording;
        expect(state.elapsedSeconds, 0);
        expect(state.paused, isFalse);
        expect(state.pauseCount, 0);
        expect(recorder.startCount, 1);
      });
    });

    test('the timer counts elapsed seconds once per second while recording', () {
      fakeAsync((async) {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingRecording;
        expect(state.elapsedSeconds, 5);
      });
    });

    test('auto-stops at the 90-second cap, moving to AiSpeakingRecorded with timeLimitReached true', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/full.m4a');
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 90));
        async.flushMicrotasks();

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingRecorded;
        expect(state.timeLimitReached, isTrue);
        expect(state.pauseLimitExceeded, isFalse);
        expect(state.audioFilePath, '/tmp/full.m4a');
        expect(recorder.stopCount, 1);
      });
    });

    test('pausing while recording stops the timer and marks the state paused', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        notifier.pauseRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10)); // must NOT keep counting while paused

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingRecording;
        expect(state.paused, isTrue);
        expect(state.elapsedSeconds, 3);
        expect(state.pauseCount, 1);
        expect(recorder.pauseCount, 1);
      });
    });

    test('resuming continues the timer from where it left off', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        notifier.pauseRecording();
        async.flushMicrotasks();

        notifier.resumeRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingRecording;
        expect(state.paused, isFalse);
        expect(state.elapsedSeconds, 5);
        expect(recorder.resumeCount, 1);
      });
    });

    test('exceeding 5 pauses auto-stops the recording with pauseLimitExceeded true', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/paused-out.m4a');
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        for (var i = 0; i < 5; i++) {
          notifier.pauseRecording();
          async.flushMicrotasks();
          notifier.resumeRecording();
          async.flushMicrotasks();
        }
        // 6th pause exceeds the cap of 5 and auto-stops.
        notifier.pauseRecording();
        async.flushMicrotasks();

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingRecorded;
        expect(state.pauseLimitExceeded, isTrue);
        expect(state.pauseCount, 6);
        expect(state.audioFilePath, '/tmp/paused-out.m4a');
      });
    });

    test('stopRecording with no recorded file falls back to AiSpeakingIdle with an error message', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: null);
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        notifier.stopRecording();
        async.flushMicrotasks();

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingIdle;
        expect(state.micErrorMessage, isNotNull);
      });
    });

    test('submitForAnalysis sends the recorded file and topic, moving to AiSpeakingResult with a computed quick tip on success', () {
      fakeAsync((async) {
        final repo = _FakeAiSpeakingRepository()..analyzeResult = Success(_analysisResult(score25: 22));
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        final initialTopic = container.read(aiSpeakingControllerProvider(1)).topic;
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        final state = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingResult;
        expect(state.result.score25, 22);
        expect(state.quickTip, isNotEmpty);
        expect(repo.analyzeCallCount, 1);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
        expect(repo.lastDurationSeconds, 4.0);
        expect(repo.lastReferenceText, initialTopic);
        expect(repo.lastLanguage, 'english');
      });
    });

    test('setLanguage changes the language sent on the next submission', () {
      fakeAsync((async) {
        final repo = _FakeAiSpeakingRepository()..analyzeResult = Success(_analysisResult());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.setLanguage('vietnam');
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        expect(repo.lastLanguage, 'vietnam');
      });
    });

    test('a failed submission moves to AiSpeakingSubmitFailed, preserving the recording for retry', () {
      fakeAsync((async) {
        final repo = _FakeAiSpeakingRepository()..analyzeResult = const Failed(ServerFailure());
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        final failedState = container.read(aiSpeakingControllerProvider(1)) as AiSpeakingSubmitFailed;
        expect(failedState.failure, isA<ServerFailure>());
        expect(failedState.audioFilePath, '/tmp/take1.m4a');

        // Retry resends the exact same recording.
        repo.analyzeResult = Success(_analysisResult());
        notifier.submitForAnalysis();
        async.flushMicrotasks();

        expect(container.read(aiSpeakingControllerProvider(1)), isA<AiSpeakingResult>());
        expect(repo.analyzeCallCount, 2);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
      });
    });

    test('tryAgain from a result resets to idle on the same topic, discarding the result', () {
      fakeAsync((async) {
        final repo = _FakeAiSpeakingRepository()..analyzeResult = Success(_analysisResult());
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);
        final topic = container.read(aiSpeakingControllerProvider(1)).topic;
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();
        notifier.submitForAnalysis();
        async.flushMicrotasks();
        expect(container.read(aiSpeakingControllerProvider(1)), isA<AiSpeakingResult>());

        notifier.tryAgain();

        final state = container.read(aiSpeakingControllerProvider(1));
        expect(state, isA<AiSpeakingIdle>());
        expect(state.topic, topic);
      });
    });

    test('submitForAnalysis is a no-op from AiSpeakingIdle (nothing recorded yet)', () {
      fakeAsync((async) {
        final repo = _FakeAiSpeakingRepository();
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiSpeakingControllerProvider(1).notifier);

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        expect(repo.analyzeCallCount, 0);
        expect(container.read(aiSpeakingControllerProvider(1)), isA<AiSpeakingIdle>());
      });
    });
  });
}
