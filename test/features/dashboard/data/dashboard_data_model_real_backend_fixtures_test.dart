import 'dart:convert';

import 'package:career_buddy_lms/features/dashboard/data/models/dashboard_data_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// These are the *actual* JSON bodies captured by running
/// `activities.tests_dashboard_api` against the live Django backend
/// (`GET /dashboard/api/`) for each realistic scenario — not hand-invented
/// data. Each one exercises `DashboardDataParsing.fromJson` against exactly
/// what the real view returns, confirming the Flutter model and the
/// backend's actual output still agree.
const activityProgressJson = '''
{
  "stats": {"completed_count": 1, "in_progress_count": 0, "total_activities": 1, "total_score": 0},
  "activities": [
    {
      "activity_id": 1, "title": "Business Vocabulary", "completion_rate": 100.0,
      "completed_sub_activities": 1, "total_sub_activities": 1,
      "started_at": "2026-09-21T12:05:34.169609+00:00"
    }
  ],
  "recent_results": [], "recommended_jobs": [], "payment_history": [], "interview_score": null
}
''';

const recentResultsJson = '''
{
  "stats": {"completed_count": 0, "in_progress_count": 0, "total_activities": 0, "total_score": 18},
  "activities": [],
  "recent_results": [
    {
      "title": "Business Email Writing", "activity_name": "Writing", "score": 18, "max_score": 20,
      "percentage": 90.0, "date": "2026-09-21T12:05:34.663566+00:00"
    }
  ],
  "recommended_jobs": [], "payment_history": [], "interview_score": null
}
''';

const paymentHistoryJson = '''
{
  "stats": {"completed_count": 0, "in_progress_count": 0, "total_activities": 0, "total_score": 0},
  "activities": [], "recent_results": [], "recommended_jobs": [],
  "payment_history": [
    {
      "date": "2026-09-21T12:05:34.579522+00:00", "is_plan_active": true,
      "amount_rupees": 499.0, "transaction_id": "pay_TESTFIXTURE001"
    }
  ],
  "interview_score": null
}
''';

const eligibleJobsAndInterviewScoreJson = '''
{
  "stats": {"completed_count": 0, "in_progress_count": 0, "total_activities": 0, "total_score": 0},
  "activities": [], "recent_results": [],
  "recommended_jobs": [
    {
      "title": "Customer Support Executive", "company_name": "Acme Corp",
      "skills": ["Communication", "English", "CRM"], "location": "Remote",
      "job_type": "Full Time", "experience_level": "Fresher", "salary_display": "As per industry norms"
    },
    {
      "title": "Citizen Service Executive", "company_name": "Tata Consultancy Services",
      "skills": ["Customer Service", "Communication", "English", "Government Services", "Data Entry", "Passport Services"],
      "location": "Vishakhapatnam", "job_type": "Full Time", "experience_level": "Fresher",
      "salary_display": "As per industry norms"
    },
    {
      "title": "Customer Care Executive", "company_name": "BPO Convergence",
      "skills": ["Communication", "English", "Hindi", "Customer Service", "BPO", "Problem Solving"],
      "location": "Hyderabad", "job_type": "Full Time", "experience_level": "Fresher",
      "salary_display": "₹1.3 - 1.7 LPA"
    },
    {
      "title": "Retail Sales Associate / CSA", "company_name": "GMR Group",
      "skills": ["Retail", "Customer Service", "Communication", "Duty Free", "Fashion", "Electronics", "Airport Retail"],
      "location": "Vishakhapatnam International Airport", "job_type": "Full Time",
      "experience_level": "1-2 Years", "salary_display": "As per industry norms"
    },
    {
      "title": "Mobiliser / Telecaller", "company_name": "Funfirst Global Skillers",
      "skills": ["Telecalling", "Mobilization", "Communication", "Outreach"],
      "location": "Field", "job_type": "Full Time", "experience_level": "Fresher",
      "salary_display": "As per industry norms"
    }
  ],
  "payment_history": [], "interview_score": 85
}
''';

const incompleteOrMissingJson = '''
{
  "stats": {"completed_count": 0, "in_progress_count": 1, "total_activities": 1, "total_score": 6},
  "activities": [
    {
      "activity_id": 2, "title": "Grammar Basics", "completion_rate": 0.0,
      "completed_sub_activities": 0, "total_sub_activities": 1,
      "started_at": "2026-09-21T12:05:34.414015+00:00"
    }
  ],
  "recent_results": [
    {
      "title": "Reading Session", "activity_name": "Reading", "score": 6, "max_score": 10,
      "percentage": 60.0, "date": "2026-09-21T12:05:34.414317+00:00"
    }
  ],
  "recommended_jobs": [], "payment_history": [], "interview_score": null
}
''';

const noDashboardDataJson = '''
{
  "stats": {"completed_count": 0, "in_progress_count": 0, "total_activities": 1, "total_score": 0},
  "activities": [
    {
      "activity_id": 3, "title": "Untouched Activity", "completion_rate": 0.0,
      "completed_sub_activities": 0, "total_sub_activities": 1, "started_at": null
    }
  ],
  "recent_results": [], "recommended_jobs": [], "payment_history": [], "interview_score": null
}
''';

void main() {
  group('DashboardDataParsing.fromJson against real backend responses', () {
    test('activity progress', () {
      final data = DashboardDataParsing.fromJson(jsonDecode(activityProgressJson));
      expect(data.stats.completedCount, 1);
      expect(data.activities.single.title, 'Business Vocabulary');
      expect(data.activities.single.completionRate, 100.0);
    });

    test('recent assessment results', () {
      final data = DashboardDataParsing.fromJson(jsonDecode(recentResultsJson));
      expect(data.recentResults.single.title, 'Business Email Writing');
      expect(data.recentResults.single.percentage, 90.0);
    });

    test('payment history', () {
      final data = DashboardDataParsing.fromJson(jsonDecode(paymentHistoryJson));
      expect(data.paymentHistory.single.amountRupees, 499.0);
      expect(data.paymentHistory.single.isPlanActive, isTrue);
    });

    test('eligible recommended jobs and interview score', () {
      final data = DashboardDataParsing.fromJson(jsonDecode(eligibleJobsAndInterviewScoreJson));
      expect(data.interviewScore, 85);
      expect(data.recommendedJobs, hasLength(5));
      expect(data.recommendedJobs.first.companyName, 'Acme Corp');
      // The ₹ salary display (non-ASCII) round-trips correctly through JSON parsing.
      final priced = data.recommendedJobs.firstWhere((j) => j.companyName == 'BPO Convergence');
      expect(priced.salaryDisplay, '₹1.3 - 1.7 LPA');
    });

    test('incomplete/missing optional data', () {
      final data = DashboardDataParsing.fromJson(jsonDecode(incompleteOrMissingJson));
      expect(data.activities.single.completionRate, 0.0);
      expect(data.recentResults.single.title, 'Reading Session');
      expect(data.recommendedJobs, isEmpty);
      expect(data.paymentHistory, isEmpty);
      expect(data.interviewScore, isNull);
    });

    test('no dashboard data (new user)', () {
      final data = DashboardDataParsing.fromJson(jsonDecode(noDashboardDataJson));
      expect(data.activities.single.startedAt, isNull);
      expect(data.recentResults, isEmpty);
      expect(data.recommendedJobs, isEmpty);
      expect(data.paymentHistory, isEmpty);
    });
  });
}
