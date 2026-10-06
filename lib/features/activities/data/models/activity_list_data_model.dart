import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/activity_category.dart';
import '../../domain/entities/activity_list_data.dart';
import '../../domain/entities/activity_summary.dart';

/// Parses `GET /activities/api/`'s `data` object (see
/// `docs/BACKEND_CONTRACT_activities.md`) into [ActivityListData].
extension ActivityListDataParsing on ActivityListData {
  static ActivityListData fromJson(Map<String, dynamic> json) {
    return ActivityListData(
      activities: requireList(json, 'activities').map((e) => _activityFromJson(asMap(e, 'activities[]'))).toList(),
      categories: requireList(
        json,
        'categories',
      ).map((e) => _categoryFromJson(asMap(e, 'categories[]'))).toList(),
      selectedCategory: requireString(json, 'selected_category'),
      isFreePreview: requireBool(json, 'is_free_preview'),
      totalActivities: requireInt(json, 'total_activities'),
    );
  }

  static ActivitySummary _activityFromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      id: requireInt(json, 'id'),
      title: requireString(json, 'title'),
      description: requireString(json, 'description'),
      category: requireString(json, 'category'),
      categoryDisplay: requireString(json, 'category_display'),
      level: requireString(json, 'level'),
      duration: requireString(json, 'duration'),
      isLocked: requireBool(json, 'is_locked'),
      completionRate: requireInt(json, 'completion_rate'),
      isCompleted: requireBool(json, 'is_completed'),
    );
  }

  static ActivityCategory _categoryFromJson(Map<String, dynamic> json) {
    return ActivityCategory(value: requireString(json, 'value'), label: requireString(json, 'label'));
  }
}
