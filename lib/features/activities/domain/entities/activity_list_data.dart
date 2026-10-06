import 'activity_category.dart';
import 'activity_summary.dart';

class ActivityListData {
  const ActivityListData({
    required this.activities,
    required this.categories,
    required this.selectedCategory,
    required this.isFreePreview,
    required this.totalActivities,
  });

  final List<ActivitySummary> activities;
  final List<ActivityCategory> categories;

  /// Empty string means "All".
  final String selectedCategory;
  final bool isFreePreview;
  final int totalActivities;
}
