/// Ports `get_module_template()`'s speaking-specific branch verbatim
/// (`activities/views.py:27-42`): `"speaking" in title.lower() and
/// "professional" in title.lower()`. The routing decision is made on the
/// **Activity's** title, not the exercise's or sub-activity's — every
/// exercise under a matching activity routes to this module on the web
/// (`exercise_detail()` calls `get_module_template(activity)`, deriving
/// `activity = sub.activity`), so callers must pass the parent activity's
/// title, not the exercise's own.
bool isSpeakingModuleActivity(String activityTitle) {
  final title = activityTitle.toLowerCase();
  return title.contains('speaking') && title.contains('professional');
}
