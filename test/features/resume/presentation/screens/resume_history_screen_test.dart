import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/media/media_url_resolver.dart';
import 'package:career_buddy_lms/core/media/protected_media_download_controller.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:career_buddy_lms/features/resume/presentation/screens/resume_history_screen.dart';
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
  _FakeResumeRepository(this.historyResult);

  Result<List<ResumeHistoryItem>> historyResult;
  int reanalyzeCallCount = 0;
  int? lastReanalyzedId;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async => throw UnimplementedError();

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async {
    reanalyzeCallCount++;
    lastReanalyzedId = resumeId;
    return const Success(
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
  }

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async => historyResult;
}

/// Avoids exercising the real `path_provider`/`url_launcher` plugins (no
/// platform channel is registered in a widget test) — records the call so
/// tests can assert tapping "View File" reaches the controller with the
/// right filename, same technique as every other fake controller in this
/// suite.
class _FakeProtectedMediaDownloadController extends ProtectedMediaDownloadController {
  _FakeProtectedMediaDownloadController(super.resolvedUrl);

  int callCount = 0;
  String? lastFilename;

  @override
  Future<void> downloadAndOpen(String filename) async {
    callCount++;
    lastFilename = filename;
  }
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.resumeHistory,
  routes: [
    GoRoute(path: RoutePaths.resumeHistory, builder: (context, state) => const ResumeHistoryScreen()),
    GoRoute(path: RoutePaths.resumeBuilder, builder: (context, state) => const Scaffold(body: Text('Resume Builder Screen'))),
  ],
);

Future<ProviderContainer> _pump(WidgetTester tester, Result<List<ResumeHistoryItem>> historyResult) async {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository(historyResult)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  group('ResumeHistoryScreen', () {
    testWidgets('shows a loading indicator while the fetch is in flight', (tester) async {
      tester.view.physicalSize = const Size(400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository(const Success([]))),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders every resume with its filename, date, and Current badge', (tester) async {
      await _pump(tester, const Success([
        ResumeHistoryItem(
          id: 42,
          fileName: 'priya_resume_final.pdf',
          uploadedAtDisplay: '29 Sep 2026, 3:45 PM',
          isCurrent: true,
          fileUrl: '/media/resumes/priya_resume_final.pdf',
        ),
        ResumeHistoryItem(
          id: 17,
          fileName: 'old_resume.docx',
          uploadedAtDisplay: '01 Jan 2026, 9:00 AM',
          isCurrent: false,
          fileUrl: null,
        ),
      ]));

      expect(find.text('2 resumes uploaded so far'), findsOneWidget);
      expect(find.text('priya_resume_final.pdf'), findsOneWidget);
      expect(find.text('old_resume.docx'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Uploaded 29 Sep 2026, 3:45 PM'), findsOneWidget);
      // Only the current resume has a fileUrl, so only 1 "View File" button.
      expect(find.text('View File'), findsOneWidget);
      expect(find.text('View ATS Analysis'), findsNWidgets(2));
    });

    testWidgets('shows the empty-state copy when there are no resumes', (tester) async {
      await _pump(tester, const Success([]));

      expect(find.text('No resumes uploaded yet'), findsOneWidget);
      expect(find.text('Upload your first resume to get an AI-powered ATS score.'), findsOneWidget);
    });

    testWidgets('tapping "View ATS Analysis" reanalyzes that resume and navigates to Resume Builder', (tester) async {
      final container = await _pump(tester, const Success([
        ResumeHistoryItem(
          id: 42,
          fileName: 'priya_resume_final.pdf',
          uploadedAtDisplay: '29 Sep 2026, 3:45 PM',
          isCurrent: true,
          fileUrl: null,
        ),
      ]));

      await tester.tap(find.text('View ATS Analysis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;
      expect(repo.reanalyzeCallCount, 1);
      expect(repo.lastReanalyzedId, 42);
      expect(find.text('Resume Builder Screen'), findsOneWidget);
      expect(container.read(resumeBuilderControllerProvider), isA<ResumeResultState>());
    });

    testWidgets('tapping "View File" downloads the resume through the authenticated controller, not an external browser', (
      tester,
    ) async {
      const fileUrl = '/media/resumes/priya_resume_final.pdf';
      final resolvedUrl = resolveMediaUrl(fileUrl)!;
      final fakeDownload = _FakeProtectedMediaDownloadController(resolvedUrl);

      tester.view.physicalSize = const Size(400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          resumeRepositoryProvider.overrideWithValue(
            _FakeResumeRepository(
              const Success([
                ResumeHistoryItem(
                  id: 42,
                  fileName: 'priya_resume_final.pdf',
                  uploadedAtDisplay: '29 Sep 2026, 3:45 PM',
                  isCurrent: true,
                  fileUrl: fileUrl,
                ),
              ]),
            ),
          ),
          protectedMediaDownloadControllerProvider(resolvedUrl).overrideWith(() => fakeDownload),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('View File'));
      await tester.pump();

      expect(fakeDownload.callCount, 1);
      expect(fakeDownload.lastFilename, 'priya_resume_final.pdf');
    });

    testWidgets('shows a retryable error view for a fetch failure, and Retry re-fetches', (tester) async {
      final container = await _pump(tester, const Failed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);

      final repo = container.read(resumeRepositoryProvider) as _FakeResumeRepository;
      repo.historyResult = const Success([]);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No resumes uploaded yet'), findsOneWidget);
    });
  });
}
