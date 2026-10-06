import '../../features/activities/domain/entities/exercise_attempt.dart';

/// In-memory, session-only progress tracking for Demo Mode. Lets a demo
/// AI-module or MCQ submission show up as a "previous attempt" the next
/// time the same demo exercise/sub-activity is visited, and lets "Mark
/// Complete" actually flip a demo sub-activity's status — without ever
/// touching the real (empty) Django database. Resets on app restart; never
/// read by, or written from, any real/API-backed repository.
class DemoProgressStore {
  DemoProgressStore._();

  static final DemoProgressStore instance = DemoProgressStore._();

  final Map<int, ExerciseAttempt> _lastAttemptByExerciseId = {};
  final Map<int, int> _attemptCountByExerciseId = {};
  final Set<int> _completedSubActivityIds = {};
  final Set<int> _startedSubActivityIds = {};

  ExerciseAttempt? lastAttemptFor(int exerciseId) => _lastAttemptByExerciseId[exerciseId];

  void recordAttempt(int exerciseId, {required int score, required int maxScore}) {
    final attemptNumber = (_attemptCountByExerciseId[exerciseId] ?? 0) + 1;
    _attemptCountByExerciseId[exerciseId] = attemptNumber;
    final percentage = maxScore == 0 ? 0 : ((score / maxScore) * 100).round();
    _lastAttemptByExerciseId[exerciseId] = ExerciseAttempt(
      score: score,
      maxScore: maxScore,
      percentage: percentage,
      attemptNumber: attemptNumber,
      completedAt: DateTime.now(),
    );
  }

  void markSubActivityStarted(int subActivityId) => _startedSubActivityIds.add(subActivityId);

  void markSubActivityComplete(int subActivityId) {
    _startedSubActivityIds.add(subActivityId);
    _completedSubActivityIds.add(subActivityId);
  }

  bool isSubActivityStarted(int subActivityId) => _startedSubActivityIds.contains(subActivityId);

  bool isSubActivityComplete(int subActivityId) => _completedSubActivityIds.contains(subActivityId);

  /// Test-only: resets all accumulated demo progress so tests don't leak
  /// state into one another via this singleton.
  void reset() {
    _lastAttemptByExerciseId.clear();
    _attemptCountByExerciseId.clear();
    _completedSubActivityIds.clear();
    _startedSubActivityIds.clear();
  }
}
