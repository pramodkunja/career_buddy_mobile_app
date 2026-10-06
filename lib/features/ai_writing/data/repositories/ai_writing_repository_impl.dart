import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/writing_analysis_result.dart';
import '../../domain/repositories/ai_writing_repository.dart';
import '../datasources/ai_writing_remote_datasource.dart';

class AiWritingRepositoryImpl implements AiWritingRepository {
  AiWritingRepositoryImpl(this._remote);

  final AiWritingRemoteDataSource _remote;

  @override
  Future<Result<WritingAnalysisResult>> analyze({
    required int exerciseId,
    required String text,
    required String language,
    required String referenceText,
    String? previousImprovedPassage,
  }) async {
    try {
      final data = await _remote.analyze(
        exerciseId: exerciseId,
        text: text,
        language: language,
        referenceText: referenceText,
        previousImprovedPassage: previousImprovedPassage,
      );
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
