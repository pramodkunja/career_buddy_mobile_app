/// A JAM ("Just A Minute") practice topic — mirrors `jam_app.models.Topic`
/// (`id`, `title`, `description`, `difficulty`). `difficulty` is kept as the
/// raw backend string (`'easy'` / `'medium'` / `'hard'`) rather than an enum
/// so an unrecognized value from the server never crashes parsing — callers
/// that need a display label can title-case it themselves.
class JamTopic {
  const JamTopic({required this.id, required this.title, required this.description, required this.difficulty});

  final int id;
  final String title;
  final String description;
  final String difficulty;
}
