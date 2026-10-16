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
  _FakeManualResumeDraftRepository({this.loadResult, this.saveResult});

  Result<ManualResumeDraft?>? loadResult;
  Result<void>? saveResult;
  final Map<String, ManualResumeDraft> saved = {};
  int saveCallCount = 0;
  int clearCallCount = 0;

  @override
  Future<Result<ManualResumeDraft?>> loadDraft(String username) async => loadResult ?? const Success(null);

  @override
  Future<Result<void>> saveDraft(String username, ManualResumeDraft draft) async {
    saveCallCount++;
    saved[username] = draft;
    return saveResult ?? const Success(null);
  }

  @override
  Future<Result<void>> clearDraft(String username) async {
    clearCallCount++;
    saved.remove(username);
    return const Success(null);
  }
}

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.rolesResult, this.levelCommonResult, this.previewResult});

  Result<List<ResumeRole>>? rolesResult;
  Result<Map<String, LevelCommonSuggestions>>? levelCommonResult;
  Result<ManualResumePreviewOutcome>? previewResult;
  int previewCallCount = 0;

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
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(ManualResumeDraft draft) async {
    previewCallCount++;
    return previewResult ?? const Failed(UnexpectedFailure());
  }

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(ManualResumeDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(ManualResumeDraft draft) async =>
      throw UnimplementedError();
}

const _role = ResumeRole(
  slug: 'qa-engineer',
  title: 'QA Engineer',
  category: 'it',
  categoryLabel: 'IT Role',
  subtitle: 'Manual & automation testing',
  fields: [ResumeRoleSkillField(key: 'testing-tools', label: 'Testing tools', options: ['Selenium', 'Postman'])],
);

/// A draft that passes every Step 1 validation rule — used by the
/// `nextStep()` gating tests so they isolate the *gating* behavior itself
/// rather than re-testing the validator (already covered exhaustively in
/// `manual_resume_validation_test.dart`).
ManualResumeDraft _step1ValidDraft() => ManualResumeDraft.blank().copyWith(
  personal: const ManualResumePersonalInfo(name: 'Anita Sharma', email: 'anita@example.com', phone: '9876543210'),
);

/// Also waits for `AuthController.build()`'s own async `restoreSession()`
/// call to settle (mirroring `auth_controller_test.dart`'s `_readyContainer`
/// helper) — without this, `AuthController`'s state is still the transient
/// `AuthUnknown` when `load()` reads it, which this controller would
/// (correctly) also treat as "can't identify whose draft this is".
Future<ProviderContainer> _buildContainer({
  AuthUser? restoredUser = const AuthUser(username: 'alice'),
  ManualResumeDraftRepository? draftRepository,
  ResumeRepository? resumeRepository,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(restoredUser: restoredUser)),
      manualResumeDraftRepositoryProvider.overrideWithValue(draftRepository ?? _FakeManualResumeDraftRepository()),
      resumeRepositoryProvider.overrideWithValue(resumeRepository ?? _FakeResumeRepository()),
    ],
  );
  container.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
  return container;
}

ManualResumeBuilderReady _ready(ProviderContainer container) =>
    container.read(manualResumeBuilderControllerProvider) as ManualResumeBuilderReady;

void main() {
  group('ManualResumeBuilderController', () {
    test('initial state is loading', () async {
      final container = await _buildContainer();
      addTearDown(container.dispose);
      expect(container.read(manualResumeBuilderControllerProvider), isA<ManualResumeBuilderLoading>());
    });

    test('load() with no saved draft starts a blank draft at step 1', () async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await container.read(manualResumeBuilderControllerProvider.notifier).load();

      final state = _ready(container);
      expect(state.draft.currentStep, kManualResumeFirstStep);
      expect(state.draft.role, '');
    });

    test('load() restores a previously saved draft and resolves its role from the catalog', () async {
      final draftRepo = _FakeManualResumeDraftRepository(
        loadResult: Success(ManualResumeDraft.blank().copyWith(role: 'qa-engineer', currentStep: 4)),
      );
      final container = await _buildContainer(
        draftRepository: draftRepo,
        resumeRepository: _FakeResumeRepository(rolesResult: const Success([_role])),
      );
      addTearDown(container.dispose);

      await container.read(manualResumeBuilderControllerProvider.notifier).load();

      final state = _ready(container);
      expect(state.draft.role, 'qa-engineer');
      expect(state.draft.currentStep, 4);
      expect(state.role?.slug, 'qa-engineer');
    });

    test('a load failure surfaces as ManualResumeBuilderLoadFailed, not a crash', () async {
      final draftRepo = _FakeManualResumeDraftRepository(loadResult: const Failed(UnexpectedFailure()));
      final container = await _buildContainer(draftRepository: draftRepo);
      addTearDown(container.dispose);

      await container.read(manualResumeBuilderControllerProvider.notifier).load();

      expect(container.read(manualResumeBuilderControllerProvider), isA<ManualResumeBuilderLoadFailed>());
    });

    test('load() without an authenticated user fails with UnauthorizedFailure rather than guessing a key', () async {
      final container = await _buildContainer(restoredUser: null);
      addTearDown(container.dispose);

      await container.read(manualResumeBuilderControllerProvider.notifier).load();

      final state = container.read(manualResumeBuilderControllerProvider);
      expect(state, isA<ManualResumeBuilderLoadFailed>());
      expect((state as ManualResumeBuilderLoadFailed).failure, isA<UnauthorizedFailure>());
    });

    test('a role-catalog fetch failure degrades suggestions but never blocks the draft itself', () async {
      final container = await _buildContainer(
        resumeRepository: _FakeResumeRepository(rolesResult: const Failed(ServerFailure())),
      );
      addTearDown(container.dispose);

      await container.read(manualResumeBuilderControllerProvider.notifier).load();

      final state = _ready(container);
      expect(state.roleCatalogLoadFailed, isTrue);
      expect(state.role, isNull);
    });

    group('step navigation', () {
      test('goToStep() jumps directly to a given step with no validation at all', () async {
        final draftRepo = _FakeManualResumeDraftRepository();
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        await controller.goToStep(5);

        expect(_ready(container).draft.currentStep, 5);
        expect(draftRepo.saveCallCount, 1);
      });

      test('previousStep() moves back freely and at step 1 is a no-op', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        await controller.goToStep(2);
        await controller.previousStep();
        expect(_ready(container).draft.currentStep, 1);

        await controller.previousStep();
        expect(_ready(container).draft.currentStep, 1);
      });

      test('nextStep() is blocked by a current-step validation error and marks those fields touched', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load(); // blank draft — step 1 has name/email/phone errors

        final advanced = await controller.nextStep();

        expect(advanced, isFalse);
        expect(_ready(container).draft.currentStep, 1);
        expect(_ready(container).touched, containsAll(['personal.name', 'personal.email', 'personal.phone']));
      });

      test('nextStep() advances once the current step is valid', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        controller.updatePersonal((p) => _step1ValidDraft().personal);

        final advanced = await controller.nextStep();

        expect(advanced, isTrue);
        expect(_ready(container).draft.currentStep, 2);
      });

      test('nextStep() at step 5 is a no-op', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        await controller.goToStep(5);

        expect(await controller.nextStep(), isFalse);
        expect(_ready(container).draft.currentStep, 5);
      });
    });

    group('setRoleIfBlank', () {
      test('fills the role on a blank draft and stores the full role object directly', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.setRoleIfBlank(_role);

        final state = _ready(container);
        expect(state.draft.role, 'qa-engineer');
        expect(state.role, same(_role));
      });

      test('never overwrites a draft that already has a different role', () async {
        final draftRepo = _FakeManualResumeDraftRepository(
          loadResult: Success(ManualResumeDraft.blank().copyWith(role: 'existing-role')),
        );
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.setRoleIfBlank(_role);

        expect(_ready(container).draft.role, 'existing-role');
      });
    });

    group('field updates and debounced autosave', () {
      test('updateDraft reflects the change in state immediately, before the debounce fires', () async {
        final draftRepo = _FakeManualResumeDraftRepository();
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.updatePersonal((p) => p.copyWith(name: 'Anita'));

        expect(_ready(container).draft.personal.name, 'Anita');
        expect(draftRepo.saveCallCount, 0, reason: 'the debounce has not elapsed yet');
      });

      test('the debounced save actually persists after it elapses', () async {
        final draftRepo = _FakeManualResumeDraftRepository();
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.setTargetTitle('QA Lead');
        await Future<void>.delayed(ManualResumeBuilderController.saveDebounce + const Duration(milliseconds: 50));

        expect(draftRepo.saveCallCount, 1);
        expect(draftRepo.saved['alice']?.targetTitle, 'QA Lead');
      });

      test('rapid edits within the debounce window collapse into a single save', () async {
        final draftRepo = _FakeManualResumeDraftRepository();
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.setDomain('IT');
        controller.setDomain('IT Services');
        controller.setDomain('IT Services and Consulting');
        await Future<void>.delayed(ManualResumeBuilderController.saveDebounce + const Duration(milliseconds: 50));

        expect(draftRepo.saveCallCount, 1);
        expect(draftRepo.saved['alice']?.domain, 'IT Services and Consulting');
      });

      test('a save failure is surfaced, never silently swallowed', () async {
        final draftRepo = _FakeManualResumeDraftRepository(saveResult: const Failed(UnexpectedFailure()));
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.setSummary('Something');
        await Future<void>.delayed(ManualResumeBuilderController.saveDebounce + const Duration(milliseconds: 50));

        expect(_ready(container).saveFailed, isTrue);
      });

      test('a new edit optimistically clears a previous save-failed flag', () async {
        final draftRepo = _FakeManualResumeDraftRepository(saveResult: const Failed(UnexpectedFailure()));
        final container = await _buildContainer(draftRepository: draftRepo);
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        controller.setSummary('First');
        await Future<void>.delayed(ManualResumeBuilderController.saveDebounce + const Duration(milliseconds: 50));
        expect(_ready(container).saveFailed, isTrue);

        controller.setSummary('Second');

        expect(_ready(container).saveFailed, isFalse);
      });
    });

    group('skills', () {
      test('toggleGroupSkill adds then removes a skill', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.toggleGroupSkill('testing-tools', 'Selenium');
        expect(_ready(container).draft.skills.groups['testing-tools'], ['Selenium']);

        controller.toggleGroupSkill('testing-tools', 'Selenium');
        expect(_ready(container).draft.skills.groups['testing-tools'], isEmpty);
      });

      test('addCustomGroupSkill rejects a skill shorter than 2 characters', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        final error = controller.addCustomGroupSkill('testing-tools', 'x');

        expect(error, isNotNull);
        expect(_ready(container).draft.skills.groups['testing-tools'] ?? const [], isEmpty);
      });

      test('addCustomGroupSkill accepts a valid skill and never duplicates it case-insensitively', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        expect(controller.addCustomGroupSkill('testing-tools', 'Cypress'), isNull);
        expect(controller.addCustomGroupSkill('testing-tools', 'cypress'), isNull);

        expect(_ready(container).draft.skills.groups['testing-tools'], ['Cypress']);
      });

      test('setOtherSkillsText splits and dedupes like the server would', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.setOtherSkillsText('Jira, Jira, Confluence\nSlack');

        expect(_ready(container).draft.skills.other, ['Jira', 'Confluence', 'Slack']);
      });
    });

    group('repeatable entries', () {
      test('addEmployment appends a blank entry, up to kMaxItems', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        for (var i = 0; i < kMaxItems + 5; i++) {
          controller.addEmployment();
        }

        expect(_ready(container).draft.employment, hasLength(kMaxItems));
      });

      test('updateEmployment edits only the targeted entry', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        controller.addEmployment();
        controller.addEmployment();

        controller.updateEmployment(1, (e) => e.copyWith(title: 'Engineer'));

        final employment = _ready(container).draft.employment;
        expect(employment[0].title, '');
        expect(employment[1].title, 'Engineer');
      });

      test('removeEmployment removes the targeted entry', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        controller.addEmployment();
        controller.updateEmployment(0, (e) => e.copyWith(title: 'Engineer'));

        controller.removeEmployment(0);

        expect(_ready(container).draft.employment, isEmpty);
      });

      test('addProjectNamed creates a project pre-filled with the suggestion', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.addProjectNamed('Portfolio website');

        expect(_ready(container).draft.projects.single.name, 'Portfolio website');
      });

      test('appendEmploymentBulletSuggestion appends as a new line, never duplicating an existing one', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        controller.addEmployment();
        controller.updateEmployment(0, (e) => e.copyWith(bullets: 'Wrote unit tests'));

        controller.appendEmploymentBulletSuggestion(0, 'Reviewed code');
        controller.appendEmploymentBulletSuggestion(0, 'wrote unit tests'); // case-insensitive duplicate

        expect(_ready(container).draft.employment.single.bullets, 'Wrote unit tests\nReviewed code');
      });
    });

    group('summary helpers', () {
      test('appendAchievementSuggestion appends once, not twice', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.appendAchievementSuggestion('Completed training ahead of schedule');
        controller.appendAchievementSuggestion('Completed training ahead of schedule');

        expect(_ready(container).draft.achievements, 'Completed training ahead of schedule');
      });

      test('fillPlaceholders substitutes known tokens from data already on the draft', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        controller.setYears('4');
        controller.setDomain('fintech');
        controller.setSummary('Professional with [X] years in [industry or domain].');

        controller.fillPlaceholders();

        expect(_ready(container).draft.summary, 'Professional with 4 years in fintech.');
      });
    });

    group('touched / review', () {
      test('markTouched reveals that field\'s error without affecting others', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();

        controller.markTouched('personal.name');

        final state = _ready(container);
        expect(state.touched, {'personal.name'});
        expect(state.visibleErrors.map((e) => e.field), contains('personal.name'));
        expect(state.visibleErrors.map((e) => e.field), isNot(contains('personal.email')));
      });

      test('reviewAll makes every error visible and jumps to the first one\'s step', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        await controller.goToStep(5);

        final firstError = controller.reviewAll();

        expect(firstError, isNotNull);
        expect(_ready(container).showAllErrors, isTrue);
        expect(_ready(container).draft.currentStep, firstError!.step);
      });

      test('reviewAll on an already-valid draft returns null and changes nothing about the step', () async {
        final container = await _buildContainer();
        addTearDown(container.dispose);
        final controller = container.read(manualResumeBuilderControllerProvider.notifier);
        await controller.load();
        // `setRoleIfBlank` only resolves the full `ResumeRole` object (needed
        // by validation's own role-null check) when the draft's role is
        // still blank — it must run before anything else sets `draft.role`.
        controller.setRoleIfBlank(_role);
        controller.updateDraft(
          (d) => d.copyWith(
            level: '1-3',
            personal: const ManualResumePersonalInfo(name: 'Anita Sharma', email: 'a@example.com', phone: '9876543210'),
            skills: const ManualResumeSkills(groups: {'testing-tools': ['Selenium']}),
            employment: const [ManualResumeJobEntry(title: 'QA Engineer', company: 'Acme')],
            education: const [ManualResumeEducationEntry(degree: 'B.Tech')],
          ),
        );

        final firstError = controller.reviewAll();

        expect(firstError, isNull);
      });
    });

    test('clearDraft() resets to a blank draft, removes it from storage, and cancels a pending save', () async {
      final draftRepo = _FakeManualResumeDraftRepository(
        loadResult: Success(ManualResumeDraft.blank().copyWith(role: 'some-role', currentStep: 3)),
      );
      final container = await _buildContainer(draftRepository: draftRepo);
      addTearDown(container.dispose);
      final controller = container.read(manualResumeBuilderControllerProvider.notifier);
      await controller.load();
      controller.setSummary('About to be cleared'); // schedules a debounced save

      await controller.clearDraft();
      await Future<void>.delayed(ManualResumeBuilderController.saveDebounce + const Duration(milliseconds: 50));

      final state = _ready(container);
      expect(state.draft.role, '');
      expect(state.draft.currentStep, kManualResumeFirstStep);
      expect(draftRepo.clearCallCount, 1);
      expect(draftRepo.saved['alice'], isNull, reason: 'the pending debounced save must not resurrect the cleared draft');
    });
  });
}
