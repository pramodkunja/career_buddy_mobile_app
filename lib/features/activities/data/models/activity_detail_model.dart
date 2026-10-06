import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/activity_detail.dart';
import '../../domain/entities/sub_activity_status.dart';
import '../../domain/entities/sub_activity_summary.dart';

/// Parses `GET /activities/api/<id>/`'s `data` object (see
/// `docs/BACKEND_CONTRACT_activities.md`) into [ActivityDetail].
extension ActivityDetailParsing on ActivityDetail {
  static ActivityDetail fromJson(Map<String, dynamic> json) {
    return ActivityDetail(
      id: requireInt(json, 'id'),
      title: requireString(json, 'title'),
      description: requireString(json, 'description'),
      category: requireString(json, 'category'),
      categoryDisplay: requireString(json, 'category_display'),
      level: requireString(json, 'level'),
      duration: requireString(json, 'duration'),
      isWorkshop: requireBool(json, 'is_workshop'),
      isModule: requireBool(json, 'is_module'),
      completionRate: requireInt(json, 'completion_rate'),
      subActivities: requireList(
        json,
        'sub_activities',
      ).map((e) => _subActivityFromJson(asMap(e, 'sub_activities[]'))).toList(),
    );
  }

  static SubActivitySummary _subActivityFromJson(Map<String, dynamic> json) {
    return SubActivitySummary(
      id: requireInt(json, 'id'),
      title: requireString(json, 'title'),
      description: requireString(json, 'description'),
      order: requireInt(json, 'order'),
      status: SubActivityStatus.fromWire(requireString(json, 'status')),
      exerciseCount: requireInt(json, 'exercise_count'),
      startedAt: optionalDateTime(json, 'started_at'),
      completedAt: optionalDateTime(json, 'completed_at'),
    );
  }
}
