import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/public_job_detail.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/public_job_detail_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/public_job_detail_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/public_job_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.isEmployer = false});

  final bool isEmployer;

  @override
  Future<AuthUser?> restoreSession() async => AuthUser(username: 'u', isEmployer: isEmployer);

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeRepository implements PublicJobDetailRepository {
  _FakeRepository(this.detailResult, {this.applyResult = const Success(null)});

  Result<PublicJobDetail> detailResult;
  Result<void> applyResult;

  @override
  Future<Result<PublicJobDetail>> getJobDetail(int jobId) async => detailResult;

  @override
  Future<Result<void>> apply(int jobId, PublicJobApplicationSubmission data) async => applyResult;
}

const _job = PublicJobDetail(
  title: 'Senior Python Developer',
  companyName: 'Acme Corp',
  jobType: 'Full Time',
  experience: '5-8 Years',
  location: 'Hyderabad',
  salaryDisplay: '₹12 - 18 LPA',
  openings: '3 Opening(s)',
  description: 'We are hiring.',
  requirements: '5+ years Python.',
  skills: ['Python', 'Django'],
  deadline: 'Dec. 31, 2026',
);

Future<void> _pump(
  WidgetTester tester, {
  required Result<PublicJobDetail> result,
  bool isEmployer = false,
  Result<void> applyResult = const Success(null),
}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(isEmployer: isEmployer)),
        publicJobDetailRepositoryProvider.overrideWithValue(_FakeRepository(result, applyResult: applyResult)),
      ],
      child: const MaterialApp(home: PublicJobDetailScreen(jobId: 68)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('PublicJobDetailScreen', () {
    testWidgets('renders job details and shows the apply form for a non-employer session', (tester) async {
      await _pump(tester, result: const Success(_job));

      expect(find.text('Senior Python Developer'), findsOneWidget);
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('Apply for this Position'), findsOneWidget);
    });

    testWidgets('hides the apply form for an employer session', (tester) async {
      await _pump(tester, result: const Success(_job), isEmployer: true);

      expect(find.text('Senior Python Developer'), findsOneWidget);
      expect(find.text('Apply for this Position'), findsNothing);
    });

    testWidgets('submitting the apply form shows a confirmation on success', (tester) async {
      await _pump(tester, result: const Success(_job));

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Alex Kumar');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'alex@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Phone Number'), '9876543210');
      await tester.tap(find.text('Submit My Application'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Application submitted successfully!'), findsOneWidget);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, result: const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
