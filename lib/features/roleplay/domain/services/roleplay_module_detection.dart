/// Ports `get_workshop_url()`'s Roleplay branch verbatim
/// (`activities/views.py:59`): `'role play' in title.lower() or 'roleplay'
/// in title.lower()`, also consistent with `_can_access_workshop`'s own
/// `_WORKSHOP_TITLE_KEYWORDS['roleplay']`. The routing decision is made on
/// the **Activity's** title, matching the `isSpeakingModuleActivity`-style
/// helpers used for the AI modules.
bool isRoleplayModuleActivity(String activityTitle) {
  final title = activityTitle.toLowerCase();
  return title.contains('role play') || title.contains('roleplay');
}
