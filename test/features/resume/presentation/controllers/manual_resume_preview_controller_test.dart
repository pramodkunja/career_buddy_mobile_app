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
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_preview_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});
  AuthUser? restoredUser;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;
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
  /// immediately — lets a test deterministically hold a request "in flight"
  /// (e.g. across a provider invalidation) rather than racing a zero-delay
  /// `Future`'s own microtask timing.
  Completer<Result<ManualResumePreviewOutcome>>? previewCompleter;
  int callCount = 0;
  List<ManualResumeDraft> receivedDrafts = [];

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
    receivedDrafts.add(draft);
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
    contact: [],
    level: '1-3',
    levelLabel: '1–3 Years',
    role: 'QA Engineer',
    sections: [],
  ),
  warnings: [],
  completeness: ManualResumeCompletenessSummary(overall: 80, categories: []),
  filename: 'resume.pdf',
);

Future<ProviderContainer> _buildContainer({Result<ManualResumePreviewOutcome>? previewResult}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'alice'))),
      manualResumeDraftRepositoryProvider.overrideWithValue(_FakeManualResumeDraftRepository()),
      resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository(previewResult: previewResult)),
    ],
  );
  container.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
  // Settle the Manual Resume Builder controller into Ready — `setServerErrors`
  // is a no-op before that, which several tests below rely on observing.
  await container.read(manualResumeBuilderControllerProvider.notifier).load();
  return container;
}

void main() {
  group('ManualResumePreviewController', () {
    test('initial state is idle', () async {
      final container = await _buildContainer();
      addTearDown(container.dispose);
      expect(container.read(manualResumePreviewControllerProvider), isA<ManualResumePreviewIdle>());
    });

    test('generate() moves through loading to a ready result on success', () async {
      final container = await _buildContainer(previewResult: const Success(_readyOutcome));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePreviewControllerProvider.notifier);

      final future = controller.generate(ManualResumeDraft.blank());
      expect(container.read(manualResumePreviewControllerProvider), isA<ManualResumePreviewLoading>());
      await future;

      final state = container.read(manualResumePreviewControllerProvider);
      expect(state, isA<ManualResumePreviewReadyState>());
      expect((state as ManualResumePreviewReadyState).document.name, 'Anita Sharma');
      expect((state).filename, 'resume.pdf');
    });

    test('a validation rejection surfaces as ManualResumePreviewValidationFailed', () async {
      const rejected = ManualResumePreviewRejected(
        errors: [ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.')],
      );
      final container = await _buildContainer(previewResult: const Success(rejected));
      addTearDown(container.dispose);

      await container.read(manualResumePreviewControllerProvider.notifier).generate(ManualResumeDraft.blank());

      final state = container.read(manualResumePreviewControllerProvider);
      expect(state, isA<ManualResumePreviewValidationFailed>());
      expect((state as ManualResumePreviewValidationFailed).errors.single.field, 'personal.name');
    });

    test('a transport failure surfaces as ManualResumePreviewFailed, not a crash', () async {
      final container = await _buildContainer(previewResult: const Failed(ServerFailure()));
      addTearDown(container.dispose);

      await container.read(manualResumePreviewControllerProvider.notifier).generate(ManualResumeDraft.blank());

      expect(container.read(manualResumePreviewControllerProvider), isA<ManualResumePreviewFailed>());
    });

    test('a second generate() call while already loading is a no-op (duplicate-submit prevention)', () async {
      final container = await _buildContainer(previewResult: const Success(_readyOutcome));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePreviewControllerProvider.notifier);
      final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;

      final first = controller.generate(ManualResumeDraft.blank());
      final second = controller.generate(ManualResumeDraft.blank());
      await Future.wait([first, second]);

      expect(repo.callCount, 1);
    });

    test('retry() resubmits the given draft', () async {
      final container = await _buildContainer(previewResult: const Success(_readyOutcome));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePreviewControllerProvider.notifier);
      final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;
      final draft = ManualResumeDraft.blank().copyWith(summary: 'A summary');

      await controller.generate(draft);
      await controller.retry(draft);

      expect(repo.callCount, 2);
      expect(repo.receivedDrafts, [draft, draft]);
    });

    group('Builder controller integration', () {
      test('a rejection immediately feeds its errors into the Builder controller and jumps to the first error\'s step', () async {
        const rejected = ManualResumePreviewRejected(
          errors: [
            ManualResumeValidationError(field: 'education', step: 4, message: 'Please add your education details.'),
          ],
        );
        final container = await _buildContainer(previewResult: const Success(rejected));
        addTearDown(container.dispose);

        await container.read(manualResumePreviewControllerProvider.notifier).generate(ManualResumeDraft.blank());

        final builderState =
            container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady;
        expect(builderState.serverErrors.single.field, 'education');
        expect(builderState.draft.currentStep, 4);
        expect(builderState.visibleErrors.map((e) => e.field), contains('education'));
      });

      test('a success clears any stale server errors already on the Builder controller', () async {
        final container = await _buildContainer(previewResult: const Success(_readyOutcome));
        addTearDown(container.dispose);
        container
            .read(manualResumeBuilderControllerProvider.notifier)
            .setServerErrors(const [
              ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.'),
            ]);
        expect(
          (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).serverErrors,
          isNotEmpty,
        );

        await container.read(manualResumePreviewControllerProvider.notifier).generate(ManualResumeDraft.blank());

        expect(
          (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).serverErrors,
          isEmpty,
        );
      });
    });

    group('lifecycle safety (Phase 32)', () {
      test(
        'a response that arrives after this controller has been invalidated (the real logout/account-switch '
        'trigger, Phase 31) is ignored — no unhandled UnmountedRefException, no stale write to the new instance',
        () async {
          final container = await _buildContainer();
          addTearDown(container.dispose);
          final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;
          final completer = Completer<Result<ManualResumePreviewOutcome>>();
          repo.previewCompleter = completer;

          final pending = container
              .read(manualResumePreviewControllerProvider.notifier)
              .generate(ManualResumeDraft.blank());
          expect(container.read(manualResumePreviewControllerProvider), isA<ManualResumePreviewLoading>());

          // The exact real trigger: `AuthController._invalidateUserScopedProviders()`
          // calls `ref.invalidate()` on this provider while the request above
          // is still pending. Reading it immediately afterward is what
          // actually rebuilds it (a fresh `ManualResumePreviewController`
          // instance, per Riverpod's own "NotifierProviders always create a
          // new Notifier instance" contract) — exactly what every real
          // caller of this provider does the moment it needs the state again.
          container.invalidate(manualResumePreviewControllerProvider);
          expect(container.read(manualResumePreviewControllerProvider), isA<ManualResumePreviewIdle>());

          // Resolve the original request, now orphaned on the disposed instance.
          completer.complete(const Success(_readyOutcome));

          // The crux of this test: completing the stale request must not
          // throw. Before the Phase 32 guard, the disposed instance's own
          // `state = ...` write threw `UnmountedRefException` here.
          await expectLater(pending, completes);

          // The fresh instance (what every real reader now sees) must still
          // be untouched by the stale completion — not overwritten with the
          // previous account's result.
          expect(container.read(manualResumePreviewControllerProvider), isA<ManualResumePreviewIdle>());
        },
      );
    });
  });
}
