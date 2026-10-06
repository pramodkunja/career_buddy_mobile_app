class ActivityProgress {
  const ActivityProgress({
    required this.activityId,
    required this.title,
    required this.completionRate,
    required this.completedSubActivities,
    required this.totalSubActivities,
    this.startedAt,
  });

  final int activityId;
  final String title;

  /// Percentage, 0-100 (matches the web dashboard's progress bar width).
  final double completionRate;
  final int completedSubActivities;
  final int totalSubActivities;
  final DateTime? startedAt;
}
