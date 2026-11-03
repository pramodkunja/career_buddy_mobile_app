import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_assessment.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_history_profile.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_session_result.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_history_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_history_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _emptyPage = JamHistoryPage(sessions: [], assessments: []);

class _FakeJamHistoryRepository implements JamHistoryRepository {
  _FakeJamHistoryRepository({required this.pageResult, required this.deleteResult});

  Result<JamHistoryPage> pageResult;
  Result<void> deleteResult;
  int getHistoryPageCallCount = 0;
  int? lastDeletedSessionId;
  int? lastDeletedAssessmentId;

  @override
  Future<Result<JamHistoryPage>> getHistoryPage() async {
    getHistoryPageCallCount++;
    return pageResult;
  }

  @override
  Future<Result<JamSessionResult>> getSessionDetail(int sessionId) async => throw UnimplementedError();

  @override
  Future<Result<JamAssessmentResult>> getAssessmentResult(int assessmentId) async => throw UnimplementedError();

  @override
  Future<Result<void>> deleteSession(int sessionId) async {
    lastDeletedSessionId = sessionId;
    return deleteResult;
  }

  @override
  Future<Result<void>> deleteAssessment(int assessmentId) async {
    lastDeletedAssessmentId = assessmentId;
    return deleteResult;
  }
}

void main() {
  group('JamHistoryController', () {
    test('loads history page on build', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Success(_emptyPage),
        deleteResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(jamHistoryControllerProvider.future);

      expect(data.sessions, isEmpty);
      expect(data.assessments, isEmpty);
      expect(repo.getHistoryPageCallCount, 1);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Failed(UnauthorizedFailure()),
        deleteResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(jamHistoryControllerProvider.future);
      } catch (_) {
        // expected
      }

      final state = container.read(jamHistoryControllerProvider);
      expect(state, isA<AsyncError<JamHistoryPage>>());
      expect((state as AsyncError).error, isA<UnauthorizedFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Success(_emptyPage),
        deleteResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jamHistoryControllerProvider.future);
      expect(repo.getHistoryPageCallCount, 1);

      await container.read(jamHistoryControllerProvider.notifier).retry();

      expect(repo.getHistoryPageCallCount, 2);
    });

    test('deleteSession success refetches history', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Success(_emptyPage),
        deleteResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jamHistoryControllerProvider.future);
      expect(repo.getHistoryPageCallCount, 1);

      final result = await container.read(jamHistoryControllerProvider.notifier).deleteSession(10);

      expect(result, isA<Success<void>>());
      expect(repo.lastDeletedSessionId, 10);
      expect(repo.getHistoryPageCallCount, 2);
    });

    test('deleteSession failure does not refetch', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Success(_emptyPage),
        deleteResult: const Failed(ServerFailure()),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jamHistoryControllerProvider.future);
      expect(repo.getHistoryPageCallCount, 1);

      final result = await container.read(jamHistoryControllerProvider.notifier).deleteSession(10);

      expect(result, isA<Failed<void>>());
      expect(repo.getHistoryPageCallCount, 1);
    });

    test('deleteAssessment success refetches history', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Success(_emptyPage),
        deleteResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jamHistoryControllerProvider.future);
      expect(repo.getHistoryPageCallCount, 1);

      final result = await container.read(jamHistoryControllerProvider.notifier).deleteAssessment(20);

      expect(result, isA<Success<void>>());
      expect(repo.lastDeletedAssessmentId, 20);
      expect(repo.getHistoryPageCallCount, 2);
    });

    test('deleteAssessment failure does not refetch', () async {
      final repo = _FakeJamHistoryRepository(
        pageResult: const Success(_emptyPage),
        deleteResult: const Failed(ServerFailure()),
      );
      final container = ProviderContainer(
        overrides: [jamHistoryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jamHistoryControllerProvider.future);
      expect(repo.getHistoryPageCallCount, 1);

      final result = await container.read(jamHistoryControllerProvider.notifier).deleteAssessment(20);

      expect(result, isA<Failed<void>>());
      expect(repo.getHistoryPageCallCount, 1);
    });
  });
}
