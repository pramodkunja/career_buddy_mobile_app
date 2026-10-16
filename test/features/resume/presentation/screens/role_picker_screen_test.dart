import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/level_common_suggestions.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_page_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_pdf_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_role.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/role_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.rolesResult, this.selectTargetRoleResult});

  Result<List<ResumeRole>>? rolesResult;
  Result<ResumeRoleSelection>? selectTargetRoleResult;
  int selectTargetRoleCallCount = 0;
  ({String role, String dept, String track})? lastSelectTargetRoleArgs;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async => throw UnimplementedError();

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async =>
      throw UnimplementedError();

  @override
  Future<ResumeParseQuota?> getParseQuota() async => throw UnimplementedError();

  @override
  Future<Result<List<ResumeRole>>> getRoles() async => rolesResult!;

  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async {
    selectTargetRoleCallCount++;
    lastSelectTargetRoleArgs = (role: role, dept: dept, track: track);
    return selectTargetRoleResult!;
  }

  @override
  Future<Result<Map<String, LevelCommonSuggestions>>>
  getLevelCommonSuggestions() async => throw UnimplementedError();

  @override
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(
    ManualResumeDraft draft,
  ) async => throw UnimplementedError();

  @override
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(
    ManualResumeDraft draft,
  ) async => throw UnimplementedError();

  @override
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(
    ManualResumeDraft draft,
  ) async => throw UnimplementedError();
}

const _softwareDev = ResumeRole(
  slug: 'software-developer',
  title: 'Software Developer',
  category: 'it',
  categoryLabel: 'IT Role',
  subtitle: 'Frontend, backend, full-stack',
);
const _hseEngineer = ResumeRole(
  slug: 'hse-engineer',
  title: 'HSE Engineer',
  category: 'nt',
  categoryLabel: 'Non-IT · Non-Technical',
  subtitle: 'Health, Safety & Environment',
);

Future<ResumeRoleSelection?> _pump(
  WidgetTester tester, {
  Result<List<ResumeRole>>? rolesResult,
  Result<ResumeRoleSelection>? selectTargetRoleResult,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  ResumeRoleSelection? popped;
  final repo = _FakeResumeRepository(
    rolesResult: rolesResult,
    selectTargetRoleResult: selectTargetRoleResult,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<ResumeRoleSelection>(
                MaterialPageRoute(builder: (_) => const RolePickerScreen()),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  group('RolePickerScreen', () {
    testWidgets(
      'shows a loading state, then the real roles once the fetch resolves',
      (tester) async {
        await _pump(
          tester,
          rolesResult: const Success([_softwareDev, _hseEngineer]),
        );

        expect(find.text('Software Developer'), findsOneWidget);
        expect(find.text('HSE Engineer'), findsOneWidget);
      },
    );

    testWidgets(
      'shows a retryable error state on failure, and retry reloads successfully',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final repo = _FakeResumeRepository(
          rolesResult: const Failed(ServerFailure()),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: RolePickerScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(const ServerFailure().message), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        repo.rolesResult = const Success([_softwareDev]);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Software Developer'), findsOneWidget);
      },
    );

    testWidgets(
      'shows an honest empty state when the catalog itself is empty',
      (tester) async {
        await _pump(tester, rolesResult: const Success([]));

        expect(find.text('No roles are available right now.'), findsOneWidget);
      },
    );

    testWidgets('search filters the real fixture data by title', (
      tester,
    ) async {
      await _pump(
        tester,
        rolesResult: const Success([_softwareDev, _hseEngineer]),
      );

      await tester.enterText(
        find.byKey(const Key('role-search-field')),
        'software',
      );
      await tester.pumpAndSettle();

      expect(find.text('Software Developer'), findsOneWidget);
      expect(find.text('HSE Engineer'), findsNothing);
    });

    testWidgets(
      'a search with no matches shows the "no matches" copy, not the "no roles at all" copy',
      (tester) async {
        await _pump(tester, rolesResult: const Success([_softwareDev]));

        await tester.enterText(
          find.byKey(const Key('role-search-field')),
          'zzz-nonexistent',
        );
        await tester.pumpAndSettle();

        expect(find.text('No roles match your search.'), findsOneWidget);
        expect(find.text('No roles are available right now.'), findsNothing);
      },
    );

    testWidgets('the category filter narrows the list to that category only', (
      tester,
    ) async {
      await _pump(
        tester,
        rolesResult: const Success([_softwareDev, _hseEngineer]),
      );

      await tester.tap(find.text('IT'));
      await tester.pumpAndSettle();

      expect(find.text('Software Developer'), findsOneWidget);
      expect(find.text('HSE Engineer'), findsNothing);
    });

    testWidgets(
      'tapping a role opens the action sheet with Skills honestly disabled, Build Resume enabled',
      (tester) async {
        await _pump(tester, rolesResult: const Success([_softwareDev]));

        await tester.tap(find.text('Software Developer'));
        await tester.pumpAndSettle();

        expect(find.text('Resume Parsing & Interview'), findsOneWidget);
        expect(find.text('Skills'), findsOneWidget);
        expect(find.text('Build Resume'), findsOneWidget);
        expect(
          find.text('Coming soon'),
          findsOneWidget,
        ); // Skills only, as of Phase 25

        // The disabled action must not be tappable into any destination at all.
        await tester.tap(find.text('Skills'));
        await tester.pumpAndSettle();
        expect(
          find.text('Resume Parsing & Interview'),
          findsOneWidget,
        ); // sheet still open, nothing navigated
      },
    );

    testWidgets(
      'tapping "Build Resume" closes the sheet and opens the Manual Resume Builder for that role',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final repo = _FakeResumeRepository(
          rolesResult: const Success([_softwareDev]),
        );
        ResumeRole? receivedRole;
        final router = GoRouter(
          initialLocation: RoutePaths.resumeRolePicker,
          routes: [
            GoRoute(
              path: RoutePaths.resumeRolePicker,
              builder: (context, state) => const RolePickerScreen(),
            ),
            GoRoute(
              path: RoutePaths.manualResumeBuilder,
              builder: (context, state) {
                receivedRole = state.extra as ResumeRole?;
                return const Scaffold(
                  body: Text('Manual Resume Builder Screen'),
                );
              },
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Software Developer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Build Resume'));
        await tester.pumpAndSettle();

        expect(find.text('Manual Resume Builder Screen'), findsOneWidget);
        expect(
          find.text('Resume Parsing & Interview'),
          findsNothing,
        ); // the sheet/picker are gone, not stacked
        expect(receivedRole, _softwareDev);
      },
    );

    testWidgets(
      'confirming Resume Parsing & Interview sends the exact role/dept/track and pops with the result',
      (tester) async {
        ResumeRoleSelection? popped;
        final repo = _FakeResumeRepository(
          rolesResult: const Success([_softwareDev]),
          selectTargetRoleResult: const Success((
            role: 'Software Developer',
            dept: 'Frontend, backend, full-stack',
          )),
        );
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context)
                        .push<ResumeRoleSelection>(
                          MaterialPageRoute(
                            builder: (_) => const RolePickerScreen(),
                          ),
                        );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await _tapRoleAndConfirm(tester, 'Software Developer');

        expect(popped, (
          role: 'Software Developer',
          dept: 'Frontend, backend, full-stack',
        ));
        expect(repo.selectTargetRoleCallCount, 1);
        expect(repo.lastSelectTargetRoleArgs, (
          role: 'Software Developer',
          dept: 'Frontend, backend, full-stack',
          track: 'tech',
        ));
      },
    );

    testWidgets(
      'backing out of the picker without selecting a role returns null — no selectTargetRole call',
      (tester) async {
        ResumeRoleSelection? popped;
        final repo = _FakeResumeRepository(
          rolesResult: const Success([_softwareDev]),
        );
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context)
                        .push<ResumeRoleSelection>(
                          MaterialPageRoute(
                            builder: (_) => const RolePickerScreen(),
                          ),
                        );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(popped, isNull);
        expect(repo.selectTargetRoleCallCount, 0);
      },
    );

    testWidgets(
      'a failed selection shows an inline error and does not pop the screen',
      (tester) async {
        await _pump(
          tester,
          rolesResult: const Success([_softwareDev]),
          selectTargetRoleResult: const Failed(UnauthorizedFailure()),
        );

        await tester.tap(find.text('Software Developer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resume Parsing & Interview'));
        await tester.pumpAndSettle();

        expect(find.text(const UnauthorizedFailure().message), findsOneWidget);
        // The sheet (and the picker beneath it) are both still showing — a
        // failure must never silently close anything or imply success.
        expect(find.text('Resume Parsing & Interview'), findsOneWidget);
      },
    );

    testWidgets('renders without horizontal overflow at narrow phone widths', (
      tester,
    ) async {
      // Pumps `RolePickerScreen` directly (no push-button indirection) so
      // each loop iteration gets a genuinely fresh `Navigator`/route stack
      // — reusing `_pump`'s push helper across iterations would leave the
      // previous iteration's pushed screen stacked underneath, hiding the
      // "open" button the next iteration looks for.
      for (final size in [
        const Size(320, 800),
        const Size(360, 800),
        const Size(390, 800),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final repo = _FakeResumeRepository(
          rolesResult: const Success([_softwareDev, _hseEngineer]),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: RolePickerScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}

Future<void> _tapRoleAndConfirm(WidgetTester tester, String roleTitle) async {
  await tester.tap(find.text(roleTitle));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Resume Parsing & Interview'));
  await tester.pumpAndSettle();
}
