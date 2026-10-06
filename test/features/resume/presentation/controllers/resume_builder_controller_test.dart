import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_analysis.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_history_item.dart';
import 'package:career_buddy_lms/features/resume/domain/repositories/resume_repository.dart';
import 'package:career_buddy_lms/features/resume/presentation/controllers/resume_builder_controller.dart';
import 'package:career_buddy_lms/features/resume/presentation/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeResumeRepository implements ResumeRepository {
  _FakeResumeRepository({this.uploadResult, this.reanalyzeResult});

  Result<ResumeAnalysisResult>? uploadResult;
  Result<ResumeAnalysisResult>? reanalyzeResult;
  int uploadCallCount = 0;

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
  });
}
