import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/answer_submission_result.dart';
import '../domain/entities/interview_analytics.dart';
import '../domain/entities/malpractice.dart';
import '../domain/entities/next_question_outcome.dart';
import '../domain/repositories/mock_interview_repository.dart';
import 'datasources/mock_interview_remote_datasource.dart';

class MockInterviewRepositoryImpl implements MockInterviewRepository {
  MockInterviewRepositoryImpl(this._remote);

  final MockInterviewRemoteDataSource _remote;

  @override
  Future<Result<void>> startInterview() async {
    try {
      await _remote.startInterview();
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> confirmCameraLive() async {
    try {
      await _remote.confirmCameraLive();
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<NextQuestionOutcome>> getNextQuestion({required bool advance}) async {
    try {
      return Success(await _remote.getNextQuestion(advance: advance));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<AnswerSubmissionResult>> submitAnswer({required int questionId, required String answerText}) async {
    try {
      return Success(await _remote.submitAnswer(questionId: questionId, answerText: answerText));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<ViolationState>> getViolationState() async {
    try {
      return Success(await _remote.getViolationState());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<ViolationRecordResult>> recordViolation({required ViolationType type, double? durationSeconds}) async {
    try {
      return Success(await _remote.recordViolation(type: type, durationSeconds: durationSeconds));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  /// Best-effort by design, mirroring the real web page's own
  /// `finishVideoRecording` (which silently gives up after one retry rather
  /// than blocking the candidate from reaching their results,
  /// `templates/resume_interview.html:877-906`): a failed upload here is
  /// never surfaced as a user-facing [Failure] to the results flow — it
  /// just returns `false` (not stored). The caller decides whether to even
  /// attempt this at all (this app defers actually recording interview
  /// video — see `MockInterviewController`'s doc comment).
  @override
  Future<Result<bool>> uploadInterviewVideo(String filePath) async {
    try {
      return Success(await _remote.uploadInterviewVideo(filePath));
    } on AppException catch (_) {
      return const Success(false);
    }
  }

  @override
  Future<Result<InterviewAnalyticsResult>> getAnalytics() async {
    try {
      return Success(await _remote.getAnalytics());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
