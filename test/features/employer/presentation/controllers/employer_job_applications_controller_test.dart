import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_job_applications.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_job_applications_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/employer_job_applications_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_job_applications_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kPage = EmployerJobApplicationsPage(jobTitle: 'Flutter Developer', applications: []);

class _FakeEmployerJobApplicationsRepository implements EmployerJobApplicationsRepository {
  _FakeEmployerJobApplicationsRepository(this.result);

  Result<EmployerJobApplicationsPage> result;
  int callCount = 0;
  int? lastJobId;
  String lastStatusFilter = '';

  @override
  Future<Result<EmployerJobApplicationsPage>> getApplications(int jobId, {String statusFilter = ''}) async {
    callCount++;
    lastJobId = jobId;
    lastStatusFilter = statusFilter;
    return result;
  }
}

void main() {
  group('EmployerJobApplicationsController', () {
    test('loads applications for the given job id', () async {
      final repo = _FakeEmployerJobApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerJobApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(employerJobApplicationsControllerProvider(1).future);

      expect(data.jobTitle, 'Flutter Developer');
      expect(repo.lastJobId, 1);
      expect(repo.callCount, 1);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeEmployerJobApplicationsRepository(const Failed(NetworkFailure()));
      final container = ProviderContainer(
        overrides: [employerJobApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(employerJobApplicationsControllerProvider(5).future);
      } catch (_) {}

      final state = container.read(employerJobApplicationsControllerProvider(5));
      expect(state, isA<AsyncError<EmployerJobApplicationsPage>>());
      expect((state as AsyncError).error, isA<NetworkFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeEmployerJobApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerJobApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerJobApplicationsControllerProvider(1).future);
      expect(repo.callCount, 1);

      await container.read(employerJobApplicationsControllerProvider(1).notifier).retry();

      expect(repo.callCount, 2);
    });

    test('setStatusFilter re-fetches with new filter', () async {
      final repo = _FakeEmployerJobApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerJobApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerJobApplicationsControllerProvider(10).future);
      expect(repo.callCount, 1);

      await container.read(employerJobApplicationsControllerProvider(10).notifier).setStatusFilter('shortlisted');

      expect(repo.callCount, 2);
      expect(repo.lastStatusFilter, 'shortlisted');
    });

    test('setStatusFilter is no-op when filter is unchanged', () async {
      final repo = _FakeEmployerJobApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerJobApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerJobApplicationsControllerProvider(10).future);
      expect(repo.callCount, 1);

      await container.read(employerJobApplicationsControllerProvider(10).notifier).setStatusFilter('');

      expect(repo.callCount, 1);
    });

    test('different job ids are independent', () async {
      final repo = _FakeEmployerJobApplicationsRepository(const Success(_kPage));
      final container = ProviderContainer(
        overrides: [employerJobApplicationsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(employerJobApplicationsControllerProvider(1).future);
      await container.read(employerJobApplicationsControllerProvider(2).future);

      expect(repo.callCount, 2);

      await container.read(employerJobApplicationsControllerProvider(1).notifier).setStatusFilter('applied');

      expect(repo.callCount, 3);
      expect(container.read(employerJobApplicationsControllerProvider(1).notifier).statusFilter, 'applied');
      expect(container.read(employerJobApplicationsControllerProvider(2).notifier).statusFilter, '');
    });
  });
}
