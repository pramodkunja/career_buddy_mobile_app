/// On-device speech-to-text for the user's own GD turn — the mobile
/// equivalent of the real web's browser `SpeechRecognition` capture
/// (`GD_app/static/GD_app/js/gd.js`'s `startSpeechRecognition`/
/// `finishSpeaking`, read in full): continuous listening with live interim
/// text, ended by an explicit "done speaking" action (not silence
/// detection), whose final recognized text is what actually gets sent as
/// `action: 'user_message'`. [GdSpeechServiceImpl] wraps `package:
/// speech_to_text`; this interface is the seam `GdSessionController`'s own
/// tests fake against.
abstract interface class GdSpeechService {
  /// Must succeed before [startListening] can do anything. Returns `false`
  /// on a genuine failure (no permission, no recognizer available on this
  /// device) — callers must surface a real error state on `false`, never
  /// fabricate a transcript.
  Future<bool> initialize();

  bool get isListening;

  /// Starts a listening session. [onPartialResult] fires repeatedly with
  /// the best-guess-so-far text (for a live "Listening... `<text>`" bubble,
  /// mirroring `liveUserBubble`'s live updates on the web); [onFinalResult]
  /// fires exactly once, either because [stopListening] was called or
  /// because the platform recognizer ended the session on its own (mirrors
  /// `recognition.onerror`/`recognition.onend` both funnelling into
  /// `finishSpeaking` on the web) — a caller must not assume
  /// [stopListening] is the only thing that ever produces a final result.
  Future<void> startListening({
    required void Function(String partialText) onPartialResult,
    required void Function(String finalText) onFinalResult,
  });

  /// Requests the recognizer to stop — [onFinalResult] (registered in
  /// [startListening]) still fires asynchronously with the result, exactly
  /// like `recognition.stop()` triggering `onend` on the web; this method
  /// itself does not return the text.
  Future<void> stopListening();

  /// Discards the current listening session without triggering
  /// [onFinalResult] — used on teardown (e.g. the discussion screen being
  /// disposed mid-turn), not part of the normal turn-taking flow.
  Future<void> cancel();
}
