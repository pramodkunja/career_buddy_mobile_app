import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/entities/listening_story.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/repositories/ai_listening_repository.dart';
import 'package:career_buddy_lms/features/ai_listening/domain/services/listening_tts_service.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/controllers/ai_listening_controller.dart';
import 'package:career_buddy_lms/features/ai_listening/presentation/providers/ai_listening_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeListeningTtsService implements ListeningTtsService {
  void Function()? _onStart;
  void Function()? _onComplete;
  void Function(String)? _onError;

  int speakCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  String? lastSpokenText;
  double? lastRate;

  @override
  Future<void> speak(String text, {required double rate}) async {
    speakCount++;
    lastSpokenText = text;
    lastRate = rate;
    _onStart?.call();
  }

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> stop() async => stopCount++;

  @override
  void setOnStart(void Function() callback) => _onStart = callback;

  @override
  void setOnComplete(void Function() callback) => _onComplete = callback;

  @override
  void setOnError(void Function(String message) callback) => _onError = callback;

  void fireComplete() => _onComplete?.call();
  void fireError(String message) => _onError?.call(message);
}

ListeningAnalysisResult _analysisResult({int score25 = 20, int match = 80}) => ListeningAnalysisResult(
  text: 'A summary.',
  issues: const [],
  improvedPassage: 'An improved summary.',
  feedback: 'Good job.',
  scores: const {'fluency': 90},
  score25: score25,
  contentMatchPercent: match,
);

class _FakeAiListeningRepository implements AiListeningRepository {
  Result<String>? tokenResult;
  Result<ListeningAnalysisResult>? analyzeResult;
  int analyzeCallCount = 0;
  String? lastText;
  String? lastReferenceText;
  int? lastDurationSeconds;
  int? lastPauseCount;
  String? lastAttemptToken;
  String? lastLanguage;

  @override
  Future<Result<String>> fetchAttemptToken(int exerciseId) async => tokenResult!;

  @override
  Future<Result<ListeningAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  }) async {
    analyzeCallCount++;
    lastText = text;
    lastReferenceText = referenceText;
    lastDurationSeconds = durationSeconds;
    lastPauseCount = pauseCount;
    lastAttemptToken = attemptToken;
    lastLanguage = language;
    return analyzeResult!;
  }
}

ProviderContainer _buildContainer({required _FakeAiListeningRepository repo, _FakeListeningTtsService? tts}) {
  return ProviderContainer(
    overrides: [
      aiListeningRepositoryProvider.overrideWithValue(repo),
      listeningTtsServiceProvider.overrideWithValue(tts ?? _FakeListeningTtsService()),
    ],
  );
}

void main() {
  group('AiListeningController', () {
    test('starts in ListeningLoading, then moves to ListeningActive once the token loads', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);

        expect(container.read(aiListeningControllerProvider(1)), isA<ListeningLoading>());
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.attemptToken, 'tok-1');
        expect(state.level, kListeningDefaultLevel);
        expect(state.status, PlaybackStatus.ready);
        expect(kListeningStoriesByLevel['beginner']!.map((s) => s.title), contains(state.story.title));
      });
    });

    test('a token-fetch failure moves to ListeningLoadFailed', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Failed(ForbiddenFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);

        expect(container.read(aiListeningControllerProvider(1)), isA<ListeningLoading>());
        async.flushMicrotasks();

        expect(container.read(aiListeningControllerProvider(1)), isA<ListeningLoadFailed>());
      });
    });

    test('retry() re-fetches the token after a failure', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Failed(ServerFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);

        repo.tokenResult = const Success('tok-2');
        notifier.retry();
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.attemptToken, 'tok-2');
      });
    });

    test('play() starts narration, marking status playing and revealing the story text', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final tts = _FakeListeningTtsService();
        final container = _buildContainer(repo: repo, tts: tts);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        final story = (container.read(aiListeningControllerProvider(1)) as ListeningActive).story;

        notifier.play();
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.status, PlaybackStatus.playing);
        expect(state.storyRevealed, isTrue);
        expect(tts.speakCount, 1);
        expect(tts.lastSpokenText, story.text);
      });
    });

    test('the timer advances elapsed seconds while playing, capped at durationSeconds', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.play();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 2));

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.elapsedSeconds, closeTo(2.0, 0.01));
      });
    });

    test('onComplete callback marks status completed and stops the timer', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final tts = _FakeListeningTtsService();
        final container = _buildContainer(repo: repo, tts: tts);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.play();
        async.flushMicrotasks();

        tts.fireComplete();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.status, PlaybackStatus.completed);
        expect(state.elapsedSeconds, state.durationSeconds.toDouble());
      });
    });

    test('pause() while playing increments pauseCount and pauses the TTS engine', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final tts = _FakeListeningTtsService();
        final container = _buildContainer(repo: repo, tts: tts);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.play();
        async.flushMicrotasks();

        notifier.pause();
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.status, PlaybackStatus.paused);
        expect(state.pauseCount, 1);
        expect(tts.pauseCount, 1);
      });
    });

    test('exceeding 5 pauses terminates the session', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final tts = _FakeListeningTtsService();
        final container = _buildContainer(repo: repo, tts: tts);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);

        for (var i = 0; i < 5; i++) {
          notifier.play();
          async.flushMicrotasks();
          notifier.pause();
          async.flushMicrotasks();
          notifier.resumeNarration();
          async.flushMicrotasks();
        }
        // 6th pause exceeds the cap of 5.
        notifier.pause();
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.status, PlaybackStatus.terminated);
        expect(state.pauseCount, 6);
      });
    });

    test('resumeNarration restarts narration from the beginning, resetting elapsed but keeping pauseCount', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final tts = _FakeListeningTtsService();
        final container = _buildContainer(repo: repo, tts: tts);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.play();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3));
        notifier.pause();
        async.flushMicrotasks();

        notifier.resumeNarration();
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.status, PlaybackStatus.playing);
        expect(state.elapsedSeconds, 0);
        expect(state.pauseCount, 1);
        expect(tts.speakCount, 2);
      });
    });

    test('pickNewStory fully resets: new story, playback ready, and any submission cleared', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = Success(_analysisResult());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.play();
        async.flushMicrotasks();
        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();
        expect((container.read(aiListeningControllerProvider(1)) as ListeningActive).submission, isA<SubmissionSucceeded>());

        notifier.pickNewStory();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.status, PlaybackStatus.ready);
        expect(state.elapsedSeconds, 0);
        expect(state.pauseCount, 0);
        expect(state.storyRevealed, isFalse);
        expect(state.submission, isA<SubmissionIdle>());
      });
    });

    test('setSpeed resets playback but does NOT clear an existing submission', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = Success(_analysisResult());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.play();
        async.flushMicrotasks();
        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();

        notifier.setSpeed(1.2);

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.speed, 1.2);
        expect(state.status, PlaybackStatus.ready);
        expect(state.elapsedSeconds, 0);
        // Submission untouched — only "New Story"/level change clears it.
        expect(state.submission, isA<SubmissionSucceeded>());
      });
    });

    test('submit() sends the story text as reference_text and locks on success', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = Success(_analysisResult(score25: 22));
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        final story = (container.read(aiListeningControllerProvider(1)) as ListeningActive).story;

        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.submission, isA<SubmissionSucceeded>());
        expect((state.submission as SubmissionSucceeded).result.score25, 22);
        expect(repo.lastReferenceText, story.text);
        expect(repo.lastAttemptToken, 'tok-1');
        expect(repo.analyzeCallCount, 1);
      });
    });

    test('submit() with too-short text is rejected locally, without calling the server', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);

        notifier.submit('too short');
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.submission, isA<SubmissionFailed>());
        expect(repo.analyzeCallCount, 0);
      });
    });

    test('submit() after termination shows the pause-limit message locally, without calling the server', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()..tokenResult = const Success('tok-1');
        final tts = _FakeListeningTtsService();
        final container = _buildContainer(repo: repo, tts: tts);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        for (var i = 0; i < 5; i++) {
          notifier.play();
          async.flushMicrotasks();
          notifier.pause();
          async.flushMicrotasks();
          notifier.resumeNarration();
          async.flushMicrotasks();
        }
        notifier.pause();
        async.flushMicrotasks();

        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        final submission = state.submission as SubmissionFailed;
        expect(submission.failure.message, contains('maximum pause count'));
        expect(repo.analyzeCallCount, 0);
      });
    });

    test('submit() is a no-op once already succeeded — the attempt is permanently locked', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = Success(_analysisResult());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();
        expect(repo.analyzeCallCount, 1);

        notifier.submit('a different summary attempting to resubmit here');
        async.flushMicrotasks();

        expect(repo.analyzeCallCount, 1); // still 1 — no second call
      });
    });

    test('a failed (non-terminated) submission allows retrying with the same token', () {
      fakeAsync((async) {
        final repo = _FakeAiListeningRepository()
          ..tokenResult = const Success('tok-1')
          ..analyzeResult = const Failed(ServerFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        container.read(aiListeningControllerProvider(1)); // trigger build()
        async.flushMicrotasks();
        final notifier = container.read(aiListeningControllerProvider(1).notifier);
        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();
        expect(
          (container.read(aiListeningControllerProvider(1)) as ListeningActive).submission,
          isA<SubmissionFailed>(),
        );

        repo.analyzeResult = Success(_analysisResult());
        notifier.submit('a meaningful enough summary of the story here');
        async.flushMicrotasks();

        final state = container.read(aiListeningControllerProvider(1)) as ListeningActive;
        expect(state.submission, isA<SubmissionSucceeded>());
        expect(repo.analyzeCallCount, 2);
        expect(repo.lastAttemptToken, 'tok-1'); // same token both times
      });
    });
  });
}
