import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

const _htmlHeaders = {
  'content-type': ['text/html'],
};

/// A trimmed but structurally faithful slice of the real
/// `templates/dashboard.html` — every marker this file's parser anchors on
/// is present, read directly from that template rather than invented.
const _validDashboardHtml = '''
<div class="dashboard-welcome">
  <h2>Welcome back, <span class="text-accent">Jane</span></h2>
</div>
<div class="row g-4 mb-4">
  <div class="stat-card stat-card-blue"><div class="stat-card-value">12</div></div>
  <div class="stat-card stat-card-green"><div class="stat-card-value">3</div></div>
  <div class="stat-card stat-card-orange"><div class="stat-card-value">2</div></div>
  <div class="stat-card stat-card-purple"><div class="stat-card-value">145</div></div>
</div>
<div class="card border-0 rounded-4 shadow-sm p-4 mb-4 bg-white">
  <small class="text-muted">Unlocked with your interview score of <strong>82/100</strong> — matched.</small>
  <div class="row g-3">
    <div class="col-md-4">
      <div class="job-card border rounded-3 p-3 h-100 overflow-hidden">
        <h6 class="fw-bold mb-0 text-truncate" title="Customer Support Executive">Customer Support Executive</h6>
        <small class="text-muted">Acme Corp</small>
        <span class="badge bg-light text-dark border text-truncate">Communication</span>
        <span class="badge bg-light text-dark border text-truncate">English</span>
        <span class="text-muted"><i class="fas fa-map-marker-alt me-1"></i>Remote</span>
        <span class="badge bg-primary bg-opacity-10 text-primary">Full-time</span>
        <span class="text-muted"><i class="fas fa-briefcase me-1"></i>0-1 years</span>
        <small class="fw-bold text-success"><i class="fas fa-rupee-sign me-1"></i>₹2.5L - ₹3.5L</small>
      </div>
    </div>
  </div>
</div>
<div class="dashboard-card-body">
  <div class="progress-activity-item">
    <a href="/activities/4/" class="progress-activity-link">
      <span class="progress-activity-name">1. Business Vocabulary</span>
      <span class="progress-activity-pct text-warning">60%</span>
      <small class="text-muted">3/5 sub-activities</small>
      <small class="text-info">Started Sep 1, 2026</small>
    </a>
  </div>
  <div class="progress-activity-item">
    <a href="/activities/7/" class="progress-activity-link">
      <span class="progress-activity-name">2. Negotiation</span>
      <span class="progress-activity-pct text-muted">0%</span>
      <small class="text-muted">0/4 sub-activities</small>
    </a>
  </div>
</div>
<div class="dashboard-card mt-4">
  <div class="dashboard-card-body p-0">
    <table class="table">
      <tbody>
        <tr>
          <td>Aug 1, 2026</td>
          <td><span class="badge bg-success">Active</span></td>
          <td>₹499.00</td>
          <td>Razorpay</td>
          <td><small class="text-muted">pay_ABC123</small></td>
        </tr>
      </tbody>
    </table>
  </div>
</div>
<div class="dashboard-card-body p-0">
  <div class="recent-result-item">
    <div class="result-exercise-name">Negotiation Quiz</div>
    <div class="result-activity-name text-muted">Negotiation</div>
    <span class="score-badge score-high">8/10</span>
  </div>
</div>
''';

const _loginRedirectHtml = '''
<html><body><form id="login-form"><input name="username"></form></body></html>
''';

ApiClient _clientReturning({required int statusCode, required String body, Map<String, List<String>>? headers}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body, headers: headers)
    ..interceptors.add(ApiExceptionsInterceptor());
  return ApiClient.forTesting(dio);
}

void main() {
  group('DashboardRemoteDataSource.getDashboard', () {
    test('parses a valid 200 HTML response — the real /dashboard/ page, not the undeployed JSON sibling', () async {
      final client = _clientReturning(statusCode: 200, body: _validDashboardHtml, headers: _htmlHeaders);
      final data = await DashboardRemoteDataSource(client).getDashboard();

      expect(data.stats.totalActivities, 12);
      expect(data.stats.completedCount, 3);
      expect(data.stats.inProgressCount, 2);
      expect(data.stats.totalScore, 145);
      expect(data.interviewScore, 82);

      expect(data.activities, hasLength(2));
      expect(data.activities[0].activityId, 4);
      expect(data.activities[0].title, 'Business Vocabulary');
      expect(data.activities[0].completionRate, 60);
      expect(data.activities[0].completedSubActivities, 3);
      expect(data.activities[0].totalSubActivities, 5);
      expect(data.activities[0].startedAt, DateTime(2026, 9, 1));
      expect(data.activities[1].startedAt, isNull);

      expect(data.recommendedJobs, hasLength(1));
      expect(data.recommendedJobs.single.title, 'Customer Support Executive');
      expect(data.recommendedJobs.single.companyName, 'Acme Corp');
      expect(data.recommendedJobs.single.skills, ['Communication', 'English']);
      expect(data.recommendedJobs.single.salaryDisplay, '₹2.5L - ₹3.5L');

      expect(data.paymentHistory, hasLength(1));
      expect(data.paymentHistory.single.isPlanActive, isTrue);
      expect(data.paymentHistory.single.amountRupees, 499);
      expect(data.paymentHistory.single.transactionId, 'pay_ABC123');
      expect(data.paymentHistory.single.date, DateTime(2026, 8, 1));

      expect(data.recentResults, hasLength(1));
      expect(data.recentResults.single.title, 'Negotiation Quiz');
      expect(data.recentResults.single.score, 8);
      expect(data.recentResults.single.maxScore, 10);
      expect(data.recentResults.single.percentage, 80);
    });

    test('a page missing recommended_jobs/payment_history sections (the real {% if %} being false) parses as empty, not an error', () async {
      final sparse = _validDashboardHtml
          .replaceAll(RegExp(r'<div class="card border-0 rounded-4 shadow-sm p-4 mb-4 bg-white">[\s\S]*?</div>\s*</div>\s*</div>'), '')
          .replaceAll(RegExp(r'<div class="dashboard-card mt-4">[\s\S]*?</table>\s*</div>\s*</div>'), '');
      final client = _clientReturning(statusCode: 200, body: sparse, headers: _htmlHeaders);
      final data = await DashboardRemoteDataSource(client).getDashboard();

      expect(data.recommendedJobs, isEmpty);
      expect(data.paymentHistory, isEmpty);
      expect(data.interviewScore, isNull);
      // Confirms the strip above didn't accidentally eat the still-expected
      // sections too.
      expect(data.stats.totalActivities, 12);
      expect(data.activities, hasLength(2));
    });

    test('a login-redirect page (session expired) throws UnauthorizedException, not a confusing parse error', () async {
      final client = _clientReturning(statusCode: 200, body: _loginRedirectHtml, headers: _htmlHeaders);

      expect(
        () => DashboardRemoteDataSource(client).getDashboard(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('a non-200 status maps through the existing exception mapper', () async {
      final client = _clientReturning(statusCode: 500, body: '');

      expect(
        () => DashboardRemoteDataSource(client).getDashboard(),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
