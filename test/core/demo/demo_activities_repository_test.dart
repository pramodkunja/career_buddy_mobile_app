import 'package:career_buddy_lms/core/demo/demo_activities_repository.dart';
import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/activity_list_data.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_detail.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/sub_activity_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  late DemoActivitiesRepository repo;
  setUp(() => repo = DemoActivitiesRepository());

  group('getActivityList', () {
    test('returns all 12 demo activities, covering every required category, when no category filter is given', () async {
      final result = await repo.getActivityList();
      final data = (result as Success<ActivityListData>).value;

      expect(data.activities.length, 12);
      expect(data.totalActivities, 12);
      final titles = data.activities.map((a) => a.title).toSet();
      expect(
        titles,
        containsAll(<String>[
          'Professional Speaking',
          'Professional Passage Writing',
          'Listen & Write',
          'Professional Reading',
          'Group Discussion',
          'JAM',
          'Role Play',
          'Vocabulary Quiz',
          'Vocabulary Matching',
          'Vocabulary Bingo',
          'Vocabulary Fill in the Blank',
          'Business Negotiation Simulation',
        ]),
      );
    });

    test('filters by category', () async {
      final result = await repo.getActivityList(category: 'workshop');
      final data = (result as Success<ActivityListData>).value;

      expect(data.activities.length, 3);
      expect(data.activities.every((a) => a.category == 'workshop'), isTrue);
      expect(data.selectedCategory, 'workshop');
    });

    test('an empty-string category is treated as "All", matching the domain contract', () async {
      final result = await repo.getActivityList(category: '');
      final data = (result as Success<ActivityListData>).value;

      expect(data.activities.length, 12);
    });
  });

  group('getActivityDetail', () {
    test('returns sub-activities for a known demo activity id', () async {
      final result = await repo.getActivityDetail(9001);
      final detail = (result as Success<ActivityDetail>).value;

      expect(detail.title, 'Professional Speaking');
      expect(detail.isModule, isTrue);
      expect(detail.isWorkshop, isFalse);
      expect(detail.subActivities, hasLength(1));
      expect(detail.subActivities.single.title, 'Speaking Practice');
    });

    test('a workshop activity has isWorkshop true and isModule false', () async {
      final result = await repo.getActivityDetail(9005);
      final detail = (result as Success<ActivityDetail>).value;

      expect(detail.title, 'Group Discussion');
      expect(detail.isWorkshop, isTrue);
      expect(detail.isModule, isFalse);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getActivityDetail(999999);
      expect(result, isA<Failed<ActivityDetail>>());
    });
  });

  group('getSubActivityDetail', () {
    test('returns the AI Speaking exercise for the Speaking Practice sub-activity', () async {
      final result = await repo.getSubActivityDetail(9001, 9101);
      final detail = (result as Success<SubActivityDetail>).value;

      expect(detail.activityId, 9001);
      expect(detail.activityTitle, 'Professional Speaking');
      expect(detail.exercises, hasLength(1));
      expect(detail.exercises.single.exerciseType, 'speaking');
      expect(detail.exercises.single.title, 'AI Speaking Exercise');
      expect(detail.exercises.single.lastAttempt, isNull);
    });

    test('the mcq exercise under Vocabulary Practice has exerciseType "mcq"', () async {
      final result = await repo.getSubActivityDetail(9001, 9108);
      final detail = (result as Success<SubActivityDetail>).value;

      expect(detail.exercises.single.exerciseType, 'mcq');
    });

    test('visiting a sub-activity marks it started, flipping status from notStarted to inProgress', () async {
      final before = (await repo.getSubActivityDetail(9001, 9102) as Success<SubActivityDetail>).value;
      expect(before.status, SubActivityStatus.inProgress); // already started by this same call

      // A second, independent repository instance sees the same shared
      // progress store, matching how a fresh Riverpod-provided instance
      // would behave across screen rebuilds.
      final again = (await DemoActivitiesRepository().getSubActivityDetail(9001, 9102) as Success<SubActivityDetail>).value;
      expect(again.status, SubActivityStatus.inProgress);
    });

    test('an exercise attempt recorded via DemoProgressStore surfaces as lastAttempt on the next fetch', () async {
      DemoProgressStore.instance.recordAttempt(9201, score: 19, maxScore: 25);

      final detail = (await repo.getSubActivityDetail(9001, 9101) as Success<SubActivityDetail>).value;

      expect(detail.exercises.single.lastAttempt, isNotNull);
      expect(detail.exercises.single.lastAttempt!.score, 19);
    });

    test('an unknown id returns a NotFoundFailure', () async {
      final result = await repo.getSubActivityDetail(0, 999999);
      expect(result, isA<Failed<SubActivityDetail>>());
    });
  });

  group('markSubComplete', () {
    test('flips the sub-activity to completed and raises the parent activity completion rate', () async {
      final before = (await repo.getActivityDetail(9001) as Success<ActivityDetail>).value;
      expect(before.completionRate, 0);

      final markResult = await repo.markSubComplete(9101);
      expect(markResult, isA<Success<void>>());

      final sub = (await repo.getSubActivityDetail(9001, 9101) as Success<SubActivityDetail>).value;
      expect(sub.status, SubActivityStatus.completed);

      final after = (await repo.getActivityDetail(9001) as Success<ActivityDetail>).value;
      expect(after.completionRate, 100);
    });
  });
}
