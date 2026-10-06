import '../../../../core/utils/result.dart';
import '../entities/jam_assessment.dart';
import '../entities/jam_session_start.dart';

/// The 3-stage Assessment flow's own repository seam, kept separate from
/// [JamRepository] rather than adding methods to it — [JamRepository] is an
/// existing, already-tested interface with several `implements
/// JamRepository` fakes across `test/features/jam/`
/// (`_FakeJamRepository`/`_NeverJamRepository`), and Dart's `implements`
/// requires every member to be re-declared regardless of whether the
/// interface method has a body; adding a method there would silently break
/// those fakes' compilation. This interface is additive instead: a second,
/// independent seam `JamSessionController` reads only when it's actually
/// driving the assessment flow (`session.stage != null`), never touched by
/// the existing single-topic flow or its tests.
abstract class JamAssessmentRepository {
  /// `jam:history` → `computeJamAssessmentEligibility` — see
  /// `JamRemoteDataSource.getHistory`'s doc comment.
  Future<Result<List<JamPracticeSessionSummary>>> getHistory();

  /// `jam:start_assessment`.
  Future<Result<JamSessionStart>> startAssessment();

  /// `jam:complete_session` for an assessment-stage session — see
  /// `JamRemoteDataSource.completeAssessmentStage`'s doc comment.
  Future<Result<JamAssessmentStageOutcome>> completeAssessmentStage(int sessionId);
}
