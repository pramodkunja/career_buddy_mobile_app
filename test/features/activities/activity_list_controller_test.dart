import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/controllers/activity_list_controller.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityListData _sampleData({String selectedCategory = ''}) => ActivityListData(
  activities: const [],
  categories: const [],
  selectedCategory: selectedCategory,
  isFreePreview: false,
  totalActivities: 0,
);

class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository(this.listResult);

  Result<ActivityListData> listResult;
  String? lastRequestedCategory;
  int listCallCount = 0;

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async {
    listCallCount++;
    lastRequestedCategory = category;
    return listResult;
  }

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => throw UnimplementedError();

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async => throw UnimplementedError();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

void main() {
  group('ActivityListController', () {
    test('resolves to the repository data on success', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleData()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(activityListControllerProvider.future);

      expect(data.totalActivities, 0);
      expect(repo.lastRequestedCategory, isNull);
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeActivitiesRepository(const Failed(UnauthorizedFailure()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(activityListControllerProvider.future);
      } catch (_) {
        // expected
      }

      final state = container.read(activityListControllerProvider);
      expect(state, isA<AsyncError<ActivityListData>>());
      expect((state as AsyncError).error, isA<UnauthorizedFailure>());
    });

    test('filterByCategory re-fetches with the new category', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleData()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(activityListControllerProvider.future);
      expect(repo.listCallCount, 1);

      repo.listResult = Success(_sampleData(selectedCategory: 'writing'));
      await container.read(activityListControllerProvider.notifier).filterByCategory('writing');

      expect(repo.listCallCount, 2);
      expect(repo.lastRequestedCategory, 'writing');
      final state = container.read(activityListControllerProvider);
      expect((state as AsyncData<ActivityListData>).value.selectedCategory, 'writing');
    });

    test('retry re-invokes the repository', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleData()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(activityListControllerProvider.future);
      expect(repo.listCallCount, 1);

      await container.read(activityListControllerProvider.notifier).retry();

      expect(repo.listCallCount, 2);
    });
  });
}
