import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/roleplay/domain/entities/roleplay_analysis_result.dart';
import 'package:career_buddy_lms/features/roleplay/domain/entities/roleplay_generated_content.dart';
import 'package:career_buddy_lms/features/roleplay/domain/repositories/roleplay_repository.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/controllers/roleplay_controller.dart';
import 'package:career_buddy_lms/features/roleplay/presentation/providers/roleplay_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  _FakeAudioRecorderService({this.permissionGranted = true, this.stopPath = '/tmp/roleplay.m4a'});

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

RoleplayGeneratedContent _content({List<String>? followUps}) => RoleplayGeneratedContent(
  usedPrompt: 'a rainy day',
  title: 'A Rainy Day',
  contentHeading: 'Short story',
  content: 'Once upon a time...',
  followUps: followUps ?? const ['Who is the main character?', 'What happened?', 'What is the lesson?'],
  coachTip: 'Answer clearly.',
);

RoleplayAnalysisResult _analysis() => const RoleplayAnalysisResult(
  transcript: 'A transcript.',
  issues: [],
  improvedPassage: 'An improved passage.',
  feedback: 'Good job.',
  quickTip: 'Speak slower.',
  scores: {'overall': 70, 'fluency': 75, 'grammar': 80, 'clarity': 65},
  durationSeconds: 10,
  pauseCount: 0,
);

class _FakeRoleplayRepository implements RoleplayRepository {
  Result<RoleplayGeneratedContent>? generateResult;
  Result<RoleplayAnalysisResult>? analyzeResult;
  int generateCallCount = 0;
  int analyzeCallCount = 0;
  String? lastTopicSlug;
  String? lastPrompt;
  String? lastTopicLabel;
  String? lastAudioFilePath;
  double? lastDurationSeconds;
  String? lastReferenceText;

  @override
  Future<Result<RoleplayGeneratedContent>> generatePractice({
    required String topicSlug,
    required String prompt,
    required String language,
  }) async {
    generateCallCount++;
    lastTopicSlug = topicSlug;
    lastPrompt = prompt;
    return generateResult!;
  }

  @override
  Future<Result<RoleplayAnalysisResult>> analyze({
    required String topicLabel,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    analyzeCallCount++;
    lastTopicLabel = topicLabel;
    lastAudioFilePath = audioFilePath;
    lastDurationSeconds = durationSeconds;
    lastReferenceText = referenceText;
    return analyzeResult!;
  }
}

ProviderContainer _buildContainer({_FakeAudioRecorderService? recorder, _FakeRoleplayRepository? repo}) {
  return ProviderContainer(
    overrides: [
      roleplayAudioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
      roleplayRepositoryProvider.overrideWithValue(repo ?? _FakeRoleplayRepository()),
    ],
  );
}

void main() {
  group('RoleplayController', () {
    test('starts in RoleplaySetup with an empty prompt', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final state = container.read(roleplayControllerProvider('storytelling'));

      expect(state, isA<RoleplaySetup>());
      expect((state as RoleplaySetup).promptText, isEmpty);
      expect(state.topicSlug, 'storytelling');
    });

    test('updatePrompt updates the Setup state prompt text', () {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(roleplayControllerProvider('storytelling').notifier);

      notifier.updatePrompt('a rainy day');

      final state = container.read(roleplayControllerProvider('storytelling')) as RoleplaySetup;
      expect(state.promptText, 'a rainy day');
    });

    test('generate rejects a roleplay prompt missing a second character without calling the server', () {
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository();
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('roleplay').notifier);
        notifier.updatePrompt('Manager');

        notifier.generate();
        async.flushMicrotasks();

        final state = container.read(roleplayControllerProvider('roleplay')) as RoleplaySetup;
        expect(state.validationError, isNotNull);
        expect(repo.generateCallCount, 0);
      });
    });

    test('generate does not apply the two-party check to storytelling/situations', () {
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository()..generateResult = Success(_content());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);
        notifier.updatePrompt('Manager');

        notifier.generate();
        async.flushMicrotasks();

        expect(container.read(roleplayControllerProvider('storytelling')), isA<RoleplayReading>());
        expect(repo.generateCallCount, 1);
      });
    });

    test('generate moves Setup -> Generating -> Reading on success, sending the slug and trimmed prompt', () {
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository()..generateResult = Success(_content());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);
        notifier.updatePrompt('  a rainy day  ');

        notifier.generate();
        async.flushMicrotasks();

        final state = container.read(roleplayControllerProvider('storytelling'));
        expect(state, isA<RoleplayReading>());
        expect((state as RoleplayReading).content.title, 'A Rainy Day');
        expect(repo.lastTopicSlug, 'storytelling');
        expect(repo.lastPrompt, 'a rainy day');
      });
    });

    test('generate moves to RoleplayLocked on a ForbiddenFailure', () {
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository()..generateResult = const Failed(ForbiddenFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);

        notifier.generate();
        async.flushMicrotasks();

        final state = container.read(roleplayControllerProvider('storytelling'));
        expect(state, isA<RoleplayLocked>());
        expect((state as RoleplayLocked).message, const ForbiddenFailure().message);
      });
    });

    test('generate moves to RoleplayGenerateFailed on any other failure, preserving the prompt', () {
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository()..generateResult = const Failed(ServerFailure());
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);
        notifier.updatePrompt('a rainy day');

        notifier.generate();
        async.flushMicrotasks();

        final state = container.read(roleplayControllerProvider('storytelling'));
        expect(state, isA<RoleplayGenerateFailed>());
        expect((state as RoleplayGenerateFailed).promptText, 'a rainy day');
        expect(state.failure, isA<ServerFailure>());
      });
    });

    test('generate moves to RoleplayGenerateFailed, not RoleplayReading, when the server returns an empty follow_ups list', () {
      // Mirrors `roleplay.html:550,553`'s own explicit guard against this
      // exact case — a prior gap let an empty list through to
      // `RoleplayReading`, where `followUps[0]` would throw once the user
      // tapped "I'm Ready".
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository()..generateResult = Success(_content(followUps: const []));
        final container = _buildContainer(repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);
        notifier.updatePrompt('a rainy day');

        notifier.generate();
        async.flushMicrotasks();

        final state = container.read(roleplayControllerProvider('storytelling'));
        expect(state, isA<RoleplayGenerateFailed>());
        expect((state as RoleplayGenerateFailed).promptText, 'a rainy day');
      });
    });

    test('startQuestions denies with a mic error message when permission is refused', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(permissionGranted: false);
        final repo = _FakeRoleplayRepository()..generateResult = Success(_content());
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);
        notifier.generate();
        async.flushMicrotasks();

        notifier.startQuestions();
        async.flushMicrotasks();

        final state = container.read(roleplayControllerProvider('storytelling')) as RoleplayReading;
        expect(state.micErrorMessage, isNotNull);
        expect(recorder.startCount, 0);
      });
    });

    test('the full flow: generate -> startQuestions -> nextQuestion x2 -> finishAndAnalyze -> Result', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final repo = _FakeRoleplayRepository()
          ..generateResult = Success(_content())
          ..analyzeResult = Success(_analysis());
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);

        notifier.generate();
        async.flushMicrotasks();
        expect(container.read(roleplayControllerProvider('storytelling')), isA<RoleplayReading>());

        notifier.startQuestions();
        async.flushMicrotasks();
        var state = container.read(roleplayControllerProvider('storytelling')) as RoleplayRecording;
        expect(state.questionIndex, 0);
        expect(recorder.startCount, 1);

        async.elapse(const Duration(seconds: 3));
        state = container.read(roleplayControllerProvider('storytelling')) as RoleplayRecording;
        expect(state.elapsedSeconds, 3);

        notifier.nextQuestion();
        state = container.read(roleplayControllerProvider('storytelling')) as RoleplayRecording;
        expect(state.questionIndex, 1);

        notifier.nextQuestion();
        state = container.read(roleplayControllerProvider('storytelling')) as RoleplayRecording;
        expect(state.questionIndex, 2);
        expect(state.isLastQuestion, isTrue);

        // Advancing past the last question is a no-op.
        notifier.nextQuestion();
        state = container.read(roleplayControllerProvider('storytelling')) as RoleplayRecording;
        expect(state.questionIndex, 2);

        notifier.finishAndAnalyze();
        async.flushMicrotasks();

        final result = container.read(roleplayControllerProvider('storytelling'));
        expect(result, isA<RoleplayResult>());
        expect((result as RoleplayResult).result.feedback, 'Good job.');
        expect(recorder.stopCount, 1);
        expect(repo.analyzeCallCount, 1);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
        expect(repo.lastDurationSeconds, 3.0);
        expect(repo.lastReferenceText, 'Once upon a time...');
        // Mirrors `promptInput.value || active_topic` — the used prompt, not the slug.
        expect(repo.lastTopicLabel, 'a rainy day');
      });
    });

    test('a failed analysis moves to RoleplaySubmitFailed, and retryAnalysis resends the same recording', () {
      fakeAsync((async) {
        final recorder = _FakeAudioRecorderService(stopPath: '/tmp/take1.m4a');
        final repo = _FakeRoleplayRepository()
          ..generateResult = Success(_content(followUps: ['Only question?']))
          ..analyzeResult = const Failed(ServerFailure());
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('storytelling').notifier);
        notifier.generate();
        async.flushMicrotasks();
        notifier.startQuestions();
        async.flushMicrotasks();

        notifier.finishAndAnalyze();
        async.flushMicrotasks();

        final failedState = container.read(roleplayControllerProvider('storytelling'));
        expect(failedState, isA<RoleplaySubmitFailed>());
        expect((failedState as RoleplaySubmitFailed).audioFilePath, '/tmp/take1.m4a');

        repo.analyzeResult = Success(_analysis());
        notifier.retryAnalysis();
        async.flushMicrotasks();

        expect(container.read(roleplayControllerProvider('storytelling')), isA<RoleplayResult>());
        expect(repo.analyzeCallCount, 2);
        expect(repo.lastAudioFilePath, '/tmp/take1.m4a');
      });
    });

    test('tryAgain resets to an empty Setup on the same topic slug', () {
      fakeAsync((async) {
        final repo = _FakeRoleplayRepository()
          ..generateResult = Success(_content(followUps: ['Only question?']))
          ..analyzeResult = Success(_analysis());
        final recorder = _FakeAudioRecorderService();
        final container = _buildContainer(recorder: recorder, repo: repo);
        addTearDown(container.dispose);
        final notifier = container.read(roleplayControllerProvider('situations').notifier);
        notifier.updatePrompt('a scenario');
        notifier.generate();
        async.flushMicrotasks();
        notifier.startQuestions();
        async.flushMicrotasks();
        notifier.finishAndAnalyze();
        async.flushMicrotasks();
        expect(container.read(roleplayControllerProvider('situations')), isA<RoleplayResult>());

        notifier.tryAgain();

        final state = container.read(roleplayControllerProvider('situations'));
        expect(state, isA<RoleplaySetup>());
        expect((state as RoleplaySetup).promptText, isEmpty);
        expect(state.topicSlug, 'situations');
      });
    });
  });
}
