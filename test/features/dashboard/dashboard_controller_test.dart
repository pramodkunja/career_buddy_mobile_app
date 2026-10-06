import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/activity_progress.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardData _sampleData({int completedCount = 1}) => DashboardData(
  stats: DashboardStats(completedCount: completedCount, inProgressCount: 0, totalActivities: 1, totalScore: 0),
  activities: const <ActivityProgress>[],
  recentResults: const [],
  recommendedJobs: const [],
  paymentHistory: const [],
);

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository(this.result);

  Result<DashboardData> result;
  int callCount = 0;

  @override
  Future<Result<DashboardData>> getDashboard() async {
    callCount++;
    return result;
  }
}

void main() {
  group('DashboardController', () {
    test('starts loading, then resolves to the repository\'s data on success', () async {
      final repo = _FakeDashboardRepository(Success(_sampleData()));
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      expect(container.read(dashboardControllerProvider), isA<AsyncLoading>());
      final data = await container.read(dashboardControllerProvider.future);

      expect(data.stats.completedCount, 1);
      expect(container.read(dashboardControllerProvider), isA<AsyncData<DashboardData>>());
    });

    test('resolves to AsyncError carrying the mapped Failure on failure', () async {
      final repo = _FakeDashboardRepository(const Failed(NotFoundFailure()));
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(dashboardControllerProvider.future);
      } catch (_) {
        // expected: build() rethrows the mapped Failure on a Failed result.
      }

      final state = container.read(dashboardControllerProvider);
      expect(state, isA<AsyncError<DashboardData>>());
      expect((state as AsyncError).error, isA<NotFoundFailure>());
    });

    test('retry() re-invokes the repository', () async {
      final repo = _FakeDashboardRepository(Success(_sampleData()));
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(dashboardControllerProvider.future);
      expect(repo.callCount, 1);

      repo.result = Success(_sampleData(completedCount: 5));
      await container.read(dashboardControllerProvider.notifier).retry();

      expect(repo.callCount, 2);
      final state = container.read(dashboardControllerProvider);
      expect((state as AsyncData<DashboardData>).value.stats.completedCount, 5);
    });
  });
}
