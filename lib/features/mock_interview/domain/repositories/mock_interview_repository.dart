import '../../../../core/utils/result.dart';
import '../entities/answer_submission_result.dart';
import '../entities/interview_analytics.dart';
import '../entities/malpractice.dart';
import '../entities/next_question_outcome.dart';

abstract class MockInterviewRepository {
  /// `resume_start_interview` (following its redirect to `resume_interview_chat`,
  /// see `ApiEndpoints.resumeStartInterview`'s doc comment) — creates a fresh
  /// `ResumeInterviewSession` and its fixed Q1-10 question bank server-side.
  Future<Result<void>> startInterview();

  /// `resume_camera_verified` — the client's self-attestation that a live
  /// camera preview is showing (see `InterviewCameraService`), mirroring the
  /// web's own boolean self-attestation.
  Future<Result<void>> confirmCameraLive();

  /// `resume_get_next_question`. [advance] is the `?next=true` query flag —
  /// `false` for the very first question of the interview, `true` every time
  /// after a question has just been answered.
  Future<Result<NextQuestionOutcome>> getNextQuestion({required bool advance});

  /// `resume_submit_answer`.
  Future<Result<AnswerSubmissionResult>> submitAnswer({required int questionId, required String answerText});

  /// `resume_violation_state` — restores the server's own running
  /// count/status (e.g. after an app restart mid-interview).
  Future<Result<ViolationState>> getViolationState();

  /// `resume_record_violation`.
  Future<Result<ViolationRecordResult>> recordViolation({required ViolationType type, double? durationSeconds});

  /// `resume_upload_interview_video` — best-effort; see
  /// `MockInterviewRemoteDataSource.uploadInterviewVideo`'s doc comment.
  /// Returns whether the server actually persisted it (`false` for a
  /// below-passing session, per the endpoint's own keep/discard rule).
  Future<Result<bool>> uploadInterviewVideo(String filePath);

  /// `resume_analytics`.
  Future<Result<InterviewAnalyticsResult>> getAnalytics();
}
