import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/career_department.dart';
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
import 'package:career_buddy_lms/features/resume/presentation/widgets/career_role_action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _department = CareerDepartment(
  category: 'tech',
  icon: 'search',
  name: 'Engineering Recruitment & Technical Staffing',
  roles: [],
);

const _role = CareerRole(
  name: 'Lead Technical Recruiter (Engineering)',
  skillGroups: [
    CareerRoleSkillGroup(
      label: 'Role skills',
      skills: ['Full-cycle technical sourcing', 'Boolean search'],
    ),
  ],
);

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.selectTargetRoleResult});

  Result<ResumeRoleSelection>? selectTargetRoleResult;
  String? lastRole;
  String? lastDept;
  String? lastTrack;

  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async {
    lastRole = role;
    lastDept = dept;
    lastTrack = track;
    return selectTargetRoleResult ?? const Success((role: 'x', dept: 'y'));
  }

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
  Future<Result<List<ResumeRole>>> getRoles() async => throw UnimplementedError();
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

Future<_FakeResumeRepository> _pump(
  WidgetTester tester, {
  Result<ResumeRoleSelection>? selectTargetRoleResult,
}) async {
  final repo = _FakeResumeRepository(selectTargetRoleResult: selectTargetRoleResult);
  final container = ProviderContainer(
    overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/sheet-host',
    routes: [
      GoRoute(
        path: '/sheet-host',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    const CareerRoleActionSheet(role: _role, department: _department),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.resumeBuilder,
        builder: (context, state) => const Scaffold(body: Text('Resume Builder Screen')),
      ),
      GoRoute(
        path: RoutePaths.manualResumeBuilder,
        builder: (context, state) => Scaffold(
          body: Text('Manual Resume Builder: ${(state.extra! as ResumeRole).title}'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('CareerRoleActionSheet', () {
    testWidgets('shows the role name, department and all 3 actions', (tester) async {
      await _pump(tester);

      expect(find.text('Lead Technical Recruiter (Engineering)'), findsOneWidget);
      expect(find.text('Engineering Recruitment & Technical Staffing'), findsOneWidget);
      expect(find.byKey(const Key('career-role-action-skills')), findsOneWidget);
      expect(find.byKey(const Key('career-role-action-build-resume')), findsOneWidget);
      expect(find.byKey(const Key('career-role-action-resume-parsing')), findsOneWidget);
    });

    testWidgets('Skills opens the real skills view with this role\'s actual skills', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('career-role-action-skills')));
      await tester.pumpAndSettle();

      expect(find.text('Skills this role requires.'), findsOneWidget);
      expect(find.text('Full-cycle technical sourcing'), findsOneWidget);
      expect(find.text('Boolean search'), findsOneWidget);
      expect(find.text('Explore Skill Up'), findsOneWidget);
    });

    testWidgets('Build Resume opens the Manual Resume Builder with a synthetic role for this exact role', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('career-role-action-build-resume')));
      await tester.pumpAndSettle();

      expect(
        find.text('Manual Resume Builder: Lead Technical Recruiter (Engineering)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Resume Parsing & Interview sends the exact role/dept/track, applies the result and navigates',
      (tester) async {
        final repo = await _pump(tester);

        await tester.tap(find.byKey(const Key('career-role-action-resume-parsing')));
        await tester.pumpAndSettle();

        expect(repo.lastRole, 'Lead Technical Recruiter (Engineering)');
        expect(repo.lastDept, 'Engineering Recruitment & Technical Staffing');
        // category 'tech' (Non-IT) -> track 'nonit', confirmed directly
        // against the real `pickRole()`'s own mapping.
        expect(repo.lastTrack, 'nonit');
        expect(find.text('Resume Builder Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'a failed Resume Parsing attempt (e.g. a guest/expired session) shows the real error and never navigates',
      (tester) async {
        await _pump(
          tester,
          selectTargetRoleResult: const Failed(UnauthorizedFailure()),
        );

        await tester.tap(find.byKey(const Key('career-role-action-resume-parsing')));
        await tester.pumpAndSettle();

        expect(find.text(const UnauthorizedFailure().message), findsOneWidget);
        expect(find.text('Resume Builder Screen'), findsNothing);
      },
    );
  });
}
