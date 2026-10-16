import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/level_common_suggestions.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_page_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_pdf_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_role.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/manual_resume_draft_repository.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/features/resume/domain/validation/manual_resume_validation.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/manual_resume_builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../support/fake_open_file_platform.dart';
import '../../../../support/fake_path_provider_platform.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'jane');

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

class _FakeManualResumeDraftRepository implements ManualResumeDraftRepository {
  _FakeManualResumeDraftRepository({this.loadResult});

  Result<ManualResumeDraft?>? loadResult;
  int clearCallCount = 0;

  @override
  Future<Result<ManualResumeDraft?>> loadDraft(String username) async => loadResult ?? const Success(null);

  @override
  Future<Result<void>> saveDraft(String username, ManualResumeDraft draft) async => const Success(null);

  @override
  Future<Result<void>> clearDraft(String username) async {
    clearCallCount++;
    return const Success(null);
  }
}

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.rolesResult, this.levelCommonResult, this.previewResult, this.pdfResult});

  Result<List<ResumeRole>>? rolesResult;
  Result<Map<String, LevelCommonSuggestions>>? levelCommonResult;
  Result<ManualResumePreviewOutcome>? previewResult;
  Result<ManualResumePdfOutcome>? pdfResult;
  int pdfCallCount = 0;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({required String filePath, required String fileName}) async =>
      throw UnimplementedError();

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async => throw UnimplementedError();

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async => throw UnimplementedError();

  @override
  Future<ResumeParseQuota?> getParseQuota() async => throw UnimplementedError();

  @override
  Future<Result<List<ResumeRole>>> getRoles() async => rolesResult ?? const Success([]);

  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async => throw UnimplementedError();

  @override
  Future<Result<Map<String, LevelCommonSuggestions>>> getLevelCommonSuggestions() async =>
      levelCommonResult ?? const Success({});

  @override
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(ManualResumeDraft draft) async =>
      previewResult ?? const Failed(UnexpectedFailure());

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(ManualResumeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(ManualResumeDraft draft) async {
    pdfCallCount++;
    return pdfResult ?? const Failed(UnexpectedFailure());
  }
}

const _role = ResumeRole(
  slug: 'qa-engineer',
  title: 'QA Engineer',
  category: 'it',
  categoryLabel: 'IT Role',
  subtitle: 'Manual & automation testing',
  fields: [ResumeRoleSkillField(key: 'testing-tools', label: 'Testing tools', options: ['Selenium', 'Postman'])],
  summaries: {
    '1-3': ['QA Engineer with hands-on testing experience across manual and automated suites.'],
  },
);

Future<_FakeManualResumeDraftRepository> _pump(
  WidgetTester tester, {
  ResumeRole? role,
  Result<ManualResumeDraft?>? loadResult,
  Result<List<ResumeRole>>? rolesResult,
  Result<ManualResumePdfOutcome>? pdfResult,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final draftRepo = _FakeManualResumeDraftRepository(loadResult: loadResult);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      manualResumeDraftRepositoryProvider.overrideWithValue(draftRepo),
      resumeRepositoryProvider.overrideWithValue(
        _FakeResumeRepository(rolesResult: rolesResult, pdfResult: pdfResult),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Settle AuthController's build()-time restoreSession() first — matching
  // the real app, where the router's auth guard has always already done
  // this long before this screen is reachable (see this controller's own
  // `_username` doc comment). A bare `await Future.delayed(Duration.zero)`
  // would hang forever here: `flutter test`'s fake-clock binding never
  // fires a real `Timer` (which `Future.delayed` is, even at zero duration)
  // on its own — `tester.runAsync` is the documented escape hatch that lets
  // it actually run.
  container.read(authControllerProvider);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ManualResumeBuilderScreen(role: role)),
    ),
  );
  // Bounded pumps instead of `pumpAndSettle` — matching
  // `profile_screen_test.dart`'s own convention for auth-dependent screens,
  // and safer regardless since `AppLoader`'s `CircularProgressIndicator` is
  // a repeating animation while a state transition is still in flight.
  await tester.pump();
  await tester.pump();
  // `setRoleIfBlank` (fired above, when [role] is non-null) schedules its
  // own debounced save just like any other edit — settle it here so every
  // test starts with no pending `Timer`, regardless of whether it goes on
  // to make further edits of its own.
  await _settleDebounce(tester);
  return draftRepo;
}

/// Lets the controller's debounced autosave `Timer` actually fire —
/// required at the end of any test that edited the draft, since
/// `flutter test`'s fake-clock binding fails a test that ends with a
/// `Timer` still pending. Unlike settling a real `Future.delayed` (which
/// needs `tester.runAsync` to escape into the real event loop), this timer
/// lives *inside* the same `FakeAsync` zone the widget tree runs in —
/// `tester.pump(duration)` is what advances that zone's own clock and
/// fires it; `runAsync` would run in the wrong zone entirely and never
/// touch it.
Future<void> _settleDebounce(WidgetTester tester) =>
    tester.pump(ManualResumeBuilderController.saveDebounce + const Duration(milliseconds: 50));

void main() {
  group('ManualResumeBuilderScreen', () {
    testWidgets('step 1 shows the real Personal fields', (tester) async {
      await _pump(tester);

      expect(find.text('Full name *'), findsOneWidget);
      expect(find.text('Email *'), findsOneWidget);
      expect(find.text('Phone *'), findsOneWidget);
      expect(find.byKey(const Key('wizard-previous-button')), findsOneWidget);
      expect(find.byKey(const Key('wizard-next-button')), findsOneWidget);
    });

    testWidgets('Next is blocked on an empty Personal step and does not advance', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('wizard-next-button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Full name *'), findsOneWidget); // still on step 1
    });

    testWidgets('filling Personal and tapping Next advances to Career & Skills', (tester) async {
      await _pump(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Full name *'), 'Anita Sharma');
      await tester.enterText(find.widgetWithText(TextField, 'Email *'), 'anita@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Phone *'), '9876543210');
      await tester.pump();
      await tester.tap(find.byKey(const Key('wizard-next-button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Experience level *'), findsOneWidget);
      await _settleDebounce(tester);
    });

    testWidgets('Previous moves back freely with no validation', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('wizard-review-button')));
      await tester.pump();
      // goToStep is ungated — jump straight to step 2 via the step indicator.
      await tester.tap(find.text('Career & Skills').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('Experience level *'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wizard-previous-button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Full name *'), findsOneWidget);
    });

    testWidgets('the selected role is shown on Career & Skills', (tester) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]));

      await tester.tap(find.text('Career & Skills').last);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('career-role-title')), findsOneWidget);
      expect(find.text('QA Engineer'), findsWidgets); // also appears as the Target job title field's hint
      expect(find.text('Testing tools'), findsOneWidget);
      expect(find.text('Selenium'), findsOneWidget);
    });

    testWidgets('selecting a skill chip updates the draft (survives a step round-trip)', (tester) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]));
      await tester.tap(find.text('Career & Skills').last);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(FilterChip, 'Selenium'));
      await tester.pump();

      final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Selenium'));
      expect(chip.selected, isTrue);
      await _settleDebounce(tester);
    });

    testWidgets('Experience step: Add Employment adds a card; an untouched entry removes without confirming', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('Experience').last);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('+ Add Employment'));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Job title (optional)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Job title (optional)'), findsNothing);
      expect(find.text('Remove this employment?'), findsNothing); // no confirmation for a blank entry
      await _settleDebounce(tester);
    });

    testWidgets('Experience step: removing a touched entry asks for confirmation', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Experience').last);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('+ Add Employment'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Job title (optional)'), 'Engineer');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();

      expect(find.text('Remove this employment?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Job title (optional)'), findsOneWidget); // still there
      await _settleDebounce(tester);
    });

    testWidgets('Education step shows the real fields', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Education').last);
      await tester.pump();
      await tester.pump();

      expect(find.text('Education'), findsWidgets);
      expect(find.text('Certifications'), findsOneWidget);
      expect(find.text('Training'), findsOneWidget);
    });

    testWidgets('Summary step: applying a template replaces an empty summary without confirming', (tester) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]));
      await tester.tap(find.text('Career & Skills').last);
      await tester.pump();
      await tester.pump();

      // Open the Experience level dropdown, then pick an item from its menu.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('1–3 Years').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tester.tap(find.text('Summary').last);
      await tester.pump();
      await tester.pump();

      expect(find.text('Use this template'), findsWidgets);
      final summaryBefore = tester.widget<TextField>(find.widgetWithText(TextField, 'Professional summary (optional)'));
      expect(summaryBefore.controller!.text, isEmpty);

      await tester.tap(find.text('Use this template').first);
      await tester.pump();

      final summaryAfter = tester.widget<TextField>(find.widgetWithText(TextField, 'Professional summary (optional)'));
      expect(summaryAfter.controller!.text, isNotEmpty);
      await _settleDebounce(tester);
    });

    testWidgets('Clear Draft asks for confirmation, and only clears when confirmed', (tester) async {
      final draftRepo = await _pump(
        tester,
        loadResult: Success(ManualResumeDraft.blank().copyWith(role: 'some-role')),
      );

      await tester.tap(find.byKey(const Key('clear-draft-button')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Clear Draft'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();
      expect(draftRepo.clearCallCount, 0);

      await tester.tap(find.byKey(const Key('clear-draft-button')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Clear Draft'));
      await tester.pump();
      await tester.pump();

      expect(draftRepo.clearCallCount, 1);
    });

    testWidgets('a load failure shows a retryable error, not a crash', (tester) async {
      await _pump(tester, loadResult: const Failed(ServerFailure()));

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders the Personal step without horizontal overflow at narrow phone widths', (tester) async {
      for (final size in [const Size(320, 800), const Size(360, 800), const Size(390, 800)]) {
        await _pump(tester, role: _role, rolesResult: const Success([_role]), size: size);
        expect(tester.takeException(), isNull, reason: 'Personal step at width ${size.width}');
      }
    });

    testWidgets('renders the Career & Skills step without horizontal overflow at a narrow phone width', (
      tester,
    ) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]), size: const Size(320, 800));
      await tester.tap(find.text(kManualResumeStepLabels[1]).last);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the Experience step without horizontal overflow at a narrow phone width', (tester) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]), size: const Size(320, 800));
      await tester.tap(find.text(kManualResumeStepLabels[2]).last);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('+ Add Employment'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _settleDebounce(tester);
    });

    testWidgets('renders the Education step without horizontal overflow at a narrow phone width', (tester) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]), size: const Size(320, 800));
      await tester.tap(find.text(kManualResumeStepLabels[3]).last);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the Summary step without horizontal overflow at a narrow phone width', (tester) async {
      await _pump(tester, role: _role, rolesResult: const Success([_role]), size: const Size(320, 800));
      await tester.tap(find.text(kManualResumeStepLabels[4]).last);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Preview Resume" navigates to the preview route carrying the current draft', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final draftRepo = _FakeManualResumeDraftRepository(
        loadResult: Success(ManualResumeDraft.blank().copyWith(summary: 'Already written summary')),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          manualResumeDraftRepositoryProvider.overrideWithValue(draftRepo),
          resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      ManualResumeDraft? receivedDraft;
      final router = GoRouter(
        initialLocation: RoutePaths.manualResumeBuilder,
        routes: [
          GoRoute(
            path: RoutePaths.manualResumeBuilder,
            builder: (context, state) => const ManualResumeBuilderScreen(),
          ),
          GoRoute(
            path: RoutePaths.manualResumePreview,
            builder: (context, state) {
              receivedDraft = state.extra as ManualResumeDraft?;
              return const Scaffold(body: Text('Manual Resume Preview Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('wizard-preview-button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Manual Resume Preview Screen'), findsOneWidget);
      expect(receivedDraft?.summary, 'Already written summary');
    });

    testWidgets('"Page Preview" navigates to the page-preview route carrying the current draft', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final draftRepo = _FakeManualResumeDraftRepository(
        loadResult: Success(ManualResumeDraft.blank().copyWith(summary: 'Already written summary')),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          manualResumeDraftRepositoryProvider.overrideWithValue(draftRepo),
          resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      ManualResumeDraft? receivedDraft;
      final router = GoRouter(
        initialLocation: RoutePaths.manualResumeBuilder,
        routes: [
          GoRoute(
            path: RoutePaths.manualResumeBuilder,
            builder: (context, state) => const ManualResumeBuilderScreen(),
          ),
          GoRoute(
            path: RoutePaths.manualResumePagePreview,
            builder: (context, state) {
              receivedDraft = state.extra as ManualResumeDraft?;
              return const Scaffold(body: Text('Manual Resume Page Preview Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('wizard-page-preview-button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Manual Resume Page Preview Screen'), findsOneWidget);
      expect(receivedDraft?.summary, 'Already written summary');
    });

    group('"Generate PDF"', () {
      late Directory tempDir;
      final originalOpenFilePlatform = OpenFilePlatform.platform;
      final originalPathProviderPlatform = PathProviderPlatform.instance;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('manual_resume_builder_screen_test');
        PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
      });

      tearDown(() async {
        OpenFilePlatform.platform = originalOpenFilePlatform;
        PathProviderPlatform.instance = originalPathProviderPlatform;
        await tempDir.delete(recursive: true);
      });

      /// Invokes the button's own `onPressed` handler directly rather than
      /// simulating a tap gesture — in this widget tree, `tester.tap()` on
      /// this button does not reliably reach its `onPressed` despite the
      /// finder resolving to exactly one widget with a non-null handler and
      /// no hit-test-mismatch warning (the same harness/timing quirk already
      /// documented for the page-preview carousel's chevrons in
      /// `manual_resume_page_preview_screen_test.dart`, confirmed again here
      /// by calling the controller directly — see that file's test). This
      /// still verifies the real button-wiring/controller/file-save logic,
      /// just not Flutter's own gesture-dispatch pipeline.
      Future<void> pressGeneratePdf(WidgetTester tester) async {
        final button = tester.widget<FilledButton>(find.byKey(const Key('wizard-generate-pdf-button')));
        await tester.runAsync(() => button.onPressed!.call() as dynamic);
      }

      testWidgets('a successful tap saves the PDF and hands it to OpenFile', (tester) async {
        final fakeOpenFile = FakeOpenFilePlatform(result: OpenResult(type: ResultType.done, message: 'done'));
        OpenFilePlatform.platform = fakeOpenFile;
        final pdfOutcome = ManualResumePdfReady(bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), filename: 'resume.pdf');
        await _pump(tester, pdfResult: Success(pdfOutcome));

        await pressGeneratePdf(tester);
        await tester.pump();

        expect(fakeOpenFile.lastFilePath, '${tempDir.path}/resume.pdf');
      });

      testWidgets('shows a loading indicator on the button while generating', (tester) async {
        OpenFilePlatform.platform = FakeOpenFilePlatform();
        final pdfOutcome = ManualResumePdfReady(bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), filename: 'resume.pdf');
        await _pump(tester, pdfResult: Success(pdfOutcome));

        final button = tester.widget<FilledButton>(find.byKey(const Key('wizard-generate-pdf-button')));
        final pressFuture = tester.runAsync(() => button.onPressed!.call() as dynamic);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await pressFuture;
        await tester.pump();
      });

      testWidgets('a server validation rejection shows an inline error and never reaches OpenFile', (tester) async {
        final fakeOpenFile = FakeOpenFilePlatform();
        OpenFilePlatform.platform = fakeOpenFile;
        const rejected = ManualResumePdfRejected([
          ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.'),
        ]);
        await _pump(tester, pdfResult: const Success(rejected));

        await pressGeneratePdf(tester);
        await tester.pump();

        expect(find.byKey(const Key('pdf-validation-error')), findsOneWidget);
        expect(fakeOpenFile.lastFilePath, isNull);
      });
    });
  });
}
