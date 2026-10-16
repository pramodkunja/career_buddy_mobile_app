import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_draft_summary.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_outcomes.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_validation_error.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/create_resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/create_resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/create_resume_pdf_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../support/fake_open_file_platform.dart';
import '../../../../support/fake_path_provider_platform.dart';

class _FakeCreateResumeRepository implements CreateResumeRepository {
  _FakeCreateResumeRepository({this.pdfResult, this.pdfCompleter});

  Result<CreateResumePdfOutcome>? pdfResult;
  Completer<Result<CreateResumePdfOutcome>>? pdfCompleter;
  int callCount = 0;

  @override
  Future<Result<CreateResumePdfOutcome>> generatePdf(
    CreateResumeFormState state,
  ) async {
    callCount++;
    if (pdfCompleter != null) return pdfCompleter!.future;
    return pdfResult ?? const Failed(UnexpectedFailure());
  }

  @override
  Future<Result<CreateResumePreviewOutcome>> preview(
    CreateResumeFormState state,
  ) async => throw UnimplementedError();
  @override
  Future<Result<CreateResumePagePreviewOutcome>> pagePreview(
    CreateResumeFormState state,
  ) async => throw UnimplementedError();
  @override
  Future<Result<List<CreateResumeDraftSummary>>> listDrafts() async =>
      const Success([]);
  @override
  Future<Result<CreateResumeFormState>> loadDraft(int id) async =>
      throw UnimplementedError();
  @override
  Future<Result<int>> saveDraft(CreateResumeFormState state) async =>
      throw UnimplementedError();
  @override
  Future<Result<void>> deleteDraft(int id) async => const Success(null);
}

final _readyOutcome = CreateResumePdfReady(
  bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
  filename: 'resume.pdf',
);

void main() {
  late Directory tempDir;
  final originalOpenFilePlatform = OpenFilePlatform.platform;
  final originalPathProviderPlatform = PathProviderPlatform.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('create_resume_pdf_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    OpenFilePlatform.platform = originalOpenFilePlatform;
    PathProviderPlatform.instance = originalPathProviderPlatform;
    await tempDir.delete(recursive: true);
  });

  ProviderContainer buildContainer({
    Result<CreateResumePdfOutcome>? pdfResult,
  }) {
    final container = ProviderContainer(
      overrides: [
        createResumeRepositoryProvider.overrideWithValue(
          _FakeCreateResumeRepository(pdfResult: pdfResult),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(createResumeBuilderControllerProvider.notifier).startBlank();
    return container;
  }

  group('CreateResumePdfController', () {
    test('initial state is idle', () {
      final container = buildContainer();
      expect(
        container.read(createResumePdfControllerProvider),
        isA<CreateResumePdfIdle>(),
      );
    });

    test(
      'a successful generation writes the file to a temp path and hands it to OpenFile, then returns to idle',
      () async {
        final fakeOpenFile = FakeOpenFilePlatform(
          result: OpenResult(type: ResultType.done, message: 'done'),
        );
        OpenFilePlatform.platform = fakeOpenFile;
        final container = buildContainer(pdfResult: Success(_readyOutcome));

        await container
            .read(createResumePdfControllerProvider.notifier)
            .generateAndOpen(const CreateResumeFormState());

        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfIdle>(),
        );
        expect(fakeOpenFile.lastFilePath, '${tempDir.path}/resume.pdf');
        expect(
          await File('${tempDir.path}/resume.pdf').readAsBytes(),
          _readyOutcome.bytes,
        );
      },
    );

    test(
      'generateAndOpen() moves through Generating before resolving',
      () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform();
        final container = buildContainer(pdfResult: Success(_readyOutcome));
        final controller = container.read(
          createResumePdfControllerProvider.notifier,
        );

        final future = controller.generateAndOpen(
          const CreateResumeFormState(),
        );
        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfGenerating>(),
        );
        await future;
      },
    );

    test(
      'a server rejection surfaces as CreateResumePdfValidationFailed, never reaching OpenFile',
      () async {
        final fakeOpenFile = FakeOpenFilePlatform();
        OpenFilePlatform.platform = fakeOpenFile;
        const rejected = CreateResumePdfRejected([
          CreateResumeValidationError(
            field: 'personal.name',
            section: 'personal',
            message: 'Please enter your full name.',
          ),
        ]);
        final container = buildContainer(pdfResult: const Success(rejected));

        await container
            .read(createResumePdfControllerProvider.notifier)
            .generateAndOpen(const CreateResumeFormState());

        final state = container.read(createResumePdfControllerProvider);
        expect(state, isA<CreateResumePdfValidationFailed>());
        expect(
          (state as CreateResumePdfValidationFailed).errors.single.field,
          'personal.name',
        );
        expect(fakeOpenFile.lastFilePath, isNull);

        final builderState =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(builderState.serverErrors.single.field, 'personal.name');
      },
    );

    test(
      'a transport failure surfaces as CreateResumePdfFailed, never reaching OpenFile',
      () async {
        final fakeOpenFile = FakeOpenFilePlatform();
        OpenFilePlatform.platform = fakeOpenFile;
        final container = buildContainer(
          pdfResult: const Failed(ServerFailure()),
        );

        await container
            .read(createResumePdfControllerProvider.notifier)
            .generateAndOpen(const CreateResumeFormState());

        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfFailed>(),
        );
        expect(fakeOpenFile.lastFilePath, isNull);
      },
    );

    test(
      'a second generateAndOpen() call while already generating is a no-op (duplicate-submit prevention)',
      () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform();
        final container = buildContainer(pdfResult: Success(_readyOutcome));
        final controller = container.read(
          createResumePdfControllerProvider.notifier,
        );
        final repo =
            container.read(createResumeRepositoryProvider)
                as _FakeCreateResumeRepository;

        final first = controller.generateAndOpen(const CreateResumeFormState());
        final second = controller.generateAndOpen(
          const CreateResumeFormState(),
        );
        await Future.wait([first, second]);

        expect(repo.callCount, 1);
      },
    );

    test(
      'reset() returns a failed state to idle so a retry starts clean',
      () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform();
        final container = buildContainer(
          pdfResult: const Failed(ServerFailure()),
        );
        final controller = container.read(
          createResumePdfControllerProvider.notifier,
        );
        await controller.generateAndOpen(const CreateResumeFormState());
        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfFailed>(),
        );

        controller.reset();

        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfIdle>(),
        );
      },
    );

    test(
      'a response that arrives after this controller has been invalidated is ignored — no unhandled lifecycle '
      'exception, no stale write, and OpenFile is never reached for the stale result',
      () async {
        final fakeOpenFile = FakeOpenFilePlatform();
        OpenFilePlatform.platform = fakeOpenFile;
        final container = buildContainer();
        final repo =
            container.read(createResumeRepositoryProvider)
                as _FakeCreateResumeRepository;
        final completer = Completer<Result<CreateResumePdfOutcome>>();
        repo.pdfCompleter = completer;

        final pending = container
            .read(createResumePdfControllerProvider.notifier)
            .generateAndOpen(const CreateResumeFormState());
        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfGenerating>(),
        );

        container.invalidate(createResumePdfControllerProvider);
        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfIdle>(),
        );

        completer.complete(Success(_readyOutcome));

        await expectLater(pending, completes);

        expect(
          container.read(createResumePdfControllerProvider),
          isA<CreateResumePdfIdle>(),
        );
        expect(fakeOpenFile.lastFilePath, isNull);
      },
    );
  });
}
