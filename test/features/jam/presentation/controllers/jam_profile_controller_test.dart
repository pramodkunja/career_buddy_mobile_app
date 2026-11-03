import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/jam/domain/entities/jam_history_profile.dart';
import 'package:career_buddy_lms/features/jam/domain/repositories/jam_profile_repository.dart';
import 'package:career_buddy_lms/features/jam/presentation/controllers/jam_profile_controller.dart';
import 'package:career_buddy_lms/features/jam/presentation/providers/jam_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleProfile = JamProfile(
  fullName: 'Jane Doe',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  bio: '',
  totalSessions: 5,
  totalMinutes: 30,
);

class _FakeJamProfileRepository implements JamProfileRepository {
  _FakeJamProfileRepository({
    required this.profileResult,
    this.updateResult = const Success(null),
    this.resetResult = const Success(null),
  });

  Result<JamProfile> profileResult;
  Result<void> updateResult;
  Result<void> resetResult;
  int getProfileCallCount = 0;
  JamProfileUpdate? lastUpdatedProfile;

  @override
  Future<Result<JamProfile>> getProfile() async {
    getProfileCallCount++;
    return profileResult;
  }

  @override
  Future<Result<void>> updateProfile(JamProfileUpdate data) async {
    lastUpdatedProfile = data;
    return updateResult;
  }

  @override
  Future<Result<void>> resetProgress() async => resetResult;
}

ProviderContainer _buildContainer(_FakeJamProfileRepository repo) {
  final container = ProviderContainer(
    overrides: [jamProfileRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('JamProfileController', () {
    test('resolves to data on success', () async {
      final repo = _FakeJamProfileRepository(profileResult: const Success(_sampleProfile));
      final container = _buildContainer(repo);

      final data = await container.read(jamProfileControllerProvider.future);
      expect(data.fullName, 'Jane Doe');
      expect(data.totalSessions, 5);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeJamProfileRepository(profileResult: const Failed(NetworkFailure()));
      final container = _buildContainer(repo);

      try {
        await container.read(jamProfileControllerProvider.future);
      } catch (_) {}

      expect(container.read(jamProfileControllerProvider), isA<AsyncError>());
    });

    test('retry re-fetches the profile', () async {
      final repo = _FakeJamProfileRepository(profileResult: const Success(_sampleProfile));
      final container = _buildContainer(repo);
      await container.read(jamProfileControllerProvider.future);
      expect(repo.getProfileCallCount, 1);

      await container.read(jamProfileControllerProvider.notifier).retry();
      expect(repo.getProfileCallCount, 2);
    });

    test('updateProfile success refetches profile', () async {
      final repo = _FakeJamProfileRepository(profileResult: const Success(_sampleProfile));
      final container = _buildContainer(repo);
      await container.read(jamProfileControllerProvider.future);
      expect(repo.getProfileCallCount, 1);

      const update = JamProfileUpdate(
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        bio: 'Updated bio',
      );
      final result = await container.read(jamProfileControllerProvider.notifier).updateProfile(update);

      expect(result, isA<Success>());
      expect(repo.getProfileCallCount, 2);
      expect(repo.lastUpdatedProfile?.firstName, 'John');
    });

    test('updateProfile failure does not refetch profile', () async {
      final repo = _FakeJamProfileRepository(
        profileResult: const Success(_sampleProfile),
        updateResult: const Failed(ServerFailure()),
      );
      final container = _buildContainer(repo);
      await container.read(jamProfileControllerProvider.future);
      expect(repo.getProfileCallCount, 1);

      const update = JamProfileUpdate(firstName: 'X', lastName: 'Y', email: 'x@y.com', bio: '');
      final result = await container.read(jamProfileControllerProvider.notifier).updateProfile(update);

      expect(result, isA<Failed>());
      expect(repo.getProfileCallCount, 1);
    });

    test('resetProgress success refetches profile', () async {
      final repo = _FakeJamProfileRepository(profileResult: const Success(_sampleProfile));
      final container = _buildContainer(repo);
      await container.read(jamProfileControllerProvider.future);
      expect(repo.getProfileCallCount, 1);

      final result = await container.read(jamProfileControllerProvider.notifier).resetProgress();

      expect(result, isA<Success>());
      expect(repo.getProfileCallCount, 2);
    });

    test('resetProgress failure does not refetch profile', () async {
      final repo = _FakeJamProfileRepository(
        profileResult: const Success(_sampleProfile),
        resetResult: const Failed(ServerFailure()),
      );
      final container = _buildContainer(repo);
      await container.read(jamProfileControllerProvider.future);
      expect(repo.getProfileCallCount, 1);

      final result = await container.read(jamProfileControllerProvider.notifier).resetProgress();

      expect(result, isA<Failed>());
      expect(repo.getProfileCallCount, 1);
    });
  });
}
