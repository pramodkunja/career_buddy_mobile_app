/// One past attempt, for the "Top score" / "Last 5 attempts" summary.
///
/// Mirrors the web's own `scoreBoard` exactly
/// (`static/001 Career Buddy/TechCenter/005 oop-mastery.html:2505-2536`,
/// `LS_KEY='oopScores'`) — which is itself **browser `localStorage`, not a
/// server record** (a real `skillup_assessment.QuizAttempt` row is also
/// written server-side on every submit, but the web page's own history UI
/// never reads it back — only this device-local log). This entity is the
/// Flutter equivalent of that same local-only log, not a new feature.
class MockTestAttemptRecord {
  const MockTestAttemptRecord({required this.score, required this.total, required this.completedAt});

  final int score;
  final int total;
  final DateTime completedAt;

  int get percentage => total == 0 ? 0 : ((score / total) * 100).round();
}
