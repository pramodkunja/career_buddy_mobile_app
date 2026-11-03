import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_start.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_topic.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_topics_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _easyTopic = JamTopic(id: 1, title: 'Greetings', description: 'desc', difficulty: 'easy');
const _mediumTopic = JamTopic(id: 2, title: 'Storytelling', description: 'desc', difficulty: 'medium');
const _hardTopic = JamTopic(id: 3, title: 'Debate', description: 'desc', difficulty: 'hard');

class _FakeJamRepository implements JamRepository {
  _FakeJamRepository(this.topicsResult);

  Result<List<JamTopic>> topicsResult;
  int callCount = 0;

  @override
  Future<Result<List<JamTopic>>> getTopics() async {
    callCount++;
    return topicsResult;
  }

  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) async => throw UnimplementedError();

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) async => throw UnimplementedError();

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) async => throw UnimplementedError();
}

void main() {
  group('JamTopicsController', () {
    test('buckets topics by difficulty into easy/medium/hard', () async {
      final repo = _FakeJamRepository(
        const Success([_easyTopic, _mediumTopic, _hardTopic]),
      );
      final container = ProviderContainer(
        overrides: [jamRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final state = await container.read(jamTopicsControllerProvider.future);

      expect(state.easy.length, 1);
      expect(state.medium.length, 1);
      expect(state.hard.length, 1);
      expect(state.easy.first.id, 1);
      expect(state.medium.first.id, 2);
      expect(state.hard.first.id, 3);
    });

    test('hard topics are not in easy bucket', () async {
      final repo = _FakeJamRepository(
        const Success([_easyTopic, _mediumTopic, _hardTopic]),
      );
      final container = ProviderContainer(
        overrides: [jamRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final state = await container.read(jamTopicsControllerProvider.future);

      expect(state.easy.any((t) => t.difficulty == 'hard'), isFalse);
      expect(state.hard.any((t) => t.difficulty == 'easy'), isFalse);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeJamRepository(const Failed(ServerFailure()));
      final container = ProviderContainer(
        overrides: [jamRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(jamTopicsControllerProvider.future);
      } catch (_) {
        // expected
      }

      final state = container.read(jamTopicsControllerProvider);
      expect(state, isA<AsyncError<JamTopicsState>>());
      expect((state as AsyncError).error, isA<ServerFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeJamRepository(const Success([_easyTopic]));
      final container = ProviderContainer(
        overrides: [jamRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jamTopicsControllerProvider.future);
      expect(repo.callCount, 1);

      await container.read(jamTopicsControllerProvider.notifier).retry();

      expect(repo.callCount, 2);
    });
  });
}
