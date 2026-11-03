import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_application_detail.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_application_detail_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/employer_application_detail_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_application_detail_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _kDetail = EmployerApplicationDetail(
  applicantName: 'Jane Doe',
  jobTitle: 'Flutter Developer',
  applicantEmail: 'jane@example.com',
  applicantPhone: '+1 555-0100',
  yearsExperience: 3,
  currentCompany: 'Tech Inc',
  currentSalary: '₹45000.00 LPA',
  expectedSalary: '₹60000.00 LPA',
  resumeUrl: null,
  coverLetter: null,
  interviewScore: null,
  interviewVideoUrl: null,
  interviewRecordedAt: null,
  status: 'applied',
  employerNotes: '',
  appliedAt: '01 Jan 2026',
);

class _FakeEmployerApplicationDetailRepository implements EmployerApplicationDetailRepository {
  _FakeEmployerApplicationDetailRepository({
    required this.detailResult,
    this.updateResult = const Success(null),
  });

  Result<EmployerApplicationDetail> detailResult;
  Result<void> updateResult;
  int getDetailCallCount = 0;
  String? lastUpdatedStatus;
  String? lastUpdatedNotes;

  @override
  Future<Result<EmployerApplicationDetail>> getApplicationDetail(int applicationId) async {
    getDetailCallCount++;
    return detailResult;
  }

  @override
  Future<Result<void>> updateStatus({
    required int applicationId,
    required String status,
    required String employerNotes,
  }) async {
    lastUpdatedStatus = status;
    lastUpdatedNotes = employerNotes;
    return updateResult;
  }
}

void main() {
  group('EmployerApplicationDetailController', () {
    test('loads detail for the given application id', () async {
      final repo = _FakeEmployerApplicationDetailRepository(detailResult: const Success(_kDetail));
      final container = ProviderContainer(
        overrides: [employerApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(employerApplicationDetailControllerProvider(1).future);

      expect(data.applicantName, 'Jane Doe');
      expect(data.jobTitle, 'Flutter Developer');
      expect(repo.getDetailCallCount, 1);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeEmployerApplicationDetailRepository(
        detailResult: const Failed(NotFoundFailure()),
      );
      final container = ProviderContainer(
        overrides: [employerApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(employerApplicationDetailControllerProvider(99).future);
      } catch (_) {}

      final state = container.read(employerApplicationDetailControllerProvider(99));
      expect(state, isA<AsyncError<EmployerApplicationDetail>>());
      expect((state as AsyncError).error, isA<NotFoundFailure>());
    });

    test('retry re-fetches', () async {
      final repo = _FakeEmployerApplicationDetailRepository(detailResult: const Success(_kDetail));
      final container = ProviderContainer(
        overrides: [employerApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerApplicationDetailControllerProvider(1).future);
      expect(repo.getDetailCallCount, 1);

      await container.read(employerApplicationDetailControllerProvider(1).notifier).retry();

      expect(repo.getDetailCallCount, 2);
    });

    test('updateStatus success refetches detail', () async {
      final repo = _FakeEmployerApplicationDetailRepository(
        detailResult: const Success(_kDetail),
        updateResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [employerApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerApplicationDetailControllerProvider(1).future);
      expect(repo.getDetailCallCount, 1);

      await container
          .read(employerApplicationDetailControllerProvider(1).notifier)
          .updateStatus(status: 'shortlisted', employerNotes: 'Great candidate');

      expect(repo.getDetailCallCount, 2);
      expect(repo.lastUpdatedStatus, 'shortlisted');
      expect(repo.lastUpdatedNotes, 'Great candidate');
    });

    test('updateStatus failure does not refetch', () async {
      final repo = _FakeEmployerApplicationDetailRepository(
        detailResult: const Success(_kDetail),
        updateResult: const Failed(ServerFailure()),
      );
      final container = ProviderContainer(
        overrides: [employerApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerApplicationDetailControllerProvider(1).future);
      expect(repo.getDetailCallCount, 1);

      await container
          .read(employerApplicationDetailControllerProvider(1).notifier)
          .updateStatus(status: 'rejected', employerNotes: '');

      expect(repo.getDetailCallCount, 1);
    });

    test('updateStatus returns the repository result', () async {
      final repo = _FakeEmployerApplicationDetailRepository(
        detailResult: const Success(_kDetail),
        updateResult: const Success(null),
      );
      final container = ProviderContainer(
        overrides: [employerApplicationDetailRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(employerApplicationDetailControllerProvider(1).future);

      final successResult = await container
          .read(employerApplicationDetailControllerProvider(1).notifier)
          .updateStatus(status: 'offered', employerNotes: 'Welcome aboard');
      expect(successResult, isA<Success<void>>());

      repo.updateResult = const Failed(NetworkFailure());
      final failedResult = await container
          .read(employerApplicationDetailControllerProvider(1).notifier)
          .updateStatus(status: 'offered', employerNotes: '');
      expect(failedResult, isA<Failed<void>>());
    });
  });
}
