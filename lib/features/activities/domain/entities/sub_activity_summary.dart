import 'sub_activity_status.dart';

class SubActivitySummary {
  const SubActivitySummary({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.status,
    required this.exerciseCount,
    this.startedAt,
    this.completedAt,
  });

  final int id;
  final String title;
  final String description;
  final int order;
  final SubActivityStatus status;
  final int exerciseCount;
  final DateTime? startedAt;
  final DateTime? completedAt;
}
