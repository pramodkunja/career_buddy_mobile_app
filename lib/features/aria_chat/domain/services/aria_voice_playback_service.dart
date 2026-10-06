/// A thin, testable seam over on-device audio playback for ARIA's spoken
/// replies — the same "define an interface for a platform capability,
/// inject it" pattern already used by `AudioRecorderService`/
/// `GrammarTtsService`. Mirrors the real web's own `speakText()` decision
/// tree (`static/js/BOTscript.js`): play real server-generated audio when
/// available, otherwise fall back to the device's own voice synthesis —
/// the mobile equivalent of the browser's `speechSynthesis` fallback.
abstract class AriaVoicePlaybackService {
  /// Decodes [base64Audio] (a WAV file, no `data:` URI prefix — see
  /// `ApiEndpoints.riyaTts`'s doc comment) and plays it. Returns `false`
  /// (without throwing) if playback could not start at all, so the caller
  /// can fall back to [speakDeviceVoice] — same as the real web's own
  /// `.catch(() => speakWithBrowser(text))`.
  Future<bool> playAudioBytes(String base64Audio);

  /// On-device voice synthesis — the mobile equivalent of the browser's
  /// `speechSynthesis` fallback (`GrammarTtsService`'s same reasoning).
  Future<void> speakDeviceVoice(String text);

  /// Stops whichever of the two playback paths is currently active.
  /// Called before starting a new utterance, matching the real web's own
  /// "Buddy must never hear its own response" half-duplex rule and
  /// preventing overlapping playback.
  Future<void> stop();

  /// Fires once when the current utterance (either path) finishes on its
  /// own — not called by [stop].
  void setOnComplete(void Function() callback);
}
