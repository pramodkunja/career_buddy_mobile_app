import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_dashboard_summary.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_dashboard_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_dashboard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kSummary = EmployerDashboardSummary(
  greetingName: 'Acme Corp',
  totalJobsCount: 3,
  activeJobs: 2,
  totalApps: 10,
  jobs: [],
);

class _FakeEmployerDashboardRepository implements EmployerDashboardRepository {
  _FakeEmployerDashboardRepository({
    required this.dashboardResult,
    this.deleteResult = const Success(null),
  });

  Result<EmployerDashboardSummary> dashboardResult;
  Result<void> deleteResult;
  int getDashboardCallCount = 0;
  int? lastDeletedJobId;

  @override
  Future<Result<EmployerDashboardSummary>> getDashboard() async {
    getDashboardCallCount++;
    return dashboardResult;
  }

  @override
  Future<Result<void>> deleteJob(int jobId) async {
    lastDeletedJobId = jobId;
    return deleteResult;
  }
}

void main() {
  group('EmployerDashboardController', () {
    test('resolves to data on success', () async {
      final repo = _FakeEmployerDashboardRepository(dashboardResult: const Success(_kSummary));
      final container = ProviderContainer(
        overrides: [employerDashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(employerDashboardControllerProvider.future);

      expect(data.greetingName, 'Acme Corp');
      expect(data.totalJobsCount, 3);
      expect(repo.getDashboardCallCount, 1);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeEmployerDashboardRepository(
        dashboardResult: const Failed(NetworkFailure()),
      );
      final container = ProviderContainer(
        overrides: [employerDashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(employerDashboardControllerProvider.future);
      } catch (_) {}

      final state = container.read(employerDashboardControllerProvider);
      expect(state, isA<AsyncError<EmployerDashboardSummary>>());
      expect((state as AsyncError).error, isA<NetworkFailure>());
    });

    test('retry re-fetches the dashboard', () async {
      final repo = _FakeEmployerDashboardRepository(dashboardResult: const Success(_kSummary));
      final container = ProviderContainer(
        overrides: [employerDashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerDashboardControllerProvider.future);
      expect(repo.getDashboardCallCount, 1);

      await container.read(employerDashboardControllerProvider.notifier).retry();

      expect(repo.getDashboardCallCount, 2);
    });

    test('deleteJob calls repo and refetches on success', () async {
      final repo = _FakeEmployerDashboardRepository(
        dashboardResult: const Success(_kSummary),
        deleteResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [employerDashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerDashboardControllerProvider.future);
      expect(repo.getDashboardCallCount, 1);

      final result = await container.read(employerDashboardControllerProvider.notifier).deleteJob(42);

      expect(repo.lastDeletedJobId, 42);
      expect(repo.getDashboardCallCount, 2);
      expect(result, isA<Success<void>>());
    });

    test('deleteJob does not refetch on failure', () async {
      final repo = _FakeEmployerDashboardRepository(
        dashboardResult: const Success(_kSummary),
        deleteResult: const Failed(ServerFailure()),
      );
      final container = ProviderContainer(
        overrides: [employerDashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerDashboardControllerProvider.future);
      expect(repo.getDashboardCallCount, 1);

      final result = await container.read(employerDashboardControllerProvider.notifier).deleteJob(7);

      expect(repo.lastDeletedJobId, 7);
      expect(repo.getDashboardCallCount, 1);
      expect(result, isA<Failed<void>>());
    });
  });
}
