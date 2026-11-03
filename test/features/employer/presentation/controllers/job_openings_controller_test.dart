import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/job_openings.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/job_openings_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/job_openings_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/job_openings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _emptyPage = JobOpeningsPage(jobs: []);

class _FakeJobOpeningsRepository implements JobOpeningsRepository {
  _FakeJobOpeningsRepository(this.result);

  Result<JobOpeningsPage> result;
  int callCount = 0;

  @override
  Future<Result<JobOpeningsPage>> getJobOpenings() async {
    callCount++;
    return result;
  }
}

void main() {
  group('JobOpeningsController', () {
    test('resolves to data on success', () async {
      final repo = _FakeJobOpeningsRepository(const Success(_emptyPage));
      final container = ProviderContainer(
        overrides: [jobOpeningsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(jobOpeningsControllerProvider.future);

      expect(data.jobs, isEmpty);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeJobOpeningsRepository(const Failed(UnauthorizedFailure()));
      final container = ProviderContainer(
        overrides: [jobOpeningsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(jobOpeningsControllerProvider.future);
      } catch (_) {
        // expected
      }

      final state = container.read(jobOpeningsControllerProvider);
      expect(state, isA<AsyncError<JobOpeningsPage>>());
      expect((state as AsyncError).error, isA<UnauthorizedFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeJobOpeningsRepository(const Success(_emptyPage));
      final container = ProviderContainer(
        overrides: [jobOpeningsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(jobOpeningsControllerProvider.future);
      expect(repo.callCount, 1);

      await container.read(jobOpeningsControllerProvider.notifier).retry();

      expect(repo.callCount, 2);
    });
  });
}
