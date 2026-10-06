import 'aria_chat_message.dart';

/// The parsed, successful shape of an `/api/riya/chat/` response. Verified
/// directly against `riya_bot/views.py:riya_chat`: the response is always a
/// flat JSON object with `reply`/`message` (identical text, `message` is
/// just an alias the view adds for a separate voice contract this app
/// doesn't use), `actions`, `source`, `success`, `speak`, and `audio` —
/// `speak`/`audio` are TTS-related and deliberately ignored here (no TTS
/// playback in scope for this task).
class AriaChatReply {
  const AriaChatReply({required this.reply, required this.actions, this.source});

  final String reply;
  final List<AriaChatAction> actions;

  /// `"ai" | "intent" | "skillup" | "fallback"` — informational only, not
  /// currently used to change rendering.
  final String? source;
}
