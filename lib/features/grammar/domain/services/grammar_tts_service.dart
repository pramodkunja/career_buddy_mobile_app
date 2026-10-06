/// On-device text-to-speech for the "Audio Recap" media card
/// (`templates/subject/detail.html:986-995`) — the web's own instant/
/// fallback playback path is the browser's Web Speech API
/// (`speechSynthesis`/`SpeechSynthesisUtterance`), ahead of a neural-TTS
/// server call it prefers only once that finishes prefetching
/// (`/api/voice/tts/`, a separate app's endpoint). This app reproduces
/// only the always-available `speechSynthesis`-equivalent path — the same
/// "define an interface for a platform capability, inject it" pattern
/// already used by `ListeningTtsService`/`AudioRecorderService`.
abstract class GrammarTtsService {
  Future<void> speak(String text);
  Future<void> stop();
  void setOnComplete(void Function() callback);
}
