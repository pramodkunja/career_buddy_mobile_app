import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/jam_assessment.dart';
import '../domain/entities/jam_session_start.dart';
import '../domain/repositories/jam_assessment_repository.dart';
import 'jam_remote_datasource.dart';

class JamAssessmentRepositoryImpl implements JamAssessmentRepository {
  JamAssessmentRepositoryImpl(this._remote);

  final JamRemoteDataSource _remote;

  @override
  Future<Result<List<JamPracticeSessionSummary>>> getHistory() async {
    try {
      return Success(await _remote.getHistory());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<JamSessionStart>> startAssessment() async {
    try {
      return Success(await _remote.startAssessment());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId) async {
    try {
      return Success(await _remote.completeAssessmentStage(sessionId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
