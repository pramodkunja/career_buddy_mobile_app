import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
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

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.uploadResult});

  Result<ResumeAnalysisResult>? uploadResult;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async => uploadResult!;

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async => throw UnimplementedError();

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async => const Success([]);
}

const _analysis = ResumeAnalysis(
  matchPercentage: 82,
  matchingSkills: ['python', 'django'],
  missingSkills: ['docker'],
  summary: 'Strong technical resume with clear achievements.',
  careerAdvice: ['Quantify your achievements with numbers.'],
);

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.resumeBuilder,
  routes: [
    GoRoute(path: RoutePaths.resumeBuilder, builder: (context, state) => const ResumeBuilderScreen()),
    GoRoute(path: RoutePaths.resumeHistory, builder: (context, state) => const Scaffold(body: Text('Resume History Screen'))),
    GoRoute(path: RoutePaths.pro, builder: (context, state) => const ComingSoonScreen(title: 'Upgrade Plan', message: 'x')),
    GoRoute(
      path: RoutePaths.resumeInterviewPlaceholder,
      builder: (context, state) => const ComingSoonScreen(title: 'AI Mock Interview', message: 'x'),
    ),
  ],
);

Future<ProviderContainer> _pump(WidgetTester tester, {Result<ResumeAnalysisResult>? uploadResult}) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository(uploadResult: uploadResult)),
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
    testWidgets('renders the hero, upload zone, and feature cards', (tester) async {
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

    testWidgets('the submit button is disabled until a file is picked', (tester) async {
      await _pump(tester);

      final button = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Analyze Resume with AI'), matching: find.byType(ElevatedButton)),
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
  });

  group('ResumeBuilderScreen (result)', () {
    testWidgets('renders the score, skills, summary, and advice once a result is set', (tester) async {
      final container = await _pump(
        tester,
        uploadResult: const Success(
          ResumeAnalysisResult(analysis: _analysis, isAtsOnly: true, yearsExperience: 1.0, canInterview: false),
        ),
      );

      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');
      await tester.pump();
      // Let the score-ring's animation settle without pumpAndSettle (the
      // chatbot overlay's own infinite animation would hang it).
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Resume Analysis Complete'), findsOneWidget);
      expect(find.text('Strong technical resume with clear achievements.'), findsOneWidget);
      expect(find.text('python'), findsOneWidget);
      expect(find.text('docker'), findsOneWidget);
      expect(find.text('Quantify your achievements with numbers.'), findsOneWidget);
      expect(find.text('Recommended ATS Resume Templates'), findsOneWidget);
    });

    testWidgets('shows the validation warning when resumeValid is false', (tester) async {
      final container = await _pump(tester);
      const badResult = ResumeAnalysisResult(
        analysis: _analysis,
        isAtsOnly: true,
        yearsExperience: 0.0,
        canInterview: false,
        resumeValid: false,
        validationMessage: 'Invalid resume. We could only find 2 out of 10 standard resume sections.',
      );
      (container.read(resumeRepositoryProvider) as _FakeResumeRepository).uploadResult = const Success(badResult);

      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.text('Invalid resume. We could only find 2 out of 10 standard resume sections.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping "Analyze Another Resume" resets back to the upload form', (tester) async {
      final container = await _pump(
        tester,
        uploadResult: const Success(
          ResumeAnalysisResult(analysis: _analysis, isAtsOnly: true, yearsExperience: 1.0, canInterview: false),
        ),
      );
      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Resume Analysis Complete'), findsOneWidget);

      await tester.ensureVisible(find.text('Analyze Another Resume'));
      await tester.tap(find.text('Analyze Another Resume'));
      await tester.pump();

      expect(find.text('Drag & Drop your resume here'), findsOneWidget);
    });

    testWidgets('renders the full result body without overflow at every target width', (tester) async {
      const longAdviceResult = ResumeAnalysisResult(
        analysis: ResumeAnalysis(
          matchPercentage: 91,
          matchingSkills: ['python', 'django', 'docker', 'kubernetes', 'postgresql', 'aws', 'rest api'],
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

        final container = await _pump(tester, uploadResult: const Success(longAdviceResult));
        await container
            .read(resumeBuilderControllerProvider.notifier)
            .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);
      }
    });
  });
}
