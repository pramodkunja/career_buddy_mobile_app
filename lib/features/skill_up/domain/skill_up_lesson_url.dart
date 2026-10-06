import '../../../app/config/environment.dart';

/// Builds the real, live, unauthenticated static file URL for a Skill Up
/// lesson from its [relativePath] (relative to `static/001 Career Buddy/`
/// on the Django backend, exactly as found in the real page's `#load=`
/// href — see `SkillUpLesson.relativePath`'s doc comment).
///
/// Django's `STATIC_URL` is `/static/` and `STATICFILES_DIRS` includes
/// `BASE_DIR / 'static'`, so the real, directly-servable, unauthenticated
/// absolute path is `/static/001%20Career%20Buddy/<relativePath>`. Each
/// path segment is percent-encoded individually via [Uri.encodeComponent]
/// and rejoined with `/` (rather than encoding the whole string at once),
/// so a literal space or parenthesis inside a single segment — e.g.
/// `GrammerActivities/grammar-activities (1).html` — is escaped without
/// touching the `/` separators themselves.
String buildSkillUpLessonUrl(String relativePath) {
  final encodedSegments = relativePath.split('/').map(Uri.encodeComponent).join('/');
  return '${EnvironmentConfig.baseUrl}/static/001%20Career%20Buddy/$encodedSegments';
}
