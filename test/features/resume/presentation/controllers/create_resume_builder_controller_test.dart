import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_draft_summary.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_outcomes.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_validation_error.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/create_resume_guest_draft_repository.dart';
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

/// Phase 42 — a fake for the guest-local save path, kept entirely separate
/// from [_FakeCreateResumeRepository] so a test can assert which one (or
/// neither) was actually called.
class _FakeCreateResumeGuestDraftRepository
    implements CreateResumeGuestDraftRepository {
  _FakeCreateResumeGuestDraftRepository({this.saveResult, this.loadResult});

  Result<void>? saveResult;
  int saveCallCount = 0;
  CreateResumeFormState? lastSavedState;

  Result<CreateResumeFormState?>? loadResult;
  int loadCallCount = 0;

  /// Phase 45 — when set, [loadDraft] waits on this before returning,
  /// letting a test simulate the user typing *while* the real async
  /// storage read is still in flight (a race this device's
  /// [SecureStorageService] read makes possible but the real web's own
  /// synchronous `localStorage` read never could — see
  /// `restoreGuestDraftIfAvailable`'s own doc comment).
  Completer<void>? loadGate;

  @override
  Future<Result<void>> saveDraft(CreateResumeFormState form) async {
    saveCallCount++;
    lastSavedState = form;
    return saveResult ?? const Success(null);
  }

  @override
  Future<Result<CreateResumeFormState?>> loadDraft() async {
    loadCallCount++;
    if (loadGate != null) await loadGate!.future;
    return loadResult ?? const Success(null);
  }

  @override
  Future<Result<void>> clearDraft() async => const Success(null);
}

/// Copied from `manual_resume_builder_controller_test.dart`'s own fake —
/// same minimal shape, only `restoreSession()` is ever exercised here.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  AuthUser? restoredUser;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async =>
      throw UnimplementedError();
}

void main() {
  /// [authUser] defaults to a signed-in account — every pre-existing test
  /// below predates the guest/authenticated split (Phase 42) and was
  /// written against an always-server-saves controller, so the default
  /// here preserves their original, already-correct expectations. Pass
  /// `authUser: null` for the new guest-path tests.
  ///
  /// Also waits for `AuthController.build()`'s own async `restoreSession()`
  /// call to settle (mirroring `manual_resume_builder_controller_test.dart`'s
  /// `_buildContainer` helper) — without this, `AuthController`'s state is
  /// still the transient `AuthUnknown` when `save()` reads it, which this
  /// controller would (correctly, per its own `_isAuthenticated` doc
  /// comment) also treat as "not signed in".
  Future<ProviderContainer> buildContainer({
    Result<int>? saveResult,
    AuthUser? authUser = const AuthUser(username: 'alice'),
    _FakeCreateResumeGuestDraftRepository? guestDraftRepository,
  }) async {
    final container = ProviderContainer(
      overrides: [
        createResumeRepositoryProvider.overrideWithValue(
          _FakeCreateResumeRepository(saveResult: saveResult),
        ),
        createResumeGuestDraftRepositoryProvider.overrideWithValue(
          guestDraftRepository ?? _FakeCreateResumeGuestDraftRepository(),
        ),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(restoredUser: authUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  group('CreateResumeBuilderController', () {
    test(
      'startBlank() produces a ready state with an empty form at step 1',
      () async {
        final container = await buildContainer();
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
      () async {
        final container = await buildContainer();
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
        () async {
          final container = await buildContainer();
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
        () async {
          final container = await buildContainer();
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
        () async {
          final container = await buildContainer();
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
        () async {
          final container = await buildContainer();
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

    group('save() — authenticated', () {
      test(
        'a successful save records the returned draft id and a saved timestamp',
        () async {
          final container = await buildContainer(
            saveResult: const Success(99),
          );
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
          final guestRepo =
              container.read(createResumeGuestDraftRepositoryProvider)
                  as _FakeCreateResumeGuestDraftRepository;
          expect(
            guestRepo.saveCallCount,
            0,
            reason: 'an authenticated save must never touch local guest storage',
          );
        },
      );

      test(
        'a failed save surfaces the failure message without clearing the form',
        () async {
          final container = await buildContainer(
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
        'a genuinely expired session surfaces its own message, never the guest-save path',
        () async {
          final container = await buildContainer(
            saveResult: const Failed(UnauthorizedFailure()),
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.save();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.saveFailureMessage, const UnauthorizedFailure().message);
          final guestRepo =
              container.read(createResumeGuestDraftRepositoryProvider)
                  as _FakeCreateResumeGuestDraftRepository;
          expect(guestRepo.saveCallCount, 0);
        },
      );

      test(
        'a second save() call while already saving is a no-op (duplicate-submit prevention)',
        () async {
          final container = await buildContainer();
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
          final container = await buildContainer(saveResult: const Success(5));
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

    group('save() — guest (Phase 42)', () {
      test(
        'a guest save writes to local storage only, never the server',
        () async {
          final container = await buildContainer(authUser: null);
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.save();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.saving, isFalse);
          expect(state.lastSavedAt, isNotNull);
          expect(state.saveFailureMessage, isNull);
          // Never assigned a server id — a guest draft has none.
          expect(state.form.draftId, isNull);

          final guestRepo =
              container.read(createResumeGuestDraftRepositoryProvider)
                  as _FakeCreateResumeGuestDraftRepository;
          expect(guestRepo.saveCallCount, 1);
          final serverRepo =
              container.read(createResumeRepositoryProvider)
                  as _FakeCreateResumeRepository;
          expect(
            serverRepo.saveCallCount,
            0,
            reason:
                'a guest save must never send an unauthenticated server request',
          );
        },
      );

      test(
        'a guest save preserves whatever the candidate entered', () async {
          final container = await buildContainer(authUser: null);
          final controller =
              container.read(createResumeBuilderControllerProvider.notifier)
                ..startBlank()
                ..updatePersonal((p) => p.copyWith(name: 'Guest Candidate'));

          await controller.save();

          final guestRepo =
              container.read(createResumeGuestDraftRepositoryProvider)
                  as _FakeCreateResumeGuestDraftRepository;
          expect(guestRepo.lastSavedState!.personal.name, 'Guest Candidate');
        },
      );

      test(
        'a local-storage failure surfaces its own message, never "session expired"',
        () async {
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: _FakeCreateResumeGuestDraftRepository(
              saveResult: const Failed(
                UnexpectedFailure('Could not save the resume draft on this device.'),
              ),
            ),
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.save();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(
            state.saveFailureMessage,
            'Could not save the resume draft on this device.',
          );
          expect(
            state.saveFailureMessage,
            isNot(contains('session')),
            reason: 'a guest never had a session to expire',
          );
          // A failed save must never be reported as successful.
          expect(state.lastSavedAt, isNull);
        },
      );

      test(
        'a second guest save() call while already saving is a no-op',
        () async {
          final container = await buildContainer(authUser: null);
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();
          final guestRepo =
              container.read(createResumeGuestDraftRepositoryProvider)
                  as _FakeCreateResumeGuestDraftRepository;

          final first = controller.save();
          final second = controller.save();
          await Future.wait([first, second]);

          expect(guestRepo.saveCallCount, 1);
        },
      );
    });

    group('server error wiring', () {
      test(
        'setServerErrors()/clearServerErrors() update the visible error list',
        () async {
          final container = await buildContainer();
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
      test('is false for a freshly-started blank form', () async {
        final container = await buildContainer();
        final controller = container.read(
          createResumeBuilderControllerProvider.notifier,
        )..startBlank();
        expect(controller.hasUnsavedContent, isFalse);
      });

      test('is true once a personal field is entered', () async {
        final container = await buildContainer();
        final controller =
            container.read(createResumeBuilderControllerProvider.notifier)
              ..startBlank()
              ..updatePersonal((p) => p.copyWith(name: 'Asha Rao'));
        expect(controller.hasUnsavedContent, isTrue);
      });

      test('is true once a non-blank experience entry exists', () async {
        final container = await buildContainer();
        final controller = container.read(
          createResumeBuilderControllerProvider.notifier,
        )..startBlank();
        controller.addExperience();
        expect(controller.hasUnsavedContent, isFalse);
        controller.updateExperience(0, (e) => e.copyWith(company: 'Acme'));
        expect(controller.hasUnsavedContent, isTrue);
      });
    });

    group('restoreGuestDraftIfAvailable() — Phase 45', () {
      const savedDraft = CreateResumeFormState(
        personal: CreateResumePersonalInfo(
          name: 'Guest Candidate',
          email: 'guest@example.com',
        ),
        summary: 'A dedicated professional.',
        skills: CreateResumeSkills(
          technical: ['Dart', 'Flutter'],
          soft: ['Communication'],
        ),
        experience: [
          CreateResumeExperienceEntry(company: 'Acme', title: 'Engineer'),
          CreateResumeExperienceEntry(company: 'Globex', title: 'Lead Engineer'),
        ],
        education: [
          CreateResumeEducationEntry(institution: 'State University', degree: 'B.Sc.'),
          CreateResumeEducationEntry(institution: 'Community College', degree: 'A.A.'),
        ],
      );

      test(
        'a guest with no saved draft opens a normal blank builder',
        () async {
          final container = await buildContainer(authUser: null);
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.personal.name, isEmpty);
          expect(state.restoredFromLocalDraft, isFalse);
        },
      );

      test(
        'a guest with a saved draft has it restored automatically, including '
        'multiple experience and education entries',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.personal.name, 'Guest Candidate');
          expect(state.form.personal.email, 'guest@example.com');
          expect(state.form.summary, 'A dedicated professional.');
          expect(state.form.skills.technical, ['Dart', 'Flutter']);
          expect(state.form.skills.soft, ['Communication']);
          expect(state.form.experience, hasLength(2));
          expect(state.form.experience[0].company, 'Acme');
          expect(state.form.experience[1].company, 'Globex');
          expect(state.form.education, hasLength(2));
          expect(state.form.education[0].institution, 'State University');
          expect(state.form.education[1].institution, 'Community College');
          expect(state.restoredFromLocalDraft, isTrue);
          expect(guestRepo.loadCallCount, 1);
        },
      );

      test(
        'editing a restored draft and saving again persists the latest values',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();
          await controller.restoreGuestDraftIfAvailable();

          controller.updatePersonal((p) => p.copyWith(name: 'Updated Name'));
          await controller.save();

          expect(guestRepo.saveCallCount, 1);
          expect(guestRepo.lastSavedState!.personal.name, 'Updated Name');
          // The rest of the restored content travels along unchanged.
          expect(guestRepo.lastSavedState!.experience, hasLength(2));
        },
      );

      test(
        'a malformed/unreadable saved draft does not crash the builder',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Failed(
              UnexpectedFailure('Could not load the resume draft saved on this device.'),
            ),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          // Still a perfectly usable blank builder — no crash, no stuck
          // loading state.
          expect(state.form.personal.name, isEmpty);
          expect(state.restoredFromLocalDraft, isFalse);
        },
      );

      test(
        'restoration does not overwrite text entered before it completes',
        () async {
          final loadGate = Completer<void>();
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          )..loadGate = loadGate;
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          // Kick off restoration — it will block on `loadGate` before
          // applying anything.
          final restoreFuture = controller.restoreGuestDraftIfAvailable();

          // The guest starts typing *while the storage read is still in
          // flight* — a real race this device's async storage makes
          // possible (the real web's synchronous `localStorage` read never
          // could hit this).
          controller.updatePersonal((p) => p.copyWith(name: 'Typed Live'));

          // Now let the (now-stale) restoration resolve.
          loadGate.complete();
          await restoreFuture;

          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.personal.name, 'Typed Live');
          expect(
            state.restoredFromLocalDraft,
            isFalse,
            reason: 'the stale restore must not have applied at all',
          );
        },
      );

      test(
        'repeated restoration attempts in the same session do not restore twice',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();
          // A second attempt in the same blank session (e.g. an accidental
          // duplicate call) must be a complete no-op.
          await controller.restoreGuestDraftIfAvailable();

          expect(guestRepo.loadCallCount, 1);
        },
      );

      test(
        'a fresh startBlank() call permits a new restoration attempt',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();
          expect(guestRepo.loadCallCount, 1);

          // Leaving and reopening the builder calls `startBlank()` again.
          controller.startBlank();
          await controller.restoreGuestDraftIfAvailable();
          expect(guestRepo.loadCallCount, 2);
        },
      );

      test(
        'startFromDraft() is never followed by a guest-draft restore',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startFromDraft(const CreateResumeFormState(draftId: 7));

          await controller.restoreGuestDraftIfAvailable();

          expect(guestRepo.loadCallCount, 0);
          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.draftId, 7);
        },
      );

      test(
        'guest restoration makes no server requests', () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            authUser: null,
            guestDraftRepository: guestRepo,
          );
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();

          final serverRepo =
              container.read(createResumeRepositoryProvider)
                  as _FakeCreateResumeRepository;
          expect(serverRepo.saveCallCount, 0);
        },
      );

      test(
        'an authenticated session never triggers a guest-draft restore',
        () async {
          final guestRepo = _FakeCreateResumeGuestDraftRepository(
            loadResult: const Success(savedDraft),
          );
          final container = await buildContainer(
            guestDraftRepository: guestRepo,
          ); // default authUser — signed in
          final controller = container.read(
            createResumeBuilderControllerProvider.notifier,
          )..startBlank();

          await controller.restoreGuestDraftIfAvailable();

          expect(guestRepo.loadCallCount, 0);
          final state =
              container.read(createResumeBuilderControllerProvider)
                  as CreateResumeBuilderReady;
          expect(state.form.personal.name, isEmpty);
        },
      );
    });
  });
}
