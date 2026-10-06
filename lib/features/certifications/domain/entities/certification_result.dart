/// The user's best-ever Mock Test result for one certification subject —
/// `mock_test_integration.get_mock_test_result`'s exact return shape
/// (`skillup_assessment/mock_test_integration.py:22-47`):
/// `{"score": int | None, "total": int | None, "completed": bool}`.
/// `score`/`total` are `null` whenever `completed` is `false` (never
/// attempted) — this is real, server-computed data, never a client guess.
class CertificationResult {
  const CertificationResult({required this.score, required this.total, required this.completed});

  final int? score;
  final int? total;
  final bool completed;

  /// `score / total`, purely a display-formatting convenience over the two
  /// real numbers above — `null` whenever either is unavailable. This is
  /// NOT a fabricated score: it's the same arithmetic the backend itself
  /// uses to decide eligibility (`mock_test_integration.is_eligible`), just
  /// re-run here for presentation only; the server's own `state` field is
  /// still what's ever used to drive certificate actions.
  double? get percentage {
    if (score == null || total == null || total == 0) return null;
    return (score! / total!) * 100;
  }
}
