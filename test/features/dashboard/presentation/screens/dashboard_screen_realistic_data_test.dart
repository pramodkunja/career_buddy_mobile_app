import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/activity_progress.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/payment_record.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/recent_result.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/recommended_job.dart';
import 'package:career_buddy_lms/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.restoredUser);
  final AuthUser? restoredUser;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository(this.data);
  final DashboardData data;

  @override
  Future<Result<DashboardData>> getDashboard() async => Success(data);
}

/// Combines every real backend fixture captured from
/// `activities.tests_dashboard_api` into one payload — a student who has
/// progress, results, all 5 recommended jobs, payment history, and an
/// interview score simultaneously. Real per-user Django responses only
/// ever populate a subset at once (the eligibility rules are mutually
/// exclusive in places, e.g. a brand-new user has no payments), but the
/// *union* is the worst case for layout — the most content any single
/// dashboard render has to fit without overflowing.
DashboardData _fullRealisticData() => DashboardData(
  stats: const DashboardStats(completedCount: 3, inProgressCount: 2, totalActivities: 20, totalScore: 145),
  activities: const [
    ActivityProgress(
      activityId: 1,
      title: 'Business Vocabulary',
      completionRate: 100,
      completedSubActivities: 1,
      totalSubActivities: 1,
    ),
    ActivityProgress(
      activityId: 2,
      title: 'Grammar Basics',
      completionRate: 0,
      completedSubActivities: 0,
      totalSubActivities: 1,
    ),
  ],
  recentResults: [
    RecentResult(
      title: 'Business Email Writing',
      activityName: 'Writing',
      score: 18,
      maxScore: 20,
      percentage: 90,
      date: DateTime.parse('2026-09-21T12:05:34.663566+00:00'),
    ),
    RecentResult(
      title: 'Reading Session',
      activityName: 'Reading',
      score: 6,
      maxScore: 10,
      percentage: 60,
      date: DateTime.parse('2026-09-21T12:05:34.414317+00:00'),
    ),
  ],
  recommendedJobs: const [
    RecommendedJob(
      title: 'Customer Support Executive',
      companyName: 'Acme Corp',
      skills: ['Communication', 'English', 'CRM'],
      location: 'Remote',
      jobType: 'Full Time',
      experienceLevel: 'Fresher',
      salaryDisplay: 'As per industry norms',
    ),
    RecommendedJob(
      title: 'Citizen Service Executive',
      companyName: 'Tata Consultancy Services',
      skills: ['Customer Service', 'Communication', 'English', 'Government Services', 'Data Entry', 'Passport Services'],
      location: 'Vishakhapatnam',
      jobType: 'Full Time',
      experienceLevel: 'Fresher',
      salaryDisplay: 'As per industry norms',
    ),
    RecommendedJob(
      title: 'Customer Care Executive',
      companyName: 'BPO Convergence',
      skills: ['Communication', 'English', 'Hindi', 'Customer Service', 'BPO', 'Problem Solving'],
      location: 'Hyderabad',
      jobType: 'Full Time',
      experienceLevel: 'Fresher',
      salaryDisplay: '₹1.3 - 1.7 LPA',
    ),
    RecommendedJob(
      title: 'Retail Sales Associate / CSA',
      companyName: 'GMR Group',
      skills: ['Retail', 'Customer Service', 'Communication', 'Duty Free', 'Fashion', 'Electronics', 'Airport Retail'],
      location: 'Vishakhapatnam International Airport',
      jobType: 'Full Time',
      experienceLevel: '1-2 Years',
      salaryDisplay: 'As per industry norms',
    ),
    RecommendedJob(
      title: 'Mobiliser / Telecaller',
      companyName: 'Funfirst Global Skillers',
      skills: ['Telecalling', 'Mobilization', 'Communication', 'Outreach'],
      location: 'Field',
      jobType: 'Full Time',
      experienceLevel: 'Fresher',
      salaryDisplay: 'As per industry norms',
    ),
  ],
  paymentHistory: [
    PaymentRecord(
      date: DateTime.parse('2026-09-21T12:05:34.579522+00:00'),
      isPlanActive: true,
      amountRupees: 499,
      transactionId: 'pay_TESTFIXTURE001',
    ),
  ],
  interviewScore: 85,
);

Future<void> _pumpDashboard(WidgetTester tester, DashboardData data) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(const AuthUser(username: 'jane'))),
        dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository(data)),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  group('DashboardScreen with realistic (real-backend-shaped) full data', () {
    testWidgets('renders every section with no layout overflow at phone width', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDashboard(tester, _fullRealisticData());

      // The username is its own accent-colored `TextSpan` now (matching the
      // web's `<span class="text-accent">`), so `findRichText` is required.
      expect(find.text('Welcome back, jane', findRichText: true), findsOneWidget);

      // The rest of the page is below the fold in a single-column phone
      // layout — a plain ListView only builds slivers near the viewport, so
      // reaching later content (and thereby exercising it for overflow)
      // means scrolling to it, not just asserting on the initial frame.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Customer Support Executive'), 300, scrollable: scrollable);
      expect(find.text('View & Apply'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Mobiliser / Telecaller'), 300, scrollable: scrollable);
      await tester.scrollUntilVisible(find.text('Business Vocabulary'), 300, scrollable: scrollable);
      await tester.scrollUntilVisible(find.textContaining('pay_TESTFIXTURE001'), 300, scrollable: scrollable);
      await tester.scrollUntilVisible(find.text('Quick Start'), 300, scrollable: scrollable);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders every section with no layout overflow at tablet width', (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDashboard(tester, _fullRealisticData());

      // Tablet layout splits into two columns; both sides' headings should render.
      expect(find.text('Activity Progress'), findsOneWidget);
      expect(find.text('Recent Results'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Mobiliser / Telecaller'), 300, scrollable: scrollable);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders correctly on a narrow phone (320px) with long job/company names', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDashboard(tester, _fullRealisticData());

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Retail Sales Associate / CSA'), 300, scrollable: scrollable);
      expect(find.text('Retail Sales Associate / CSA'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Business Vocabulary'), 300, scrollable: scrollable);
      await tester.scrollUntilVisible(find.textContaining('pay_TESTFIXTURE001'), 300, scrollable: scrollable);

      expect(tester.takeException(), isNull);
    });
  });
}
