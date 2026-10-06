import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_summary.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/repositories/activities_repository.dart';
import 'package:career_buddy_lms/features/activities/presentation/controllers/workshop_dashboard_controller.dart';
import 'package:career_buddy_lms/features/activities/presentation/providers/activities_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ActivitySummary _summary({required int id, required String title, required String category}) => ActivitySummary(
  id: id,
  title: title,
  description: 'An objective for $title.',
  category: category,
  categoryDisplay: category,
  level: 'Beginner',
  duration: '30 min',
  isLocked: false,
  completionRate: 0,
  isCompleted: false,
);

class _FakeActivitiesRepository implements ActivitiesRepository {
  _FakeActivitiesRepository(this.workshopResult);

  Result<ActivityListData> workshopResult;
  int workshopCallCount = 0;

  @override
  Future<Result<ActivityListData>> getWorkshopModules() async {
    workshopCallCount++;
    return workshopResult;
  }

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async => throw UnimplementedError();

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async => throw UnimplementedError();

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async => throw UnimplementedError();

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async => throw UnimplementedError();
}

void main() {
  group('WorkshopDashboardController', () {
    test('fetches via the dedicated, ungated workshop endpoint and resolves to the returned activities', () async {
      // Covers the real, previously-confirmed bug this controller used to
      // have: calling the general Activities list with a `category`
      // filter silently returned 0 cards for a Free Plan user, since that
      // endpoint ignores `category` for anyone but a full-access user and
      // substitutes their fixed free-catalogue selection instead. Routing
      // through `getWorkshopModules()` (the real, unconditionally-ungated
      // `/activities/workshop/` page) fixes this — there is no longer any
      // client-side category filtering to test, since every activity this
      // endpoint returns is a workshop module by construction.
      final repo = _FakeActivitiesRepository(
        Success(
          ActivityListData(
            activities: [_summary(id: 1, title: 'Group Discussion Practice', category: 'workshop')],
            categories: const [],
            selectedCategory: '',
            isFreePreview: false,
            totalActivities: 1,
          ),
        ),
      );
      final container = ProviderContainer(overrides: [activitiesRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      final modules = await container.read(workshopDashboardControllerProvider.future);

      expect(repo.workshopCallCount, 1);
      expect(modules, hasLength(1));
      expect(modules.single.title, 'Group Discussion Practice');
    });

    test('resolves to AsyncError on failure', () async {
      final repo = _FakeActivitiesRepository(const Failed(UnauthorizedFailure()));
      final container = ProviderContainer(overrides: [activitiesRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      try {
        await container.read(workshopDashboardControllerProvider.future);
      } catch (_) {
        // expected
      }

      final state = container.read(workshopDashboardControllerProvider);
      expect(state, isA<AsyncError<List<ActivitySummary>>>());
      expect((state as AsyncError).error, isA<UnauthorizedFailure>());
    });

    test('retry re-invokes the repository', () async {
      final repo = _FakeActivitiesRepository(
        Success(
          const ActivityListData(activities: [], categories: [], selectedCategory: 'workshop', isFreePreview: false, totalActivities: 0),
        ),
      );
      final container = ProviderContainer(overrides: [activitiesRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      await container.read(workshopDashboardControllerProvider.future);
      expect(repo.workshopCallCount, 1);

      await container.read(workshopDashboardControllerProvider.notifier).retry();

      expect(repo.workshopCallCount, 2);
    });
  });
}
