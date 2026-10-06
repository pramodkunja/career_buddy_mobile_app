import 'aria_chat_reply.dart';

/// One parsed SSE event from `ApiEndpoints.riyaChatStream` — see that
/// constant's doc comment for the full, source-verified event-shape
/// contract (`{"t": ...}` / `{"reply": ...}` / `{"done": true, ...}` /
/// `data: [DONE]`).
sealed class AriaStreamEvent {
  const AriaStreamEvent();
}

/// `{"t": "<token>"}` — one streamed token to append to the in-progress
/// reply. [raw] is the token exactly as received, **not** yet stripped of
/// any `<LANG:code>` directive — stripping/interception happens once on
/// the accumulated text, at the controller layer, not per-token here.
class AriaStreamToken extends AriaStreamEvent {
  const AriaStreamToken(this.raw);

  final String raw;
}

/// Either complete-event shape (`{"reply": ...}` fast-path, or
/// `{"done": true, "reply": ...}` after the AI path's own tokens) —
/// collapsed into one type here since both carry exactly the same fields
/// and this app's rendering doesn't need to distinguish them.
class AriaStreamComplete extends AriaStreamEvent {
  const AriaStreamComplete(this.reply);

  final AriaChatReply reply;
}
