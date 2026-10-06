import '../../../../core/utils/result.dart';
import '../entities/jam_assessment.dart';
import '../entities/jam_history_profile.dart';
import '../entities/jam_session_result.dart';

/// The "Practice History" screen's own repository seam — additive, kept
/// separate from [JamRepository]/[JamAssessmentRepository] for the same
/// `implements`-breaks-existing-fakes reason documented on
/// `JamAssessmentRepository`.
abstract class JamHistoryRepository {
  /// `jam:history` — full page (both tabs).
  Future<Result<JamHistoryPage>> getHistoryPage();

  /// `jam:session_detail` — pure read, revisiting a past session.
  Future<Result<JamSessionResult>> getSessionDetail(int sessionId);

  /// `jam:assessment_result` — revisiting a past assessment.
  Future<Result<JamAssessmentResult>> getAssessmentResult(int assessmentId);

  /// `jam:delete_session`.
  Future<Result<void>> deleteSession(int sessionId);

  /// `jam:delete_assessment`.
  Future<Result<void>> deleteAssessment(int assessmentId);
}
