import '../../../../core/utils/result.dart';
import '../entities/mock_test_question.dart';
import '../entities/mock_test_submission_result.dart';

/// Shared contract for the "mock quiz" family of endpoints — OOP Mastery
/// (`/activities/oop-quiz/...`) and the generic per-subject Subject Quiz
/// (`/activities/quiz/<subject>/...`) share an **identical** request/response
/// shape (verified directly against `activities/views.py`:
/// `oop_quiz_questions`/`oop_quiz_submit` and
/// `quiz_questions`/`quiz_submit` are byte-for-byte the same logic, only
/// the question-bank file differs) — only their URLs differ, so one
/// implementation of this contract, constructed with a different endpoint
/// pair, is enough for both. AMCAT/CoCubes are a genuinely different,
/// multi-section response shape and are deliberately NOT modeled here.
abstract class MockQuizRepository {
  Future<Result<List<MockTestQuestion>>> getQuestions();

  /// [answers] maps question id -> chosen option index (0-3). The server
  /// treats any id missing from this map / any other value the same as an
  /// explicit unanswered sentinel — see `MockQuizRemoteDataSource`.
  Future<Result<MockTestSubmissionResult>> submitAnswers(Map<int, int> answers);
}
