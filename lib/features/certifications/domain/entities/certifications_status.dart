import 'certification_category.dart';

/// The full `GET api_certifications_status` payload
/// (`skillup_assessment/views.py:301-327`):
/// `{"categories": [...], "total_count", "attempted_count", "earned_count"}`.
/// All three counts are computed server-side from the real per-subject
/// states (`total_certification_opportunities()` / a `sum(...)` over every
/// subject's `state`) — never recomputed or trusted client-side beyond
/// simply displaying them.
class CertificationsStatus {
  const CertificationsStatus({
    required this.categories,
    required this.totalCount,
    required this.attemptedCount,
    required this.earnedCount,
  });

  final List<CertificationCategory> categories;
  final int totalCount;
  final int attemptedCount;
  final int earnedCount;
}
