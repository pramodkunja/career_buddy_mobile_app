import 'package:career_buddy_lms/features/dashboard/data/models/dashboard_data_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validJson({bool includeOptionalFields = true}) => {
  'stats': <String, dynamic>{
    'completed_count': 3,
    'in_progress_count': 2,
    'total_activities': 20,
    'total_score': 145,
  },
  'activities': [
    {
      'activity_id': 4,
      'title': 'Business Vocabulary',
      'completion_rate': 60.0,
      'completed_sub_activities': 3,
      'total_sub_activities': 5,
      'started_at': '2026-09-01T10:00:00Z',
    },
  ],
  'recent_results': [
    {
      'title': 'Negotiation Quiz',
      'activity_name': 'Negotiation',
      'score': 8,
      'max_score': 10,
      'percentage': 80.0,
      'date': '2026-09-15T14:30:00Z',
    },
  ],
  if (includeOptionalFields) ...{
    'recommended_jobs': [
      {
        'title': 'Customer Support Executive',
        'company_name': 'Acme Corp',
        'skills': ['Communication', 'English', 'CRM'],
        'location': 'Remote',
        'job_type': 'Full-time',
        'experience_level': '0-1 years',
        'salary_display': '₹2.5L - ₹3.5L',
      },
    ],
    'payment_history': [
      {
        'date': '2026-08-01T00:00:00Z',
        'is_plan_active': true,
        'amount_rupees': 499,
        'transaction_id': 'pay_ABC123',
      },
    ],
    'interview_score': 78,
  },
};

void main() {
  group('DashboardDataParsing.fromJson', () {
    test('parses a full valid response', () {
      final data = DashboardDataParsing.fromJson(_validJson());

      expect(data.stats.completedCount, 3);
      expect(data.stats.inProgressCount, 2);
      expect(data.stats.totalActivities, 20);
      expect(data.stats.totalScore, 145);

      expect(data.activities, hasLength(1));
      expect(data.activities.single.title, 'Business Vocabulary');
      expect(data.activities.single.completionRate, 60.0);
      expect(data.activities.single.startedAt, DateTime.parse('2026-09-01T10:00:00Z'));

      expect(data.recentResults.single.title, 'Negotiation Quiz');
      expect(data.recommendedJobs.single.companyName, 'Acme Corp');
      expect(data.paymentHistory.single.transactionId, 'pay_ABC123');
      expect(data.interviewScore, 78);
    });

    test('defaults missing optional fields safely instead of throwing', () {
      final data = DashboardDataParsing.fromJson(_validJson(includeOptionalFields: false));

      expect(data.recommendedJobs, isEmpty);
      expect(data.paymentHistory, isEmpty);
      expect(data.interviewScore, isNull);
    });

    test('throws on a malformed required field instead of silently defaulting', () {
      final json = _validJson();
      (json['stats'] as Map<String, dynamic>)['completed_count'] = 'not a number';

      expect(() => DashboardDataParsing.fromJson(json), throwsFormatException);
    });

    test('throws when a required top-level field is missing', () {
      final json = _validJson()..remove('activities');

      expect(() => DashboardDataParsing.fromJson(json), throwsFormatException);
    });
  });
}
