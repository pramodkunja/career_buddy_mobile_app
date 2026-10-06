import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/jam_session_result.dart';
import '../domain/entities/jam_session_start.dart';
import '../domain/entities/jam_topic.dart';
import '../domain/repositories/jam_repository.dart';
import 'jam_remote_datasource.dart';

class JamRepositoryImpl implements JamRepository {
  JamRepositoryImpl(this._remote);

  final JamRemoteDataSource _remote;

  @override
  Future<Result<List<JamTopic>>> getTopics() async {
    try {
      return Success(await _remote.getTopics());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<JamSessionStart>> startSession({int? topicId}) async {
    try {
      return Success(await _remote.startSession(topicId: topicId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  }) async {
    try {
      await _remote.saveAudio(
        sessionId: sessionId,
        audioFilePath: audioFilePath,
        durationSeconds: durationSeconds,
        language: language,
        transcript: transcript,
      );
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<JamSessionResult>> completeSession(int sessionId) async {
    try {
      return Success(await _remote.completeSession(sessionId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
