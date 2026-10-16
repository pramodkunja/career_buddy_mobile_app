import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_draft_summary.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_outcomes.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_validation_error.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/create_resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/create_resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCreateResumeRepository implements CreateResumeRepository {
  _FakeCreateResumeRepository({this.saveResult});

  Result<int>? saveResult;
  int saveCallCount = 0;
  CreateResumeFormState? lastSavedState;

  @override
  Future<Result<int>> saveDraft(CreateResumeFormState state) async {
    saveCallCount++;
    lastSavedState = state;
    return saveResult ?? const Success(1);
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
  Future<Result<List<CreateResumeDraftSummary>>> listDrafts() async =>
      const Success([]);
  @override
  Future<Result<CreateResumeFormState>> loadDraft(int id) async =>
      throw UnimplementedError();
  @override
  Future<Result<void>> deleteDraft(int id) async => const Success(null);
}

void main() {
  ProviderContainer buildContainer({Result<int>? saveResult}) {
    final container = ProviderContainer(
      overrides: [
        createResumeRepositoryProvider.overrideWithValue(
          _FakeCreateResumeRepository(saveResult: saveResult),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('CreateResumeBuilderController', () {
    test(
      'startBlank() produces a ready state with an empty form at step 1',
      () {
        final container = buildContainer();
        container
            .read(createResumeBuilderControllerProvider.notifier)
            .startBlank();

        final state = container.read(createResumeBuilderControllerProvider);
        expect(state, isA<CreateResumeBuilderReady>());
        expect(
          (state as CreateResumeBuilderReady).currentStep,
          kCreateResumeFirstStep,
        );
        expect(state.form.draftId, isNull);
      },
    );

    test(
      'startFromDraft() opens the builder pre-filled with the given form state',
      () {
        final container = buildContainer();
        const form = CreateResumeFormState(
          draftId: 42,
          personal: CreateResumePersonalInfo(name: 'Asha Rao'),
        );
        container
            .read(createResumeBuilderControllerProvider.notifier)
            .startFromDraft(form);

        final state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.draftId, 42);
        expect(state.form.personal.name, 'Asha Rao');
      },
    );

    group('step navigation', () {
      test(
        'nextStep()/previousStep() move within bounds and clamp at the edges',
        () {
          final container = buildContainer();
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          controller.previousStep(); // already at first step — no-op
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .currentStep,
            kCreateResumeFirstStep,
          );

          for (var i = kCreateResumeFirstStep; i < kCreateResumeLastStep; i++) {
            controller.nextStep();
          }
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .currentStep,
            kCreateResumeLastStep,
          );

          controller.nextStep(); // already at last step — no-op
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .currentStep,
            kCreateResumeLastStep,
          );
        },
      );

      test(
        'goToStep() jumps freely — this builder has no step-blocking validation of its own',
        () {
          final container = buildContainer();
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          controller.goToStep(4);
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .currentStep,
            4,
          );
        },
      );
    });

    group('repeatable entries', () {
      test(
        'addExperience()/removeExperience()/updateExperience() manage the list correctly',
        () {
          final container = buildContainer();
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          controller.addExperience();
          controller.addExperience();
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .form
                .experience,
            hasLength(2),
          );

          controller.updateExperience(0, (e) => e.copyWith(company: 'Acme'));
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .form
                .experience[0]
                .company,
            'Acme',
          );

          controller.removeExperience(1);
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .form
                .experience,
            hasLength(1),
          );
        },
      );

      test(
        'addEducation()/removeEducation()/updateEducation() manage the list correctly',
        () {
          final container = buildContainer();
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          controller.addEducation();
          controller.updateEducation(
            0,
            (e) => e.copyWith(institution: 'State University'),
          );

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.education.single.institution, 'State University');

          controller.removeEducation(0);
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .form
                .education,
            isEmpty,
          );
        },
      );
    });

    group('save()', () {
      test(
        'a successful save records the returned draft id and a saved timestamp',
        () async {
          final container = buildContainer(saveResult: const Success(99));
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.save();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.draftId, 99);
          expect(state.saving, isFalse);
          expect(state.lastSavedAt, isNotNull);
          expect(state.saveFailureMessage, isNull);
        },
      );

      test(
        'a failed save surfaces the failure message without clearing the form',
        () async {
          final container = buildContainer(
            saveResult: const Failed(
              ValidationFailure({}, 'You can keep up to 20 resumes.'),
            ),
          );
          final controller =
              container.read(createResumeBuilderControllerProvider.notifier)
                ..startBlank()
                ..updatePersonal((p) => p.copyWith(name: 'Asha Rao'));

          await controller.save();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.saveFailureMessage, 'You can keep up to 20 resumes.');
          expect(state.saving, isFalse);
          expect(state.form.personal.name, 'Asha Rao');
        },
      );

      test(
        'a second save() call while already saving is a no-op (duplicate-submit prevention)',
        () async {
          final container = buildContainer();
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();
          final repo =
              container.read(createResumeRepositoryProvider)
                  as _FakeCreateResumeRepository;

          final first = controller.save();
          final second = controller.save();
          await Future.wait([first, second]);

          expect(repo.saveCallCount, 1);
        },
      );

      test(
        'saving an already-saved draft sends its existing draftId, updating rather than creating',
        () async {
          final container = buildContainer(saveResult: const Success(5));
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startFromDraft(const CreateResumeFormState(draftId: 5));
          final repo =
              container.read(createResumeRepositoryProvider)
                  as _FakeCreateResumeRepository;

          await controller.save();

          expect(repo.lastSavedState!.draftId, 5);
        },
      );
    });

    group('server error wiring', () {
      test(
        'setServerErrors()/clearServerErrors() update the visible error list',
        () {
          final container = buildContainer();
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          controller.setServerErrors(const [
            CreateResumeValidationError(
              field: 'personal.email',
              section: 'personal',
              message: 'Invalid email.',
            ),
          ]);
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .serverErrors,
            hasLength(1),
          );

          controller.clearServerErrors();
          expect(
            (container.read(createResumeBuilderControllerProvider)
                    as CreateResumeBuilderReady)
                .serverErrors,
            isEmpty,
          );
        },
      );
    });

    group('hasUnsavedContent', () {
      test('is false for a freshly-started blank form', () {
        final container = buildContainer();
        final controller = container.read(
          createResumeBuilderControllerProvider.notifier,
        )..startBlank();
        expect(controller.hasUnsavedContent, isFalse);
      });

      test('is true once a personal field is entered', () {
        final container = buildContainer();
        final controller =
            container.read(createResumeBuilderControllerProvider.notifier)
              ..startBlank()
              ..updatePersonal((p) => p.copyWith(name: 'Asha Rao'));
        expect(controller.hasUnsavedContent, isTrue);
      });

      test('is true once a non-blank experience entry exists', () {
        final container = buildContainer();
        final controller = container.read(
          createResumeBuilderControllerProvider.notifier,
        )..startBlank();
        controller.addExperience();
        expect(controller.hasUnsavedContent, isFalse);
        controller.updateExperience(0, (e) => e.copyWith(company: 'Acme'));
        expect(controller.hasUnsavedContent, isTrue);
      });
    });
  });
}
