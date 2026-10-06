import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/speaking_analysis_result.dart';
import '../../domain/repositories/ai_speaking_repository.dart';
import '../datasources/ai_speaking_remote_datasource.dart';

class AiSpeakingRepositoryImpl implements AiSpeakingRepository {
  AiSpeakingRepositoryImpl(this._remote);

  final AiSpeakingRemoteDataSource _remote;

  @override
  Future<Result<SpeakingAnalysisResult>> analyze({
    required int exerciseId,
    required String audioFilePath,
    required double durationSeconds,
    required int pauseCount,
    required String language,
    required String referenceText,
  }) async {
    try {
      final data = await _remote.analyze(
        exerciseId: exerciseId,
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
