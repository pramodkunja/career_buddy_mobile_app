import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/activity_progress.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/entities/recent_result.dart';
import '../../domain/entities/recommended_job.dart';

/// Parses the JSON contract documented in
/// `docs/BACKEND_CONTRACT_dashboard.md` into [DashboardData]. Required
/// fields that are missing or the wrong type throw a [FormatException]
/// (caught by `DashboardRemoteDataSource` and surfaced as an
/// `UnexpectedResponseException`) rather than being silently defaulted —
/// a malformed response should never look like valid, if sparse, data.
extension DashboardDataParsing on DashboardData {
  static DashboardData fromJson(Map<String, dynamic> json) {
    return DashboardData(
      stats: _statsFromJson(requireMap(json, 'stats')),
      activities: requireList(json, 'activities').map((e) => _activityFromJson(asMap(e, 'activities[]'))).toList(),
      recentResults: requireList(
        json,
        'recent_results',
      ).map((e) => _recentResultFromJson(asMap(e, 'recent_results[]'))).toList(),
      recommendedJobs: (optionalList(json, 'recommended_jobs') ?? const [])
          .map((e) => _recommendedJobFromJson(asMap(e, 'recommended_jobs[]')))
          .toList(),
      paymentHistory: (optionalList(json, 'payment_history') ?? const [])
          .map((e) => _paymentRecordFromJson(asMap(e, 'payment_history[]')))
          .toList(),
      interviewScore: json['interview_score'] as num?,
    );
  }

  static DashboardStats _statsFromJson(Map<String, dynamic> json) {
    return DashboardStats(
      completedCount: requireInt(json, 'completed_count'),
      inProgressCount: requireInt(json, 'in_progress_count'),
      totalActivities: requireInt(json, 'total_activities'),
      totalScore: requireNum(json, 'total_score'),
    );
  }

  static ActivityProgress _activityFromJson(Map<String, dynamic> json) {
    return ActivityProgress(
      activityId: requireInt(json, 'activity_id'),
      title: requireString(json, 'title'),
      completionRate: requireNum(json, 'completion_rate').toDouble(),
      completedSubActivities: requireInt(json, 'completed_sub_activities'),
      totalSubActivities: requireInt(json, 'total_sub_activities'),
      startedAt: optionalDateTime(json, 'started_at'),
    );
  }

  static RecentResult _recentResultFromJson(Map<String, dynamic> json) {
    return RecentResult(
      title: requireString(json, 'title'),
      activityName: requireString(json, 'activity_name'),
      score: requireNum(json, 'score'),
      maxScore: requireNum(json, 'max_score'),
      percentage: requireNum(json, 'percentage').toDouble(),
      date: requireDateTime(json, 'date'),
    );
  }

  static RecommendedJob _recommendedJobFromJson(Map<String, dynamic> json) {
    return RecommendedJob(
      title: requireString(json, 'title'),
      companyName: requireString(json, 'company_name'),
      skills: (optionalList(json, 'skills') ?? const []).map((e) => e.toString()).toList(),
      location: requireString(json, 'location'),
      jobType: requireString(json, 'job_type'),
      experienceLevel: requireString(json, 'experience_level'),
      salaryDisplay: requireString(json, 'salary_display'),
    );
  }

  static PaymentRecord _paymentRecordFromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      date: requireDateTime(json, 'date'),
      isPlanActive: json['is_plan_active'] == true,
      amountRupees: requireNum(json, 'amount_rupees'),
      transactionId: requireString(json, 'transaction_id'),
    );
  }
}
