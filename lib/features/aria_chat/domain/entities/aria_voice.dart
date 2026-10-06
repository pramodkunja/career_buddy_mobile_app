/// `riya_bot.views.riya_voice_transcribe` — see
/// `ApiEndpoints.riyaVoiceTranscribe`'s doc comment for the full,
/// source-verified contract (including the real `raw.data.text` vs.
/// `raw.text` bug in the web's own JS consumption of this same response,
/// which this entity's shape deliberately does **not** reproduce).
class AriaVoiceTranscription {
  const AriaVoiceTranscription({required this.text, required this.source});

  final String text;

  /// `"sarvam" | "browser_fallback"` — informational only. This app never
  /// sends a `client_transcript`, so `"browser_fallback"` is unreachable in
  /// practice (see the endpoint's doc comment).
  final String source;
}
