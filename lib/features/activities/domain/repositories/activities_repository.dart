import '../../../../core/utils/result.dart';
import '../entities/activity_detail.dart';
import '../entities/activity_list_data.dart';
import '../entities/sub_activity_detail.dart';

abstract class ActivitiesRepository {
  /// [category] is the raw category value (e.g. `'speaking'`); pass `null`
  /// or an empty string for "All".
  Future<Result<ActivityListData>> getActivityList({String? category});

  /// See `ActivitiesRemoteDataSource.getWorkshopModules`'s doc comment.
  Future<Result<ActivityListData>> getWorkshopModules();

  Future<Result<ActivityDetail>> getActivityDetail(int id);

  /// [activityId] is required alongside [subActivityId] because the real
  /// web page this is ultimately sourced from lives at the composite URL
  /// `/activities/{activity_pk}/sub/{sub_pk}/` — there is no single-id
  /// lookup on the real web (see `RoutePaths.subActivityDetail`'s doc
  /// comment).
  Future<Result<SubActivityDetail>> getSubActivityDetail(int activityId, int subActivityId);

  /// Calls the web's own "Mark Complete" form action
  /// (`activities/views.py:mark_sub_complete`) — no JSON API exists for
  /// this, so it's invoked the same way the browser's form does. See
  /// `ActivitiesRemoteDataSource.markSubComplete`.
  Future<Result<void>> markSubComplete(int subActivityId);
}
