/// A thin, testable seam over on-device text-to-speech — the web's
/// equivalent is the browser's Web Speech API
/// (`window.speechSynthesis`/`SpeechSynthesisUtterance`,
/// `static/activities/js/listening.js:428-490`). There is no server-
/// provided audio file or streamed audio anywhere in this feature — the
/// "story" is narrated entirely client-side from fixed text, on the web
/// and here alike. Same "define an interface for a platform capability,
/// inject it" pattern as `AudioRecorderService`.
abstract class ListeningTtsService {
  /// Starts speaking [text] at the given [rate] (matches the web's
  /// `speedSelect`: 0.8/1.0/1.2). Fires [onStart] once playback begins,
  /// [onComplete] when it finishes naturally, [onError] if the platform
  /// TTS engine fails.
  Future<void> speak(String text, {required double rate});

  /// Pauses in-progress speech. Platform pause/resume support varies
  /// (reliable on iOS; not guaranteed on every Android API level) — see
  /// `docs/W016_AI_LISTENING.md` for the documented, honest fallback
  /// behavior when true mid-utterance resume isn't available.
  Future<void> pause();

  Future<void> stop();

  void setOnStart(void Function() callback);
  void setOnComplete(void Function() callback);
  void setOnError(void Function(String message) callback);
}
