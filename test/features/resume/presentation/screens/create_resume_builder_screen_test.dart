import 'package:career_buddy_lms/app/router/route_paths.dart';
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
import 'package:career_buddy_lms/features/resume/domain/repositories/create_resume_guest_draft_repository.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/create_resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/create_resume_builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoredUser});

  final AuthUser? restoredUser;

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
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({
    required String email,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async =>
      throw UnimplementedError();
}

class _FakeCreateResumeRepository implements CreateResumeRepository {
  @override
  Future<Result<int>> saveDraft(CreateResumeFormState state) async =>
      const Success(1);
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

class _FakeCreateResumeGuestDraftRepository
    implements CreateResumeGuestDraftRepository {
  _FakeCreateResumeGuestDraftRepository({this.saveResult, this.loadResult});

  Result<void>? saveResult;
  Result<CreateResumeFormState?>? loadResult;

  @override
  Future<Result<void>> saveDraft(CreateResumeFormState form) async =>
      saveResult ?? const Success(null);
  @override
  Future<Result<CreateResumeFormState?>> loadDraft() async =>
      loadResult ?? const Success(null);
  @override
  Future<Result<void>> clearDraft() async => const Success(null);
}

Future<void> _pump(
  WidgetTester tester, {
  AuthUser? authUser,
  Result<void>? guestSaveResult,
  Result<CreateResumeFormState?>? guestLoadResult,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(restoredUser: authUser),
      ),
      createResumeRepositoryProvider.overrideWithValue(
        _FakeCreateResumeRepository(),
      ),
      createResumeGuestDraftRepositoryProvider.overrideWithValue(
        _FakeCreateResumeGuestDraftRepository(
          saveResult: guestSaveResult,
          loadResult: guestLoadResult,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Settle AuthController's build()-time restoreSession() first — same
  // reasoning as `manual_resume_builder_screen_test.dart`'s own `_pump`
  // helper: a bare `Future.delayed` never fires under `flutter_test`'s
  // fake clock without `tester.runAsync`.
  container.read(authControllerProvider);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));

  final router = GoRouter(
    initialLocation: '/create-resume',
    routes: [
      GoRoute(
        path: '/create-resume',
        builder: (_, _) => const CreateResumeBuilderScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, _) => const Scaffold(body: Text('Login Screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('CreateResumeBuilderScreen — Phase 42 guest-save experience', () {
    testWidgets(
      'an authenticated save shows the plain "Saved." banner, never the guest prompt',
      (tester) async {
        await _pump(tester, authUser: const AuthUser(username: 'alice'));

        await tester.tap(find.byKey(const Key('wizard-save-button')));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('save-success-banner')), findsOneWidget);
        expect(find.byKey(const Key('save-success-guest-banner')), findsNothing);
        expect(find.text('Saved.'), findsOneWidget);
      },
    );

    testWidgets(
      'a guest save shows the local-save message with a Sign in action, not "Saved."',
      (tester) async {
        await _pump(tester); // no authUser — guest

        await tester.tap(find.byKey(const Key('wizard-save-button')));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('save-success-guest-banner')), findsOneWidget);
        expect(find.byKey(const Key('save-success-banner')), findsNothing);
        expect(find.text('Draft saved on this device.'), findsOneWidget);
        expect(
          find.byKey(const Key('save-success-guest-sign-in-button')),
          findsOneWidget,
        );
        // Never the misleading message a real expired session would show.
        expect(find.textContaining('session'), findsNothing);
      },
    );

    testWidgets(
      'tapping the guest Sign in action navigates to the login screen',
      (tester) async {
        await _pump(tester);

        await tester.tap(find.byKey(const Key('wizard-save-button')));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(const Key('save-success-guest-sign-in-button')));
        await tester.pumpAndSettle();

        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'a guest local-save failure shows the error banner, never a success banner',
      (tester) async {
        await _pump(
          tester,
          guestSaveResult: const Failed(
            UnexpectedFailure('Could not save the resume draft on this device.'),
          ),
        );

        await tester.tap(find.byKey(const Key('wizard-save-button')));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('save-failed-banner')), findsOneWidget);
        expect(
          find.text('Could not save the resume draft on this device.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('save-success-guest-banner')), findsNothing);
        expect(find.byKey(const Key('save-success-banner')), findsNothing);
      },
    );
  });

  group('CreateResumeBuilderScreen — Phase 45 guest draft restoration', () {
    const savedDraft = CreateResumeFormState(
      personal: CreateResumePersonalInfo(name: 'Restored Candidate'),
      summary: 'Restored summary.',
    );

    testWidgets(
      'a guest with a saved local draft sees it restored with a confirmation banner',
      (tester) async {
        await _pump(tester, guestLoadResult: const Success(savedDraft));
        await tester.pump();

        expect(find.byKey(const Key('restored-local-draft-banner')), findsOneWidget);
        expect(
          find.text('Restored the draft saved on this device.'),
          findsOneWidget,
        );
        expect(find.text('Restored Candidate'), findsOneWidget);
      },
    );

    testWidgets(
      'a guest with no saved draft sees the normal blank builder, no banner',
      (tester) async {
        await _pump(tester); // no guestLoadResult override — defaults to "no draft"
        await tester.pump();

        expect(find.byKey(const Key('restored-local-draft-banner')), findsNothing);
      },
    );

    testWidgets(
      'an authenticated user never sees the restored-draft banner',
      (tester) async {
        await _pump(
          tester,
          authUser: const AuthUser(username: 'alice'),
          guestLoadResult: const Success(savedDraft),
        );
        await tester.pump();

        expect(find.byKey(const Key('restored-local-draft-banner')), findsNothing);
        expect(find.text('Restored Candidate'), findsNothing);
      },
    );

    testWidgets(
      'tapping Sign in from the restored-draft banner navigates to the login screen',
      (tester) async {
        await _pump(tester, guestLoadResult: const Success(savedDraft));
        await tester.pump();

        await tester.tap(find.byKey(const Key('restored-local-draft-sign-in-button')));
        await tester.pumpAndSettle();

        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'saving after a restore replaces the restored banner with the normal guest-save banner',
      (tester) async {
        await _pump(tester, guestLoadResult: const Success(savedDraft));
        await tester.pump();
        expect(find.byKey(const Key('restored-local-draft-banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('wizard-save-button')));
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('restored-local-draft-banner')), findsNothing);
        expect(find.byKey(const Key('save-success-guest-banner')), findsOneWidget);
      },
    );
  });
}
