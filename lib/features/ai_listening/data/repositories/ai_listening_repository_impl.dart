import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/listening_analysis_result.dart';
import '../../domain/repositories/ai_listening_repository.dart';
import '../datasources/ai_listening_remote_datasource.dart';

class AiListeningRepositoryImpl implements AiListeningRepository {
  AiListeningRepositoryImpl(this._remote);

  final AiListeningRemoteDataSource _remote;

  @override
  Future<Result<String>> fetchAttemptToken(int exerciseId) async {
    try {
      return Success(await _remote.fetchAttemptToken(exerciseId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<ListeningAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String referenceText,
    required int durationSeconds,
    required int pauseCount,
    required String attemptToken,
    required String language,
  }) async {
    try {
      final data = await _remote.analyze(
        exerciseId: exerciseId,
        text: text,
        referenceText: referenceText,
        durationSeconds: durationSeconds,
        pauseCount: pauseCount,
        attemptToken: attemptToken,
        language: language,
      );
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
