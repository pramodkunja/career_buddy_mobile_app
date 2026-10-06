class DashboardStats {
  const DashboardStats({
    required this.completedCount,
    required this.inProgressCount,
    required this.totalActivities,
    required this.totalScore,
  });

  final int completedCount;
  final int inProgressCount;
  final int totalActivities;
  final num totalScore;
}
