import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/resume_analysis.dart';
import '../domain/entities/resume_history_item.dart';
import '../domain/repositories/resume_repository.dart';
import 'resume_remote_datasource.dart';

class ResumeRepositoryImpl implements ResumeRepository {
  ResumeRepositoryImpl(this._remote);

  final ResumeRemoteDataSource _remote;

  @override
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  }) async {
    try {
      return Success(await _remote.uploadAndAnalyze(filePath: filePath, fileName: fileName));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId) async {
    try {
      return Success(await _remote.reanalyze(resumeId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<List<ResumeHistoryItem>>> getHistory() async {
    try {
      return Success(await _remote.getHistory());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
