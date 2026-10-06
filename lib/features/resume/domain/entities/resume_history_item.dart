/// One row of `templates/resume_history.html`'s `resumes` queryset
/// (`career_app.views.resume_history`, `core.models.Resume`).
class ResumeHistoryItem {
  const ResumeHistoryItem({
    required this.id,
    required this.fileName,
    required this.uploadedAtDisplay,
    required this.isCurrent,
    required this.fileUrl,
  });

  final int id;

  /// `{{ resume.file.name|cut:"resumes/" }}` — the stored filename with the
  /// literal `resumes/` prefix stripped (a Django `cut` filter, not a
  /// basename() call — reproduced identically rather than "fixed" into a
  /// real basename, in case a filename ever legitimately contains that
  /// substring elsewhere).
  final String fileName;

  /// Already formatted exactly as the web renders it (`d M Y, g:i A`, e.g.
  /// "29 Sep 2026, 3:45 PM") — not re-parsed into a `DateTime`, since nothing
  /// else in this app needs to compute on it, only display it.
  final String uploadedAtDisplay;

  /// Whether this row's id matches the session's `rb_resume_id` — the
  /// resume the last upload/reanalyze actually produced results for.
  final bool isCurrent;

  /// `resume.file.url` (a protected `/media/resumes/...` path, see
  /// `core/media_views.py: serve_protected_media`) — `null` when the
  /// template's own `{% if resume.file %}` guard would have hidden the
  /// "View File" link too.
  final String? fileUrl;
}
