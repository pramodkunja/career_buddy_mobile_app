/// `jam:history` (`templates/jam/history.html`) — the full "Practice
/// History" page: completed, non-assessment sessions plus completed
/// Assessment groups. A richer parse of the same page
/// `JamPracticeSessionSummary`/`parseJamHistoryHtml` already reads (for
/// Assessment eligibility only) — see `parseJamHistoryPageHtml`.
class JamHistoryPage {
  const JamHistoryPage({required this.sessions, required this.assessments});

  final List<JamHistorySession> sessions;
  final List<JamHistoryAssessment> assessments;
}

class JamHistorySession {
  const JamHistorySession({
    required this.sessionId,
    required this.topicTitle,
    required this.difficulty,
    required this.createdAt,
    required this.durationDisplay,
    required this.overallScore,
  });

  final int sessionId;
  final String topicTitle;

  /// Raw backend string (`'easy'`/`'medium'`/`'hard'`).
  final String difficulty;

  /// Already formatted exactly as the web renders it (`M d Y h:i A`).
  final String createdAt;

  /// `JAMSession.duration_display` (e.g. `"1m 5s"`).
  final String durationDisplay;

  /// `JAMSession.overall_score_display` — sum of the 5 category scores out
  /// of 25, or `null` if the session has no scores yet (the web's own
  /// `{% if session.overall_score_display %}` hides the stat entirely in
  /// that case, not shows a zero).
  final int? overallScore;
}

class JamHistoryAssessment {
  const JamHistoryAssessment({
    required this.assessmentId,
    required this.createdAt,
    required this.easyTopicTitle,
    required this.mediumTopicTitle,
    required this.hardTopicTitle,
  });

  final int assessmentId;
  final String createdAt;
  final String easyTopicTitle;
  final String mediumTopicTitle;
  final String hardTopicTitle;
}

/// `jam:profile` (`templates/jam/profile.html`) — `UserProfile` + the
/// linked `User`'s name/email fields.
class JamProfile {
  const JamProfile({
    required this.fullName,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.bio,
    required this.totalSessions,
    required this.totalMinutes,
  });

  /// `user.get_full_name|default:user.username` — already resolved
  /// server-side exactly like the web's own avatar-initial header.
  final String fullName;
  final String email;
  final String firstName;
  final String lastName;
  final String bio;
  final int totalSessions;
  final int totalMinutes;
}

/// POST payload for `jam:profile`. The web's own form has no password/
/// avatar fields — only these four.
class JamProfileUpdate {
  const JamProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.bio,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String bio;
}
