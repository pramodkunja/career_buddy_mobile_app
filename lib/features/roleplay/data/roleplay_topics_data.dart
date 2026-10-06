import '../domain/entities/roleplay_topic.dart';

/// `TOPIC_PRACTICE_CONFIG` (`riya_bot/agents/utils.py:22-62`), transcribed
/// verbatim. This is the exact dict `roleplay_home`/`roleplay_practice_view`
/// pass into their templates — the 3 sub-features (Storytelling / Situations
/// / Roleplay) and their labels/placeholders/examples never come from a
/// database or a network call, so this is pure constant Dart data (same
/// "hand-transcribed once" precedent as `SkillUpData`), not a JSON asset or
/// a datasource.
///
/// NOTE: A second, near-identical `TOPIC_PRACTICE_CONFIG` exists at
/// `activities/agents/utils.py:16`, but `activities/views.py`'s
/// `roleplay_home`/`roleplay_practice`/`roleplay_practice_view` all
/// explicitly `from riya_bot.agents.utils import TOPIC_PRACTICE_CONFIG` (or
/// `get_topic_practice_config`) — the `riya_bot` copy below is the one
/// actually live on these 3 endpoints, confirmed by reading the imports in
/// `activities/views.py` directly.
abstract final class RoleplayTopicsData {
  static const RoleplayTopic storytelling = RoleplayTopic(
    slug: 'storytelling',
    pageTitle: 'Storytelling Practice',
    pageDescription: 'Read one short AI story and answer three simple questions below.',
    inputLabel: 'Story idea',
    inputPlaceholder: 'A rainy school day, a missing key, a brave child...',
    buttonLabel: 'Tell Story',
    defaultPrompt: 'a school picnic with a surprise ending',
    contentHeadingLabel: 'Short story',
    followUpsLabel: 'Questions',
    coachTipLabel: 'Coach tip',
    examples: ['A shy singer on stage', 'A rainy day at school', 'A puppy in the park'],
  );

  static const RoleplayTopic situations = RoleplayTopic(
    slug: 'situations',
    pageTitle: 'Situation Practice',
    pageDescription: 'Get one real-life speaking situation and practice short responses.',
    inputLabel: 'Situation idea',
    inputPlaceholder: 'At the airport, asking for help, ordering food...',
    buttonLabel: 'Create Situation',
    defaultPrompt: 'asking for help at a railway station',
    contentHeadingLabel: 'Practice situation',
    followUpsLabel: 'Try answering these',
    coachTipLabel: 'Coach tip',
    examples: ['At the airport', 'Speaking to a teacher', 'Returning an item at a shop'],
  );

  static const RoleplayTopic roleplay = RoleplayTopic(
    slug: 'roleplay',
    pageTitle: 'Roleplay Practice',
    pageDescription: 'Start a short roleplay scene and reply in your own words.',
    inputLabel: 'Roleplay idea',
    inputPlaceholder: 'Student and teacher, customer and cashier, teammate and manager...',
    buttonLabel: 'Start Roleplay',
    defaultPrompt: 'student asking a teacher for more project time',
    contentHeadingLabel: 'Roleplay scene',
    followUpsLabel: 'Reply to these lines',
    coachTipLabel: 'Coach tip',
    examples: ['Customer asking for a refund', 'Friend inviting you to an event', 'Employee asking for leave'],
  );

  /// Iteration order mirrors `roleplay_home.html`'s `{% for key, config in
  /// configs.items %}` — Python dict insertion order, i.e. the order the 3
  /// keys are written in `TOPIC_PRACTICE_CONFIG` itself: storytelling,
  /// situations, roleplay.
  static const List<RoleplayTopic> all = [storytelling, situations, roleplay];

  /// Mirrors `get_topic_practice_config` (`TOPIC_PRACTICE_CONFIG.get(...)`).
  static RoleplayTopic? bySlug(String slug) {
    final normalized = slug.trim().toLowerCase();
    for (final topic in all) {
      if (topic.slug == normalized) return topic;
    }
    return null;
  }
}
