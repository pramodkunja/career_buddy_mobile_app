import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/entities/reading_passage.dart';
import 'package:career_buddy_lms/features/ai_reading/domain/repositories/ai_reading_repository.dart';
import 'package:career_buddy_lms/features/ai_reading/presentation/controllers/ai_reading_controller.dart';
import 'package:career_buddy_lms/features/ai_reading/presentation/providers/ai_reading_providers.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/ai_speaking/presentation/providers/ai_speaking_providers.dart' show audioRecorderServiceProvider;
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

ReadingAnalysisResult _analysisResult({int score25 = 20}) => ReadingAnalysisResult(
  text: 'The reference passage.',
  issues: const [],
  improvedPassage: 'An improved reading.',
  feedback: 'Great reading.',
  quickTip: 'Keep it steady.',
  scores: const {'accuracy': 90},
  score25: score25,
);

class _FakeAiReadingRepository implements AiReadingRepository {
  Result<ReadingAnalysisResult>? analyzeResult;
  int analyzeCallCount = 0;
  String? lastAudioFilePath;
  double? lastDurationSeconds;
  int? lastPauseCount;
  String? lastLanguage;
  String? lastReferenceText;

  @override
  Future<Result<ReadingAnalysisResult>> analyze({
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

ProviderContainer _buildContainer({_FakeAudioRecorderService? recorder, _FakeAiReadingRepository? repo}) {
  return ProviderContainer(
    overrides: [
      audioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
      aiReadingRepositoryProvider.overrideWithValue(repo ?? _FakeAiReadingRepository()),
    ],
  );
}

void main() {
  group('AiReadingController', () {
    test('starts in ReadingIdle at level 1 with a passage from that pool, no async loading phase', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final state = container.read(aiReadingControllerProvider(1));

      expect(state, isA<ReadingIdle>());
      expect(state.level, 1);
      expect(kReadingPassagesByLevel[1]!.map((p) => p.title), contains(state.passage.title));
    });

    test('setLevel switches to the requested level with a passage from its own pool, discarding any result', () async {
      final repo = _FakeAiReadingRepository()..analyzeResult = Success(_analysisResult());
      final container = _buildContainer(repo: repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiReadingControllerProvider(1).notifier);

      notifier.setLevel(2);

      final state = container.read(aiReadingControllerProvider(1));
      expect(state.level, 2);
      expect(kReadingPassagesByLevel[2]!.map((p) => p.title), contains(state.passage.title));
      expect(state, isA<ReadingIdle>());
    });

    test('pickNewPassage switches to a different passage from the same level, never repeating before the pool is exhausted', () {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiReadingControllerProvider(1).notifier);

      final seen = <String>{};
      for (var i = 0; i < kReadingPassagesByLevel[1]!.length - 1; i++) {
        notifier.pickNewPassage();
        final title = container.read(aiReadingControllerProvider(1)).passage.title;
        expect(seen.contains(title), isFalse, reason: 'passage "$title" repeated before the pool was exhausted');
        seen.add(title);
      }
    });

    test('startRecording denies with a mic error message when permission is refused, without starting the recorder', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(permissionGranted: false);
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(aiReadingControllerProvider(1)) as ReadingIdle;
        expect(state.micErrorMessage, isNotNull);
        expect(recorder.startCount, 0);
      });
    });

    test('startRecording moves to ReadingRecording at 0 elapsed seconds and starts the platform recorder', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);

        notifier.startRecording();
        async.flushMicrotasks();

        final state = container.read(aiReadingControllerProvider(1)) as ReadingRecording;
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
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));

        final state = container.read(aiReadingControllerProvider(1)) as ReadingRecording;
        expect(state.elapsedSeconds, 5);
      });
    });

    test('pausing while recording stops the timer and marks the state paused', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));

        notifier.pauseRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        final state = container.read(aiReadingControllerProvider(1)) as ReadingRecording;
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
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        notifier.pauseRecording();
        async.flushMicrotasks();

        notifier.resumeRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));

        final state = container.read(aiReadingControllerProvider(1)) as ReadingRecording;
        expect(state.paused, isFalse);
        expect(state.elapsedSeconds, 5);
        expect(recorder.resumeCount, 1);
      });
    });

    test('exceeding 5 pauses discards the recording entirely and returns to ReadingIdle with a message '
        '(unlike Speaking, which keeps the recording)', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/paused-out.m4a');
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        for (var i = 0; i < 5; i++) {
          notifier.pauseRecording();
          async.flushMicrotasks();
          notifier.resumeRecording();
          async.flushMicrotasks();
        }
        // 6th pause exceeds the cap of 5.
        notifier.pauseRecording();
        async.flushMicrotasks();

        final state = container.read(aiReadingControllerProvider(1)) as ReadingIdle;
        expect(state.micErrorMessage, contains('maximum pause count'));
        expect(recorder.cancelCount, greaterThanOrEqualTo(1));
      });
    });

    test('stopRecording with no recorded file falls back to ReadingIdle with an error message', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: null);
        final container = _buildContainer(recorder: recorder);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();

        notifier.stopRecording();
        async.flushMicrotasks();

        final state = container.read(aiReadingControllerProvider(1)) as ReadingIdle;
        expect(state.micErrorMessage, isNotNull);
      });
    });

    test('submitForAnalysis sends the recorded file and passage text, moving to ReadingResult on success', () {
      fakeAsync((async) {
        final repo = _FakeAiReadingRepository()..analyzeResult = Success(_analysisResult(score25: 22));
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        final passageText = container.read(aiReadingControllerProvider(1)).passage.text;
        notifier.startRecording();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        final state = container.read(aiReadingControllerProvider(1)) as ReadingResult;
        expect(state.result.score25, 22);
        expect(repo.analyzeCallCount, 1);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
        expect(repo.lastDurationSeconds, 4.0);
        expect(repo.lastReferenceText, passageText);
        expect(repo.lastLanguage, 'english');
      });
    });

    test('setLanguage changes the language sent on the next submission', () {
      fakeAsync((async) {
        final repo = _FakeAiReadingRepository()..analyzeResult = Success(_analysisResult());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.setLanguage('russian');
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        expect(repo.lastLanguage, 'russian');
      });
    });

    test('a failed submission moves to ReadingSubmitFailed, and retrying with the same recording succeeds', () {
      fakeAsync((async) {
        final repo = _FakeAiReadingRepository()..analyzeResult = const Failed(ServerFailure());
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        final failedState = container.read(aiReadingControllerProvider(1)) as ReadingSubmitFailed;
        expect(failedState.failure, isA<ServerFailure>());
        expect(failedState.audioFilePath, '/tmp/take1.m4a');

        repo.analyzeResult = Success(_analysisResult());
        notifier.submitForAnalysis();
        async.flushMicrotasks();

        expect(container.read(aiReadingControllerProvider(1)), isA<ReadingResult>());
        expect(repo.analyzeCallCount, 2);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
      });
    });

    test('submitForAnalysis is a no-op once a result exists — the attempt is locked until Try Again/restart', () {
      fakeAsync((async) {
        final repo = _FakeAiReadingRepository()..analyzeResult = Success(_analysisResult(score25: 15));
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();
        notifier.submitForAnalysis();
        async.flushMicrotasks();
        expect(container.read(aiReadingControllerProvider(1)), isA<ReadingResult>());
        expect(repo.analyzeCallCount, 1);

        notifier.submitForAnalysis(); // no-op: state is ReadingResult, matched by `default:` in the switch
        async.flushMicrotasks();

        expect(repo.analyzeCallCount, 1);
      });
    });

    test('tryAgain from a result resets to idle on the same passage, discarding the result and unlocking submission', () {
      fakeAsync((async) {
        final repo = _FakeAiReadingRepository()..analyzeResult = Success(_analysisResult());
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);
        final passage = container.read(aiReadingControllerProvider(1)).passage;
        notifier.startRecording();
        async.flushMicrotasks();
        notifier.stopRecording();
        async.flushMicrotasks();
        notifier.submitForAnalysis();
        async.flushMicrotasks();
        expect(container.read(aiReadingControllerProvider(1)), isA<ReadingResult>());

        notifier.tryAgain();

        final state = container.read(aiReadingControllerProvider(1));
        expect(state, isA<ReadingIdle>());
        expect(state.passage.title, passage.title);
      });
    });

    test('submitForAnalysis is a no-op from ReadingIdle (nothing recorded yet)', () {
      fakeAsync((async) {
        final repo = _FakeAiReadingRepository();
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(aiReadingControllerProvider(1).notifier);

        notifier.submitForAnalysis();
        async.flushMicrotasks();

        expect(repo.analyzeCallCount, 0);
        expect(container.read(aiReadingControllerProvider(1)), isA<ReadingIdle>());
      });
    });
  });
}
