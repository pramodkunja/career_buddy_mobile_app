/// Ports `get_module_template()`'s listening-specific branch verbatim
/// (`activities/views.py:27-42`): `"listen" in title.lower()` — **no**
/// `"professional" in title` requirement, unlike the Speaking/Writing/
/// Reading branches. Confirmed by re-reading the source directly rather
/// than assumed from the other two modules' pattern; the real seed title
/// is `'Listen & Write'` (`setup_professional_modules.py`), which would
/// fail a "professional" check entirely.
bool isListeningModuleActivity(String activityTitle) {
  return activityTitle.toLowerCase().contains('listen');
}
