class RecentResult {
  const RecentResult({
    required this.title,
    required this.activityName,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.date,
  });

  final String title;
  final String activityName;
  final num score;
  final num maxScore;
  final double percentage;
  final DateTime date;
}
