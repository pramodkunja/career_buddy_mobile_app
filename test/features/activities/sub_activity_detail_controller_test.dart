import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_status.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/controllers/sub_activity_detail_controller.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SubActivityDetail _sampleDetail() => const SubActivityDetail(
  id: 34,
  title: 'Common Business Terms',
  description: 'desc',
  instructions: 'instr',
  order: 1,
  activityId: 12,
  activityTitle: 'Business Vocabulary Building Games',
  status: SubActivityStatus.inProgress,
  allExercisesDone: false,
  exercises: [],
);

class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository(this.result);

  Result<SubActivityDetail> result;
  int callCount = 0;

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async {
    callCount++;
    return result;
  }

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async => throw UnimplementedError();

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async => throw UnimplementedError();

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

void main() {
  group('SubActivityDetailController', () {
    test('resolves to the repository data on success', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleDetail()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final data = await container.read(subActivityDetailControllerProvider((activityId: 12, subActivityId: 34)).future);

      expect(data.id, 34);
    });

    test('resolves to AsyncError with NotFoundFailure for an invalid id', () async {
      final repo = _FakeActivitiesRepository(const Failed(NotFoundFailure()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      try {
        await container.read(subActivityDetailControllerProvider((activityId: 12, subActivityId: 999999)).future);
      } catch (_) {
        // expected
      }

      final state = container.read(subActivityDetailControllerProvider((activityId: 12, subActivityId: 999999)));
      expect((state as AsyncError).error, isA<NotFoundFailure>());
    });

    test('retry re-invokes the repository', () async {
      final repo = _FakeActivitiesRepository(Success(_sampleDetail()));
      final container = ProviderContainer(
        overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(subActivityDetailControllerProvider((activityId: 12, subActivityId: 34)).future);
      expect(repo.callCount, 1);

      await container.read(subActivityDetailControllerProvider((activityId: 12, subActivityId: 34)).notifier).retry();

      expect(repo.callCount, 2);
    });
  });
}
