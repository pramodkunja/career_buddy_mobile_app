import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_analysis_result.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/entities/writing_topic.dart';
import 'package:career_buddy_lms/features/ai_writing/domain/repositories/ai_writing_repository.dart';
import 'package:career_buddy_lms/features/ai_writing/presentation/controllers/ai_writing_controller.dart';
import 'package:career_buddy_lms/features/ai_writing/presentation/providers/ai_writing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

WritingAnalysisResult _analysisResult({int score25 = 20, String improvedPassage = 'An improved passage.'}) =>
    WritingAnalysisResult(
      text: 'My essay text.',
      issues: const [],
      improvedPassage: improvedPassage,
      feedback: 'Good job.',
      quickTip: 'Read your draft once more.',
      scores: const {'grammar': 90, 'vocabulary': 90, 'overall': 90},
      score25: score25,
    );

class _FakeAiWritingRepository implements AiWritingRepository {
  Result<WritingAnalysisResult>? analyzeResult;
  int analyzeCallCount = 0;
  String? lastText;
  String? lastLanguage;
  String? lastReferenceText;
  String? lastPreviousImprovedPassage;

  @override
  Future<Result<WritingAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String language,
    required String referenceText,
    String? previousImprovedPassage,
  }) async {
    analyzeCallCount++;
    lastText = text;
    lastLanguage = language;
    lastReferenceText = referenceText;
    lastPreviousImprovedPassage = previousImprovedPassage;
    return analyzeResult!;
  }
}

ProviderContainer _buildContainer(_FakeAiWritingRepository repo) {
  return ProviderContainer(overrides: [aiWritingRepositoryProvider.overrideWithValue(repo)]);
}

void main() {
  group('AiWritingController', () {
    test('starts in WritingIdle with the hardcoded initial topic and the "general" type', () {
      final container = _buildContainer(_FakeAiWritingRepository());
      addTearDown(container.dispose);

      final state = container.read(aiWritingControllerProvider(1));

      expect(state, isA<WritingIdle>());
      expect(state.topic, kWritingInitialTopic);
      expect(state.writingType, kWritingDefaultType);
    });

    test('pickNewTopic switches to a different topic from the same type\'s pool, never changing the type', () {
      final container = _buildContainer(_FakeAiWritingRepository());
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      notifier.pickNewTopic();

      final state = container.read(aiWritingControllerProvider(1));
      expect(state, isA<WritingIdle>());
      expect(state.writingType, 'general');
      expect(kWritingTopicsByType['general']!.contains(state.topic), isTrue);
    });

    test('pickNewTopic never repeats a topic before the type\'s pool (minus current) is exhausted', () {
      final container = _buildContainer(_FakeAiWritingRepository());
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      final seen = <String>{};
      for (var i = 0; i < kWritingTopicsByType['general']!.length - 1; i++) {
        notifier.pickNewTopic();
        final topic = container.read(aiWritingControllerProvider(1)).topic;
        expect(seen.contains(topic), isFalse, reason: 'topic "$topic" repeated before the pool was exhausted');
        seen.add(topic);
      }
    });

    test('setWritingType switches to the requested type with a topic from its own pool', () {
      final container = _buildContainer(_FakeAiWritingRepository());
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      notifier.setWritingType('story');

      final state = container.read(aiWritingControllerProvider(1));
      expect(state.writingType, 'story');
      expect(kWritingTopicsByType['story']!.contains(state.topic), isTrue);
    });

    test('submit is a no-op when the text is outside the 500-900 character range', () async {
      final repo = _FakeAiWritingRepository();
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      await notifier.submit('too short');

      expect(repo.analyzeCallCount, 0);
      expect(container.read(aiWritingControllerProvider(1)), isA<WritingIdle>());
    });

    test('submit sends the topic as reference_text and moves to WritingResult on success', () async {
      final repo = _FakeAiWritingRepository()..analyzeResult = Success(_analysisResult(score25: 22));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);
      final topic = container.read(aiWritingControllerProvider(1)).topic;

      await notifier.submit('a' * 600);

      final state = container.read(aiWritingControllerProvider(1)) as WritingResult;
      expect(state.result.score25, 22);
      expect(repo.analyzeCallCount, 1);
      expect(repo.lastText, 'a' * 600);
      expect(repo.lastReferenceText, topic);
      expect(repo.lastLanguage, 'english');
      expect(repo.lastPreviousImprovedPassage, isNull);
    });

    test('a second submit resends the prior (formatted) improved passage as previous_improved_passage', () async {
      final repo = _FakeAiWritingRepository()..analyzeResult = Success(_analysisResult(improvedPassage: 'first improvement'));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      await notifier.submit('a' * 600);
      expect(repo.lastPreviousImprovedPassage, isNull);

      repo.analyzeResult = Success(_analysisResult(improvedPassage: 'second improvement'));
      await notifier.submit('a' * 700);

      // formatImprovedPassage capitalizes + adds a period.
      expect(repo.lastPreviousImprovedPassage, 'First improvement.');
      expect(repo.analyzeCallCount, 2);
    });

    test('setLanguage changes the language sent on the next submission', () async {
      final repo = _FakeAiWritingRepository()..analyzeResult = Success(_analysisResult());
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      notifier.setLanguage('russian');
      await notifier.submit('a' * 600);

      expect(repo.lastLanguage, 'russian');
    });

    test('a failed submission moves to WritingSubmitFailed, and text stays whatever the caller passes on retry', () async {
      final repo = _FakeAiWritingRepository()..analyzeResult = const Failed(ServerFailure());
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);

      await notifier.submit('a' * 600);

      final failedState = container.read(aiWritingControllerProvider(1)) as WritingSubmitFailed;
      expect(failedState.failure, isA<ServerFailure>());

      repo.analyzeResult = Success(_analysisResult());
      await notifier.submit('a' * 600); // retry = submit again with the same (still-held-by-the-widget) text

      expect(container.read(aiWritingControllerProvider(1)), isA<WritingResult>());
      expect(repo.analyzeCallCount, 2);
    });

    test('submitting again from WritingResult re-analyzes rather than being blocked', () async {
      final repo = _FakeAiWritingRepository()..analyzeResult = Success(_analysisResult(score25: 15));
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);
      await notifier.submit('a' * 600);
      expect(container.read(aiWritingControllerProvider(1)), isA<WritingResult>());

      repo.analyzeResult = Success(_analysisResult(score25: 24));
      await notifier.submit('a' * 650);

      final state = container.read(aiWritingControllerProvider(1)) as WritingResult;
      expect(state.result.score25, 24);
      expect(repo.analyzeCallCount, 2);
    });

    test('pickNewTopic / setWritingType discard an existing result, resetting to WritingIdle', () async {
      final repo = _FakeAiWritingRepository()..analyzeResult = Success(_analysisResult());
      final container = _buildContainer(repo);
      addTearDown(container.dispose);
      final notifier = container.read(aiWritingControllerProvider(1).notifier);
      await notifier.submit('a' * 600);
      expect(container.read(aiWritingControllerProvider(1)), isA<WritingResult>());

      notifier.pickNewTopic();

      expect(container.read(aiWritingControllerProvider(1)), isA<WritingIdle>());
    });
  });
}
