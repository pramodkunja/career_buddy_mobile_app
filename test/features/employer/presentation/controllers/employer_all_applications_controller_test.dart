import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_all_applications.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_all_applications_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/employer_all_applications_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_all_applications_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kPage = EmployerAllApplicationsPage(applications: []);

class _FakeEmployerAllApplicationsRepository implements EmployerAllApplicationsRepository {
  _FakeEmployerAllApplicationsRepository(this.result);

  Result<EmployerAllApplicationsPage> result;
  int getApplicationsCallCount = 0;
  String lastQuery = '';
  String lastStatusFilter = '';
  String lastSourceFilter = '';

  @override
  Future<Result<EmployerAllApplicationsPage>> getApplications({
    String query = '',
    String statusFilter = '',
    String sourceFilter = '',
  }) async {
    getApplicationsCallCount++;
    lastQuery = query;
    lastStatusFilter = statusFilter;
    lastSourceFilter = sourceFilter;
    return result;
  }
}

void main() {
  group('EmployerAllApplicationsController', () {
    test('loads applications on build', () async {
      final repo = _FakeEmployerAllApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerAllApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(employerAllApplicationsControllerProvider.future);

      expect(data.applications, isEmpty);
      expect(repo.getApplicationsCallCount, 1);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeEmployerAllApplicationsRepository(const Failed(NetworkFailure()));
      final container = ProviderContainer(
        overrides: [employerAllApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(employerAllApplicationsControllerProvider.future);
      } catch (_) {}

      final state = container.read(employerAllApplicationsControllerProvider);
      expect(state, isA<AsyncError<EmployerAllApplicationsPage>>());
      expect((state as AsyncError).error, isA<NetworkFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeEmployerAllApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerAllApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerAllApplicationsControllerProvider.future);
      expect(repo.getApplicationsCallCount, 1);

      await container.read(employerAllApplicationsControllerProvider.notifier).retry();

      expect(repo.getApplicationsCallCount, 2);
    });

    test('applyFilters re-fetches with new params', () async {
      final repo = _FakeEmployerAllApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerAllApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerAllApplicationsControllerProvider.future);
      expect(repo.getApplicationsCallCount, 1);

      await container.read(employerAllApplicationsControllerProvider.notifier).applyFilters(
        query: 'flutter',
        statusFilter: 'applied',
        sourceFilter: 'direct',
      );

      expect(repo.getApplicationsCallCount, 2);
      expect(repo.lastQuery, 'flutter');
      expect(repo.lastStatusFilter, 'applied');
      expect(repo.lastSourceFilter, 'direct');
    });

    test('applyFilters is no-op when params are unchanged', () async {
      final repo = _FakeEmployerAllApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerAllApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerAllApplicationsControllerProvider.future);
      expect(repo.getApplicationsCallCount, 1);

      await container.read(employerAllApplicationsControllerProvider.notifier).applyFilters(
        query: '',
        statusFilter: '',
        sourceFilter: '',
      );

      expect(repo.getApplicationsCallCount, 1);
    });
  });
}
