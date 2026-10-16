import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_draft_summary.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_outcomes.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/create_resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCreateResumeRepository implements CreateResumeRepository {
  _FakeCreateResumeRepository({this.listResult, this.deleteResult});

  Result<List<CreateResumeDraftSummary>>? listResult;
  Result<void>? deleteResult;
  int listCallCount = 0;
  int? lastDeletedId;

  @override
  Future<Result<List<CreateResumeDraftSummary>>> listDrafts() async {
    listCallCount++;
    return listResult ?? const Success([]);
  }

  @override
  Future<Result<void>> deleteDraft(int id) async {
    lastDeletedId = id;
    return deleteResult ?? const Success(null);
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
  Future<Result<CreateResumePdfOutcome>> generatePdf(
    CreateResumeFormState state,
  ) async => throw UnimplementedError();
  @override
  Future<Result<CreateResumeFormState>> loadDraft(int id) async =>
      throw UnimplementedError();
  @override
  Future<Result<int>> saveDraft(CreateResumeFormState state) async =>
      throw UnimplementedError();
}

final _sampleDrafts = [
  CreateResumeDraftSummary(
    id: 1,
    title: 'Backend Engineer – Asha Rao',
    template: 'classic',
    updatedAt: DateTime(2026),
  ),
  CreateResumeDraftSummary(
    id: 2,
    title: 'Untitled resume',
    template: 'modern',
    updatedAt: DateTime(2026, 2),
  ),
];

void main() {
  ProviderContainer buildContainer({
    Result<List<CreateResumeDraftSummary>>? listResult,
    Result<void>? deleteResult,
  }) {
    final container = ProviderContainer(
      overrides: [
        createResumeRepositoryProvider.overrideWithValue(
          _FakeCreateResumeRepository(
            listResult: listResult,
            deleteResult: deleteResult,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('CreateResumeDraftsController', () {
    test('build() loads the drafts list on first read', () async {
      final container = buildContainer(listResult: Success(_sampleDrafts));
      final result = await container.read(
        createResumeDraftsControllerProvider.future,
      );
      expect(result, hasLength(2));
      expect(result.first.title, 'Backend Engineer – Asha Rao');
    });

    test(
      'a repository failure surfaces as AsyncError, not a silently-empty list',
      () async {
        final container = buildContainer(
          listResult: const Failed(UnauthorizedFailure()),
        );

        try {
          await container.read(createResumeDraftsControllerProvider.future);
        } catch (_) {
          // expected: build() rethrows the mapped Failure on a Failed result.
        }

        final state = container.read(createResumeDraftsControllerProvider);
        expect(state, isA<AsyncError<List<CreateResumeDraftSummary>>>());
        expect((state as AsyncError).error, isA<UnauthorizedFailure>());
      },
    );

    test('retry() re-fetches the list', () async {
      final container = buildContainer(listResult: Success(_sampleDrafts));
      await container.read(createResumeDraftsControllerProvider.future);
      final repo =
          container.read(createResumeRepositoryProvider)
              as _FakeCreateResumeRepository;

      await container
          .read(createResumeDraftsControllerProvider.notifier)
          .retry();

      expect(repo.listCallCount, 2);
    });

    group('deleteDraft()', () {
      test(
        'a successful delete re-fetches the list and returns true',
        () async {
          final container = buildContainer(listResult: Success(_sampleDrafts));
          await container.read(createResumeDraftsControllerProvider.future);
          final repo =
              container.read(createResumeRepositoryProvider)
                  as _FakeCreateResumeRepository;

          final ok = await container
              .read(createResumeDraftsControllerProvider.notifier)
              .deleteDraft(1);

          expect(ok, isTrue);
          expect(repo.lastDeletedId, 1);
          expect(repo.listCallCount, 2);
        },
      );

      test(
        'a failed delete returns false and leaves the existing list intact (no false "removed" state)',
        () async {
          final container = buildContainer(
            listResult: Success(_sampleDrafts),
            deleteResult: const Failed(ServerFailure()),
          );
          await container.read(createResumeDraftsControllerProvider.future);
          final repo =
              container.read(createResumeRepositoryProvider)
                  as _FakeCreateResumeRepository;

          final ok = await container
              .read(createResumeDraftsControllerProvider.notifier)
              .deleteDraft(1);

          expect(ok, isFalse);
          expect(
            repo.listCallCount,
            1,
            reason: 'a failed delete must not re-fetch as if it succeeded',
          );
          final current = container
              .read(createResumeDraftsControllerProvider)
              .value;
          expect(current, hasLength(2));
        },
      );
    });
  });
}
