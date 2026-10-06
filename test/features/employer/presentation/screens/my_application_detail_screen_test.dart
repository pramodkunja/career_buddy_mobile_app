import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/my_application_detail.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/my_application_detail_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/my_application_detail_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/my_application_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// `BuddyChatbotOverlay` (now part of every screen's `Scaffold`, per the
/// web's unconditional `{% include 'includes/aria_assistant.html' %}`)
/// reads `authControllerProvider` for its greeting, which otherwise falls
/// through to `authRepositoryProvider` -> `authRemoteDataSourceProvider` ->
/// `apiClientProvider` (unimplemented outside `main()`). Overriding
/// `authRepositoryProvider` directly — same pattern as
/// `GrammarDetailScreen`'s own test doubles — avoids that without this
/// screen's own tests needing to care about auth at all.
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

class _FakeRepository implements MyApplicationDetailRepository {
  _FakeRepository(this.result);

  Result<MyApplicationDetail> result;

  @override
  Future<Result<MyApplicationDetail>> getApplicationDetail(int applicationId) async => result;
}

const _activeJobApplication = MyApplicationDetail(
  applicationId: 12,
  jobId: 68,
  jobTitle: 'Senior Python Developer',
  companyName: 'Acme Corp',
  jobLocation: 'Hyderabad',
  status: 'reviewing',
  appliedAt: '10 Sep 2026, 09:15',
  updatedAt: '12 Sep 2026, 14:00',
  applicantName: 'Alex Kumar',
  applicantEmail: 'alex@example.com',
  jobType: 'Full Time',
  jobExperience: '5-8 Years',
  coverLetter: 'I am excited to apply.',
  jobIsActive: true,
);

Future<void> _pump(WidgetTester tester, Result<MyApplicationDetail> result) async {
  final repo = _FakeRepository(result);
  final router = GoRouter(
    initialLocation: '/my-applications/12',
    routes: [
      GoRoute(
        path: RoutePaths.myApplicationDetailPattern,
        builder: (context, state) => const MyApplicationDetailScreen(applicationId: 12),
      ),
      GoRoute(
        path: RoutePaths.publicJobDetailPattern,
        builder: (context, state) => Scaffold(body: Text('JOB:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        myApplicationDetailRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  group('MyApplicationDetailScreen', () {
    testWidgets('renders every field including the cover letter', (tester) async {
      await _pump(tester, const Success(_activeJobApplication));

      expect(find.text('Application #12'), findsOneWidget);
      expect(find.text('Senior Python Developer'), findsOneWidget);
      expect(find.text('Acme Corp · Hyderabad'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text('I am excited to apply.'), findsOneWidget);
      expect(find.text('View job posting'), findsOneWidget);
    });

    testWidgets('tapping View job posting navigates to the Public Job Detail screen', (tester) async {
      await _pump(tester, const Success(_activeJobApplication));

      await tester.tap(find.text('View job posting'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('JOB:68'), findsOneWidget);
    });

    testWidgets('hides the job-posting link when the job is no longer active', (tester) async {
      await _pump(
        tester,
        const Success(
          MyApplicationDetail(
            applicationId: 9,
            jobId: null,
            jobTitle: 'Closed Role',
            companyName: 'Career Buddy Partner',
            jobLocation: '',
            status: 'rejected',
            appliedAt: '1 Oct 2026, 08:00',
            updatedAt: '1 Oct 2026, 08:00',
            applicantName: 'Jordan Lee',
            applicantEmail: 'jordan@example.com',
            jobType: 'Internship',
            jobExperience: 'Fresher',
            coverLetter: null,
            jobIsActive: false,
          ),
        ),
      );

      expect(find.text('View job posting'), findsNothing);
    });

    testWidgets('shows a retryable error view for a generic failure', (tester) async {
      await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
