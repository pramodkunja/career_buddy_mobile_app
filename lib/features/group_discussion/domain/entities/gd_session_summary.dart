/// One row of `GD_app:api_sessions`'s `{"sessions": [...]}` list — a past
/// session belonging to the requesting user, for a future History surface.
/// `created_at` is whatever ISO-ish string Django's `JsonResponse`
/// serializes a `DateTimeField` to via `.values(...)` (kept as a raw string
/// here rather than parsed — this client doesn't currently render it, only
/// carries it for a future screen).
class GdSessionSummary {
  const GdSessionSummary({
    required this.id,
    required this.topic,
    required this.createdAt,
    required this.isActive,
  });

  final int id;
  final String topic;
  final String createdAt;
  final bool isActive;

  factory GdSessionSummary.fromJson(Map<String, dynamic> json) {
    return GdSessionSummary(
      id: (json['id'] as num).toInt(),
      topic: json['topic'] as String? ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}
