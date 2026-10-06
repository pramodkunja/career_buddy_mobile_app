/// Ports `get_module_template()`'s reading-specific branch verbatim
/// (`activities/views.py:27-42`): `"reading" in title.lower() and
/// "professional" in title.lower()` — requires "professional", same as
/// Speaking/Writing, unlike Listening's looser `"listen" in title` check.
/// Confirmed independently against the real seed title
/// (`'Professional Reading'`, `setup_professional_modules.py`).
bool isReadingModuleActivity(String activityTitle) {
  final title = activityTitle.toLowerCase();
  return title.contains('reading') && title.contains('professional');
}
