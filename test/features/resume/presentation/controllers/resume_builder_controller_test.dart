import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_role.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.uploadResult, this.reanalyzeResult, this.parseQuotaResult});

  Result<ResumeAnalysisResult>? uploadResult;
  Result<ResumeAnalysisResult>? reanalyzeResult;
  ResumeParseQuota? parseQuotaResult;
  int uploadCallCount = 0;
  int parseQuotaCallCount = 0;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async {
    uploadCallCount++;
    return uploadResult!;
  }

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async => reanalyzeResult!;

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async => throw UnimplementedError();

  @override
  Future<ResumeParseQuota?> getParseQuota() async {
    parseQuotaCallCount++;
    return parseQuotaResult;
  }

  @override
  Future<Result<List<ResumeRole>>> getRoles() async => throw UnimplementedError();

  @override
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  }) async => throw UnimplementedError();
}

const _sampleAnalysis = ResumeAnalysis(
  matchPercentage: 78,
  matchingSkills: ['python', 'django'],
  missingSkills: ['docker'],
  summary: 'Solid resume overall.',
  careerAdvice: ['Add a Skills section.'],
);

void main() {
  group('ResumeBuilderController', () {
    test('starts in ResumeIdle with no error', () {
      final container = ProviderContainer(
        overrides: [resumeRepositoryProvider.overrideWithValue(_FakeResumeRepository())],
      );
      addTearDown(container.dispose);

      final state = container.read(resumeBuilderControllerProvider);
      expect(state, isA<ResumeIdle>());
      expect((state as ResumeIdle).errorMessage, isNull);
    });

    test('uploadAndAnalyze() success moves to ResumeResultState with the parsed analysis', () async {
      const result = ResumeAnalysisResult(
        analysis: _sampleAnalysis,
        isAtsOnly: true,
        yearsExperience: 2.0,
        canInterview: false,
      );
      final repo = _FakeResumeRepository(uploadResult: const Success(result));
      final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');

      final state = container.read(resumeBuilderControllerProvider);
      expect(state, isA<ResumeResultState>());
      expect((state as ResumeResultState).result.analysis.matchPercentage, 78);
      expect(repo.uploadCallCount, 1);
    });

    test('uploadAndAnalyze() failure moves back to ResumeIdle carrying the failure message', () async {
      const failure = ValidationFailure({}, "We couldn't read any text from this resume.");
      final repo = _FakeResumeRepository(uploadResult: const Failed(failure));
      final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/bad.txt', fileName: 'bad.txt');

      final state = container.read(resumeBuilderControllerProvider);
      expect(state, isA<ResumeIdle>());
      expect((state as ResumeIdle).errorMessage, failure.message);
    });

    test('reanalyze() success moves to ResumeResultState', () async {
      const result = ResumeAnalysisResult(
        analysis: _sampleAnalysis,
        isAtsOnly: true,
        yearsExperience: 2.0,
        canInterview: true,
      );
      final repo = _FakeResumeRepository(reanalyzeResult: const Success(result));
      final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      await container.read(resumeBuilderControllerProvider.notifier).reanalyze(42);

      final state = container.read(resumeBuilderControllerProvider);
      expect(state, isA<ResumeResultState>());
      expect((state as ResumeResultState).result.canInterview, isTrue);
    });

    group('REGRESSION (Phase 19) — loadParseQuota', () {
      test('a valid quota from the repository is carried into ResumeIdle', () async {
        final repo = _FakeResumeRepository(parseQuotaResult: (left: 3, limit: 4));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);

        await container.read(resumeBuilderControllerProvider.notifier).loadParseQuota();

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.parseQuota, (left: 3, limit: 4));
        expect(repo.parseQuotaCallCount, 1);
      });

      test('a null quota (paid plan, or fetch failure) leaves the counter hidden, with no error surfaced', () async {
        final repo = _FakeResumeRepository(); // parseQuotaResult left unset -> null
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);

        await container.read(resumeBuilderControllerProvider.notifier).loadParseQuota();

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.parseQuota, isNull);
        expect(state.errorMessage, isNull); // never surfaced as an error
      });

      test('a prior quota is preserved across ResumeUploading and a failed upload', () async {
        const failure = ValidationFailure({}, 'Could not analyze this resume.');
        final repo = _FakeResumeRepository(parseQuotaResult: (left: 2, limit: 4), uploadResult: const Failed(failure));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        final notifier = container.read(resumeBuilderControllerProvider.notifier);
        await notifier.loadParseQuota();

        await notifier.uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.parseQuota, (left: 2, limit: 4)); // not lost by the failed upload
        expect(state.errorMessage, failure.message); // the real error still surfaces too
      });

      test('reset() clears the quota — the fresh upload form re-fetches it on its own next mount', () async {
        final repo = _FakeResumeRepository(parseQuotaResult: (left: 2, limit: 4));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        final notifier = container.read(resumeBuilderControllerProvider.notifier);
        await notifier.loadParseQuota();

        notifier.reset();

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.parseQuota, isNull);
      });
    });

    test('reset() returns to a clean ResumeIdle with no error, from any prior state', () async {
      const result = ResumeAnalysisResult(
        analysis: _sampleAnalysis,
        isAtsOnly: true,
        yearsExperience: 0.0,
        canInterview: false,
      );
      final repo = _FakeResumeRepository(uploadResult: const Success(result));
      final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      await container
          .read(resumeBuilderControllerProvider.notifier)
          .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');
      expect(container.read(resumeBuilderControllerProvider), isA<ResumeResultState>());

      container.read(resumeBuilderControllerProvider.notifier).reset();

      final state = container.read(resumeBuilderControllerProvider);
      expect(state, isA<ResumeIdle>());
      expect((state as ResumeIdle).errorMessage, isNull);
    });

    group('REGRESSION (Phase 23) — role-fit picker: setTargetRole', () {
      const selection = (role: 'Software Developer', dept: 'Frontend, backend, full-stack');

      test('setTargetRole makes no network call itself — the picker already confirmed it', () async {
        final repo = _FakeResumeRepository();
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);

        container.read(resumeBuilderControllerProvider.notifier).setTargetRole(selection);

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.targetRole, selection);
      });

      test('a never-selected role leaves targetRole null — ordinary analysis stays unaffected either way', () async {
        const result = ResumeAnalysisResult(
          analysis: _sampleAnalysis,
          isAtsOnly: true,
          yearsExperience: 1.0,
          canInterview: false,
        );
        final repo = _FakeResumeRepository(uploadResult: const Success(result));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);

        await container
            .read(resumeBuilderControllerProvider.notifier)
            .uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');

        expect(container.read(resumeBuilderControllerProvider), isA<ResumeResultState>());
        expect(repo.uploadCallCount, 1); // the existing upload call is entirely unaffected
      });

      test('the selected role survives the upload-in-flight -> failure transition, unlike a cleared one', () async {
        const failure = ValidationFailure({}, 'Could not analyze this resume.');
        final repo = _FakeResumeRepository(uploadResult: const Failed(failure));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        final notifier = container.read(resumeBuilderControllerProvider.notifier);
        notifier.setTargetRole(selection);

        await notifier.uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.targetRole, selection); // not lost by the failed upload
        expect(state.errorMessage, failure.message);
      });

      test('reset() ("Analyze Another Resume") preserves the selected role, unlike the quota', () async {
        const result = ResumeAnalysisResult(
          analysis: _sampleAnalysis,
          isAtsOnly: true,
          yearsExperience: 0.0,
          canInterview: false,
        );
        final repo = _FakeResumeRepository(uploadResult: const Success(result), parseQuotaResult: (left: 2, limit: 4));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        final notifier = container.read(resumeBuilderControllerProvider.notifier);
        await notifier.loadParseQuota();
        notifier.setTargetRole(selection);
        await notifier.uploadAndAnalyze(filePath: '/tmp/resume.pdf', fileName: 'resume.pdf');

        notifier.reset();

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        // The server's own session still has this role set (it doesn't
        // auto-clear between analyses, confirmed in the Phase 22 audit) —
        // showing "no role" here would be a false display, unlike the
        // quota, which genuinely needs a fresh fetch.
        expect(state.targetRole, selection);
        expect(state.parseQuota, isNull);
      });

      test('loadParseQuota resolving late does not clear an already-selected role', () async {
        final repo = _FakeResumeRepository(parseQuotaResult: (left: 3, limit: 4));
        final container = ProviderContainer(overrides: [resumeRepositoryProvider.overrideWithValue(repo)]);
        addTearDown(container.dispose);
        final notifier = container.read(resumeBuilderControllerProvider.notifier);
        notifier.setTargetRole(selection);

        await notifier.loadParseQuota();

        final state = container.read(resumeBuilderControllerProvider) as ResumeIdle;
        expect(state.targetRole, selection);
        expect(state.parseQuota, (left: 3, limit: 4));
      });
    });
  });
}
