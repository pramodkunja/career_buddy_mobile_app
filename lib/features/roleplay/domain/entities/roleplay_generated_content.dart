/// The AI-generated (or offline-fallback) session content returned by
/// `POST /roleplay/practice/` (`roleplay_practice`,
/// `activities/views.py:2028-2080`) as `result`. Both code paths that can
/// produce it — `topic_practice_with_sarvam_chat` (its system prompt
/// explicitly requests these 5 keys) and `fallback_topic_practice`
/// (`riya_bot/agents/utils.py:79-127`, used whenever `SARVAM_API_KEY` is
/// unset or the AI call fails/returns nothing) — always populate exactly
/// these 5 fields; `fallback_topic_practice`'s storytelling branch adds an
/// extra `intro` key no other branch has, so that one is intentionally not
/// modeled here.
class RoleplayGeneratedContent {
  const RoleplayGeneratedContent({
    required this.usedPrompt,
    required this.title,
    required this.contentHeading,
    required this.content,
    required this.followUps,
    required this.coachTip,
  });

  /// The response's top-level `used_prompt` (a sibling of `result`, not
  /// part of it) — the prompt actually used to generate this content: the
  /// caller's own trimmed `prompt`, or `topic['default_prompt']` when that
  /// was empty.
  final String usedPrompt;

  /// `result.title`.
  final String title;

  /// `result.content_heading` — mirrors `topic.content_heading_label`.
  final String contentHeading;

  /// `result.content` — the short story / situation / roleplay scene text
  /// shown in `#story-content` before questions begin.
  final String content;

  /// `result.follow_ups` — the AI path always asks for exactly 5; the
  /// offline fallback always returns exactly 3. Either way, this is
  /// whatever the server actually sent, not padded or truncated client-side.
  final List<String> followUps;

  /// `result.coach_tip`.
  final String coachTip;
}
