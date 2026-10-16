import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_pdf_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../support/fake_open_file_platform.dart';
import '../../../../support/fake_path_provider_platform.dart';

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
  _FakeResumeRepository({this.pdfResult, this.pdfCompleter});

  Result<ManualResumePdfOutcome>? pdfResult;

  /// When set, [generateManualResumePdf] awaits this instead of returning
  /// immediately — lets a test deterministically hold a request "in flight"
  /// rather than racing a zero-delay `Future`'s own microtask timing.
  Completer<Result<ManualResumePdfOutcome>>? pdfCompleter;
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
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(ManualResumeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(ManualResumeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(ManualResumeDraft draft) async {
    callCount++;
    receivedDrafts.add(draft);
    if (pdfCompleter != null) return pdfCompleter!.future;
    return pdfResult ?? const Failed(UnexpectedFailure());
  }
}

final _readyOutcome = ManualResumePdfReady(bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), filename: 'resume.pdf');

void main() {
  late Directory tempDir;
  final originalOpenFilePlatform = OpenFilePlatform.platform;
  final originalPathProviderPlatform = PathProviderPlatform.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('manual_resume_pdf_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    OpenFilePlatform.platform = originalOpenFilePlatform;
    PathProviderPlatform.instance = originalPathProviderPlatform;
    await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> buildContainer({Result<ManualResumePdfOutcome>? pdfResult}) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: const AuthUser(username: 'alice'))),
        manualResumeDraftRepositoryProvider.overrideWithValue(_FakeManualResumeDraftRepository()),
        resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository(pdfResult: pdfResult)),
      ],
    );
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(manualResumeBuilderControllerProvider.notifier).load();
    return container;
  }

  group('ManualResumePdfController', () {
    test('initial state is idle', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfIdle>());
    });

    test('a successful generation writes the file to a temp path and hands it to OpenFile, then returns to idle', () async {
      final fakeOpenFile = FakeOpenFilePlatform(result: OpenResult(type: ResultType.done, message: 'done'));
      OpenFilePlatform.platform = fakeOpenFile;
      final container = await buildContainer(pdfResult: Success(_readyOutcome));
      addTearDown(container.dispose);

      await container.read(manualResumePdfControllerProvider.notifier).generateAndOpen(ManualResumeDraft.blank());

      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfIdle>());
      expect(fakeOpenFile.lastFilePath, '${tempDir.path}/resume.pdf');
      expect(await File('${tempDir.path}/resume.pdf').readAsBytes(), _readyOutcome.bytes);
    });

    test('generateAndOpen() moves through Generating before resolving', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform();
      final container = await buildContainer(pdfResult: Success(_readyOutcome));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePdfControllerProvider.notifier);

      final future = controller.generateAndOpen(ManualResumeDraft.blank());
      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfGenerating>());
      await future;
    });

    test(
      'a real device reporting ResultType.noAppToOpen surfaces a specific, honest message instead of a fabricated success',
      () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform(
          result: OpenResult(type: ResultType.noAppToOpen, message: 'No APP found to open this file.'),
        );
        final container = await buildContainer(pdfResult: Success(_readyOutcome));
        addTearDown(container.dispose);

        await container.read(manualResumePdfControllerProvider.notifier).generateAndOpen(ManualResumeDraft.blank());

        final state = container.read(manualResumePdfControllerProvider);
        expect(state, isA<ManualResumePdfFailed>());
        expect(
          (state as ManualResumePdfFailed).failure.message,
          'No app installed on this device can open a PDF. Install a compatible viewer and try again.',
        );
      },
    );

    test('a server rejection surfaces as ManualResumePdfValidationFailed, never reaching OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform();
      OpenFilePlatform.platform = fakeOpenFile;
      const rejected = ManualResumePdfRejected([
        ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.'),
      ]);
      final container = await buildContainer(pdfResult: const Success(rejected));
      addTearDown(container.dispose);

      await container.read(manualResumePdfControllerProvider.notifier).generateAndOpen(ManualResumeDraft.blank());

      final state = container.read(manualResumePdfControllerProvider);
      expect(state, isA<ManualResumePdfValidationFailed>());
      expect((state as ManualResumePdfValidationFailed).errors.single.field, 'personal.name');
      expect(fakeOpenFile.lastFilePath, isNull);
    });

    test('a transport failure surfaces as ManualResumePdfFailed, never reaching OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform();
      OpenFilePlatform.platform = fakeOpenFile;
      final container = await buildContainer(pdfResult: const Failed(ServerFailure()));
      addTearDown(container.dispose);

      await container.read(manualResumePdfControllerProvider.notifier).generateAndOpen(ManualResumeDraft.blank());

      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfFailed>());
      expect(fakeOpenFile.lastFilePath, isNull);
    });

    test('a second generateAndOpen() call while already generating is a no-op (duplicate-submit prevention)', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform();
      final container = await buildContainer(pdfResult: Success(_readyOutcome));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePdfControllerProvider.notifier);
      final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;

      final first = controller.generateAndOpen(ManualResumeDraft.blank());
      final second = controller.generateAndOpen(ManualResumeDraft.blank());
      await Future.wait([first, second]);

      expect(repo.callCount, 1);
    });

    test('reset() returns a failed state to idle so a retry starts clean', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform();
      final container = await buildContainer(pdfResult: const Failed(ServerFailure()));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePdfControllerProvider.notifier);
      await controller.generateAndOpen(ManualResumeDraft.blank());
      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfFailed>());

      controller.reset();

      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfIdle>());
    });

    test('reset() is a no-op while generating', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform();
      final container = await buildContainer(pdfResult: Success(_readyOutcome));
      addTearDown(container.dispose);
      final controller = container.read(manualResumePdfControllerProvider.notifier);

      final future = controller.generateAndOpen(ManualResumeDraft.blank());
      controller.reset();
      expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfGenerating>());
      await future;
    });

    group('Builder controller integration', () {
      test("a rejection immediately feeds its errors into the Builder controller and jumps to the first error's step", () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform();
        const rejected = ManualResumePdfRejected([
          ManualResumeValidationError(field: 'education', step: 4, message: 'Please add your education details.'),
        ]);
        final container = await buildContainer(pdfResult: const Success(rejected));
        addTearDown(container.dispose);

        await container.read(manualResumePdfControllerProvider.notifier).generateAndOpen(ManualResumeDraft.blank());

        final builderState = container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady;
        expect(builderState.serverErrors.single.field, 'education');
        expect(builderState.draft.currentStep, 4);
      });

      test('a success clears any stale server errors already on the Builder controller', () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform();
        final container = await buildContainer(pdfResult: Success(_readyOutcome));
        addTearDown(container.dispose);
        container
            .read(manualResumeBuilderControllerProvider.notifier)
            .setServerErrors(const [
              ManualResumeValidationError(field: 'personal.name', step: 1, message: 'Please enter your full name.'),
            ]);

        await container.read(manualResumePdfControllerProvider.notifier).generateAndOpen(ManualResumeDraft.blank());

        expect(
          (container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady).serverErrors,
          isEmpty,
        );
      });
    });

    group('lifecycle safety (Phase 32)', () {
      test(
        'a response that arrives after this controller has been invalidated (the real logout/account-switch '
        'trigger, Phase 31) is ignored — no unhandled lifecycle exception, no stale write, and OpenFile is '
        'never reached for the stale result',
        () async {
          final fakeOpenFile = FakeOpenFilePlatform();
          OpenFilePlatform.platform = fakeOpenFile;
          final container = await buildContainer();
          addTearDown(container.dispose);
          final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;
          final completer = Completer<Result<ManualResumePdfOutcome>>();
          repo.pdfCompleter = completer;

          final pending = container
              .read(manualResumePdfControllerProvider.notifier)
              .generateAndOpen(ManualResumeDraft.blank());
          expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfGenerating>());

          // The exact real trigger: `AuthController._invalidateUserScopedProviders()`
          // calls `ref.invalidate()` on this provider while the request above
          // is still pending. Reading it immediately afterward is what
          // actually re-runs `build()` on it.
          container.invalidate(manualResumePdfControllerProvider);
          expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfIdle>());

          // Resolve the original request, now stale, with a real PDF ready
          // to save — the highest-stakes outcome, since this is the branch
          // that would otherwise write a file and call `OpenFile.open`.
          completer.complete(Success(_readyOutcome));

          // The crux of this test: completing the stale request must not
          // throw, must not write a stale result into the fresh instance,
          // and must never reach `OpenFile.open` for an account that is no
          // longer the active one.
          await expectLater(pending, completes);

          expect(container.read(manualResumePdfControllerProvider), isA<ManualResumePdfIdle>());
          expect(fakeOpenFile.lastFilePath, isNull);
        },
      );
    });
  });
}
