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
import 'package:career_buddy_lms/features/resume/presentation/controllers/create_resume_builder_controller.dart';
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
  CreateResumeFormState? lastSavedState;

  @override
  Future<Result<int>> saveDraft(CreateResumeFormState state) async {
    lastSavedState = state;
    return const Success(1);
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

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AuthUser? authUser,
  Result<void>? guestSaveResult,
  Result<CreateResumeFormState?>? guestLoadResult,
  _FakeCreateResumeRepository? repository,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(restoredUser: authUser),
      ),
      createResumeRepositoryProvider.overrideWithValue(
        repository ?? _FakeCreateResumeRepository(),
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
  return container;
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

  group('CreateResumeBuilderScreen — Phase 70 new resume sections', () {
    CreateResumeBuilderController controllerOf(ProviderContainer container) =>
        container.read(createResumeBuilderControllerProvider.notifier);

    // The wizard body's plain `ListView(children: [...])` is still backed
    // by a lazy sliver — widgets more than one cache-extent past the test
    // viewport's edge are never mounted, so an entry's later fields (or a
    // later section's button) can be absent from the tree until scrolled
    // into view, exactly as they would be on a real, short phone screen.
    Future<void> scrollToText(WidgetTester tester, String text, {double delta = 300}) {
      return tester.scrollUntilVisible(
        find.textContaining(text),
        delta,
        // The step body's `ListView` itself is the first `Scrollable`
        // found inside it (a pre-order ancestor of everything else there);
        // later matches belong to individual multi-line text fields' own
        // internal scrolling, and the step indicator's own horizontal
        // `SingleChildScrollView` lives outside the `ListView` entirely.
        scrollable: find
            .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
            .first,
      );
    }

    testWidgets(
      'every pre-existing step remains reachable alongside the 5 new ones, in the '
      "real site's own order",
      (tester) async {
        final container = await _pump(tester);
        final controller = controllerOf(container);

        for (final label in const [
          'Personal',
          'Summary',
          'Skills',
          'Experience',
          'Education',
          'Projects',
          'Certifications',
          'Achievements',
          'Internships & Volunteering',
          'Languages & Additional Info',
        ]) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: 'step indicator should list "$label"',
          );
        }
        expect(controller.hasUnsavedContent, isFalse);
      },
    );

    testWidgets(
      'the Projects step renders its real fields, required title and optional type',
      (tester) async {
        final container = await _pump(tester);
        controllerOf(container).goToStep(6);
        await tester.pump();

        expect(find.text('Add project'), findsOneWidget);
        await tester.tap(find.text('Add project'));
        await tester.pump();

        expect(find.textContaining('Project title'), findsOneWidget);
        expect(find.textContaining('Project type'), findsOneWidget);
        expect(find.textContaining('Project overview'), findsOneWidget);
      },
    );

    testWidgets(
      'adding two Project entries and editing the first never overwrites the second',
      (tester) async {
        final container = await _pump(tester);
        final controller = controllerOf(container);
        controller.goToStep(6);
        await tester.pump();

        await tester.tap(find.text('Add project'));
        await tester.pump();
        await scrollToText(tester, 'Add another project');
        await tester.tap(find.text('Add another project'));
        await tester.pump();

        controller.updateProject(0, (e) => e.copyWith(title: 'First Project'));
        await tester.pump();

        final state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.projects[0].title, 'First Project');
        expect(
          state.form.projects[1].title,
          isEmpty,
          reason: 'editing entry 0 must never leak into entry 1',
        );
      },
    );

    testWidgets(
      'removing one Project entry keeps the other entries intact',
      (tester) async {
        final container = await _pump(tester);
        final controller = controllerOf(container);
        controller.goToStep(6);
        controller.addProject();
        controller.addProject();
        controller.updateProject(0, (e) => e.copyWith(title: 'Keep me'));
        controller.updateProject(1, (e) => e.copyWith(title: 'Remove me'));
        await tester.pump();

        controller.removeProject(1);
        await tester.pump();

        final state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.projects, hasLength(1));
        expect(state.form.projects.single.title, 'Keep me');
      },
    );

    testWidgets(
      'data entered on the Projects step survives navigating away and back',
      (tester) async {
        final container = await _pump(tester);
        final controller = controllerOf(container);
        controller.goToStep(6);
        controller.addProject();
        controller.updateProject(0, (e) => e.copyWith(title: 'Persisted Project'));
        await tester.pump();

        controller.goToStep(1); // Personal
        await tester.pump();
        controller.goToStep(6); // back to Projects
        await tester.pump();

        // Matches twice by design: the entry card's own title header (set
        // from the entry's `title` once non-blank) and the editable field
        // itself both now show the same text.
        expect(find.text('Persisted Project'), findsNWidgets(2));
        final state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.projects.single.title, 'Persisted Project');
      },
    );

    testWidgets(
      'the Certifications step renders its real required fields (name, issuer)',
      (tester) async {
        final container = await _pump(tester);
        controllerOf(container).goToStep(7);
        await tester.pump();

        await tester.tap(find.text('Add certification'));
        await tester.pump();

        expect(find.textContaining('Certification / course name'), findsOneWidget);
        expect(find.textContaining('Issuing organisation'), findsOneWidget);
      },
    );

    testWidgets(
      'the Achievements step renders its real required field (title)',
      (tester) async {
        final container = await _pump(tester);
        controllerOf(container).goToStep(8);
        await tester.pump();

        await tester.tap(find.text('Add achievement'));
        await tester.pump();

        expect(find.textContaining('Achievement title'), findsOneWidget);
      },
    );

    testWidgets(
      'the Internships & Volunteering step renders both sub-sections as one combined tab, '
      'matching the real site\'s own single-tab structure',
      (tester) async {
        final container = await _pump(tester);
        controllerOf(container).goToStep(9);
        await tester.pump();

        expect(find.text('Internships'), findsOneWidget);
        expect(find.text('Volunteering'), findsOneWidget);
        expect(find.text('Add internship'), findsOneWidget);
        expect(find.text('Add volunteering'), findsOneWidget);
      },
    );

    testWidgets(
      'adding an internship never adds a volunteering entry, and vice versa',
      (tester) async {
        final container = await _pump(tester);
        final controller = controllerOf(container);
        controller.goToStep(9);
        await tester.pump();

        await tester.tap(find.text('Add internship'));
        await tester.pump();

        var state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.internships, hasLength(1));
        expect(state.form.volunteering, isEmpty);

        await scrollToText(tester, 'Add volunteering');
        await tester.tap(find.text('Add volunteering'));
        await tester.pump();

        state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.internships, hasLength(1));
        expect(state.form.volunteering, hasLength(1));
      },
    );

    testWidgets(
      'the Languages & Additional Information step renders the combined tab exactly as the '
      'real site structures it: a repeatable Languages list plus flat Additional fields',
      (tester) async {
        final container = await _pump(tester);
        controllerOf(container).goToStep(10);
        await tester.pump();

        expect(find.text('Languages'), findsOneWidget);
        expect(find.text('Add language'), findsOneWidget);
        expect(find.text('Additional information'), findsOneWidget);
        expect(find.textContaining('Professional memberships'), findsOneWidget);
        await scrollToText(tester, 'Publications');
        expect(find.textContaining('Publications'), findsOneWidget);
        await scrollToText(tester, 'Hobbies & interests');
        expect(find.textContaining('Hobbies & interests'), findsOneWidget);

        await scrollToText(tester, 'Add language', delta: -300);
        await tester.tap(find.text('Add language'));
        await tester.pump();
        expect(find.textContaining('Language'), findsWidgets);
        expect(find.textContaining('Proficiency'), findsOneWidget);
      },
    );

    testWidgets(
      'typing into an Additional Information field updates the shared form state',
      (tester) async {
        final container = await _pump(tester);
        final controller = controllerOf(container);
        controller.goToStep(10);
        await tester.pump();

        controller.updateAdditional((a) => a.copyWith(hobbies: 'Chess, reading'));
        await tester.pump();

        final state =
            container.read(createResumeBuilderControllerProvider)
                as CreateResumeBuilderReady;
        expect(state.form.additional.hobbies, 'Chess, reading');
      },
    );

    testWidgets(
      'saving a form with Phase 70 section data carries it through the existing save path, '
      'through the server\'s own field names',
      (tester) async {
        final repository = _FakeCreateResumeRepository();
        final container = await _pump(
          tester,
          authUser: const AuthUser(username: 'alice'),
          repository: repository,
        );
        final controller = controllerOf(container);
        controller.addProject();
        controller.updateProject(0, (e) => e.copyWith(title: 'Saved Project'));
        controller.addLanguage();
        controller.updateLanguage(0, (e) => e.copyWith(name: 'German', proficiency: 'Basic'));
        await tester.pump();

        await tester.tap(find.byKey(const Key('wizard-save-button')));
        await tester.pump();
        await tester.pump();

        expect(repository.lastSavedState, isNotNull);
        expect(repository.lastSavedState!.projects.single.title, 'Saved Project');
        expect(repository.lastSavedState!.languages.single.name, 'German');
        final requestJson = repository.lastSavedState!.toRequestJson();
        expect(
          (requestJson['projects'] as List).single,
          containsPair('title', 'Saved Project'),
        );
        expect(
          (requestJson['languages'] as List).single,
          containsPair('name', 'German'),
        );
      },
    );

    testWidgets(
      'a narrow phone-width viewport shows no layout overflow on the busiest new step',
      (tester) async {
        final originalSize = tester.view.physicalSize;
        final originalRatio = tester.view.devicePixelRatio;
        addTearDown(() {
          tester.view.physicalSize = originalSize;
          tester.view.devicePixelRatio = originalRatio;
        });
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(320, 640); // narrowest common phone width

        final container = await _pump(tester);
        // The combined Internships & Volunteering tab has the longest step
        // label and the most fields on screen at once — the most likely
        // place a narrow layout would overflow.
        controllerOf(container).goToStep(9);
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
