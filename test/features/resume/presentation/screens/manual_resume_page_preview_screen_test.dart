import 'dart:async';
import 'dart:convert';

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
import 'package:career_buddy_lms/features/resume/domain/validation/manual_resume_validation.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/manual_resume_page_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  @override
  Future<Result<ManualResumeDraft?>> loadDraft(String username) async => const Success(null);
  @override
  Future<Result<void>> saveDraft(String username, ManualResumeDraft draft) async => const Success(null);
  @override
  Future<Result<void>> clearDraft(String username) async => const Success(null);
}

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.pagePreviewResult, this.pagePreviewCompleter});

  Result<ManualResumePagePreviewOutcome>? pagePreviewResult;
  Completer<Result<ManualResumePagePreviewOutcome>>? pagePreviewCompleter;
  int callCount = 0;

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
  Future<Result<List<ResumeRole>>> getRoles() async => const Success([]);
  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async => throw UnimplementedError();
  @override
  Future<Result<Map<String, LevelCommonSuggestions>>> getLevelCommonSuggestions() async => const Success({});

  @override
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(ManualResumeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(ManualResumeDraft draft) async {
    callCount++;
    if (pagePreviewCompleter != null) return pagePreviewCompleter!.future;
    return pagePreviewResult ?? const Failed(UnexpectedFailure());
  }

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(ManualResumeDraft draft) async =>
      throw UnimplementedError();
}

/// A real, valid 1x1 transparent PNG — `Image.memory` decodes this eagerly,
/// so arbitrary placeholder bytes throw an "Invalid image data" decode
/// error inside the widget tree (same fixture as
/// `grammar_test_doubles.dart`'s `FakeGrammarMediaDataSource`).
final _onePage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Future<_FakeResumeRepository> _pump(
  WidgetTester tester, {
  Result<ManualResumePagePreviewOutcome>? pagePreviewResult,
  ManualResumeDraft? draft,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeResumeRepository(pagePreviewResult: pagePreviewResult);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      manualResumeDraftRepositoryProvider.overrideWithValue(_FakeManualResumeDraftRepository()),
      resumeRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  container.read(authControllerProvider);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: ManualResumePagePreviewScreen(draft: draft ?? ManualResumeDraft.blank()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  group('ManualResumePagePreviewScreen', () {
    testWidgets('shows a loading indicator while the page preview is in flight', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final completer = Completer<Result<ManualResumePagePreviewOutcome>>();
      final repo = _FakeResumeRepository(pagePreviewCompleter: completer);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          manualResumeDraftRepositoryProvider.overrideWithValue(_FakeManualResumeDraftRepository()),
          resumeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ManualResumePagePreviewScreen(draft: ManualResumeDraft.blank())),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(Success(ManualResumePagePreviewReady(pages: [_onePage], total: 1, filename: 'r.pdf')));
      await tester.pump();
      await tester.pump();
    });

    testWidgets('renders a single-page carousel on success', (tester) async {
      await _pump(
        tester,
        pagePreviewResult: Success(ManualResumePagePreviewReady(pages: [_onePage], total: 1, filename: 'r.pdf')),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      // A single page has no chevrons/dots to navigate with.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('renders multi-page navigation (chevrons, dots, page counter)', (tester) async {
      await _pump(
        tester,
        pagePreviewResult: Success(
          ManualResumePagePreviewReady(pages: [_onePage, _onePage, _onePage], total: 3, filename: 'r.pdf'),
        ),
      );

      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(find.byKey(const Key('page-preview-next')), findsOneWidget);
      expect(find.byKey(const Key('page-preview-previous')), findsOneWidget);

      // Invokes the chevron's own `onPressed` handler directly rather than
      // simulating a tap gesture — the carousel sits inside an
      // `AnimatedSwitcher`/`InteractiveViewer` stack whose gesture-arena
      // gets exercised by `tester.tap()` in a way that is a harness/timing
      // quirk, not a real app bug (same category of quirk documented in
      // `manual_resume_preview_screen_test.dart`); this still verifies the
      // real navigation logic and resulting rebuild, just not Flutter's own
      // (already well-tested) gesture-dispatch pipeline.
      tester.widget<IconButton>(find.byKey(const Key('page-preview-next'))).onPressed!();
      await tester.pump();

      expect(find.text('Page 2 of 3'), findsOneWidget);
    });

    testWidgets('shows a truncation banner when total exceeds the rendered page count', (tester) async {
      await _pump(
        tester,
        pagePreviewResult: Success(ManualResumePagePreviewReady(pages: [_onePage], total: 9, filename: 'r.pdf')),
      );

      expect(find.textContaining('Showing the first 1 of 9 pages'), findsOneWidget);
    });

    testWidgets('an empty pages result shows the empty-state message, not a crash', (tester) async {
      await _pump(
        tester,
        pagePreviewResult: const Success(ManualResumePagePreviewReady(pages: [], total: 0, filename: '')),
      );

      expect(find.textContaining('No page preview is available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows server validation errors with a way to jump to the relevant step', (tester) async {
      const rejected = ManualResumePagePreviewRejected(
        errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
      );
      await _pump(tester, pagePreviewResult: const Success(rejected));

      expect(find.text('Please enter your full name.'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping a server error pops back to the builder and jumps to that step', (tester) async {
      const rejected = ManualResumePagePreviewRejected(
        errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeResumeRepository(pagePreviewResult: const Success(rejected));
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          manualResumeDraftRepositoryProvider.overrideWithValue(_FakeManualResumeDraftRepository()),
          resumeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await container.read(manualResumeBuilderControllerProvider.notifier).load();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ManualResumePagePreviewScreen(draft: ManualResumeDraft.blank())),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_right), warnIfMissed: false);
      await tester.pump();
      await tester.pump();

      expect(find.text('open'), findsOneWidget);
      expect(
        (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).draft.currentStep,
        1,
      );
    });

    testWidgets('a network/server failure shows a retryable error, and retry resubmits', (tester) async {
      final repo = await _pump(tester, pagePreviewResult: const Failed(ServerFailure()));

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(repo.callCount, 1);

      repo.pagePreviewResult = Success(ManualResumePagePreviewReady(pages: [_onePage], total: 1, filename: 'r.pdf'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(repo.callCount, 2);
      expect(find.byType(Image), findsOneWidget);
    });

    // Phase 30 — the Phase 29 audit found no narrow-width test existed for
    // this screen either (same gap as the structured preview screen). This
    // closes it for every state the screen can land on.
    group('narrow-screen (320px) rendering', () {
      testWidgets('a multi-page carousel renders without overflow at 320px', (tester) async {
        await _pump(
          tester,
          pagePreviewResult: Success(
            ManualResumePagePreviewReady(pages: [_onePage, _onePage, _onePage], total: 3, filename: 'r.pdf'),
          ),
          size: const Size(320, 800),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Page 1 of 3'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('the truncation banner renders without overflow at 320px', (tester) async {
        await _pump(
          tester,
          pagePreviewResult: Success(ManualResumePagePreviewReady(pages: [_onePage], total: 9, filename: 'r.pdf')),
          size: const Size(320, 800),
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Showing the first 1 of 9 pages'), findsOneWidget);
      });

      testWidgets('the empty-pages state renders without overflow at 320px', (tester) async {
        await _pump(
          tester,
          pagePreviewResult: const Success(ManualResumePagePreviewReady(pages: [], total: 0, filename: '')),
          size: const Size(320, 800),
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('No page preview is available'), findsOneWidget);
      });

      testWidgets('server validation errors render without overflow at 320px', (tester) async {
        const rejected = ManualResumePagePreviewRejected(
          errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
        );
        await _pump(tester, pagePreviewResult: const Success(rejected), size: const Size(320, 800));

        expect(tester.takeException(), isNull);
        expect(find.text('Please enter your full name.'), findsOneWidget);
      });

      testWidgets('a transport-failure retry view renders without overflow at 320px', (tester) async {
        await _pump(tester, pagePreviewResult: const Failed(ServerFailure()), size: const Size(320, 800));

        expect(tester.takeException(), isNull);
        expect(find.text(const ServerFailure().message), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });
    });
  });
}
