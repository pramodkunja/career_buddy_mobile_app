import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/public_job_detail.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/public_job_detail_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/public_job_detail_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/public_job_detail_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PublicJobDetail _sampleDetail({String title = 'Flutter Developer'}) => PublicJobDetail(
  title: title,
  companyName: 'Acme Corp',
  jobType: 'Full-time',
  experience: '2+ years',
  location: 'Remote',
  salaryDisplay: '10–15 LPA',
  openings: '2',
  description: 'desc',
  requirements: 'req',
  skills: const ['Flutter', 'Dart'],
  deadline: 'Dec. 31, 2026',
);

const _sampleSubmission = PublicJobApplicationSubmission(
  name: 'Test User',
  email: 'test@example.com',
  phoneE164: '+919999999999',
);

class _FakePublicJobDetailRepository implements PublicJobDetailRepository {
  _FakePublicJobDetailRepository({required this.detailResult, required this.applyResult});

  Result<PublicJobDetail> detailResult;
  Result<void> applyResult;
  int detailCallCount = 0;
  int applyCallCount = 0;
  int? lastJobId;

  @override
  Future<Result<PublicJobDetail>> getJobDetail(int jobId) async {
    detailCallCount++;
    lastJobId = jobId;
    return detailResult;
  }

  @override
  Future<Result<void>> apply(int jobId, PublicJobApplicationSubmission data) async {
    applyCallCount++;
    lastJobId = jobId;
    return applyResult;
  }
}

void main() {
  group('PublicJobDetailController', () {
    test('loads detail for the given job id', () async {
      final repo = _FakePublicJobDetailRepository(
        detailResult: Success(_sampleDetail()),
        applyResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [publicJobDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(publicJobDetailControllerProvider(42).future);

      expect(data.title, 'Flutter Developer');
      expect(repo.lastJobId, 42);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakePublicJobDetailRepository(
        detailResult: const Failed(NotFoundFailure()),
        applyResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [publicJobDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(publicJobDetailControllerProvider(42).future);
      } catch (_) {
        // expected
      }

      final state = container.read(publicJobDetailControllerProvider(42));
      expect(state, isA<AsyncError<PublicJobDetail>>());
      expect((state as AsyncError).error, isA<NotFoundFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakePublicJobDetailRepository(
        detailResult: Success(_sampleDetail()),
        applyResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [publicJobDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(publicJobDetailControllerProvider(42).future);
      expect(repo.detailCallCount, 1);

      await container.read(publicJobDetailControllerProvider(42).notifier).retry();

      expect(repo.detailCallCount, 2);
    });

    test('apply returns Success when repository succeeds', () async {
      final repo = _FakePublicJobDetailRepository(
        detailResult: Success(_sampleDetail()),
        applyResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [publicJobDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(publicJobDetailControllerProvider(42).future);

      final result = await container.read(publicJobDetailControllerProvider(42).notifier).apply(_sampleSubmission);

      expect(result, isA<Success<void>>());
      expect(repo.applyCallCount, 1);
      expect(repo.lastJobId, 42);
    });

    test('apply returns Failed when repository fails', () async {
      final repo = _FakePublicJobDetailRepository(
        detailResult: Success(_sampleDetail()),
        applyResult: const Failed(ServerFailure()),
      );
      final container = ProviderContainer(
        overrides: [publicJobDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(publicJobDetailControllerProvider(42).future);

      final result = await container.read(publicJobDetailControllerProvider(42).notifier).apply(_sampleSubmission);

      expect(result, isA<Failed<void>>());
      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });
}
