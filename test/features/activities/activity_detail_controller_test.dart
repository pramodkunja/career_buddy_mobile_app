import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/controllers/activity_detail_controller.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityDetail _sampleDetail({int id = 12}) => ActivityDetail(
  id: id,
  title: 'Business Vocabulary Building Games',
  description: 'desc',
  category: 'vocabulary',
  categoryDisplay: 'Vocabulary & Idioms',
  level: 'Intermediate',
  duration: '30 min',
  isWorkshop: false,
  isModule: false,
  completionRate: 0,
  subActivities: const [],
);

class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository(this.detailResult);

  Result<ActivityDetail> detailResult;
  int detailCallCount = 0;
  int? lastRequestedId;

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async {
    detailCallCount++;
    lastRequestedId = id;
    return detailResult;
  }

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async => throw UnimplementedError();

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => throw UnimplementedError();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

void main() {
  group('ActivityDetailController', () {
    test('resolves to the repository data for the requested id', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleDetail(id: 12)));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(activityDetailControllerProvider(12).future);

      expect(data.id, 12);
      expect(repo.lastRequestedId, 12);
    });

    test('resolves to AsyncError with a ForbiddenFailure for a locked activity', () async {
      final repo = _FakeActivitiesRepository(const Failed(ForbiddenFailure()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(activityDetailControllerProvider(12).future);
      } catch (_) {
        // expected
      }

      final state = container.read(activityDetailControllerProvider(12));
      expect((state as AsyncError).error, isA<ForbiddenFailure>());
    });

    test('two different ids get independent state (.family)', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleDetail(id: 12)));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(activityDetailControllerProvider(12).future);
      repo.detailResult = Success(_sampleDetail(id: 34));
      await container.read(activityDetailControllerProvider(34).future);

      final first = container.read(activityDetailControllerProvider(12));
      final second = container.read(activityDetailControllerProvider(34));
      expect((first as AsyncData<ActivityDetail>).value.id, 12);
      expect((second as AsyncData<ActivityDetail>).value.id, 34);
    });

    test('retry re-invokes the repository', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleDetail()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(activityDetailControllerProvider(12).future);
      expect(repo.detailCallCount, 1);

      await container.read(activityDetailControllerProvider(12).notifier).retry();

      expect(repo.detailCallCount, 2);
    });
  });
}
