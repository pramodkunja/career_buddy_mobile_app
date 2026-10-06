class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryDisplay,
    required this.level,
    required this.duration,
    required this.isLocked,
    required this.completionRate,
    required this.isCompleted,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final String categoryDisplay;
  final String level;
  final String duration;
  final bool isLocked;

  /// Percentage, 0-100.
  final int completionRate;
  final bool isCompleted;
}
