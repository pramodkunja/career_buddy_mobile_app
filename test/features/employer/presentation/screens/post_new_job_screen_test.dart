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
  var editCallCount = 0;
  int? editedJobId;
  Result<JobPostingSubmission>? jobForEdit;

  @override
  Future<Result<void>> submit(JobPostingSubmission data) async {
    callCount++;
    submitted = data;
    return result;
  }

  @override
  Future<Result<void>> submitEdit(int jobId, JobPostingSubmission data) async {
    editCallCount++;
    editedJobId = jobId;
    submitted = data;
    return result;
  }

  @override
  Future<Result<JobPostingSubmission>> getJobForEdit(int jobId) async {
    return jobForEdit ?? Failed(const UnexpectedFailure('No job stubbed for this fake.'));
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

/// Phase 52 — the minimal set of fields `_localRequiredErrors()` now
/// actually requires for a Non-IT × Technical posting: Department (+ its
/// skill picker is hidden for Non-Technical, not relevant here), Employment
/// Type, Work Mode, and the Notice Period pills (Technical keeps these as
/// its own mandatory field — `jobs_app/forms.py:872-877`). Deliberately
/// never touches Work Environment / Interview Mode / the IT-only "Job
/// Type" dropdown / Gender — none of those are shown or required here, and
/// this is exactly the gap this phase closes.
///
/// Phase 53 — also selects a Qualification ("ITI"), now required for both
/// Non-IT sheets (`forms.py:836-838`); "ITI" is deliberately a value valid
/// under the server's own accepted-value rules for either sheet
/// (`TECH_EDUCATION_KEYS`/`TECH_ONLY_EDUCATION_KEYS` — not mirrored
/// client-side this phase, see this file's Phase 53 group), so this
/// fixture stays realistic regardless.
///
/// Phase 58 — also fills Application Contact, now required for both
/// Non-IT sheets (`forms.py`'s `NON_IT_FIELDS` — see this file's Phase 58
/// group); a plain email is deliberately used since it's unambiguously
/// valid under the real source's 3-way email/phone/name rule.
///
/// Phase 60 — also fills Industry / Sector, Industry Experience,
/// Job Responsibilities, Working Hours / Shift, and Key Skills / Keywords —
/// all required for NON-IT×Technical per `forms.py`'s `NON_IT_FIELDS`
/// sheet, previously missing from this fixture because `_localRequiredErrors()`
/// didn't check them yet either (see this file's Phase 60 group).
Future<void> _fillMinimalValidNonItTechnicalJob(WidgetTester tester) async {
  await _selectDropdown(tester, 'Job Category', 'Non-IT');
  await _selectDropdown(tester, 'Job Classification', 'Technical');
  await _selectDropdown(tester, 'Department', 'Engineering Skills');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Site Engineer');
  await _selectDropdown(tester, 'Employment Type', 'Permanent');
  await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Construction');
  await _selectDropdown(tester, 'Experience Required', '3-5 Years');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Oversee on-site execution.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '30000');
  await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '50000');
  await _selectDropdown(tester, 'Work Mode', 'On-site');
  await _selectDropdown(tester, 'Qualification', 'ITI');
  await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), '3 years in civil construction');
  await tester.enterText(find.widgetWithText(TextFormField, 'Working Hours / Shift'), 'Day shift, 9am-6pm');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Responsibilities'), 'Supervise the site crew.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'Site supervision, Safety');
  await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
  await tester.tap(find.text('Immediately'));
  await _settle(tester);
}

/// Phase 52 — the minimal set for Non-IT × Non-Technical: Employment Type,
/// Work Mode, and Joining Requirement (this classification's own mandatory
/// field instead of the Notice Period pills — `forms.py:858-859`).
/// Deliberately never touches Work Environment / Interview Mode / the
/// IT-only "Job Type" dropdown / Notice Period / Gender.
///
/// Phase 53 — also selects a Qualification ("ITI"); see the Technical
/// fixture's own doc comment above for why this value in particular.
///
/// Phase 58 — also fills Application Contact; see the Technical fixture's
/// own doc comment above.
///
/// Phase 60 — also fills Department / Function, Functional Skills,
/// Industry / Sector, Job Responsibilities, Working Hours / Shift, and
/// Key Skills / Keywords — all required for NON-IT×Non-Technical per
/// `forms.py`'s `NON_IT_FIELDS` sheet. Industry Experience is deliberately
/// left blank here (optional for this classification only), proving that
/// stays true.
Future<void> _fillMinimalValidNonItNonTechnicalJob(WidgetTester tester) async {
  await _selectDropdown(tester, 'Job Category', 'Non-IT');
  await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'HR Executive');
  await tester.enterText(find.widgetWithText(TextFormField, 'Department / Function'), 'Human Resources');
  await _selectDropdown(tester, 'Employment Type', 'Permanent');
  await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Staffing');
  await _selectDropdown(tester, 'Experience Required', '3-5 Years');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Manage employee relations.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '25000');
  await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '35000');
  await _selectDropdown(tester, 'Work Mode', 'Office');
  await _selectDropdown(tester, 'Joining Requirement', 'Immediate');
  await _selectDropdown(tester, 'Qualification', 'ITI');
  await tester.enterText(find.widgetWithText(TextFormField, 'Functional Skills'), 'Recruitment, Onboarding');
  await tester.enterText(find.widgetWithText(TextFormField, 'Working Hours / Shift'), 'Day shift, 9am-6pm');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Responsibilities'), 'Handle hiring and onboarding.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'HR, Recruitment');
  await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
  await _settle(tester);
}

/// Phase 58 — every other field `_fillMinimalValidNonItTechnicalJob` fills,
/// minus Application Contact, so a test can supply its own value (or leave
/// it blank) and observe exactly that field's behavior in isolation.
///
/// Phase 60 — also fills the fields that fixture now fills (see its own
/// doc comment above) other than Application Contact.
Future<void> _fillNonItTechnicalExceptContact(WidgetTester tester) async {
  await _selectDropdown(tester, 'Job Category', 'Non-IT');
  await _selectDropdown(tester, 'Job Classification', 'Technical');
  await _selectDropdown(tester, 'Department', 'Engineering Skills');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Site Engineer');
  await _selectDropdown(tester, 'Employment Type', 'Permanent');
  await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Construction');
  await _selectDropdown(tester, 'Experience Required', '3-5 Years');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Oversee on-site execution.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '30000');
  await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '50000');
  await _selectDropdown(tester, 'Work Mode', 'On-site');
  await _selectDropdown(tester, 'Qualification', 'ITI');
  await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), '3 years in civil construction');
  await tester.enterText(find.widgetWithText(TextFormField, 'Working Hours / Shift'), 'Day shift, 9am-6pm');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Responsibilities'), 'Supervise the site crew.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'Site supervision, Safety');
  await tester.tap(find.text('Immediately'));
  await _settle(tester);
}

/// Phase 58 — the Non-IT×Non-Technical counterpart of
/// `_fillNonItTechnicalExceptContact`.
///
/// Phase 60 — also fills the fields `_fillMinimalValidNonItNonTechnicalJob`
/// now fills (see its own doc comment above) other than Application
/// Contact.
Future<void> _fillNonItNonTechnicalExceptContact(WidgetTester tester) async {
  await _selectDropdown(tester, 'Job Category', 'Non-IT');
  await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'HR Executive');
  await tester.enterText(find.widgetWithText(TextFormField, 'Department / Function'), 'Human Resources');
  await _selectDropdown(tester, 'Employment Type', 'Permanent');
  await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Staffing');
  await _selectDropdown(tester, 'Experience Required', '3-5 Years');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Manage employee relations.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '25000');
  await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '35000');
  await _selectDropdown(tester, 'Work Mode', 'Office');
  await _selectDropdown(tester, 'Joining Requirement', 'Immediate');
  await _selectDropdown(tester, 'Qualification', 'ITI');
  await tester.enterText(find.widgetWithText(TextFormField, 'Functional Skills'), 'Recruitment, Onboarding');
  await tester.enterText(find.widgetWithText(TextFormField, 'Working Hours / Shift'), 'Day shift, 9am-6pm');
  await tester.enterText(find.widgetWithText(TextFormField, 'Job Responsibilities'), 'Handle hiring and onboarding.');
  await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'HR, Recruitment');
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

  group('PostNewJobScreen — Phase 52: Non-IT required-field parity', () {
    testWidgets(
      'the IT-only "Job Type" dropdown is not shown for Non-IT — only the real, '
      'separate "Employment Type" dropdown appears',
      (tester) async {
        await _pump(tester, _FakeJobPostingRepository(const Success(null)));

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');

        expect(find.text('Job Type'), findsNothing);
        expect(find.text('Employment Type (job nature)'), findsNothing);
        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Employment Type'), findsOneWidget);
      },
    );

    testWidgets('a valid Non-IT × Technical submission is not blocked by hidden-field validation', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1, reason: 'must reach the repository, not be stopped by phantom hidden-field errors');
      expect(find.text('This field is required.'), findsNothing);
      expect(repo.submitted?.jobCategory, 'non_it');
      expect(repo.submitted?.jobClassification, 'technical');
      // Non-IT's own equivalents were sent; the IT-only trio was not.
      expect(repo.submitted?.employmentType, 'permanent');
      expect(repo.submitted?.workMode, 'onsite');
      expect(repo.submitted?.noticePeriod, 'immediate');
      expect(repo.submitted?.educationPreset, 'iti');
      expect(repo.submitted?.jobType, '');
      expect(repo.submitted?.workEnvironment, '');
      expect(repo.submitted?.interviewMode, '');
      expect(find.text('Job posted successfully!'), findsOneWidget);
    });

    testWidgets('a valid Non-IT × Non-Technical submission is not blocked by hidden-field validation', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItNonTechnicalJob(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1, reason: 'must reach the repository, not be stopped by phantom hidden-field errors');
      expect(find.text('This field is required.'), findsNothing);
      expect(repo.submitted?.jobCategory, 'non_it');
      expect(repo.submitted?.jobClassification, 'non_technical');
      expect(repo.submitted?.employmentType, 'permanent');
      expect(repo.submitted?.workMode, 'office');
      expect(repo.submitted?.joiningRequirement, 'immediate');
      expect(repo.submitted?.educationPreset, 'iti');
      // Non-IT×Non-Technical's own equivalents were sent; Notice Period
      // (Technical/IT's own field) and the IT-only trio were not.
      expect(repo.submitted?.noticePeriod, '');
      expect(repo.submitted?.jobType, '');
      expect(repo.submitted?.workEnvironment, '');
      expect(repo.submitted?.interviewMode, '');
      expect(find.text('Job posted successfully!'), findsOneWidget);
    });

    testWidgets(
      'a Non-IT submission missing its own required fields (Work Mode, Employment Type) still shows real '
      'validation errors — hidden fields are skipped, not all validation',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Select a work mode.'), findsOneWidget);
        expect(find.text('Select an employment type.'), findsOneWidget);
        // The IT-only fields have no widget on this category at all, so
        // they can't contribute a phantom "This field is required." either.
        expect(find.text('Work Environment'), findsNothing);
        expect(find.text('Interview Mode'), findsNothing);
      },
    );

    testWidgets(
      'a Non-IT × Non-Technical submission missing its Joining Requirement is blocked with the real error',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
        await _selectDropdown(tester, 'Employment Type', 'Permanent');
        await _selectDropdown(tester, 'Work Mode', 'Office');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Select a joining requirement.'), findsOneWidget);
      },
    );

    testWidgets('Gender is optional for Non-IT (a valid submission with no gender choice still succeeds)', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      // Deliberately never taps a Gender Requirement chip.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.genderPreference, '');
    });

    testWidgets('switching from IT to Non-IT clears the IT-only fields so a stale value is never silently submitted', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      await tester.tap(find.text('Work From Office'));
      await tester.pump();
      await tester.tap(find.text('Virtual'));
      await _settle(tester);

      await _selectDropdown(tester, 'Job Category', 'Non-IT');

      // The IT-only sections are gone entirely now, so their previous
      // selections can no longer even be displayed, let alone submitted.
      expect(find.text('Work Environment'), findsNothing);
      expect(find.text('Interview Mode'), findsNothing);
    });

    testWidgets(
      'switching Non-IT classification from Technical to Non-Technical clears the Notice Period pills, '
      'not just hides them',
      (tester) async {
        await _pump(tester, _FakeJobPostingRepository(const Success(null)));

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');
        await tester.tap(find.text('Immediately'));
        await _settle(tester);
        expect(find.text('Notice Period Required'), findsOneWidget);

        await _selectDropdown(tester, 'Job Classification', 'Non-Technical');

        expect(find.text('Notice Period Required'), findsNothing);
        // Appears twice (the section heading + the dropdown's own label) —
        // what matters here is that it exists at all, not the exact count.
        expect(find.text('Joining Requirement'), findsWidgets);
      },
    );

    testWidgets('Non-IT × Technical offers Plant as a Work Mode option; Non-IT × Non-Technical offers Hybrid instead', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Work Mode').first);
      await _settle(tester);
      expect(find.text('Plant'), findsOneWidget);
      expect(find.text('Hybrid'), findsNothing);
      // Close the open dropdown menu before switching classification.
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);

      await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Work Mode').first);
      await _settle(tester);

      expect(find.text('Hybrid'), findsOneWidget);
      expect(find.text('Plant'), findsNothing);
    });
  });

  group('PostNewJobScreen — Phase 53: Non-IT education/qualification required-field parity', () {
    testWidgets(
      'a Non-IT × Technical submission missing its Qualification is blocked with the real server error',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');
        await _selectDropdown(tester, 'Department', 'Engineering Skills');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Site Engineer');
        await _selectDropdown(tester, 'Employment Type', 'Permanent');
        await _selectDropdown(tester, 'Experience Required', '3-5 Years');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Oversee on-site execution.');
        await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '30000');
        await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '50000');
        await _selectDropdown(tester, 'Work Mode', 'On-site');
        await tester.tap(find.text('Immediately'));
        await _settle(tester);
        // Deliberately never selects a Qualification.

        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Qualification is required.'), findsOneWidget);
      },
    );

    testWidgets(
      'a Non-IT × Non-Technical submission missing its Qualification is blocked with the real server error',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'HR Executive');
        await _selectDropdown(tester, 'Employment Type', 'Permanent');
        await _selectDropdown(tester, 'Experience Required', '3-5 Years');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Manage employee relations.');
        await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '25000');
        await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '35000');
        await _selectDropdown(tester, 'Work Mode', 'Office');
        await _selectDropdown(tester, 'Joining Requirement', 'Immediate');
        await _settle(tester);
        // Deliberately never selects a Qualification.

        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Qualification is required.'), findsOneWidget);
      },
    );

    testWidgets('selecting a Qualification value clears the "Qualification is required." error for Non-IT', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');
      await _selectDropdown(tester, 'Department', 'Engineering Skills');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Site Engineer');
      await _selectDropdown(tester, 'Employment Type', 'Permanent');
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Construction');
      await _selectDropdown(tester, 'Experience Required', '3-5 Years');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Oversee on-site execution.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '30000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '50000');
      await _selectDropdown(tester, 'Work Mode', 'On-site');
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), '3 years in civil construction');
      await tester.enterText(find.widgetWithText(TextFormField, 'Working Hours / Shift'), 'Day shift, 9am-6pm');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Responsibilities'), 'Supervise the site crew.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'Site supervision, Safety');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Immediately'));
      await _settle(tester);

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Qualification is required.'), findsOneWidget);

      await _selectDropdown(tester, 'Qualification', 'ITI');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Qualification is required.'), findsNothing);
      expect(repo.submitted?.educationPreset, 'iti');
    });

    testWidgets(
      'Qualification is not required for IT (a valid IT submission with no Qualification choice still succeeds)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidItJob(tester);
        // Deliberately never selects an Education/Qualification value.
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(find.text('Qualification is required.'), findsNothing);
        expect(repo.submitted?.educationPreset, '');
      },
    );
  });

  group('PostNewJobScreen — Phase 54: education options and custom qualification parity', () {
    testWidgets('IT shows the general education preset list, not the NON-IT×Technical sheet', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Education').first);
      await _settle(tester);

      expect(find.text('Below 10th Standard'), findsOneWidget);
      expect(find.text('10th / SSLC'), findsOneWidget);
      expect(find.text('Under-Graduate / Degree'), findsOneWidget);
      expect(find.text('Post-Graduate'), findsOneWidget);
      // The NON-IT×Technical-only presets must not be offered to IT.
      expect(find.text('Degree'), findsNothing);
      expect(find.text('Certification'), findsNothing);
    });

    testWidgets('Non-IT × Technical shows its own Degree/Diploma/ITI/Certification sheet, not the general list', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Qualification').first);
      await _settle(tester);

      expect(find.text('Degree'), findsOneWidget);
      expect(find.text('Diploma'), findsOneWidget);
      expect(find.text('ITI'), findsOneWidget);
      expect(find.text('Certification'), findsOneWidget);
      // The general-list-only presets must not be offered to NON-IT×Technical.
      expect(find.text('Below 10th Standard'), findsNothing);
      expect(find.text('Under-Graduate / Degree'), findsNothing);
      expect(find.text('Post-Graduate'), findsNothing);
    });

    testWidgets('Non-IT × Non-Technical shows the general education preset list, same as IT', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Qualification').first);
      await _settle(tester);

      expect(find.text('Below 10th Standard'), findsOneWidget);
      expect(find.text('Under-Graduate / Degree'), findsOneWidget);
      expect(find.text('Post-Graduate'), findsOneWidget);
      // NON-IT×Technical-only presets must not be offered here either.
      expect(find.text('Degree'), findsNothing);
      expect(find.text('Certification'), findsNothing);
    });

    testWidgets(
      'a NON-IT×Technical-only Qualification (Degree) does not remain selected after switching to '
      'Non-Technical, and blocks submission again until re-picked',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');
        await _selectDropdown(tester, 'Qualification', 'Degree');

        await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'HR Executive');
        await _selectDropdown(tester, 'Employment Type', 'Permanent');
        await _selectDropdown(tester, 'Experience Required', '3-5 Years');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
        await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Manage employee relations.');
        await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '25000');
        await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '35000');
        await _selectDropdown(tester, 'Work Mode', 'Office');
        await _selectDropdown(tester, 'Joining Requirement', 'Immediate');
        // Deliberately never re-selects a Qualification: Degree was cleared
        // by the classification switch, exactly as the web page clears a
        // stale preset no longer on the current sheet.

        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Qualification is required.'), findsOneWidget);
      },
    );

    testWidgets('switching Job Category from Non-IT×Technical to IT clears a stale Degree selection', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');
      await _selectDropdown(tester, 'Qualification', 'Degree');

      await _selectDropdown(tester, 'Job Category', 'IT');
      // IT's own general list offers Degree under a different label
      // ("Under-Graduate / Degree"), never the bare "Degree" sheet preset —
      // if the stale selection survived uncleared, the dropdown would still
      // show the old label, which cannot appear in IT's own item list.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Education').first);
      await _settle(tester);
      expect(find.text('Degree'), findsNothing);
    });

    testWidgets('selecting "Enter manually" reveals the custom Qualification text field', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      expect(find.widgetWithText(TextFormField, 'Qualification'), findsNothing);

      await _selectDropdown(tester, 'Education', 'Enter manually');

      expect(find.widgetWithText(TextFormField, 'Qualification'), findsOneWidget);
    });

    testWidgets('empty custom Qualification text is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      // Deliberately leaves the custom text field empty.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter the educational qualification.'), findsOneWidget);
    });

    testWidgets('valid custom Qualification text passes local validation and reaches the repository', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Qualification'), 'B.Tech in Mechanical Engineering');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Enter the educational qualification.'), findsNothing);
      expect(repo.submitted?.educationPreset, 'custom');
      expect(repo.submitted?.educationOther, 'B.Tech in Mechanical Engineering');
    });

    testWidgets('repeated internal whitespace in custom Qualification text is collapsed before submission', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Qualification'), '  B.Tech   CSE  ');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.educationOther, 'B.Tech CSE');
    });

    testWidgets('custom Qualification text with no letters is rejected with the real server error', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Qualification'), '12345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Education must include letters, for example 10th, B.Tech or Diploma.'), findsOneWidget);
    });

    testWidgets('a standalone number in custom Qualification text is rejected with the real server error', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Qualification'), 'Batch 2020');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Numbers are allowed only as part of a qualification, such as 10th or 12th.'),
        findsOneWidget,
      );
    });

    testWidgets('custom Qualification text over 60 characters is rejected with the real server error', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Qualification'),
        'A' * 61,
      );
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Education must be 60 characters or fewer.'), findsOneWidget);
    });

    testWidgets('correcting invalid custom Qualification text clears the validation error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Education', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Qualification'), '12345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Education must include letters, for example 10th, B.Tech or Diploma.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Qualification'), 'B.Tech');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Education must include letters, for example 10th, B.Tech or Diploma.'), findsNothing);
      expect(repo.submitted?.educationOther, 'B.Tech');
    });
  });

  group('PostNewJobScreen — Phase 55: experience range fields (experience_plus/experience_years_max)', () {
    testWidgets('a normal minimum-experience preset (no "custom") still submits correctly', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.experiencePreset, '3-5');
      expect(repo.submitted?.experienceYears, '');
      expect(repo.submitted?.experiencePlus, false);
      expect(repo.submitted?.experienceYearsMax, '');
    });

    testWidgets('selecting "No upper limit" ("10+") produces the correct submission values and hides Maximum years', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '10');
      expect(find.widgetWithText(TextFormField, 'Maximum years (optional)'), findsOneWidget);

      await tester.tap(find.text('No upper limit (e.g. "10+ years")'));
      await _settle(tester);
      expect(find.widgetWithText(TextFormField, 'Maximum years (optional)'), findsNothing);

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.experiencePreset, 'custom');
      expect(repo.submitted?.experienceYears, '10');
      expect(repo.submitted?.experiencePlus, true);
      expect(repo.submitted?.experienceYearsMax, '');
    });

    testWidgets('a supplied Maximum years value is serialized correctly, with experience_plus false', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '2');
      await tester.enterText(find.widgetWithText(TextFormField, 'Maximum years (optional)'), '5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.experienceYears, '2');
      expect(repo.submitted?.experienceYearsMax, '5');
      expect(repo.submitted?.experiencePlus, false);
    });

    testWidgets('an empty optional Maximum years field submits successfully with an empty experience_years_max', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '5');
      // Deliberately leaves Maximum years blank.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.experienceYears, '5');
      expect(repo.submitted?.experienceYearsMax, '');
    });

    testWidgets('a negative minimum years value is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '-5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Experience years cannot be negative.'), findsOneWidget);
    });

    testWidgets('a minimum years value over 99 is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '150');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Experience years must not exceed 99 (2 digits).'), findsOneWidget);
    });

    testWidgets('a non-numeric Maximum years value is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '2');
      await tester.enterText(find.widgetWithText(TextFormField, 'Maximum years (optional)'), 'abc');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter the maximum experience as a whole number of years (0-99).'), findsOneWidget);
    });

    testWidgets('a Maximum years value over 99 is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '2');
      await tester.enterText(find.widgetWithText(TextFormField, 'Maximum years (optional)'), '150');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Experience years must not exceed 99 (2 digits).'), findsOneWidget);
    });

    testWidgets(
      'a minimum greater than the maximum is rejected with the real server error, matching '
      'JobPostingForm.clean()',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidItJob(tester);
        await _selectDropdown(tester, 'Experience Required', 'Enter manually');
        await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '8');
        await tester.enterText(find.widgetWithText(TextFormField, 'Maximum years (optional)'), '5');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Minimum experience cannot be greater than maximum experience.'), findsOneWidget);
      },
    );

    testWidgets('checking "No upper limit" after typing a Maximum years value clears it, matching the real combo box', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '10');
      await tester.enterText(find.widgetWithText(TextFormField, 'Maximum years (optional)'), '15');

      await tester.tap(find.text('No upper limit (e.g. "10+ years")'));
      await _settle(tester);
      expect(find.widgetWithText(TextFormField, 'Maximum years (optional)'), findsNothing);

      // Unchecking shows the field again, now empty — not the old "15".
      await tester.tap(find.text('No upper limit (e.g. "10+ years")'));
      await _settle(tester);
      final maxField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Maximum years (optional)'));
      expect(maxField.controller!.text, '');
    });

    testWidgets('an experience range survives switching Job Category (no source rule ties it to category)', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      await _selectDropdown(tester, 'Experience Required', 'Enter manually');
      await tester.enterText(find.widgetWithText(TextFormField, 'Years of experience'), '7');

      await _selectDropdown(tester, 'Job Category', 'Non-IT');

      final yearsField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Years of experience'));
      expect(yearsField.controller!.text, '7');
    });

    testWidgets('Edit mode: a "10+" posting loads with the checkbox checked and Maximum years hidden', (tester) async {
      const jobWithPlus = JobPostingSubmission(
        jobCategory: 'it',
        jobClassification: '',
        department: '',
        departmentFunction: '',
        designation: '',
        industrySector: '',
        title: 'Senior Backend Engineer',
        jobType: 'full_time',
        contractDurationMonths: '',
        employmentType: '',
        experiencePreset: 'custom',
        experienceYears: '10',
        experiencePlus: true,
        experienceYearsMax: '',
        location: 'Pune',
        educationPreset: '',
        educationOther: '',
        functionalSkills: '',
        industryExperience: '',
        workingHours: '',
        salaryFormat: 'monthly',
        salaryMin: '40000',
        salaryMax: '60000',
        openings: 3,
        perks: ['laptop'],
        description: 'Own the payments service end to end.',
        requirements: '',
        responsibilities: '',
        certifications: '',
        softwareSkills: '',
        languageRequirements: '',
        keywords: '',
        applicationContact: '',
        skills: ['python', 'django'],
        mandatorySkills: ['python'],
        deadline: '',
        status: 'active',
        workEnvironment: 'wfo',
        interviewMode: 'virtual',
        interviewModeOther: '',
        workMode: '',
        joiningRequirement: '',
        noticePeriod: 'immediate',
        noticePeriodOther: '',
        genderPreference: 'both',
        ageLimit: '',
      );

      tester.view.physicalSize = const Size(400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeJobPostingRepository(const Success(null));
      repo.jobForEdit = const Success(jobWithPlus);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
            routes: [GoRoute(path: 'edit', builder: (context, state) => const PostNewJobScreen(jobId: 68))],
          ),
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
      router.push('/edit');
      await _settle(tester);

      final yearsField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Years of experience'));
      expect(yearsField.controller!.text, '10');
      final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, true);
      expect(find.widgetWithText(TextFormField, 'Maximum years (optional)'), findsNothing);

      // Saving an untouched edit preserves the loaded "10+" state.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.editCallCount, 1);
      expect(repo.submitted?.experiencePlus, true);
      expect(repo.submitted?.experienceYears, '10');
      expect(repo.submitted?.experienceYearsMax, '');
    });

    testWidgets('Edit mode: a range posting (min-max) loads with Maximum years populated and the checkbox unchecked', (
      tester,
    ) async {
      const jobWithRange = JobPostingSubmission(
        jobCategory: 'it',
        jobClassification: '',
        department: '',
        departmentFunction: '',
        designation: '',
        industrySector: '',
        title: 'Senior Backend Engineer',
        jobType: 'full_time',
        contractDurationMonths: '',
        employmentType: '',
        experiencePreset: 'custom',
        experienceYears: '2',
        experiencePlus: false,
        experienceYearsMax: '5',
        location: 'Pune',
        educationPreset: '',
        educationOther: '',
        functionalSkills: '',
        industryExperience: '',
        workingHours: '',
        salaryFormat: 'monthly',
        salaryMin: '40000',
        salaryMax: '60000',
        openings: 3,
        perks: ['laptop'],
        description: 'Own the payments service end to end.',
        requirements: '',
        responsibilities: '',
        certifications: '',
        softwareSkills: '',
        languageRequirements: '',
        keywords: '',
        applicationContact: '',
        skills: ['python', 'django'],
        mandatorySkills: ['python'],
        deadline: '',
        status: 'active',
        workEnvironment: 'wfo',
        interviewMode: 'virtual',
        interviewModeOther: '',
        workMode: '',
        joiningRequirement: '',
        noticePeriod: 'immediate',
        noticePeriodOther: '',
        genderPreference: 'both',
        ageLimit: '',
      );

      tester.view.physicalSize = const Size(400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeJobPostingRepository(const Success(null));
      repo.jobForEdit = const Success(jobWithRange);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
            routes: [GoRoute(path: 'edit', builder: (context, state) => const PostNewJobScreen(jobId: 68))],
          ),
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
      router.push('/edit');
      await _settle(tester);

      final yearsField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Years of experience'));
      expect(yearsField.controller!.text, '2');
      final maxField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Maximum years (optional)'));
      expect(maxField.controller!.text, '5');
      final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, false);

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.editCallCount, 1);
      expect(repo.submitted?.experienceYears, '2');
      expect(repo.submitted?.experienceYearsMax, '5');
      expect(repo.submitted?.experiencePlus, false);
    });
  });

  group('PostNewJobScreen — Phase 57: Contract Duration conditional visibility and validation', () {
    testWidgets('Project Duration is hidden for IT when no Job Type, or a non-Contract Job Type, is selected', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      expect(find.text('Project Duration (months)'), findsNothing);

      await _selectDropdown(tester, 'Job Type', 'Full Time');
      expect(find.text('Project Duration (months)'), findsNothing);
    });

    testWidgets('Project Duration is visible for IT once Job Type is Contract', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      await _selectDropdown(tester, 'Job Type', 'Contract');

      expect(find.widgetWithText(TextFormField, 'Project Duration (months)'), findsOneWidget);
    });

    testWidgets('Project Duration is visible for Non-IT × Technical once Employment Type is Contract', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');
      expect(find.text('Project / Contract Duration (months)'), findsNothing);

      await _selectDropdown(tester, 'Employment Type', 'Contract');
      expect(find.widgetWithText(TextFormField, 'Project / Contract Duration (months)'), findsOneWidget);
    });

    testWidgets('Project Duration is visible for Non-IT × Non-Technical once Employment Type is Contract', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Non-Technical');
      expect(find.text('Project / Contract Duration (months)'), findsNothing);

      await _selectDropdown(tester, 'Employment Type', 'Contract');
      expect(find.widgetWithText(TextFormField, 'Project / Contract Duration (months)'), findsOneWidget);
    });

    testWidgets(
      'switching Job Type away from Contract hides Project Duration, clears its value and any validation error',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'IT');
        await _selectDropdown(tester, 'Job Type', 'Contract');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);
        expect(repo.callCount, 0);
        expect(find.text('Enter the project duration in months.'), findsOneWidget);

        await _selectDropdown(tester, 'Job Type', 'Full Time');

        expect(find.widgetWithText(TextFormField, 'Project Duration (months)'), findsNothing);
        expect(find.text('Enter the project duration in months.'), findsNothing);
      },
    );

    testWidgets('switching back to Contract after typing a duration shows an empty field, not the stale value', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '6');

      await _selectDropdown(tester, 'Job Type', 'Full Time');
      await _selectDropdown(tester, 'Job Type', 'Contract');

      final durationField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Project Duration (months)'));
      expect(durationField.controller!.text, '');
    });

    testWidgets('a missing duration is rejected for a Contract IT posting with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      // Deliberately leaves Project Duration blank.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter the project duration in months.'), findsOneWidget);
    });

    testWidgets('valid durations of 1 and 12 months are both accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.contractDurationMonths, '1');
    });

    testWidgets('a 12-month duration is accepted (the exact maximum)', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '12');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.contractDurationMonths, '12');
    });

    testWidgets('a duration of 0 is rejected with the real "at least 1 month" error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '0');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Project duration must be at least 1 month.'), findsOneWidget);
    });

    testWidgets('a negative duration is rejected with the real "cannot be negative" error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '-1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Project duration cannot be negative.'), findsOneWidget);
    });

    testWidgets('a decimal duration is rejected with the real "whole number" error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '2.5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter the project duration as a whole number of months.'), findsOneWidget);
    });

    testWidgets('non-numeric duration text is rejected with the real "whole number" error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), 'abc');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter the project duration as a whole number of months.'), findsOneWidget);
    });

    testWidgets('a duration over 12 months is rejected with the real "cannot exceed" error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '13');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Project duration cannot exceed 12 months.'), findsOneWidget);
    });

    testWidgets('a stale duration typed while Contract was selected is not submitted after switching away', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Job Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project Duration (months)'), '6');
      await _selectDropdown(tester, 'Job Type', 'Full Time');

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.jobType, 'full_time');
      expect(repo.submitted?.contractDurationMonths, '');
    });

    testWidgets('a Non-IT × Technical Contract posting submits its duration correctly', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _selectDropdown(tester, 'Job Category', 'Non-IT');
      await _selectDropdown(tester, 'Job Classification', 'Technical');
      await _selectDropdown(tester, 'Department', 'Engineering Skills');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Site Engineer');
      await _selectDropdown(tester, 'Employment Type', 'Contract');
      await tester.enterText(find.widgetWithText(TextFormField, 'Project / Contract Duration (months)'), '4');
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Construction');
      await _selectDropdown(tester, 'Experience Required', '3-5 Years');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Description'), 'Oversee on-site execution.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Minimum Salary (₹ per month)'), '30000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Maximum Salary (₹ per month)'), '50000');
      await _selectDropdown(tester, 'Work Mode', 'On-site');
      await _selectDropdown(tester, 'Qualification', 'ITI');
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), '3 years in civil construction');
      await tester.enterText(find.widgetWithText(TextFormField, 'Working Hours / Shift'), 'Day shift, 9am-6pm');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Responsibilities'), 'Supervise the site crew.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'Site supervision, Safety');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Immediately'));
      await _settle(tester);

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.employmentType, 'contract');
      expect(repo.submitted?.contractDurationMonths, '4');
    });

    testWidgets('Edit mode: a Contract posting loads with Project Duration visible and populated', (tester) async {
      const contractJob = JobPostingSubmission(
        jobCategory: 'it',
        jobClassification: '',
        department: '',
        departmentFunction: '',
        designation: '',
        industrySector: '',
        title: 'Backend Contractor',
        jobType: 'contract',
        contractDurationMonths: '6',
        employmentType: '',
        experiencePreset: '3-5',
        experienceYears: '',
        experiencePlus: false,
        experienceYearsMax: '',
        location: 'Pune',
        educationPreset: '',
        educationOther: '',
        functionalSkills: '',
        industryExperience: '',
        workingHours: '',
        salaryFormat: 'monthly',
        salaryMin: '40000',
        salaryMax: '60000',
        openings: 3,
        perks: ['laptop'],
        description: 'Own the payments service end to end.',
        requirements: '',
        responsibilities: '',
        certifications: '',
        softwareSkills: '',
        languageRequirements: '',
        keywords: '',
        applicationContact: '',
        skills: ['python', 'django'],
        mandatorySkills: ['python'],
        deadline: '',
        status: 'active',
        workEnvironment: 'wfo',
        interviewMode: 'virtual',
        interviewModeOther: '',
        workMode: '',
        joiningRequirement: '',
        noticePeriod: 'immediate',
        noticePeriodOther: '',
        genderPreference: 'both',
        ageLimit: '',
      );

      tester.view.physicalSize = const Size(400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeJobPostingRepository(const Success(null));
      repo.jobForEdit = const Success(contractJob);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
            routes: [GoRoute(path: 'edit', builder: (context, state) => const PostNewJobScreen(jobId: 68))],
          ),
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
      router.push('/edit');
      await _settle(tester);

      final durationField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Project Duration (months)'));
      expect(durationField.controller!.text, '6');

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.editCallCount, 1);
      expect(repo.submitted?.contractDurationMonths, '6');
    });
  });

  group('PostNewJobScreen — Phase 58: Application Contact requiredness and format validation', () {
    testWidgets('Application Contact is required for Non-IT × Technical, with the real "is required" message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      // Deliberately leaves Application Contact blank.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Application Contact is required.'), findsOneWidget);
    });

    testWidgets('Application Contact is required for Non-IT × Non-Technical, with the real "is required" message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Application Contact is required.'), findsOneWidget);
    });

    testWidgets('Application Contact remains optional for IT — a valid IT submission with none still succeeds', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      // The field is never shown for IT at all.
      expect(find.widgetWithText(TextFormField, 'Application Contact'), findsNothing);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Application Contact is required.'), findsNothing);
      expect(repo.submitted?.applicationContact, '');
    });

    testWidgets('a valid email address is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'recruiter@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, 'recruiter@example.com');
    });

    testWidgets('a valid phone number is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), '9876543210');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, '9876543210');
    });

    testWidgets('a valid contact name is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'Jane Doe');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, 'Jane Doe');
    });

    for (final sep in [',', '/', '|', ';']) {
      testWidgets('the "$sep" separator splits multiple contacts, and both valid parts pass', (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItTechnicalExceptContact(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Application Contact'),
          'recruiter@example.com${sep}9876543210',
        );
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1, reason: 'the "$sep" separator must be recognised, same as the real source');
        expect(repo.submitted?.applicationContact, 'recruiter@example.com${sep}9876543210');
      });
    }

    testWidgets('multiple valid contacts across all 3 formats in one value are accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Application Contact'),
        'recruiter@example.com, 9876543210, Jane Doe',
      );
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('multiple contacts where one entry is invalid are rejected as a whole, with the real format error', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'recruiter@example.com, 123');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );
    });

    testWidgets('an invalid email-shaped value is rejected with the real format error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'not-an-email@');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );
    });

    testWidgets('an invalid phone-shaped value (too few digits) is rejected with the real format error', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      // 6 digits — 1 below the 7-digit floor.
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), '123456');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );
    });

    testWidgets('an invalid name (digits mixed into otherwise name-shaped text) is rejected with the real format error', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'Jane123');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'phone digit-count boundaries below and above the floor/ceiling both fail, with the real format error',
      (tester) async {
        // A successful submission navigates away from this screen (see the
        // top-level "navigates to Job Openings" test), so the 2 rejected
        // boundaries are chained on one pump here; the 2 accepted
        // boundaries (which each succeed) get their own dedicated pump
        // below instead.
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);
        await _fillNonItTechnicalExceptContact(tester);
        final contactField = find.widgetWithText(TextFormField, 'Application Contact');
        const errorText = 'Application Contact should be a valid email address, phone number or contact name.';

        // 6 digits: 1 below the floor — rejected.
        await tester.enterText(contactField, '123456');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);
        expect(repo.callCount, 0);
        expect(find.text(errorText), findsOneWidget);

        // 16 digits: 1 above the ceiling — rejected.
        await tester.enterText(contactField, '1234567890123456');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);
        expect(repo.callCount, 0);
        expect(find.text(errorText), findsOneWidget);
      },
    );

    testWidgets('a phone number with exactly 7 digits (the floor) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), '1234567');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, '1234567');
    });

    testWidgets('a phone number with exactly 15 digits (the ceiling) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), '123456789012345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, '123456789012345');
    });

    testWidgets('a contact name with fewer than 2 letters is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      // A single letter: matches CONTACT_NAME_RE's character class, but has
      // only 1 letter, under the 2-letter floor.
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'A');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );
    });

    testWidgets('allowed name punctuation (hyphen, apostrophe, period) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), "Mary-Jane O'Brien");
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, "Mary-Jane O'Brien");
    });

    testWidgets('a disallowed character (underscore) in an otherwise name-shaped value is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'John_Doe');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );
    });

    testWidgets('leading/trailing whitespace is trimmed and internal runs collapsed before submission', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), '  Jane   Doe  ');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.applicationContact, 'Jane Doe');
    });

    testWidgets('correcting an invalid Application Contact clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'Jane123');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsOneWidget,
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'Jane Doe');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(
        find.text('Application Contact should be a valid email address, phone number or contact name.'),
        findsNothing,
      );
      expect(repo.submitted?.applicationContact, 'Jane Doe');
    });

    testWidgets('Edit mode: an existing Non-IT posting with Application Contact loads and preserves it unchanged', (
      tester,
    ) async {
      const existingNonItJob = JobPostingSubmission(
        jobCategory: 'non_it',
        jobClassification: 'non_technical',
        department: '',
        departmentFunction: 'People Operations',
        designation: '',
        industrySector: 'Staffing',
        title: 'HR Executive',
        jobType: '',
        contractDurationMonths: '',
        employmentType: 'permanent',
        experiencePreset: '3-5',
        experienceYears: '',
        experiencePlus: false,
        experienceYearsMax: '',
        location: 'Pune',
        educationPreset: 'iti',
        educationOther: '',
        functionalSkills: 'Recruitment',
        industryExperience: '',
        workingHours: '9-6',
        salaryFormat: 'monthly',
        salaryMin: '25000',
        salaryMax: '35000',
        openings: 2,
        perks: [],
        description: 'Manage employee relations.',
        requirements: '',
        responsibilities: 'Handle hiring and onboarding.',
        certifications: '',
        softwareSkills: '',
        languageRequirements: '',
        keywords: 'HR, Recruitment',
        applicationContact: 'hr@example.com',
        skills: [],
        mandatorySkills: [],
        deadline: '',
        status: 'active',
        workEnvironment: '',
        interviewMode: '',
        interviewModeOther: '',
        workMode: 'office',
        joiningRequirement: 'immediate',
        noticePeriod: '',
        noticePeriodOther: '',
        genderPreference: 'both',
        ageLimit: '',
      );

      tester.view.physicalSize = const Size(400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeJobPostingRepository(const Success(null));
      repo.jobForEdit = const Success(existingNonItJob);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
            routes: [GoRoute(path: 'edit', builder: (context, state) => const PostNewJobScreen(jobId: 68))],
          ),
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
      router.push('/edit');
      await _settle(tester);

      final contactField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Application Contact'));
      expect(contactField.controller!.text, 'hr@example.com');

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.editCallCount, 1);
      expect(repo.submitted?.applicationContact, 'hr@example.com');
    });
  });

  group('PostNewJobScreen — Phase 59: Age Limit validation parity', () {
    testWidgets('Age Limit is not shown for IT', (tester) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _selectDropdown(tester, 'Job Category', 'IT');

      expect(find.text('Age Limit (optional)'), findsNothing);
    });

    testWidgets('Age Limit remains optional for Non-IT × Technical — a valid submission with none still succeeds', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      // Deliberately leaves Age Limit blank.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsNothing);
      expect(repo.submitted?.ageLimit, '');
    });

    testWidgets(
      'Age Limit remains optional for Non-IT × Non-Technical — a valid submission with none still succeeds',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidNonItNonTechnicalJob(tester);
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(repo.submitted?.ageLimit, '');
      },
    );

    testWidgets('a plain integer Age Limit ("25") is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.ageLimit, '25');
    });

    testWidgets('a "plus" Age Limit ("25+") is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25+');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.ageLimit, '25+');
    });

    testWidgets('a range Age Limit ("25-35") is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25-35');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.ageLimit, '25-35');
    });

    testWidgets('a range-plus Age Limit ("25-35+") is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25-35+');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.ageLimit, '25-35+');
    });

    testWidgets('the lower boundary ("1") and upper boundary ("99") are both accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '1-99');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.ageLimit, '1-99');
    });

    testWidgets('an Age Limit of "0" is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '0');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('a 3-digit Age Limit ("100") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '100');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('a decimal Age Limit ("25.5") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25.5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('a non-numeric Age Limit ("abc") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), 'abc');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('an upper age below the lower age ("35-25") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '35-25');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('an incomplete range ("25-") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25-');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('a malformed double "+" ("25++") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25++');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('a zero upper end ("25-0") is rejected with the real server error', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25-0');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);
    });

    testWidgets('whitespace around the hyphen ("25 - 35") is normalized to "25-35" before submission', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '25 - 35');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.ageLimit, '25-35');
    });

    testWidgets('correcting an invalid Age Limit clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), 'abc');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Age Limit (optional)'), '30');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Please enter a valid numeric age limit, e.g. 25 or 25-35.'), findsNothing);
      expect(repo.submitted?.ageLimit, '30');
    });

    testWidgets('Edit mode: an existing Non-IT posting with an Age Limit loads and preserves it unchanged', (
      tester,
    ) async {
      const existingNonItJobWithAgeLimit = JobPostingSubmission(
        jobCategory: 'non_it',
        jobClassification: 'non_technical',
        department: '',
        departmentFunction: 'People Operations',
        designation: '',
        industrySector: 'Staffing',
        title: 'HR Executive',
        jobType: '',
        contractDurationMonths: '',
        employmentType: 'permanent',
        experiencePreset: '3-5',
        experienceYears: '',
        experiencePlus: false,
        experienceYearsMax: '',
        location: 'Pune',
        educationPreset: 'iti',
        educationOther: '',
        functionalSkills: 'Recruitment',
        industryExperience: '',
        workingHours: '9-6',
        salaryFormat: 'monthly',
        salaryMin: '25000',
        salaryMax: '35000',
        openings: 2,
        perks: [],
        description: 'Manage employee relations.',
        requirements: '',
        responsibilities: 'Handle hiring and onboarding.',
        certifications: '',
        softwareSkills: '',
        languageRequirements: '',
        keywords: 'HR, Recruitment',
        applicationContact: 'hr@example.com',
        skills: [],
        mandatorySkills: [],
        deadline: '',
        status: 'active',
        workEnvironment: '',
        interviewMode: '',
        interviewModeOther: '',
        workMode: 'office',
        joiningRequirement: 'immediate',
        noticePeriod: '',
        noticePeriodOther: '',
        genderPreference: 'both',
        ageLimit: '25-35',
      );

      tester.view.physicalSize = const Size(400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeJobPostingRepository(const Success(null));
      repo.jobForEdit = const Success(existingNonItJobWithAgeLimit);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
            routes: [GoRoute(path: 'edit', builder: (context, state) => const PostNewJobScreen(jobId: 68))],
          ),
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
      router.push('/edit');
      await _settle(tester);

      final ageLimitField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Age Limit (optional)'));
      expect(ageLimitField.controller!.text, '25-35');

      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.editCallCount, 1);
      expect(repo.submitted?.ageLimit, '25-35');
    });
  });

  group('PostNewJobScreen — Phase 60: Non-IT required-field validation parity', () {
    // Non-IT × Technical's own required fields (`forms.py`'s `NON_IT_FIELDS`
    // `'technical'` sheet): Industry / Sector, Industry Experience, Job
    // Responsibilities, Working Hours / Shift, Key Skills / Keywords.
    for (final field in [
      'Industry / Sector',
      'Industry Experience',
      'Job Responsibilities',
      'Working Hours / Shift',
      'Key Skills / Keywords',
    ]) {
      testWidgets('$field is required for Non-IT × Technical, with the real "is required" message', (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, field), '');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0, reason: '$field must block submission when blank');
        expect(find.text('$field is required.'), findsOneWidget);
      });
    }

    // Non-IT × Non-Technical's own required fields (`'non_technical'`
    // sheet): Department / Function, Functional Skills, Industry / Sector,
    // Job Responsibilities, Working Hours / Shift, Key Skills / Keywords.
    for (final field in [
      'Department / Function',
      'Functional Skills',
      'Industry / Sector',
      'Job Responsibilities',
      'Working Hours / Shift',
      'Key Skills / Keywords',
    ]) {
      testWidgets('$field is required for Non-IT × Non-Technical, with the real "is required" message', (
        tester,
      ) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItNonTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, field), '');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0, reason: '$field must block submission when blank');
        expect(find.text('$field is required.'), findsOneWidget);
      });
    }

    testWidgets(
      'Industry Experience is optional for Non-IT × Non-Technical, even though it is required for Technical',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItNonTechnicalExceptContact(tester);
        // `_fillNonItNonTechnicalExceptContact` never touches Industry
        // Experience at all — it isn't shown as a labeled requirement for
        // this classification, only NON-IT×Technical's own sheet lists it
        // as required.
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(find.text('Industry Experience is required.'), findsNothing);
        expect(repo.submitted?.industryExperience, '');
      },
    );

    testWidgets('Certifications, Age Limit remain optional for Non-IT × Technical (a valid submission with neither still succeeds)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidNonItTechnicalJob(tester);
      // Deliberately leaves Certifications and Age Limit blank.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.certifications, '');
      expect(repo.submitted?.ageLimit, '');
    });

    testWidgets(
      'Certifications, Software Skills, Language Requirements, Age Limit remain optional for Non-IT × '
      'Non-Technical (a valid submission with none of them still succeeds)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidNonItNonTechnicalJob(tester);
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(repo.submitted?.certifications, '');
        expect(repo.submitted?.softwareSkills, '');
        expect(repo.submitted?.languageRequirements, '');
        expect(repo.submitted?.ageLimit, '');
      },
    );

    testWidgets('a whitespace-only value counts as empty, exactly like the real source\'s own .strip() check', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), '   ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Key Skills / Keywords is required.'), findsOneWidget);
    });

    testWidgets('IT postings are never subjected to any of the Non-IT-only required fields', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      // None of the Non-IT-only fields are even rendered for IT.
      for (final field in [
        'Industry / Sector',
        'Industry Experience',
        'Job Responsibilities',
        'Working Hours / Shift',
        'Key Skills / Keywords',
        'Department / Function',
        'Functional Skills',
      ]) {
        expect(find.widgetWithText(TextFormField, field), findsNothing);
      }
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.textContaining('is required.'), findsNothing);
    });

    testWidgets(
      'switching from Non-IT to IT clears a stale "is required." error from a Non-IT-only field, so it cannot '
      'block an IT submission',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);
        expect(find.text('Industry / Sector is required.'), findsOneWidget);

        await _selectDropdown(tester, 'Job Category', 'IT');
        // The field (and its error) is gone entirely — it has no IT widget.
        expect(find.widgetWithText(TextFormField, 'Industry / Sector'), findsNothing);
        expect(find.text('Industry / Sector is required.'), findsNothing);

        await _fillMinimalValidItJob(tester);
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
      },
    );

    testWidgets('filling in a missing required field clears its error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Department / Function'), '');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Department / Function is required.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Department / Function'), 'Human Resources');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Department / Function is required.'), findsNothing);
      expect(repo.submitted?.departmentFunction, 'Human Resources');
    });
  });

  group('PostNewJobScreen — Phase 61: field-specific text validation parity', () {
    const longMessages = {
      'Industry / Sector':
          'Industry / Sector should contain a valid industry name and should not contain only numbers or special characters.',
      'Industry Experience':
          'Industry Experience should describe the relevant experience and should not contain only numbers or special characters.',
      'Department / Function':
          'Department / Function should contain a valid name and should not contain only numbers or special characters.',
      'Functional Skills':
          'Functional Skills should contain valid skill names and should not contain only numbers or special characters.',
      'Key Skills / Keywords':
          'Key Skills / Keywords should contain valid keywords and should not contain only numbers or special characters.',
    };

    // (label, fill helper, a value already valid under that field's own rules)
    final fieldCases = [
      ('Industry / Sector', _fillNonItTechnicalExceptContact, 'Construction'),
      ('Industry Experience', _fillNonItTechnicalExceptContact, '3 years in civil construction'),
      ('Department / Function', _fillNonItNonTechnicalExceptContact, 'Human Resources'),
      ('Functional Skills', _fillNonItNonTechnicalExceptContact, 'Recruitment, Onboarding'),
      ('Key Skills / Keywords', _fillNonItTechnicalExceptContact, 'Site supervision, Safety'),
    ];

    for (final (label, fill, validValue) in fieldCases) {
      testWidgets('$label accepts a valid value', (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await fill(tester);
        await tester.enterText(find.widgetWithText(TextFormField, label), validValue);
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1, reason: '$label="$validValue" must be accepted');
      });

      testWidgets('$label rejects a disallowed character ("!"), with the real server message', (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await fill(tester);
        await tester.enterText(find.widgetWithText(TextFormField, label), 'Retail!!!');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text(longMessages[label]!), findsOneWidget);
      });

      testWidgets('$label rejects a value with fewer than 2 letters, with the real server message', (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await fill(tester);
        await tester.enterText(find.widgetWithText(TextFormField, label), 'A');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text(longMessages[label]!), findsOneWidget);
      });

      testWidgets('$label leaving the field blank still shows the Phase 60 "is required." message, not this '
          'field\'s own format message', (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await fill(tester);
        await tester.enterText(find.widgetWithText(TextFormField, label), '');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('$label is required.'), findsOneWidget);
        expect(find.text(longMessages[label]!), findsNothing);
      });
    }

    testWidgets('Industry / Sector rejects a standalone 3+ digit run ("no_long_digits" is true for this field)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Sector123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(longMessages['Industry / Sector']!), findsOneWidget);
    });

    testWidgets(
      'Department / Function rejects a standalone 3+ digit run ("no_long_digits" is true for this field)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItNonTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, 'Department / Function'), 'Team123');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text(longMessages['Department / Function']!), findsOneWidget);
      },
    );

    testWidgets(
      'Industry Experience accepts a standalone 3+ digit run ("no_long_digits" is false for this field)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), 'Project2020');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(repo.submitted?.industryExperience, 'Project2020');
      },
    );

    testWidgets(
      'Functional Skills accepts a standalone 3+ digit run ("no_long_digits" is false for this field)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItNonTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, 'Functional Skills'), 'ISO9001 auditing');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(repo.submitted?.functionalSkills, 'ISO9001 auditing');
      },
    );

    testWidgets('Key Skills / Keywords accepts a standalone 3+ digit run ("no_long_digits" is false for this field)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'ISO9001, Safety');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.keywords, 'ISO9001, Safety');
    });

    testWidgets('Industry Experience accepts "+" (its own chars rule includes it, unlike Industry / Sector)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), 'C++ development experience');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('Industry / Sector rejects "+" (its own chars rule does not include it)', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'IT+ Services');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(longMessages['Industry / Sector']!), findsOneWidget);
    });

    testWidgets('Key Skills / Keywords accepts "#" (its own chars rule includes it, unlike Industry / Sector)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Key Skills / Keywords'), 'C#, .NET');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('Industry / Sector rejects "#" (its own chars rule does not include it)', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'IT #Services');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(longMessages['Industry / Sector']!), findsOneWidget);
    });

    testWidgets('repeated internal whitespace in Industry / Sector is collapsed before submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Retail   Trade');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.industrySector, 'Retail Trade');
    });

    testWidgets(
      'Industry Experience\'s format rule still applies for Non-IT × Non-Technical even though the field is '
      'optional there',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItNonTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, 'Industry Experience'), '!!!');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text(longMessages['Industry Experience']!), findsOneWidget);
        // Confirms this is the format error, not a (nonexistent) required
        // error — Industry Experience is optional for Non-Technical.
        expect(find.text('Industry Experience is required.'), findsNothing);
      },
    );

    testWidgets('correcting an invalid Industry / Sector value clears the error and allows submission', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Sector123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text(longMessages['Industry / Sector']!), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Industry / Sector'), 'Construction');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text(longMessages['Industry / Sector']!), findsNothing);
      expect(repo.submitted?.industrySector, 'Construction');
    });

    testWidgets(
      'Department / Function and Functional Skills have no widget at all for Non-IT × Technical, so their '
      'rules never run there',
      (tester) async {
        await _pump(tester, _FakeJobPostingRepository(const Success(null)));

        await _selectDropdown(tester, 'Job Category', 'Non-IT');
        await _selectDropdown(tester, 'Job Classification', 'Technical');

        expect(find.widgetWithText(TextFormField, 'Department / Function'), findsNothing);
        expect(find.widgetWithText(TextFormField, 'Functional Skills'), findsNothing);
      },
    );

    testWidgets('IT postings are unaffected — a valid IT submission never shows any of these 5 fields\' messages', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      for (final message in longMessages.values) {
        expect(find.text(message), findsNothing);
      }
    });
  });

  group('PostNewJobScreen — Phase 63: salary format, range and cross-field validation', () {
    const minMonthly = 'Minimum Salary (₹ per month)';
    const maxMonthly = 'Maximum Salary (₹ per month)';
    const minLpa = 'Minimum Salary (LPA)';
    const maxLpa = 'Maximum Salary (LPA)';

    testWidgets('an empty Minimum Salary is rejected with the real "is required" message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum Salary is required.'), findsOneWidget);
    });

    testWidgets('an empty Maximum Salary is rejected with the real "is required" message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Maximum Salary is required.'), findsOneWidget);
    });

    testWidgets('a whitespace-only Minimum Salary counts as empty, showing the "is required" message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '   ');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum Salary is required.'), findsOneWidget);
      expect(find.text('Enter a valid numeric value for Minimum Salary.'), findsNothing);
    });

    testWidgets('once Salary Format is LPA, an empty Minimum Salary shows "Minimum LPA is required."', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      // Switching format already cleared Minimum/Maximum Salary.
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '10');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum LPA is required.'), findsOneWidget);
    });

    testWidgets('Monthly: the lower boundary (1000) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '1000');
      await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '2000');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.salaryMin, '1000');
    });

    testWidgets('Monthly: the upper boundary (999999) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '999998');
      await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '999999');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.salaryMax, '999999');
    });

    testWidgets('Monthly: below the minimum (999) is rejected with the real floor message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '999');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum Salary must be at least ₹1,000 per month.'), findsOneWidget);
    });

    testWidgets('Monthly: above the maximum (1000000) is rejected with the real ceiling message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '1000000');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Salary must not exceed ₹9,99,999 per month (6 digits).'), findsOneWidget);
    });

    testWidgets('Monthly: a decimal value (1500.50) is rejected with the real "whole number" message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '1500.50');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum Salary must be a whole number (no decimals).'), findsOneWidget);
    });

    testWidgets('Monthly: a non-numeric value is rejected with the real "invalid" message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), 'abc');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter a valid numeric value for Minimum Salary.'), findsOneWidget);
    });

    testWidgets('LPA: the lower boundary (1) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), '1');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.salaryMin, '1');
      expect(repo.submitted?.salaryFormat, 'lpa');
    });

    testWidgets('LPA: the upper boundary (99) is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), '98');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '99');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.salaryMax, '99');
    });

    testWidgets('LPA: below the minimum (0) is rejected with the real floor message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), '0');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '10');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum LPA must be at least 1 LPA.'), findsOneWidget);
    });

    testWidgets('LPA: above the maximum (100) is rejected with the real ceiling message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), '5');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '100');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('LPA must not exceed 99 LPA (2 digits).'), findsOneWidget);
    });

    testWidgets('LPA: a decimal value (5.5) is rejected with the real "whole number" message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), '5.5');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '10');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum LPA must be a whole number (no decimals).'), findsOneWidget);
    });

    testWidgets('LPA: a non-numeric value is rejected with the real "invalid" message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), 'abc');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '10');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Enter a valid numeric value for Minimum LPA.'), findsOneWidget);
    });

    testWidgets('a Minimum Salary greater than Maximum Salary is rejected, attached to Minimum Salary', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '60000');
      await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '50000');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Minimum Salary must not be greater than Maximum Salary.'), findsOneWidget);
    });

    testWidgets('an equal Minimum and Maximum Salary is accepted (strict ">" only)', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '40000');
      await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '40000');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.salaryMin, '40000');
      expect(repo.submitted?.salaryMax, '40000');
    });

    testWidgets(
      'no cross-field error appears when Minimum Salary is individually invalid, even if it is numerically '
      'below Maximum Salary',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidItJob(tester);
        // 999 is below the monthly floor — an individual-field error, not
        // a cross-field one, even though 999 < 50000 numerically.
        await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '999');
        await tester.enterText(find.widgetWithText(TextFormField, maxMonthly), '50000');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Minimum Salary must be at least ₹1,000 per month.'), findsOneWidget);
        expect(find.text('Minimum Salary must not be greater than Maximum Salary.'), findsNothing);
      },
    );

    testWidgets('switching Salary Format from Monthly to LPA clears both Minimum and Maximum Salary', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _fillMinimalValidItJob(tester);
      expect(find.widgetWithText(TextFormField, minMonthly), findsOneWidget);

      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');

      final minField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, minLpa));
      final maxField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, maxLpa));
      expect(minField.controller!.text, '');
      expect(maxField.controller!.text, '');
    });

    testWidgets('switching Salary Format from LPA back to Monthly clears both Minimum and Maximum Salary', (
      tester,
    ) async {
      await _pump(tester, _FakeJobPostingRepository(const Success(null)));

      await _fillMinimalValidItJob(tester);
      await _selectDropdown(tester, 'Salary Format', 'LPA (Lakhs Per Annum)');
      await tester.enterText(find.widgetWithText(TextFormField, minLpa), '5');
      await tester.enterText(find.widgetWithText(TextFormField, maxLpa), '10');

      await _selectDropdown(tester, 'Salary Format', 'Monthly');

      final minField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, minMonthly));
      final maxField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, maxMonthly));
      expect(minField.controller!.text, '');
      expect(maxField.controller!.text, '');
    });

    testWidgets('correcting an invalid Minimum Salary clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '999');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Minimum Salary must be at least ₹1,000 per month.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, minMonthly), '30000');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Minimum Salary must be at least ₹1,000 per month.'), findsNothing);
      expect(repo.submitted?.salaryMin, '30000');
    });
  });

  group('PostNewJobScreen — Phase 64: Openings minimum-value validation', () {
    const openingsLabel = 'Total Openings';

    testWidgets('Openings of "1" is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.openings, 1);
    });

    testWidgets('a typical positive Openings value ("5") is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.openings, 5);
    });

    testWidgets('a larger positive Openings value ("100") is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '100');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.openings, 100);
    });

    testWidgets('an Openings value of "0" is rejected with the real clean_openings() message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '0');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Openings must be 1 or greater.'), findsOneWidget);
    });

    testWidgets(
      'a negative Openings value ("-1") is rejected with Django\'s own uncustomized min_value message, '
      'not the "1 or greater" message',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidItJob(tester);
        await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '-1');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 0);
        expect(find.text('Ensure this value is greater than or equal to 0.'), findsOneWidget);
        expect(find.text('Openings must be 1 or greater.'), findsNothing);
      },
    );

    testWidgets('another negative Openings value ("-5") is also rejected with the same min_value message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '-5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Ensure this value is greater than or equal to 0.'), findsOneWidget);
    });

    testWidgets('non-numeric Openings input retains the existing "valid numeric value" message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), 'abc');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric value.'), findsOneWidget);
    });

    testWidgets('a decimal Openings value ("1.5") is rejected with the existing "valid numeric value" message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '1.5');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric value.'), findsOneWidget);
    });

    testWidgets('malformed Openings input does not crash and is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '--1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric value.'), findsOneWidget);
    });

    testWidgets('an empty Openings field retains the existing required-field message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric value.'), findsOneWidget);
      // The minimum-value message must never appear alongside the
      // required/invalid one for the same empty input.
      expect(find.text('Openings must be 1 or greater.'), findsNothing);
      expect(find.text('Ensure this value is greater than or equal to 0.'), findsNothing);
    });

    testWidgets('a whitespace-only Openings field behaves the same as empty', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '   ');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('Please enter a valid numeric value.'), findsOneWidget);
    });

    testWidgets('correcting "0" to "1" clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '0');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Openings must be 1 or greater.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Openings must be 1 or greater.'), findsNothing);
      expect(repo.submitted?.openings, 1);
    });

    testWidgets('correcting a negative value to "1" clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '-3');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text('Ensure this value is greater than or equal to 0.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, openingsLabel), '1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text('Ensure this value is greater than or equal to 0.'), findsNothing);
      expect(repo.submitted?.openings, 1);
    });
  });

  group('PostNewJobScreen — Phase 65: remaining text-field validation parity', () {
    const titleMessage =
        'Job Title should contain a valid job title and should not contain only numbers or special characters.';
    const locationMessage = 'Location should contain a valid place name (e.g. Hyderabad, Telangana) and should '
        'not contain only numbers or special characters.';
    const certificationsMessage = 'Required Certifications should contain valid certification names and should '
        'not contain only numbers or special characters.';
    const softwareSkillsMessage = 'Software / MS Office Skills should contain valid software names and should '
        'not contain only numbers or special characters.';
    const languageRequirementsMessage = 'Language Requirements should contain language names only.';

    // ── Job Title ──────────────────────────────────────────────────────
    testWidgets('Job Title: a valid ordinary title is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Senior Backend Engineer');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.title, 'Senior Backend Engineer');
    });

    testWidgets('Job Title: valid permitted punctuation is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Job Title'),
        "Sr. Developer, Backend/API (Remote) - Team's Lead #1",
      );
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('Job Title: a disallowed character is rejected with the real message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Developer!!!');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(titleMessage), findsOneWidget);
    });

    testWidgets('Job Title: fewer than 2 letters is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'A1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(titleMessage), findsOneWidget);
    });

    testWidgets('Job Title: numeric-only input is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), '12345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(titleMessage), findsOneWidget);
    });

    testWidgets('Job Title: 3 or more consecutive digits is rejected ("no_long_digits" is true for this field)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Manager123');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(titleMessage), findsOneWidget);
    });

    testWidgets('Job Title: exactly 2 consecutive digits is accepted (the restriction is not too broad)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Level 12 Manager');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.title, 'Level 12 Manager');
    });

    testWidgets('Job Title: an empty field shows the existing required message, not the format message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), '');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text(titleMessage), findsNothing);
    });

    testWidgets('Job Title: correcting an invalid value clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), '12345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text(titleMessage), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'Senior Backend Engineer');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text(titleMessage), findsNothing);
      expect(repo.submitted?.title, 'Senior Backend Engineer');
    });

    // ── Location ───────────────────────────────────────────────────────
    testWidgets('Location: a valid place name is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Hyderabad, Telangana');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.location, 'Hyderabad, Telangana');
    });

    testWidgets('Location: valid permitted punctuation is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), "Pune (Remote) - Hinjewadi's IT Park");
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('Location: a disallowed character is rejected with the real message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Remote!!!');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(locationMessage), findsOneWidget);
    });

    testWidgets('Location: fewer than 2 letters is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'A1');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(locationMessage), findsOneWidget);
    });

    testWidgets('Location: numeric-only input is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), '12345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(locationMessage), findsOneWidget);
    });

    testWidgets(
      'Location: 3 or more consecutive digits is accepted ("no_long_digits" is false for this field, unlike '
      'Job Title)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillMinimalValidItJob(tester);
        await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Sector 123, Pune');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(repo.submitted?.location, 'Sector 123, Pune');
      },
    );

    testWidgets('Location: an empty field shows the existing required message, not the format message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), '');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text(locationMessage), findsNothing);
    });

    testWidgets('Location: correcting an invalid value clears the error and allows submission', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillMinimalValidItJob(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), '12345');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);
      expect(repo.callCount, 0);
      expect(find.text(locationMessage), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Hyderabad');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(find.text(locationMessage), findsNothing);
      expect(repo.submitted?.location, 'Hyderabad');
    });

    // ── Required Certifications (optional, both Non-IT sheets) ─────────
    testWidgets('Required Certifications: a valid certification name is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Required Certifications'),
        'AWS Certified Solutions Architect',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.certifications, 'AWS Certified Solutions Architect');
    });

    testWidgets('Required Certifications: valid permitted punctuation is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Required Certifications'), 'NDT, CSWIP (Level 2)');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('Required Certifications: a disallowed character is rejected with the real message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Required Certifications'), 'Cert!!!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(certificationsMessage), findsOneWidget);
    });

    testWidgets('Required Certifications: fewer than 2 letters is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Required Certifications'), 'A1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(certificationsMessage), findsOneWidget);
    });

    testWidgets('Required Certifications: numeric-only input is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Required Certifications'), '12345');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(certificationsMessage), findsOneWidget);
    });

    testWidgets('Required Certifications: consecutive digits are accepted (no such restriction for this field)', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Required Certifications'), 'ISO9001 Certified');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.certifications, 'ISO9001 Certified');
    });

    testWidgets('Required Certifications: an empty optional field produces no error at all', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      // Deliberately leaves Required Certifications blank.
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.certifications, '');
      expect(find.text(certificationsMessage), findsNothing);
    });

    // ── Software / MS Office Skills (optional, Non-Technical only) ─────
    testWidgets('Software / MS Office Skills: a valid value is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), 'Excel, ERP, CRM');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.softwareSkills, 'Excel, ERP, CRM');
    });

    testWidgets('Software / MS Office Skills: "+" and "#" are both accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), 'C++, C#, Excel');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.softwareSkills, 'C++, C#, Excel');
    });

    testWidgets('Software / MS Office Skills: a disallowed character is rejected with the real message', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), 'Excel!!!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(softwareSkillsMessage), findsOneWidget);
    });

    testWidgets('Software / MS Office Skills: fewer than 2 letters is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), 'A1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(softwareSkillsMessage), findsOneWidget);
    });

    testWidgets('Software / MS Office Skills: numeric-only input is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), '12345');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(softwareSkillsMessage), findsOneWidget);
    });

    testWidgets(
      'Software / MS Office Skills: consecutive digits are accepted (no such restriction for this field)',
      (tester) async {
        final repo = _FakeJobPostingRepository(const Success(null));
        await _pump(tester, repo);

        await _fillNonItNonTechnicalExceptContact(tester);
        await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), 'Office365 Suite');
        await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(repo.callCount, 1);
        expect(repo.submitted?.softwareSkills, 'Office365 Suite');
      },
    );

    testWidgets('Software / MS Office Skills: an empty optional field produces no error at all', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.softwareSkills, '');
      expect(find.text(softwareSkillsMessage), findsNothing);
    });

    // ── Language Requirements (optional, Non-Technical only, no digits) ─
    testWidgets('Language Requirements: a valid language name is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), 'English, Hindi');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.languageRequirements, 'English, Hindi');
    });

    testWidgets('Language Requirements: multiple languages using permitted separators are accepted', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Language Requirements'),
        'English / Hindi / Telugu',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.languageRequirements, 'English / Hindi / Telugu');
    });

    testWidgets('Language Requirements: valid permitted punctuation is accepted', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), 'English (Fluent)');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
    });

    testWidgets('Language Requirements: digits are rejected, unlike every other field in this phase', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), 'English2');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(languageRequirementsMessage), findsOneWidget);
    });

    testWidgets('Language Requirements: other disallowed characters are rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), 'English!!!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(languageRequirementsMessage), findsOneWidget);
    });

    testWidgets('Language Requirements: fewer than 2 letters is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), 'A');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(languageRequirementsMessage), findsOneWidget);
    });

    testWidgets('Language Requirements: numeric-only input is rejected', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), '123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 0);
      expect(find.text(languageRequirementsMessage), findsOneWidget);
    });

    testWidgets('Language Requirements: an empty optional field produces no error at all', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      expect(repo.submitted?.languageRequirements, '');
      expect(find.text(languageRequirementsMessage), findsNothing);
    });

    // ── Regression: a fully valid Non-IT × Non-Technical submission with
    // all 5 optional/required fields present together ───────────────────
    testWidgets('a valid submission with all 5 fields populated together succeeds with no spurious errors', (
      tester,
    ) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);

      await _fillNonItNonTechnicalExceptContact(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Title'), 'HR Executive');
      await tester.enterText(find.widgetWithText(TextFormField, 'Job Location'), 'Pune, Maharashtra');
      await tester.enterText(find.widgetWithText(TextFormField, 'Required Certifications'), 'SHRM-CP');
      await tester.enterText(find.widgetWithText(TextFormField, 'Software / MS Office Skills'), 'Excel, ERP');
      await tester.enterText(find.widgetWithText(TextFormField, 'Language Requirements'), 'English, Hindi');
      await tester.enterText(find.widgetWithText(TextFormField, 'Application Contact'), 'hr@example.com');
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.callCount, 1);
      for (final message in [
        titleMessage,
        locationMessage,
        certificationsMessage,
        softwareSkillsMessage,
        languageRequirementsMessage,
      ]) {
        expect(find.text(message), findsNothing);
      }
    });
  });

  group('PostNewJobScreen — Edit mode', () {
    const existingJob = JobPostingSubmission(
      jobCategory: 'it',
      jobClassification: '',
      department: '',
      departmentFunction: '',
      designation: '',
      industrySector: '',
      title: 'Senior Backend Engineer',
      jobType: 'full_time',
      contractDurationMonths: '',
      employmentType: '',
      experiencePreset: '5-8',
      experienceYears: '',
      experiencePlus: false,
      experienceYearsMax: '',
      location: 'Pune',
      educationPreset: '',
      educationOther: '',
      functionalSkills: '',
      industryExperience: '',
      workingHours: '',
      salaryFormat: 'monthly',
      salaryMin: '40000',
      salaryMax: '60000',
      openings: 3,
      perks: ['laptop'],
      description: 'Own the payments service end to end.',
      requirements: '',
      responsibilities: '',
      certifications: '',
      softwareSkills: '',
      languageRequirements: '',
      keywords: '',
      applicationContact: '',
      skills: ['python', 'django'],
      mandatorySkills: ['python'],
      deadline: '',
      status: 'active',
      workEnvironment: 'wfo',
      interviewMode: 'virtual',
      interviewModeOther: '',
      workMode: '',
      joiningRequirement: '',
      noticePeriod: 'immediate',
      noticePeriodOther: '',
      genderPreference: 'both',
      ageLimit: '',
    );

    Future<_FakeJobPostingRepository> pumpEdit(WidgetTester tester, {Result<JobPostingSubmission>? jobForEdit}) async {
      tester.view.physicalSize = const Size(400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeJobPostingRepository(const Success(null));
      repo.jobForEdit = jobForEdit ?? const Success(existingJob);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
            routes: [
              GoRoute(path: 'edit', builder: (context, state) => const PostNewJobScreen(jobId: 68)),
            ],
          ),
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
      router.push('/edit');
      await _settle(tester);
      return repo;
    }

    testWidgets('fetches and displays the existing job\'s values, not a blank form', (tester) async {
      await pumpEdit(tester);

      expect(find.text('Edit Job'), findsOneWidget);
      expect(find.text('Senior Backend Engineer'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('Own the payments service end to end.'), findsOneWidget);
    });

    testWidgets('submitting an unrelated edit calls submitEdit with the same job id, preserving untouched fields', (
      tester,
    ) async {
      final repo = await pumpEdit(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Bengaluru');
      await tester.pump();
      await tester.tap(find.text('Save Job Posting'));
      await _settle(tester);

      expect(repo.editCallCount, 1);
      expect(repo.editedJobId, 68);
      expect(repo.submitted?.location, 'Bengaluru');
      // Untouched fields survive the edit unchanged.
      expect(repo.submitted?.title, 'Senior Backend Engineer');
      expect(repo.submitted?.skills, containsAll(['python', 'django']));
      expect(repo.submitted?.mandatorySkills, ['python']);
      expect(find.text('Job updated successfully!'), findsOneWidget);
      // Edit was reached by a push — a successful save pops back, not a
      // `go` to Job Openings.
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('shows a retry-able error view when the existing job fails to load, instead of a blank/broken form', (
      tester,
    ) async {
      final repo = await pumpEdit(tester, jobForEdit: const Failed(NotFoundFailure()));

      expect(find.text('Senior Backend Engineer'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(repo.editCallCount, 0);
    });

    testWidgets(
      'REGRESSION (Phase 11): a job whose real opening count couldn\'t be scraped (openings: null) shows the '
      'Openings field blank, not a guessed "1" — and Save is blocked by the existing field validator until a '
      'real number is entered',
      (tester) async {
        const jobWithUnknownOpenings = JobPostingSubmission(
          jobCategory: 'it',
          jobClassification: '',
          department: '',
          departmentFunction: '',
          designation: '',
          industrySector: '',
          title: 'Senior Backend Engineer',
          jobType: 'full_time',
          contractDurationMonths: '',
          employmentType: '',
          experiencePreset: '5-8',
          experienceYears: '',
          experiencePlus: false,
          experienceYearsMax: '',
          location: 'Pune',
          educationPreset: '',
          educationOther: '',
          functionalSkills: '',
          industryExperience: '',
          workingHours: '',
          salaryFormat: 'monthly',
          salaryMin: '40000',
          salaryMax: '60000',
          openings: null,
          perks: ['laptop'],
          description: 'Own the payments service end to end.',
          requirements: '',
          responsibilities: '',
          certifications: '',
          softwareSkills: '',
          languageRequirements: '',
          keywords: '',
          applicationContact: '',
          skills: ['python', 'django'],
          mandatorySkills: ['python'],
          deadline: '',
          status: 'active',
          workEnvironment: 'wfo',
          interviewMode: 'virtual',
          interviewModeOther: '',
          workMode: '',
          joiningRequirement: '',
          noticePeriod: 'immediate',
          noticePeriodOther: '',
          genderPreference: 'both',
          ageLimit: '',
        );
        final repo = await pumpEdit(tester, jobForEdit: const Success(jobWithUnknownOpenings));

        final openingsField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Total Openings'));
        expect(openingsField.controller!.text, isEmpty);

        await tester.tap(find.text('Save Job Posting'));
        await _settle(tester);

        expect(find.text('Please enter a valid numeric value.'), findsOneWidget);
        expect(repo.editCallCount, 0);
      },
    );
  });

  group('PostNewJobScreen — Phase 66: custom IT skill letter-presence validation', () {
    Future<void> addSkill(WidgetTester tester, String value) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Add a skill'), value);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await _settle(tester);
    }

    testWidgets('numeric-only input is rejected locally, matching Django\'s letter-presence rule', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);
      await _selectDropdown(tester, 'Job Category', 'IT');

      await addSkill(tester, '12345');

      expect(
        find.text('"12345" is not a valid skill name. Use letters, numbers and . & / ( ) \' + # - only, one skill at a time.'),
        findsOneWidget,
      );
    });

    testWidgets('whitespace-only input is silently ignored (no chip, no error)', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);
      await _selectDropdown(tester, 'Job Category', 'IT');

      await addSkill(tester, '   ');

      expect(
        find.text('"" is not a valid skill name. Use letters, numbers and . & / ( ) \' + # - only, one skill at a time.'),
        findsNothing,
      );
    });

    testWidgets('alphabetic-only input is accepted and added as a chip', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);
      await _selectDropdown(tester, 'Job Category', 'IT');

      await addSkill(tester, 'Python');

      expect(find.text('Python'), findsOneWidget);
    });

    testWidgets('mixed alphanumeric input is accepted and added as a chip', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);
      await _selectDropdown(tester, 'Job Category', 'IT');

      await addSkill(tester, 'Python3');

      expect(find.text('Python3'), findsOneWidget);
    });

    testWidgets('a value over 40 characters is rejected with the truncated-preview message', (tester) async {
      final repo = _FakeJobPostingRepository(const Success(null));
      await _pump(tester, repo);
      await _selectDropdown(tester, 'Job Category', 'IT');

      final tooLong = 'A' * 45;
      await addSkill(tester, tooLong);

      expect(
        find.text('"${tooLong.substring(0, 20)}..." is too long; keep each skill under 40 characters.'),
        findsOneWidget,
      );
    });
  });
}
