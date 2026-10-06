/// Mirrors `GDMessage.SPEAKER_CHOICES` (`GD_app/models.py`) exactly — the 4
/// values the server ever sends as a `speaker`/`speaker_name` pair (`user`,
/// or one of the 3 AI agents in `GD_app/agents.py`'s `AGENT_ORDER`). Kept as
/// a closed enum rather than a raw string since every real value is known
/// and fixed server-side.
enum GdSpeaker {
  user,
  alex,
  maya,
  rishi;

  /// Parses the `speaker` key the server sends (`'user'`, `'alex'`,
  /// `'maya'`, `'rishi'`) — an unrecognized value (shouldn't happen against
  /// the real backend) falls back to [user] rather than throwing, so a
  /// forward-compatible field addition can't crash the transcript.
  static GdSpeaker fromKey(String? key) {
    return switch (key) {
      'alex' => GdSpeaker.alex,
      'maya' => GdSpeaker.maya,
      'rishi' => GdSpeaker.rishi,
      _ => GdSpeaker.user,
    };
  }
}
