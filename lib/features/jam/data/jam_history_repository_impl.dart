import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/jam_assessment.dart';
import '../domain/entities/jam_history_profile.dart';
import '../domain/entities/jam_session_result.dart';
import '../domain/repositories/jam_history_repository.dart';
import 'jam_remote_datasource.dart';

class JamHistoryRepositoryImpl implements JamHistoryRepository {
  JamHistoryRepositoryImpl(this._remote);

  final JamRemoteDataSource _remote;

  @override
  Future<Result<JamHistoryPage>> getHistoryPage() async {
    try {
      return Success(await _remote.getHistoryPage());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<JamSessionResult>> getSessionDetail(int sessionId) async {
    try {
      return Success(await _remote.getSessionDetail(sessionId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<JamAssessmentResult>> getAssessmentResult(int assessmentId) async {
    try {
      return Success(await _remote.getAssessmentResult(assessmentId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> deleteSession(int sessionId) async {
    try {
      await _remote.deleteSession(sessionId);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> deleteAssessment(int assessmentId) async {
    try {
      await _remote.deleteAssessment(assessmentId);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
