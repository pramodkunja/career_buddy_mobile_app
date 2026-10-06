import '../../../../../core/utils/result.dart';
import '../entities/amcat_section.dart';
import '../entities/amcat_submission_result.dart';

/// AMCAT's contract is genuinely different from `MockQuizRepository`
/// (W020/W021's single flat question-bank model): one fetch returns ALL 5
/// sections up front (`amcat_questions`, `activities/views.py:2291-2303`),
/// and submission returns a per-section score breakdown alongside the
/// overall one (`amcat_submit`). Forcing this into `MockQuizRepository`
/// would mean either dropping the section structure or inventing fields
/// that don't exist there — so this is its own small interface instead,
/// following the same `Result`/`Failure` conventions as every other
/// repository in the app.
abstract class AmcatRepository {
  Future<Result<List<AmcatSection>>> getSections();

  /// [answers] maps question id -> chosen option index (0-3), combined
  /// across every section into one flat map in a single request — exactly
  /// how the web's own `showResults()` builds `payload.answers` (one POST
  /// for the whole test, not per-section). Every served question's id must
  /// be present, padded with `-1` for anything left unanswered — same
  /// requirement and reasoning as `MockQuizRemoteDataSource.submitAnswers`.
  Future<Result<AmcatSubmissionResult>> submit(Map<int, int> answers);
}
