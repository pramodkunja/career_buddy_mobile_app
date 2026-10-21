import '../../../app/config/environment.dart';

/// `{% static "tutorials/" %}<id>.mp4` (`templates/landing.html:7459-7462`)
/// — plain Django static-file serving, no auth, same pattern as
/// `skill_up_lesson_url.dart`'s own `/static/001%20Career%20Buddy/...`
/// construction. [id] must be one of [kHomeTutorialVideoIds] — the 5 ids
/// confirmed (via direct `ls`, Phase 40's audit) to actually have a file on
/// disk; the other `careerBuddyTutorials` entries reference ids with no
/// real file and are not reproduced here (see `HomeTutorialsSection`'s own
/// doc comment).
String homeTutorialVideoUrl(String id) => '${EnvironmentConfig.baseUrl}/static/tutorials/$id.mp4';

const List<String> kHomeTutorialVideoIds = ['welcome', 'resume', 'skillup', 'match', 'chatbot'];
