/// The four experience-level keys the real builder uses throughout
/// (`career_app/resume_roles.py`'s `LEVEL_KEYS`) — never invented, always
/// exactly these four strings.
const List<String> kManualResumeLevelKeys = ['fresher', '1-3', '3-5', '5+'];

/// Display labels for [kManualResumeLevelKeys] (`resume_roles.py`'s
/// `LEVEL_LABELS`).
const Map<String, String> kManualResumeLevelLabels = {
  'fresher': 'Fresher',
  '1-3': '1–3 Years',
  '3-5': '3–5 Years',
  '5+': '5+ Years',
};

/// Role-independent suggestions for one experience level
/// (`resume_roles.py`'s `LEVEL_COMMON`) — soft-skill chips and
/// placeholder-style achievement chips shown alongside a role's own
/// suggestions, plus a short note shown once that level is picked
/// (verified, `landing.html:8556-8559`).
class LevelCommonSuggestions {
  const LevelCommonSuggestions({this.softSkills = const [], this.achievements = const [], this.emphasis = ''});

  final List<String> softSkills;
  final List<String> achievements;
  final String emphasis;
}
