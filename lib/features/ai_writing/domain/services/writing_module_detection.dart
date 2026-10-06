/// Ports `get_module_template()`'s writing-specific branch verbatim
/// (`activities/views.py:27-42`): `"writing" in title.lower() and
/// "professional" in title.lower()`. Same title-based routing rule as
/// `isSpeakingModuleActivity` — the Activity's title decides, not the
/// exercise's own type — but checked independently against the writing
/// branch's actual keywords rather than assumed to match Speaking's.
bool isWritingModuleActivity(String activityTitle) {
  final title = activityTitle.toLowerCase();
  return title.contains('writing') && title.contains('professional');
}
