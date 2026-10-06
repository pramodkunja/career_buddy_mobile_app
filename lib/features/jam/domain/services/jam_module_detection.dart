/// Ports `get_workshop_url()`'s JAM branch verbatim
/// (`activities/views.py`): `'jam' in title.lower()`, also consistent with
/// `_can_access_workshop`'s own `_WORKSHOP_TITLE_KEYWORDS['jam']`. The
/// routing decision is made on the **Activity's** title, matching the
/// `isSpeakingModuleActivity`-style helpers used for the AI modules.
bool isJamModuleActivity(String activityTitle) {
  return activityTitle.toLowerCase().contains('jam');
}
