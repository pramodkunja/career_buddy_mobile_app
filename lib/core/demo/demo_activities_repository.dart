import '../../features/activities/domain/entities/activity_category.dart';
import '../../features/activities/domain/entities/activity_detail.dart';
import '../../features/activities/domain/entities/activity_list_data.dart';
import '../../features/activities/domain/entities/activity_summary.dart';
import '../../features/activities/domain/entities/exercise_attempt.dart';
import '../../features/activities/domain/entities/exercise_summary.dart';
import '../../features/activities/domain/entities/sub_activity_detail.dart';
import '../../features/activities/domain/entities/sub_activity_status.dart';
import '../../features/activities/domain/entities/sub_activity_summary.dart';
import '../../features/activities/domain/repositories/activities_repository.dart';
import '../errors/failures.dart';
import '../utils/result.dart';
import 'demo_activities_data.dart';
import 'demo_progress_store.dart';

const _kDemoCategories = [
  ActivityCategory(value: 'speaking', label: 'Speaking'),
  ActivityCategory(value: 'writing', label: 'Writing'),
  ActivityCategory(value: 'listening', label: 'Listening'),
  ActivityCategory(value: 'reading', label: 'Reading'),
  ActivityCategory(value: 'workshop', label: 'Workshop'),
  ActivityCategory(value: 'vocabulary', label: 'Vocabulary'),
];

/// `ActivitiesRepository` backed entirely by the fixed in-memory hierarchy
/// in `demo_activities_data.dart`, with dynamic parts (completion status,
/// last attempt, completion rate) read from the shared
/// [DemoProgressStore]. Never touches the network or the real database —
/// see `demo_mode.dart` for how this gets swapped in.
class DemoActivitiesRepository implements ActivitiesRepository {
  static const _networkDelay = Duration(milliseconds: 200);

  @override
  Future<Result<ActivityListData>> getActivityList({String? category}) async {
    await Future<void>.delayed(_networkDelay);
    final filtered = (category == null || category.isEmpty)
        ? kDemoActivities
        : kDemoActivities.where((a) => a.category == category).toList();
    final summaries = filtered.map(_toSummary).toList();
    return Success(
      ActivityListData(
        activities: summaries,
        categories: _kDemoCategories,
        selectedCategory: category ?? '',
        isFreePreview: false,
        totalActivities: summaries.length,
      ),
    );
  }

  @override
  Future<Result<ActivityListData>> getWorkshopModules() => getActivityList(category: 'workshop');

  @override
  Future<Result<ActivityDetail>> getActivityDetail(int id) async {
    await Future<void>.delayed(_networkDelay);
    final activity = _findActivity(id);
    if (activity == null) return const Failed(NotFoundFailure());
    return Success(
      ActivityDetail(
        id: activity.id,
        title: activity.title,
        description: activity.description,
        category: activity.category,
        categoryDisplay: activity.categoryDisplay,
        level: activity.level,
        duration: activity.duration,
        isWorkshop: activity.isWorkshop,
        isModule: activity.isModule,
        completionRate: _completionRateFor(activity),
        subActivities: activity.subActivities.map(_toSubActivitySummary).toList(),
      ),
    );
  }

  @override
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId) async {
    await Future<void>.delayed(_networkDelay);
    final match = _findSubActivity(subActivityId);
    if (match == null) return const Failed(NotFoundFailure());
    final (activity, sub) = match;

    DemoProgressStore.instance.markSubActivityStarted(sub.id);

    final exercises = sub.exercises
        .map(
          (e) => ExerciseSummary(
            id: e.id,
            title: e.title,
            exerciseType: e.exerciseType,
            exerciseTypeDisplay: e.exerciseTypeDisplay,
            order: e.order,
            lastAttempt: DemoProgressStore.instance.lastAttemptFor(e.id),
          ),
        )
        .toList();
    final allDone = exercises.isNotEmpty && exercises.every((e) => e.lastAttempt != null);

    return Success(
      SubActivityDetail(
        id: sub.id,
        title: sub.title,
        description: sub.description,
        instructions: sub.instructions,
        order: sub.order,
        activityId: activity.id,
        activityTitle: activity.title,
        status: _statusFor(sub.id, exercises),
        allExercisesDone: allDone,
        exercises: exercises,
      ),
    );
  }

  @override
  Future<Result<void>> markSubComplete(int subActivityId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    DemoProgressStore.instance.markSubActivityComplete(subActivityId);
    return const Success(null);
  }

  DemoActivityFixture? _findActivity(int id) {
    for (final activity in kDemoActivities) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  (DemoActivityFixture, DemoSubActivityFixture)? _findSubActivity(int id) {
    for (final activity in kDemoActivities) {
      for (final sub in activity.subActivities) {
        if (sub.id == id) return (activity, sub);
      }
    }
    return null;
  }

  ActivitySummary _toSummary(DemoActivityFixture activity) {
    return ActivitySummary(
      id: activity.id,
      title: activity.title,
      description: activity.description,
      category: activity.category,
      categoryDisplay: activity.categoryDisplay,
      level: activity.level,
      duration: activity.duration,
      isLocked: false,
      completionRate: _completionRateFor(activity),
      isCompleted: _completionRateFor(activity) >= 100,
    );
  }

  SubActivitySummary _toSubActivitySummary(DemoSubActivityFixture sub) {
    final lastAttempts = sub.exercises.map((e) => DemoProgressStore.instance.lastAttemptFor(e.id)).toList();
    final status = _statusForSummary(sub.id, lastAttempts);
    return SubActivitySummary(
      id: sub.id,
      title: sub.title,
      description: sub.description,
      order: sub.order,
      status: status,
      exerciseCount: sub.exercises.length,
      startedAt: DemoProgressStore.instance.isSubActivityStarted(sub.id) ? DateTime.now() : null,
      completedAt: DemoProgressStore.instance.isSubActivityComplete(sub.id) ? DateTime.now() : null,
    );
  }

  int _completionRateFor(DemoActivityFixture activity) {
    if (activity.subActivities.isEmpty) return 0;
    final completed = activity.subActivities
        .where((s) => DemoProgressStore.instance.isSubActivityComplete(s.id))
        .length;
    return ((completed / activity.subActivities.length) * 100).round();
  }

  SubActivityStatus _statusFor(int subActivityId, List<ExerciseSummary> exercises) {
    if (DemoProgressStore.instance.isSubActivityComplete(subActivityId)) return SubActivityStatus.completed;
    if (exercises.any((e) => e.lastAttempt != null) ||
        DemoProgressStore.instance.isSubActivityStarted(subActivityId)) {
      return SubActivityStatus.inProgress;
    }
    return SubActivityStatus.notStarted;
  }

  SubActivityStatus _statusForSummary(int subActivityId, List<ExerciseAttempt?> lastAttempts) {
    if (DemoProgressStore.instance.isSubActivityComplete(subActivityId)) return SubActivityStatus.completed;
    if (lastAttempts.any((a) => a != null) || DemoProgressStore.instance.isSubActivityStarted(subActivityId)) {
      return SubActivityStatus.inProgress;
    }
    return SubActivityStatus.notStarted;
  }
}
