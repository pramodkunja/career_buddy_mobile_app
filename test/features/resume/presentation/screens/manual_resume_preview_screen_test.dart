import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/level_common_suggestions.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_completeness.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_document.dart';
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
import 'package:career_buddy_lms/features/resume/presentation/screens/manual_resume_preview_screen.dart';
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
  _FakeResumeRepository({this.previewResult, this.previewCompleter});

  Result<ManualResumePreviewOutcome>? previewResult;

  /// When set, [previewManualResume] awaits this instead of returning
  /// immediately — lets a test deterministically hold the request "in
  /// flight" (observing the loading state) rather than racing a
  /// zero-delay `Future`'s own microtask timing.
  Completer<Result<ManualResumePreviewOutcome>>? previewCompleter;
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
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(ManualResumeDraft draft) async {
    callCount++;
    if (previewCompleter != null) return previewCompleter!.future;
    return previewResult ?? const Failed(UnexpectedFailure());
  }

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(ManualResumeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(ManualResumeDraft draft) async =>
      throw UnimplementedError();
}

const _readyOutcome = ManualResumePreviewReady(
  document: ManualResumeDocument(
    name: 'Anita Sharma',
    title: 'QA Engineer',
    contact: [ManualResumeContact(text: '9876543210', href: 'tel:9876543210')],
    level: '1-3',
    levelLabel: '1–3 Years',
    role: 'QA Engineer',
    sections: [
      ManualResumeDocumentSection(
        key: 'summary',
        heading: 'Professional Summary',
        body: ManualResumeTextBody('A dependable QA engineer.'),
      ),
    ],
  ),
  warnings: ['Add a short professional summary'],
  completeness: ManualResumeCompletenessSummary(overall: 80, categories: []),
  filename: 'Anita_Resume.pdf',
);

Future<_FakeResumeRepository> _pump(
  WidgetTester tester, {
  Result<ManualResumePreviewOutcome>? previewResult,
  ManualResumeDraft? draft,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = _FakeResumeRepository(previewResult: previewResult);
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
        home: ManualResumePreviewScreen(draft: draft ?? ManualResumeDraft.blank()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  group('ManualResumePreviewScreen', () {
    testWidgets('shows a loading indicator while the preview is in flight', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final completer = Completer<Result<ManualResumePreviewOutcome>>();
      final repo = _FakeResumeRepository(previewCompleter: completer);
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
          child: MaterialApp(home: ManualResumePreviewScreen(draft: ManualResumeDraft.blank())),
        ),
      );
      await tester.pump(); // first frame: postFrameCallback fires generate(), which stays pending
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const Success(_readyOutcome));
      await tester.pump();
      await tester.pump();
    });

    testWidgets('renders the real server document on success', (tester) async {
      await _pump(tester, previewResult: const Success(_readyOutcome));

      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(find.text('QA Engineer'), findsWidgets);
      expect(find.text('A dependable QA engineer.'), findsOneWidget);
      expect(find.textContaining('Overall completeness: 80%'), findsOneWidget);
      expect(find.text('Add a short professional summary'), findsOneWidget);
    });

    testWidgets('shows server validation errors with a way to jump to the relevant step', (tester) async {
      const rejected = ManualResumePreviewRejected(
        errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
      );
      await _pump(tester, previewResult: const Success(rejected));

      expect(find.text('Please enter your full name.'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping a server error pops back to the builder (which now shows the right step)', (tester) async {
      const rejected = ManualResumePreviewRejected(
        errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeResumeRepository(previewResult: const Success(rejected));
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
                  MaterialPageRoute(builder: (_) => ManualResumePreviewScreen(draft: ManualResumeDraft.blank())),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // A real duration, not a bare `pump()` — otherwise the pushed route's
      // own slide-in transition is still mid-animation (its content
      // partially off-screen to the right) when the tap below fires,
      // producing a hit-test miss at the not-yet-settled position.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // `warnIfMissed: false` — the tap's own hit-test offset calculation is
      // thrown off by the just-pushed route's transition geometry even
      // after settling (a harness/viewport quirk, not a real layout bug:
      // the assertions below independently confirm the tap's handler did
      // fire and behaved correctly).
      await tester.tap(find.byIcon(Icons.chevron_right), warnIfMissed: false);
      await tester.pump();
      await tester.pump();

      expect(find.text('open'), findsOneWidget); // back on the original screen
      expect(
        (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).draft.currentStep,
        1,
      );
    });

    testWidgets('a network/server failure shows a retryable error, and retry resubmits', (tester) async {
      final repo = await _pump(tester, previewResult: const Failed(ServerFailure()));

      expect(find.text(const ServerFailure().message), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(repo.callCount, 1);

      repo.previewResult = const Success(_readyOutcome);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(repo.callCount, 2);
      expect(find.text('Anita Sharma'), findsOneWidget);
    });

    testWidgets('an empty document (zero sections) renders without crashing', (tester) async {
      const empty = ManualResumePreviewReady(
        document: ManualResumeDocument(
          name: 'Anita Sharma',
          title: '',
          contact: [],
          level: '',
          levelLabel: '',
          role: '',
          sections: [],
        ),
        warnings: [],
        completeness: ManualResumeCompletenessSummary(overall: 0, categories: []),
        filename: '',
      );
      await _pump(tester, previewResult: const Success(empty));

      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Phase 30 — the Phase 29 audit found no narrow-width test existed for
    // this screen, unlike every one of the five wizard steps (each has its
    // own explicit 320px test). This closes that gap for the three states a
    // candidate can actually land on here.
    group('narrow-screen (320px) rendering', () {
      testWidgets('the real server document renders without overflow at 320px', (tester) async {
        await _pump(tester, previewResult: const Success(_readyOutcome), size: const Size(320, 800));

        expect(tester.takeException(), isNull);
        expect(find.text('Anita Sharma'), findsOneWidget);
        expect(find.byType(ManualResumePreviewScreen), findsOneWidget);
      });

      testWidgets('server validation errors render without overflow at 320px', (tester) async {
        const rejected = ManualResumePreviewRejected(
          errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
        );
        await _pump(tester, previewResult: const Success(rejected), size: const Size(320, 800));

        expect(tester.takeException(), isNull);
        expect(find.text('Please enter your full name.'), findsOneWidget);
      });

      testWidgets('a transport-failure retry view renders without overflow at 320px', (tester) async {
        await _pump(tester, previewResult: const Failed(ServerFailure()), size: const Size(320, 800));

        expect(tester.takeException(), isNull);
        expect(find.text(const ServerFailure().message), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    testWidgets('"Back to Builder" pops without clearing the draft', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = _FakeResumeRepository(previewResult: const Success(_readyOutcome));
      final draftRepo = _FakeManualResumeDraftRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          manualResumeDraftRepositoryProvider.overrideWithValue(draftRepo),
          resumeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await container.read(manualResumeBuilderControllerProvider.notifier).load();
      final draftBefore =
          (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).draft;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ManualResumePreviewScreen(draft: draftBefore)),
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

      await tester.tap(find.text('Back to Builder'));
      await tester.pump();

      final draftAfter =
          (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).draft;
      expect(draftAfter.toJson(), draftBefore.toJson());
    });
  });
}
