/// Ports `get_workshop_url()`'s GD branch verbatim (`activities/views.py`):
/// `'group discussion' in title.lower() or 'gd' == title.lower()` — also
/// consistent with `_can_access_workshop`'s own
/// `_WORKSHOP_TITLE_KEYWORDS['gd']` (`('group discussion',)`). Re-verified
/// directly against source (both call sites — `get_workshop_url` and the
/// inline check further down the same file — use this exact condition).
/// Same "routing decision made on the Activity's title" pattern as
/// `isJamModuleActivity`/`isRoleplayModuleActivity`.
bool isGdModuleActivity(String activityTitle) {
  final titleLower = activityTitle.toLowerCase();
  return titleLower.contains('group discussion') || titleLower == 'gd';
}
