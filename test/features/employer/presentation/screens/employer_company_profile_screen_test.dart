import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_dashboard_summary.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_profile_form.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_dashboard_repository.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_profile_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_dashboard_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_profile_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/employer_company_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

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

const _formData = EmployerProfileFormData(
  companyName: 'Acme Corp',
  companyWebsite: '',
  industry: 'it_software',
  companySize: '1-10',
  location: '',
  description: '',
  companyAddress: '',
  companyGst: '22AAAAA0000A1Z5',
  maskedPan: 'XXXXXX000A',
  hrContactE164: '+919876543210',
  hrMail: 'hr@acme.test',
);

class _FakeEmployerProfileRepository implements EmployerProfileRepository {
  _FakeEmployerProfileRepository(this.submitResult);

  final Result<void> submitResult;
  bool? lastIsCreateSubmitted;

  @override
  Future<Result<EmployerProfileFormData>> getProfileForm({required bool isCreate}) async => const Success(_formData);

  @override
  Future<Result<void>> updateProfile(EmployerProfileSubmission data, {required bool isCreate}) async {
    lastIsCreateSubmitted = isCreate;
    return submitResult;
  }
}

const _dashboardSummary = EmployerDashboardSummary(greetingName: 'Acme', totalJobsCount: 0, activeJobs: 0, totalApps: 0, jobs: []);

class _FakeEmployerDashboardRepository implements EmployerDashboardRepository {
  var callCount = 0;

  @override
  Future<Result<EmployerDashboardSummary>> getDashboard() async {
    callCount++;
    return const Success(_dashboardSummary);
  }

  @override
  Future<Result<void>> deleteJob(int jobId) async => const Success(null);
}

Future<void> _settle(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('EmployerCompanyProfileScreen', () {
    testWidgets(
      'a successful edit submission (isCreate: false) invalidates and refetches the employer dashboard, '
      'so a stale "complete your profile" gate does not survive a successful save',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final profileRepo = _FakeEmployerProfileRepository(const Success(null));
        final dashboardRepo = _FakeEmployerDashboardRepository();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            employerProfileRepositoryProvider.overrideWithValue(profileRepo),
            employerDashboardRepositoryProvider.overrideWithValue(dashboardRepo),
          ],
        );
        addTearDown(container.dispose);

        // An active subscription is what makes `ref.invalidate` inside the
        // screen actually trigger a real refetch (not just mark the
        // provider dirty for whenever something next reads it) — the real
        // app always has one via `EmployerDashboardScreen` itself watching
        // this same provider.
        container.listen(employerDashboardControllerProvider, (_, _) {});
        await container.read(employerDashboardControllerProvider.future);
        expect(dashboardRepo.callCount, 1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: EmployerCompanyProfileScreen(isCreate: false)),
          ),
        );
        await _settle(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save Company Profile'));
        await _settle(tester);

        expect(profileRepo.lastIsCreateSubmitted, false);
        expect(dashboardRepo.callCount, 2);
      },
    );
  });
}
