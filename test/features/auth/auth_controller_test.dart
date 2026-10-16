import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/employer_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/employer_auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:career_buddy_lms/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:career_buddy_lms/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/level_common_suggestions.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_completeness.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_document.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_page_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_pdf_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_role.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/manual_resume_draft_repository.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/domain/validation/manual_resume_validation.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_page_preview_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_pdf_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/manual_resume_preview_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser, this.loginResult});

  AuthUser? restoredUser;
  Result<AuthUser>? loginResult;

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    return loginResult!;
  }

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

class _FakeEmployerAuthRepository implements EmployerAuthRepository {
  _FakeEmployerAuthRepository({this.loginResult, this.registerResult});

  Result<AuthUser>? loginResult;
  Result<AuthUser>? registerResult;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    return loginResult!;
  }

  @override
  Future<Result<String>> sendOtp(String email) async =>
      throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(EmployerRegistrationData data) async =>
      registerResult!;
}

class _FakeDashboardRepository implements DashboardRepository {
  int callCount = 0;

  @override
  Future<Result<DashboardData>> getDashboard() async {
    callCount++;
    return Success(
      DashboardData(
        stats: DashboardStats(
          completedCount: callCount,
          inProgressCount: 0,
          totalActivities: 0,
          totalScore: 0,
        ),
        activities: const [],
        recentResults: const [],
        recommendedJobs: const [],
        paymentHistory: const [],
      ),
    );
  }
}

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({
    this.previewResult,
    this.pagePreviewResult,
    this.pdfResult,
  });

  Result<ManualResumePreviewOutcome>? previewResult;
  Result<ManualResumePagePreviewOutcome>? pagePreviewResult;
  Result<ManualResumePdfOutcome>? pdfResult;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async => throw UnimplementedError();

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async =>
      const Success(
        ResumeAnalysisResult(
          analysis: ResumeAnalysis(
            matchPercentage: 60,
            matchingSkills: [],
            missingSkills: [],
            summary: '',
            careerAdvice: [],
          ),
          isAtsOnly: true,
          yearsExperience: 0.0,
          canInterview: false,
        ),
      );

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async =>
      throw UnimplementedError();

  @override
  Future<ResumeParseQuota?> getParseQuota() async => null;

  @override
  Future<Result<List<ResumeRole>>> getRoles() async => const Success([]);

  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async => throw UnimplementedError();

  @override
  Future<Result<Map<String, LevelCommonSuggestions>>>
  getLevelCommonSuggestions() async => const Success({});

  @override
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(
    ManualResumeDraft draft,
  ) async => previewResult ?? const Failed(UnexpectedFailure());

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(
    ManualResumeDraft draft,
  ) async => pagePreviewResult ?? const Failed(UnexpectedFailure());

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(
    ManualResumeDraft draft,
  ) async => pdfResult ?? const Failed(UnexpectedFailure());
}

class _FakeManualResumeDraftRepository implements ManualResumeDraftRepository {
  final Map<String, ManualResumeDraft> _store = {};

  @override
  Future<Result<ManualResumeDraft?>> loadDraft(String username) async =>
      Success(_store[username]);

  @override
  Future<Result<void>> saveDraft(
    String username,
    ManualResumeDraft draft,
  ) async {
    _store[username] = draft;
    return const Success(null);
  }

  @override
  Future<Result<void>> clearDraft(String username) async {
    _store.remove(username);
    return const Success(null);
  }
}

const _sampleRegistration = EmployerRegistrationData(
  username: 'acmehr',
  password: 'Abcdef1!',
  passwordConfirm: 'Abcdef1!',
  email: 'acct@acme.com',
  firstName: 'Jane',
  lastName: 'Doe',
  companyName: 'Acme Corp',
  industry: 'it_software',
  hrContactE164: '+919876543210',
  hrMail: 'hr@acme.com',
);

/// Builds the controller and waits for its `build()`-time `restoreSession()`
/// call to settle, so tests start from a known, resolved state rather than
/// racing that pending future.
Future<ProviderContainer> _readyContainer(
  AuthRepository repo, [
  EmployerAuthRepository? employerRepo,
]) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      if (employerRepo != null)
        employerAuthRepositoryProvider.overrideWithValue(employerRepo),
    ],
  );
  container.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  group('AuthController', () {
    test(
      'resolves to AuthUnauthenticated when there is no cached session',
      () async {
        final container = await _readyContainer(_FakeAuthRepository());
        addTearDown(container.dispose);

        expect(
          container.read(authControllerProvider),
          isA<AuthUnauthenticated>(),
        );
      },
    );

    test('resolves to AuthAuthenticated when a session is cached', () async {
      const cachedUser = AuthUser(username: 'jane');
      final container = await _readyContainer(
        _FakeAuthRepository(restoredUser: cachedUser),
      );
      addTearDown(container.dispose);

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, cachedUser);
    });

    test('login() success moves state to AuthAuthenticated', () async {
      const user = AuthUser(username: 'jane');
      final container = await _readyContainer(
        _FakeAuthRepository(loginResult: const Success(user)),
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .login(usernameOrEmail: 'jane', password: 'secret');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, user);
    });

    test(
      'login() failure moves state to AuthUnauthenticated with the failure message',
      () async {
        final container = await _readyContainer(
          _FakeAuthRepository(loginResult: const Failed(UnauthorizedFailure())),
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .login(usernameOrEmail: 'jane', password: 'wrong');

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthUnauthenticated>());
        expect(
          (state as AuthUnauthenticated).errorMessage,
          const UnauthorizedFailure().message,
        );
      },
    );

    test('logout() moves state to AuthUnauthenticated', () async {
      const user = AuthUser(username: 'jane');
      final container = await _readyContainer(
        _FakeAuthRepository(restoredUser: user),
      );
      addTearDown(container.dispose);
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

      await container.read(authControllerProvider.notifier).logout();

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });

    test(
      'loginEmployer() success moves state to AuthAuthenticated with isEmployer:true',
      () async {
        const user = AuthUser(username: 'acmehr', isEmployer: true);
        final container = await _readyContainer(
          _FakeAuthRepository(),
          _FakeEmployerAuthRepository(loginResult: const Success(user)),
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .loginEmployer(usernameOrEmail: 'acmehr', password: 'secret');

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthAuthenticated>());
        expect((state as AuthAuthenticated).user, user);
        expect(state.user.isEmployer, isTrue);
      },
    );

    test(
      'loginEmployer() failure moves state to AuthUnauthenticated with the failure message',
      () async {
        const failure = ValidationFailure(
          {},
          'Invalid username or password, or this account cannot sign in here.',
        );
        final container = await _readyContainer(
          _FakeAuthRepository(),
          _FakeEmployerAuthRepository(loginResult: const Failed(failure)),
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .loginEmployer(usernameOrEmail: 'acmehr', password: 'wrong');

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthUnauthenticated>());
        expect((state as AuthUnauthenticated).errorMessage, failure.message);
      },
    );

    test(
      'registerEmployer() success moves state to AuthAuthenticated with isEmployer:true',
      () async {
        const user = AuthUser(username: 'acmehr', isEmployer: true);
        final container = await _readyContainer(
          _FakeAuthRepository(),
          _FakeEmployerAuthRepository(registerResult: const Success(user)),
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .registerEmployer(_sampleRegistration);

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthAuthenticated>());
        expect((state as AuthAuthenticated).user, user);
      },
    );

    test(
      'registerEmployer() failure moves state to AuthUnauthenticated with the failure message',
      () async {
        const failure = ValidationFailure({}, 'Registration failed.');
        final container = await _readyContainer(
          _FakeAuthRepository(),
          _FakeEmployerAuthRepository(registerResult: const Failed(failure)),
        );
        addTearDown(container.dispose);

        await container
            .read(authControllerProvider.notifier)
            .registerEmployer(_sampleRegistration);

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthUnauthenticated>());
        expect((state as AuthUnauthenticated).errorMessage, failure.message);
      },
    );

    test(
      'logout() then a new login() invalidates user-scoped providers (e.g. Dashboard), so a different '
      'account never sees the previous account\'s cached data',
      () async {
        // Confirmed live, on-device, with two real production accounts in
        // the same app session: without this invalidation, every
        // `AsyncNotifierProvider`-based controller (Dashboard, Profile,
        // Resume history, Employer Dashboard, etc.) stays alive in the
        // single app-wide `ProviderContainer` for the process's lifetime —
        // logging out and back in as someone else showed the PREVIOUS
        // account's Dashboard stats verbatim under the new account's name.
        final dashboardRepo = _FakeDashboardRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(restoredUser: const AuthUser(username: 'a')),
            ),
            dashboardRepositoryProvider.overrideWithValue(dashboardRepo),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);

        // User A's Dashboard is fetched and cached.
        final firstFetch = await container.read(
          dashboardControllerProvider.future,
        );
        expect(firstFetch.stats.completedCount, 1);
        expect(dashboardRepo.callCount, 1);

        // Re-reading without any session change must NOT refetch — this is
        // the normal, desired caching behavior the fix must not break.
        await container.read(dashboardControllerProvider.future);
        expect(dashboardRepo.callCount, 1);

        await container.read(authControllerProvider.notifier).logout();

        // User B logs in. The stale Dashboard data from User A must be gone
        // — reading it again must trigger a genuine refetch, not serve the
        // old cached value.
        final authRepo = _FakeAuthRepository(
          loginResult: const Success(AuthUser(username: 'b')),
        );
        container.updateOverrides([
          authRepositoryProvider.overrideWithValue(authRepo),
          dashboardRepositoryProvider.overrideWithValue(dashboardRepo),
        ]);
        await container
            .read(authControllerProvider.notifier)
            .login(usernameOrEmail: 'b', password: 'secret');

        final secondFetch = await container.read(
          dashboardControllerProvider.future,
        );
        expect(
          dashboardRepo.callCount,
          2,
          reason:
              'Dashboard must refetch for the new account, not serve User A\'s cached data',
        );
        expect(secondFetch.stats.completedCount, 2);
      },
    );

    test(
      'logout() also resets plain Notifier-based user-scoped controllers (e.g. Resume Builder), '
      'not just AsyncNotifier ones',
      () async {
        // Release audit (Phase 5) — `resumeBuilderControllerProvider` (and
        // several sibling controllers: Mock Interview, GD/JAM live session,
        // AMCAT/CoCubes/OOP/subject-quiz, and every per-exercise-type
        // controller) were added in later batches and were missing from
        // `_invalidateUserScopedProviders()` — the exact same bug class the
        // Dashboard test above guards against, just for a plain `Notifier`
        // instead of an `AsyncNotifier`. This guards one representative
        // case of that fix.
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(restoredUser: const AuthUser(username: 'a')),
            ),
            resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository()),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);

        // User A analyzes a resume — real result state now cached.
        await container
            .read(resumeBuilderControllerProvider.notifier)
            .reanalyze(42);
        expect(
          container.read(resumeBuilderControllerProvider),
          isA<ResumeResultState>(),
        );

        await container.read(authControllerProvider.notifier).logout();

        // User A's stale analysis must not survive into the next session —
        // reading it fresh after logout must be back to the initial state,
        // not the leftover result.
        expect(
          container.read(resumeBuilderControllerProvider),
          isA<ResumeIdle>(),
          reason:
              'A previous account\'s resume analysis must not leak into the next session',
        );
      },
    );

    test(
      "logout() also resets the Manual Resume Builder's in-memory draft (Phase 25) — the same "
      'cross-account leak class as the Resume Builder case above, for a draft that can contain a '
      "candidate's name, phone number and employment history",
      () async {
        final draftRepo = _FakeManualResumeDraftRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(restoredUser: const AuthUser(username: 'a')),
            ),
            manualResumeDraftRepositoryProvider.overrideWithValue(draftRepo),
            resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository()),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);

        await container
            .read(manualResumeBuilderControllerProvider.notifier)
            .load();
        await container
            .read(manualResumeBuilderControllerProvider.notifier)
            .goToStep(3);
        final beforeLogout = container.read(
          manualResumeBuilderControllerProvider,
        );
        expect(beforeLogout, isA<ManualResumeBuilderReady>());
        expect((beforeLogout as ManualResumeBuilderReady).draft.currentStep, 3);

        await container.read(authControllerProvider.notifier).logout();

        expect(
          container.read(manualResumeBuilderControllerProvider),
          isA<ManualResumeBuilderLoading>(),
          reason:
              "A previous account's in-progress draft (name/phone/employment history) must not "
              'leak into the next session',
        );
      },
    );

    // Phase 30 — the Phase 29 audit found that, unlike the Manual Resume
    // Builder case above (which has its own explicit regression test),
    // `manualResumePreviewControllerProvider`, `manualResumePagePreviewControllerProvider`,
    // and `manualResumePdfControllerProvider` were only ever *listed* in
    // `_invalidateUserScopedProviders()` (Phase 27/28), never individually
    // verified by name. Each of these can hold the same kind of
    // candidate-identifying content (an assembled resume document, decoded
    // page images, or a generated PDF's bytes) as the draft itself, so they
    // need the identical cross-account protection, by the same mechanism.
    test(
      "logout() also resets the Manual Resume Builder's structured-document preview controller "
      '(Phase 27) — the same cross-account leak class as the draft itself',
      () async {
        const readyOutcome = ManualResumePreviewReady(
          document: ManualResumeDocument(
            name: 'Alice',
            title: 'QA Engineer',
            contact: [],
            level: '1-3',
            levelLabel: '1–3 Years',
            role: 'QA Engineer',
            sections: [],
          ),
          warnings: [],
          completeness: ManualResumeCompletenessSummary(
            overall: 50,
            categories: [],
          ),
          filename: 'resume.pdf',
        );
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(restoredUser: const AuthUser(username: 'a')),
            ),
            manualResumeDraftRepositoryProvider.overrideWithValue(
              _FakeManualResumeDraftRepository(),
            ),
            resumeRepositoryProvider.overrideWithValue(
              _FakeResumeRepository(previewResult: const Success(readyOutcome)),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await container
            .read(manualResumeBuilderControllerProvider.notifier)
            .load();

        await container
            .read(manualResumePreviewControllerProvider.notifier)
            .generate(ManualResumeDraft.blank());
        expect(
          container.read(manualResumePreviewControllerProvider),
          isA<ManualResumePreviewReadyState>(),
        );

        await container.read(authControllerProvider.notifier).logout();

        expect(
          container.read(manualResumePreviewControllerProvider),
          isA<ManualResumePreviewIdle>(),
          reason:
              "A previous account's assembled resume document must not leak into the next session",
        );
      },
    );

    test(
      "logout() also resets the Manual Resume Builder's page-image preview controller (Phase 28, "
      'Part A) — the same cross-account leak class as the draft itself',
      () async {
        final readyOutcome = ManualResumePagePreviewReady(
          pages: [
            Uint8List.fromList([1, 2, 3]),
          ],
          total: 1,
          filename: 'resume.pdf',
        );
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(restoredUser: const AuthUser(username: 'a')),
            ),
            manualResumeDraftRepositoryProvider.overrideWithValue(
              _FakeManualResumeDraftRepository(),
            ),
            resumeRepositoryProvider.overrideWithValue(
              _FakeResumeRepository(pagePreviewResult: Success(readyOutcome)),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await container
            .read(manualResumeBuilderControllerProvider.notifier)
            .load();

        await container
            .read(manualResumePagePreviewControllerProvider.notifier)
            .generate(ManualResumeDraft.blank());
        expect(
          container.read(manualResumePagePreviewControllerProvider),
          isA<ManualResumePagePreviewReadyState>(),
        );

        await container.read(authControllerProvider.notifier).logout();

        expect(
          container.read(manualResumePagePreviewControllerProvider),
          isA<ManualResumePagePreviewIdle>(),
          reason:
              "A previous account's decoded resume page images must not leak into the next session",
        );
      },
    );

    test(
      "logout() also resets the Manual Resume Builder's PDF controller (Phase 28, Part B) — the "
      'same cross-account leak class as the draft itself. A validation-rejection state is used here '
      '(rather than a ready/success state, which the controller already resets to idle on its own '
      'right after a successful save) because it is the one state this controller holds that '
      "persists until something else changes it — exactly the state a stale account's leftover "
      'data would look like if this invalidation were ever missing.',
      () async {
        const rejected = ManualResumePdfRejected([
          ManualResumeValidationError(
            field: 'personal.name',
            step: 1,
            message: 'Please enter your full name.',
          ),
        ]);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(restoredUser: const AuthUser(username: 'a')),
            ),
            manualResumeDraftRepositoryProvider.overrideWithValue(
              _FakeManualResumeDraftRepository(),
            ),
            resumeRepositoryProvider.overrideWithValue(
              _FakeResumeRepository(pdfResult: const Success(rejected)),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await container
            .read(manualResumeBuilderControllerProvider.notifier)
            .load();

        await container
            .read(manualResumePdfControllerProvider.notifier)
            .generateAndOpen(ManualResumeDraft.blank());
        expect(
          container.read(manualResumePdfControllerProvider),
          isA<ManualResumePdfValidationFailed>(),
        );

        await container.read(authControllerProvider.notifier).logout();

        expect(
          container.read(manualResumePdfControllerProvider),
          isA<ManualResumePdfIdle>(),
          reason:
              "A previous account's PDF-generation state must not leak into the next session",
        );
      },
    );
  });
}
