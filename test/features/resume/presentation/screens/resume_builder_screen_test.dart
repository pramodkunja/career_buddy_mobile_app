import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/level_common_suggestions.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_page_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_pdf_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_preview_outcome.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_role.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/resume_builder_screen.dart';
import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'jane');

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

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({
    this.uploadResult,
    this.parseQuotaResult,
    this.parseQuotaCompleter,
  });

  Result<ResumeAnalysisResult>? uploadResult;
  ResumeParseQuota? parseQuotaResult;

  /// When set, [getParseQuota] awaits this instead of returning
  /// [parseQuotaResult] immediately — lets a test deterministically hold
  /// the fetch "in flight" and complete it on its own schedule, rather than
  /// racing a real `async` function's microtask timing.
  Completer<ResumeParseQuota?>? parseQuotaCompleter;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async => uploadResult!;

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async =>
      const Success([]);

  @override
  Future<ResumeParseQuota?> getParseQuota() =>
      parseQuotaCompleter?.future ?? Future.value(parseQuotaResult);

  @override
  Future<Result<List<ResumeRole>>> getRoles() async =>
      throw UnimplementedError();

  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async => throw UnimplementedError();

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

const _analysis = ResumeAnalysis(
  matchPercentage: 82,
  matchingSkills: ['python', 'django'],
  missingSkills: ['docker'],
  summary: 'Strong technical resume with clear achievements.',
  careerAdvice: ['Quantify your achievements with numbers.'],
);

/// Stands in for the real `RolePickerScreen` (already fully tested in its
/// own `role_picker_screen_test.dart`) — just enough to prove
/// `ResumeBuilderScreen` actually navigates to [RoutePaths.resumeRolePicker]
/// and correctly handles whatever comes back, without re-testing the
/// picker's own internals here.
class _FakeRolePickerScreen extends StatelessWidget {
  const _FakeRolePickerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A real AppBar (matching the real `RolePickerScreen`'s own, which
      // this stands in for) so `tester.pageBack()` has a back button to
      // find, same as the genuine screen would provide.
      appBar: AppBar(title: const Text('Choose Target Role')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.pop((
            role: 'Software Developer',
            dept: 'Frontend, backend, full-stack',
          )),
          child: const Text('Role Picker Screen — confirm fake role'),
        ),
      ),
    );
  }
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.resumeBuilder,
  routes: [
    GoRoute(
      path: RoutePaths.resumeBuilder,
      builder: (context, state) => const ResumeBuilderScreen(),
    ),
    GoRoute(
      path: RoutePaths.resumeHistory,
      builder: (context, state) =>
          const Scaffold(body: Text('Resume History Screen')),
    ),
    GoRoute(
      path: RoutePaths.resumeRolePicker,
      builder: (context, state) => const _FakeRolePickerScreen(),
    ),
    GoRoute(
      path: RoutePaths.pro,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'Upgrade Plan', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.resumeInterviewPlaceholder,
      builder: (context, state) =>
          const ComingSoonScreen(title: 'AI Mock Interview', message: 'x'),
    ),
    GoRoute(
      path: RoutePaths.createResumeBuilder,
      builder: (context, state) =>
          const Scaffold(body: Text('Create Resume Builder Screen')),
    ),
    GoRoute(
      path: RoutePaths.skillUpSections,
      builder: (context, state) =>
          const Scaffold(body: Text('Skill Up Sections Screen')),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Result<ResumeAnalysisResult>? uploadResult,
  ResumeParseQuota? parseQuotaResult,
  Completer<ResumeParseQuota?>? parseQuotaCompleter,
}) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      resumeRepositoryProvider.overrideWithValue(
        _FakeResumeRepository(
          uploadResult: uploadResult,
          parseQuotaResult: parseQuotaResult,
          parseQuotaCompleter: parseQuotaCompleter,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('ResumeBuilderScreen (idle)', () {
    testWidgets('renders the hero, upload zone, and feature cards', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Resume Analysis & ATS Score'), findsOneWidget);
      expect(find.text('Upload Resume'), findsOneWidget);
      expect(find.text('Drag & Drop your resume here'), findsOneWidget);
      expect(find.text('Supports PDF and DOCX'), findsOneWidget);
      expect(find.text('Analyze Resume with AI'), findsOneWidget);
      expect(find.text('ATS Score'), findsOneWidget);
      expect(find.text('Skills Matched'), findsOneWidget);
      expect(find.text('Job Recommendations'), findsOneWidget);
    });

    testWidgets('the submit button is disabled until a file is picked', (
      tester,
    ) async {
      await _pump(tester);

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Analyze Resume with AI'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping Resume History navigates to it', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Resume History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Resume History Screen'), findsOneWidget);
    });

    group('REGRESSION (Phase 19) — Free-plan analyses-remaining counter', () {
      testWidgets(
        'shows the server-provided count once the quota fetch resolves',
        (tester) async {
          await _pump(tester, parseQuotaResult: (left: 3, limit: 4));
          await tester.pump();

          expect(
            find.text('Free plan: 3 of 4 resume analyses left'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'shows nothing — no badge, no error — when the quota is unavailable (paid plan or failed fetch)',
        (tester) async {
          await _pump(tester); // parseQuotaResult left null, the default
          await tester.pump();

          expect(find.textContaining('resume analyses left'), findsNothing);
          expect(find.byIcon(Icons.error_outline), findsNothing);
        },
      );

      testWidgets(
        'does not show a counter while the fetch is still in flight, then shows it once it resolves',
        (tester) async {
          final completer = Completer<ResumeParseQuota?>();
          await _pump(tester, parseQuotaCompleter: completer);

          // The fetch (fired from `initState`) is deliberately held open —
          // nothing should render yet.
          expect(find.textContaining('resume analyses left'), findsNothing);

          completer.complete((left: 3, limit: 4));
          await tester.pump();

          expect(
            find.text('Free plan: 3 of 4 resume analyses left'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'refreshes after "Analyze Another Resume" returns to a fresh upload form',
        (tester) async {
          final container = await _pump(
            tester,
            uploadResult: const Success(
              ResumeAnalysisResult(
                analysis: _analysis,
                isAtsOnly: true,
                yearsExperience: 1.0,
                canInterview: false,
              ),
            ),
            parseQuotaResult: (left: 3, limit: 4),
          );
          await tester.pump();
          expect(
            find.text('Free plan: 3 of 4 resume analyses left'),
            findsOneWidget,
          );

          await container
              .read(resumeBuilderControllerProvider.notifier)
              .uploadAndAnalyze(
                filePath: '/tmp/resume.pdf',
                fileName: 'resume.pdf',
              );
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          expect(find.text('Resume Analysis Complete'), findsOneWidget);

          // The next fetch would reflect the real, just-decremented server
          // count — simulated here by changing what the fake now returns.
          (container.read(resumeRepositoryProvider) as _FakeResumeRepository)
              .parseQuotaResult = (
            left: 2,
            limit: 4,
          );
          await tester.ensureVisible(find.text('Analyze Another Resume'));
          await tester.tap(find.text('Analyze Another Resume'));
          await tester.pump();
          await tester.pump();

          expect(
            find.text('Free plan: 2 of 4 resume analyses left'),
            findsOneWidget,
          );
          expect(
            find.text('Free plan: 3 of 4 resume analyses left'),
            findsNothing,
          );
        },
      );
    });

    group('REGRESSION (Phase 23) — role-fit picker entry point', () {
      testWidgets(
        'the "Choose Target Role" entry point is visible and no role badge shows yet',
        (tester) async {
          await _pump(tester);

          expect(find.text('Choose Target Role (optional)'), findsOneWidget);
          expect(find.textContaining('Target role:'), findsNothing);
        },
      );

      testWidgets('tapping it navigates to the real role-picker route', (
        tester,
      ) async {
        await _pump(tester);

        await tester.tap(find.text('Choose Target Role (optional)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Role Picker Screen — confirm fake role'),
          findsOneWidget,
        );
      });

      testWidgets(
        'confirming a role in the picker shows the badge only after it returns',
        (tester) async {
          await _pump(tester);
          expect(find.textContaining('Target role:'), findsNothing);

          await tester.tap(find.text('Choose Target Role (optional)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Role Picker Screen — confirm fake role'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(
            find.text(
              'Target role: Software Developer · Frontend, backend, full-stack',
            ),
            findsOneWidget,
          );
          // The optional entry point is replaced by a "Change" affordance,
          // not duplicated alongside the badge.
          expect(find.text('Choose Target Role (optional)'), findsNothing);
        },
      );

      testWidgets(
        'backing out of the picker without confirming leaves the upload flow completely unaffected',
        (tester) async {
          await _pump(
            tester,
            uploadResult: const Success(
              ResumeAnalysisResult(
                analysis: _analysis,
                isAtsOnly: true,
                yearsExperience: 1.0,
                canInterview: false,
              ),
            ),
          );

          await tester.tap(find.text('Choose Target Role (optional)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pageBack();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // No badge appeared, and the ordinary "Analyze Resume with AI"
          // button is still the only thing driving the upload flow.
          expect(find.textContaining('Target role:'), findsNothing);
          expect(find.text('Choose Target Role (optional)'), findsOneWidget);
          expect(find.text('Analyze Resume with AI'), findsOneWidget);
        },
      );
    });
  });

  group('ResumeBuilderScreen (result)', () {
    testWidgets(
      'renders the score, skills, summary, and advice once a result is set',
      (tester) async {
        final container = await _pump(
          tester,
          uploadResult: const Success(
            ResumeAnalysisResult(
              analysis: _analysis,
              isAtsOnly: true,
              yearsExperience: 1.0,
              canInterview: false,
            ),
          ),
        );

        await container
            .read(resumeBuilderControllerProvider.notifier)
            .uploadAndAnalyze(
              filePath: '/tmp/resume.pdf',
              fileName: 'resume.pdf',
            );
        await tester.pump();
        // Let the score-ring's animation settle without pumpAndSettle (the
        // chatbot overlay's own infinite animation would hang it).
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('82%'), findsOneWidget);
        expect(find.text('Resume Analysis Complete'), findsOneWidget);
        expect(
          find.text('Strong technical resume with clear achievements.'),
          findsOneWidget,
        );
        expect(find.text('python'), findsOneWidget);
        expect(find.text('docker'), findsOneWidget);
        expect(
          find.text('Quantify your achievements with numbers.'),
          findsOneWidget,
        );
        expect(find.text('Recommended ATS Resume Templates'), findsOneWidget);
      },
    );

    testWidgets('shows the validation warning when resumeValid is false', (
      tester,
    ) async {
      final container = await _pump(tester);
      const badResult = ResumeAnalysisResult(
        analysis: _analysis,
        isAtsOnly: true,
        yearsExperience: 0.0,
        canInterview: false,
        resumeValid: false,
        validationMessage:
            'Invalid resume. We could only find 2 out of 10 standard resume sections.',
      );
      (container.read(resumeRepositoryProvider) as _FakeResumeRepository)
          .uploadResult = const Success(
        badResult,
      );

      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(
            filePath: '/tmp/resume.pdf',
            fileName: 'resume.pdf',
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.text(
          'Invalid resume. We could only find 2 out of 10 standard resume sections.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'tapping "Analyze Another Resume" resets back to the upload form',
      (tester) async {
        final container = await _pump(
          tester,
          uploadResult: const Success(
            ResumeAnalysisResult(
              analysis: _analysis,
              isAtsOnly: true,
              yearsExperience: 1.0,
              canInterview: false,
            ),
          ),
        );
        await container
            .read(resumeBuilderControllerProvider.notifier)
            .uploadAndAnalyze(
              filePath: '/tmp/resume.pdf',
              fileName: 'resume.pdf',
            );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Resume Analysis Complete'), findsOneWidget);

        await tester.ensureVisible(find.text('Analyze Another Resume'));
        await tester.tap(find.text('Analyze Another Resume'));
        await tester.pump();

        expect(find.text('Drag & Drop your resume here'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the full result body without overflow at every target width',
      (tester) async {
        const longAdviceResult = ResumeAnalysisResult(
          analysis: ResumeAnalysis(
            matchPercentage: 91,
            matchingSkills: [
              'python',
              'django',
              'docker',
              'kubernetes',
              'postgresql',
              'aws',
              'rest api',
            ],
            missingSkills: ['typescript', 'graphql'],
            summary:
                'A genuinely long summary sentence describing the resume in more detail than usual, '
                'long enough to wrap onto multiple lines on a narrow phone width.',
            careerAdvice: [],
          ),
          isAtsOnly: true,
          yearsExperience: 4.5,
          canInterview: true,
        );

        for (final size in [
          const Size(320, 2600),
          const Size(360, 2600),
          const Size(390, 2600),
          const Size(412, 2600),
          const Size(430, 2600),
          const Size(1024, 2000),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = await _pump(
            tester,
            uploadResult: const Success(longAdviceResult),
          );
          await container
              .read(resumeBuilderControllerProvider.notifier)
              .uploadAndAnalyze(
                filePath: '/tmp/resume.pdf',
                fileName: 'resume.pdf',
              );
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));

          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('ResumeBuilderScreen — Phase 46 low-score recovery actions', () {
    Future<ProviderContainer> pumpWithGate(
      WidgetTester tester,
      ResumeInterviewGate gate, {
      String? targetRoleName,
      bool showSkillUpAction = false,
      int matchPercentage = 60,
    }) {
      return _pump(
        tester,
        uploadResult: Success(
          ResumeAnalysisResult(
            analysis: ResumeAnalysis(
              matchPercentage: matchPercentage,
              matchingSkills: const ['python'],
              missingSkills: const ['docker'],
              summary: 'Summary text.',
              careerAdvice: const ['Quantify your achievements with numbers.'],
            ),
            isAtsOnly: true,
            yearsExperience: 1.0,
            canInterview: gate != ResumeInterviewGate.planLocked,
            gate: gate,
            targetRoleName: targetRoleName,
            showSkillUpAction: showSkillUpAction,
          ),
        ),
      );
    }

    Future<void> uploadAndSettle(WidgetTester tester, ProviderContainer container) async {
      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets(
      'role-mismatch: the top bar shows a disabled lock badge, and the banner offers Build Resume + Upload Another',
      (tester) async {
        final container = await pumpWithGate(
          tester,
          ResumeInterviewGate.roleMismatch,
          targetRoleName: 'Backend Developer',
        );
        await uploadAndSettle(tester, container);

        expect(find.text('Resume doesn’t match Backend Developer'), findsOneWidget);
        expect(find.text('Try Interview'), findsNothing);
        expect(find.text('This resume doesn’t match the Backend Developer role'), findsOneWidget);

        await tester.ensureVisible(find.text('Upload Another'));
        expect(find.text('Build Resume'), findsOneWidget);
        expect(find.text('Upload Another'), findsOneWidget);

        // The disabled top-bar badge must be genuinely unpressable, not
        // just styled differently.
        final lockButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Resume doesn’t match Backend Developer'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(lockButton.onPressed, isNull);
      },
    );

    testWidgets(
      'role-mismatch: tapping Build Resume navigates to the Create Resume builder',
      (tester) async {
        final container = await pumpWithGate(
          tester,
          ResumeInterviewGate.roleMismatch,
          targetRoleName: 'Backend Developer',
        );
        await uploadAndSettle(tester, container);

        await tester.ensureVisible(find.text('Build Resume'));
        await tester.tap(find.text('Build Resume'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Create Resume Builder Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'role-mismatch: tapping Upload Another resets to the upload form, same as Analyze Another Resume',
      (tester) async {
        final container = await pumpWithGate(
          tester,
          ResumeInterviewGate.roleMismatch,
          targetRoleName: 'Backend Developer',
        );
        await uploadAndSettle(tester, container);

        await tester.ensureVisible(find.text('Upload Another'));
        await tester.tap(find.text('Upload Another'));
        await tester.pump();

        expect(find.text('Drag & Drop your resume here'), findsOneWidget);
      },
    );

    testWidgets(
      'below-threshold: the top bar shows the correct ATS-percentage lock badge, and the banner offers Build Resume + Analyse Again',
      (tester) async {
        final container = await pumpWithGate(tester, ResumeInterviewGate.belowThreshold, matchPercentage: 60);
        await uploadAndSettle(tester, container);

        expect(find.text('Interview unlocks at 90% ATS score'), findsOneWidget);
        expect(find.text('Try Interview'), findsNothing);
        expect(find.text('Reach 90% ATS Score to Unlock the AI Interview'), findsOneWidget);
        expect(find.textContaining('Your resume scored 60%'), findsOneWidget);

        await tester.ensureVisible(find.text('Analyse Again'));
        expect(find.text('Build Resume'), findsOneWidget);
        expect(find.text('Analyse Again'), findsOneWidget);
      },
    );

    testWidgets(
      'below-threshold: tapping Analyse Again resets to the upload form',
      (tester) async {
        final container = await pumpWithGate(tester, ResumeInterviewGate.belowThreshold);
        await uploadAndSettle(tester, container);

        await tester.ensureVisible(find.text('Analyse Again'));
        await tester.tap(find.text('Analyse Again'));
        await tester.pump();

        expect(find.text('Drag & Drop your resume here'), findsOneWidget);
      },
    );

    testWidgets(
      'eligible: the top bar shows an active Try Interview button, unchanged from before this phase',
      (tester) async {
        final container = await pumpWithGate(tester, ResumeInterviewGate.eligible, matchPercentage: 95);
        await uploadAndSettle(tester, container);

        expect(find.text('Try Interview'), findsWidgets);
        expect(find.text('Build Resume'), findsNothing);
        expect(find.text('🎯 Complete the Interview to Unlock Job Recommendations'), findsOneWidget);
        expect(find.textContaining('Score 90 or above out of 100'), findsOneWidget);
      },
    );

    testWidgets(
      'planLocked (Free plan): shows Upgrade for AI Interview, never a lock badge meant for paid users',
      (tester) async {
        final container = await pumpWithGate(tester, ResumeInterviewGate.planLocked);
        await uploadAndSettle(tester, container);

        expect(find.text('Upgrade for AI Interview'), findsOneWidget);
        expect(find.text('🚀 Upgrade to Unlock the AI Interview & Job Recommendations'), findsOneWidget);
        expect(find.textContaining('score 90 or above'), findsOneWidget);
        expect(find.text('Resume doesn’t match Backend Developer'), findsNothing);
        expect(find.text('Interview unlocks at 90% ATS score'), findsNothing);
      },
    );

    testWidgets(
      'the "Skill up yourself" button renders only when the server actually sent showSkillUpAction, and navigates to Skill Up',
      (tester) async {
        final container = await pumpWithGate(
          tester,
          ResumeInterviewGate.belowThreshold,
          showSkillUpAction: true,
        );
        await uploadAndSettle(tester, container);

        await tester.ensureVisible(find.text('Skill up yourself'));
        expect(find.text('Skill up yourself'), findsOneWidget);

        await tester.tap(find.text('Skill up yourself'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Skill Up Sections Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'no "Skill up yourself" button when the server did not send showSkillUpAction',
      (tester) async {
        final container = await pumpWithGate(tester, ResumeInterviewGate.belowThreshold);
        await uploadAndSettle(tester, container);

        expect(find.text('Skill up yourself'), findsNothing);
      },
    );

    testWidgets(
      'pre-Phase-46 fixtures with no gate set still render correctly via the canInterview fallback',
      (tester) async {
        final container = await _pump(
          tester,
          uploadResult: const Success(
            ResumeAnalysisResult(
              analysis: _analysis,
              isAtsOnly: true,
              yearsExperience: 1.0,
              canInterview: true,
            ),
          ),
        );
        await uploadAndSettle(tester, container);

        expect(find.text('Try Interview'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
