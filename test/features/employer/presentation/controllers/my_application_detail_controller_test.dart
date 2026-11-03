import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/my_application_detail.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/my_application_detail_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/my_application_detail_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/my_application_detail_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MyApplicationDetail _sampleDetail({int applicationId = 42}) => MyApplicationDetail(
  applicationId: applicationId,
  jobId: 7,
  jobTitle: 'Flutter Developer',
  companyName: 'Acme Corp',
  jobLocation: 'Remote',
  status: 'pending',
  appliedAt: '01 Jan 2026, 10:00',
  updatedAt: '02 Jan 2026, 11:00',
  applicantName: 'Test User',
  applicantEmail: 'test@example.com',
  jobType: 'Full-time',
  jobExperience: '2+ years',
  coverLetter: null,
  jobIsActive: true,
);

class _FakeMyApplicationDetailRepository implements MyApplicationDetailRepository {
  _FakeMyApplicationDetailRepository(this.result);

  Result<MyApplicationDetail> result;
  int callCount = 0;
  int? lastApplicationId;

  @override
  Future<Result<MyApplicationDetail>> getApplicationDetail(int applicationId) async {
    callCount++;
    lastApplicationId = applicationId;
    return result;
  }
}

void main() {
  group('MyApplicationDetailController', () {
    test('loads detail for the given application id', () async {
      final repo = _FakeMyApplicationDetailRepository(Success(_sampleDetail(applicationId: 42)));
      final container = ProviderContainer(
        overrides: [myApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(myApplicationDetailControllerProvider(42).future);

      expect(data.applicationId, 42);
      expect(repo.lastApplicationId, 42);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeMyApplicationDetailRepository(const Failed(NotFoundFailure()));
      final container = ProviderContainer(
        overrides: [myApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(myApplicationDetailControllerProvider(42).future);
      } catch (_) {
        // expected
      }

      final state = container.read(myApplicationDetailControllerProvider(42));
      expect(state, isA<AsyncError<MyApplicationDetail>>());
      expect((state as AsyncError).error, isA<NotFoundFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeMyApplicationDetailRepository(Success(_sampleDetail()));
      final container = ProviderContainer(
        overrides: [myApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(myApplicationDetailControllerProvider(42).future);
      expect(repo.callCount, 1);

      await container.read(myApplicationDetailControllerProvider(42).notifier).retry();

      expect(repo.callCount, 2);
    });
  });
}
