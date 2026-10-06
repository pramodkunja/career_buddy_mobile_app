import 'activity_progress.dart';
import 'dashboard_stats.dart';
import 'payment_record.dart';
import 'recent_result.dart';
import 'recommended_job.dart';

/// Aggregate of everything the dashboard screen renders — mirrors
/// `dashboard()`'s context dict in `activities/views.py` (see
/// `docs/BACKEND_CONTRACT_dashboard.md` for the proposed wire format).
class DashboardData {
  const DashboardData({
    required this.stats,
    required this.activities,
    required this.recentResults,
    required this.recommendedJobs,
    required this.paymentHistory,
    this.interviewScore,
  });

  final DashboardStats stats;
  final List<ActivityProgress> activities;
  final List<RecentResult> recentResults;

  /// Empty when the student isn't eligible yet (no passed AI interview, or
  /// not on a paid plan) — same as the web dashboard's conditional card.
  final List<RecommendedJob> recommendedJobs;

  /// Empty when the student has never paid — same as the web dashboard's
  /// conditional card.
  final List<PaymentRecord> paymentHistory;
  final num? interviewScore;
}
