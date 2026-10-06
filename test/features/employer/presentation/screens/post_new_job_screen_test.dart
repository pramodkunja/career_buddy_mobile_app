import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/job_posting_submission.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/job_posting_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/job_posting_providers.dart';
import 'package:career_buddy_lms/features/employer/presentation/screens/post_new_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Same reasoning as the other employer screens' own test doubles —
/// `BuddyChatbotOverlay`/`AppNavDrawer` need `authControllerProvider` wired
/// to something real.
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

class _FakeJobPostingRepository implements JobPostingRepository {
  _FakeJobPostingRepository(this.result);

  Result<void> result;
  JobPostingSubmission? submitted;
  var callCount = 0;

  @override
  Future<Result<void>> submit(JobPostingSubmission data) async {
    callCount++;
    submitted = data;
    return result;
  }
}

/// Bounded pumps instead of `pumpAndSettle` — `BuddyChatbotOverlay`'s float
/// animation repeats forever, so `pumpAndSettle` never returns (same
/// reasoning as every other screen test in this app that includes it).
Future<void> _settle(WidgetTester tester, {int times = 6}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tall enough to lay out every section of this large form without needing
/// to scroll during a test — scrolling reliably inside a bounded-pump (no
/// `pumpAndSettle`) test adds real fragility for little value here, since
/// what's under test is field wiring/logic, not layout. One consequence:
/// at this height, the "Both" gender-preference chip happens to coincide
/// with `BuddyChatbotOverlay`'s fixed-position launcher bubble — tests
/// below deliberately pick "Female" instead for that one chip, which
/// exercises the identical code path without the collision.
Future<void> _pump(WidgetTester tester, JobPostingRepository repo) async {
  tester.view.physicalSize = const Size(400, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const PostNewJobScreen()),
      GoRoute(path: RoutePaths.employerJobOpenings, builder: (context, state) => const Scaffold(body: Text('JOB OPENINGS'))),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        jobPostingRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

Future<void> _selectDropdown(WidgetTester tester, String dropdownLabel, String optionLabel) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, dropdownLabel).first);
  await _settle(tester);
  await tester.tap(find.text(optionLabel).last);
  await _settle(tester);
}

Future<void> _fillMinimalValidItJob(WidgetTester tester) async {
  await _selectDropdown(tester, 'Job Category', 'IT');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Senior Flutter Developer');
  await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Hyderabad');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Build and ship mobile features.');
  await _selectDropdown(tester, 'Job Type', 'Full Time');
  await _selectDropdown(tester, 'Experience Required', '3-5 Years');
  await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '30000');
  await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '50000');
  // A `pump` after each tap — back-to-back `tester.tap()` calls with no
  // intervening frame left a later tap in this sequence undelivered
  // (confirmed: the real `ChoiceChip.onSelected` callback works correctly
  // when invoked directly — this is a test-harness gesture-arena queueing
  // quirk from firing several taps with no settle between them, not an app
  // bug).
  await tester.tap(find.text('Work From Office'));
  await tester.pump();
  await tester.tap(find.text('Virtual'));
  await tester.pump();
  await tester.tap(find.text('Immediately'));
  await tester.pump();
  // "Female", not "Both" — at this test's viewport height, "Both" happens
  // to coincide with `BuddyChatbotOverlay`'s fixed-position launcher
  // bubble (confirmed via Flutter's own "would not hit test" warning);
  // "Female" exercises the identical gender_preference code path without
  // the collision.
  await tester.tap(find.text('Female'));
  await _settle(tester);
}

void main() {
  group('PostNewJobScreen', () {
    testWidgets('selecting IT reveals Work Environment, Interview Mode and Technical Requirements', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');

      expect(find.text('Work Environment'), findsOneWidget);
      expect(find.text('Interview Mode'), findsOneWidget);
      expect(find.text('Technical Requirements'), findsOneWidget);
      expect(find.text('Department'), findsNothing);
    });

    testWidgets('selecting Non-IT then Technical reveals Department and hides Interview Mode', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');

      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Interview Mode'), findsNothing);
      expect(find.text('Notice Period Required'), findsOneWidget);
    });

    testWidgets('tapping Save with nothing filled shows local required-field errors and never calls the repository', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(find.text('Select a job category.'), findsOneWidget);
      expect(repo.callCount, 0);
    });

    testWidgets('a valid IT submission calls the repository, shows a success snackbar, and navigates to Job Openings', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.title, 'Senior Flutter Developer');
      expect(repo.submitted?.jobCategory, 'it');
      expect(find.text('Job posted successfully!'), findsOneWidget);
      expect(find.text('JOB OPENINGS'), findsOneWidget);
    });

    testWidgets('a server-side per-field validation failure is shown under the field, not a generic dialog', (tester) async {
      final repo = _FakeJobPostingRepository(
        const Failed(ValidationFailure({'title': ['This field is required.']})),
      );
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('JOB OPENINGS'), findsNothing);
    });
  });
}
