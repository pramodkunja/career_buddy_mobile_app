import '../../app/config/environment.dart';

/// Resolves a media URL the server rendered — which may already be
/// absolute, or (the common case for everything under `MEDIA_URL`, e.g.
/// `resume.file.url`) root-relative like `/media/resumes/x.pdf` — into one
/// consistent, fully-qualified URL string.
///
/// A relative `href` is only ever safe to render as-is inside a real
/// browser tab, which resolves it against the current page's own origin
/// automatically (confirmed directly against `templates/jobs/
/// candidate_search.html` and `jobs_app/views.py:download_candidates_csv`,
/// which explicitly prefixes `request.scheme`/`request.get_host()` itself
/// for exactly this reason when the link will be consumed outside a page —
/// see that view's doc comment). This app has no "current page origin" to
/// resolve against, so every relative media URL must be prefixed exactly
/// once with [EnvironmentConfig.baseUrl] before use — not zero times (an
/// unusable relative string), and not twice (a corrupted
/// `https://...https://...` URL from prefixing an already-absolute one).
///
/// Returns `null` for a `null` or blank [rawUrl] — there is nothing to
/// resolve, and callers should treat that the same as "no file" rather than
/// inventing a URL.
String? resolveMediaUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  final base = EnvironmentConfig.baseUrl;
  return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
}

/// A safe local filename for a downloaded media file, derived from
/// [resolvedOrRelativeUrl]'s own last path segment (e.g.
/// `/media/resumes/xyz_123.pdf` -> `xyz_123.pdf`) so the saved file keeps
/// its real extension — falling back to [fallback] when the URL has no
/// usable segment (empty, or ends in a bare `/`).
String protectedMediaFilename(String resolvedOrRelativeUrl, String fallback) {
  final segments = Uri.tryParse(resolvedOrRelativeUrl)?.pathSegments ?? const <String>[];
  for (final segment in segments.reversed) {
    if (segment.isNotEmpty) return segment;
  }
  return fallback;
}
