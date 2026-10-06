import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/gd_report.dart';
import '../domain/entities/gd_session_summary.dart';
import '../domain/entities/gd_started_session.dart';
import '../domain/repositories/gd_repository.dart';
import 'gd_remote_datasource.dart';

class GdRepositoryImpl implements GdRepository {
  GdRepositoryImpl(this._remote);

  final GdRemoteDataSource _remote;

  @override
  Future<Result<GdStartedSession>> createSession(String topic) async {
    try {
      return Success(await _remote.createSession(topic));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<List<GdSessionSummary>>> getSessions() async {
    try {
      return Success(await _remote.getSessions());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<GdReport?>> getSessionReport(int sessionId) async {
    try {
      return Success(await _remote.getSessionReport(sessionId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
