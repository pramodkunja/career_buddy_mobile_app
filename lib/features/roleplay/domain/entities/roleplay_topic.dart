/// One entry of `TOPIC_PRACTICE_CONFIG` (`riya_bot/agents/utils.py:22-62`,
/// imported and used verbatim by `activities/views.py`'s
/// `roleplay_home`/`roleplay_practice_view`/`roleplay_practice`) — the
/// static config behind the 3 Topic Practice Workshop sub-features:
/// Storytelling, Situations, and Roleplay. Every field name below mirrors
/// the Python dict key exactly (snake_case Python -> camelCase Dart), read
/// directly from source, not guessed. See `RoleplayTopicsData` for the 3
/// real, hand-transcribed values.
class RoleplayTopic {
  const RoleplayTopic({
    required this.slug,
    required this.pageTitle,
    required this.pageDescription,
    required this.inputLabel,
    required this.inputPlaceholder,
    required this.buttonLabel,
    required this.defaultPrompt,
    required this.contentHeadingLabel,
    required this.followUpsLabel,
    required this.coachTipLabel,
    required this.examples,
  });

  /// `config['slug']` — also the URL segment (`roleplay_practice_view`'s
  /// `<str:feature>`) and the `topic` form field `roleplay_practice`
  /// expects, e.g. `"storytelling"`.
  final String slug;

  /// `config['page_title']` — `roleplay.html`'s `{{ topic_config.page_title }}`.
  final String pageTitle;

  /// `config['page_description']`.
  final String pageDescription;

  /// `config['input_label']` — not actually rendered anywhere in
  /// `roleplay.html` (the input uses `input_placeholder` as its
  /// placeholder text, not a separate `<label>`), kept here only because
  /// it's a real field of the source config.
  final String inputLabel;

  /// `config['input_placeholder']` — the scenario `<input>`'s placeholder.
  final String inputPlaceholder;

  /// `config['button_label']` — not actually rendered in `roleplay.html`
  /// either (the button's real text is the hardcoded "Create Session",
  /// confirmed by reading the template directly); kept for fidelity to the
  /// source config, not used by `RoleplayPracticeScreen`'s CTA label.
  final String buttonLabel;

  /// `config['default_prompt']` — used server-side
  /// (`roleplay_practice`/`fallback_topic_practice`) whenever the client
  /// sends an empty `prompt`; not required client-side since the server
  /// applies this fallback itself, kept here for completeness.
  final String defaultPrompt;

  /// `config['content_heading_label']`.
  final String contentHeadingLabel;

  /// `config['follow_ups_label']`.
  final String followUpsLabel;

  /// `config['coach_tip_label']`.
  final String coachTipLabel;

  /// `config['examples']` — the "Try:" chip suggestions
  /// (`roleplay.html:364-371`).
  final List<String> examples;
}
