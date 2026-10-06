/// Passed via `context.push`'s `extra` to [SkillUpLessonScreen]'s route —
/// see `RoutePaths.skillUpLesson`'s doc comment.
class SkillUpLessonRouteArgs {
  const SkillUpLessonRouteArgs({required this.title, required this.url});

  /// The lesson's real title (e.g. "CEFR A1 · Elementary"), read directly
  /// from the link text/`title=` query param the real
  /// `static/001 Career Buddy/index.html` uses for this same lesson.
  final String title;

  /// The real, live, unauthenticated static file URL
  /// (`/static/001%20Career%20Buddy/{path}`) — these files are served by
  /// Django's plain `static()` file server with no `@login_required`,
  /// confirmed live.
  final String url;
}
