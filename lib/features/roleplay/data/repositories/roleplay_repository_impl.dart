import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/roleplay_analysis_result.dart';
import '../../domain/entities/roleplay_generated_content.dart';
import '../../domain/repositories/roleplay_repository.dart';
import '../datasources/roleplay_remote_datasource.dart';

class RoleplayRepositoryImpl implements RoleplayRepository {
  RoleplayRepositoryImpl(this._remote);

  final RoleplayRemoteDataSource _remote;

  @override
  Future<Result<RoleplayGeneratedContent>> generatePractice({
    required String topicSlug,
    required String prompt,
    required String language,
  }) async {
    try {
      final data = await _remote.generatePractice(topicSlug: topicSlug, prompt: prompt, language: language);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<RoleplayAnalysisResult>> analyze({
    required String topicLabel,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    try {
      final data = await _remote.analyze(
        topicLabel: topicLabel,
        audioFilePath: audioFilePath,
        durationSeconds: durationSeconds,
        pauseCount: pauseCount,
        language: language,
        referenceText: referenceText,
      );
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
