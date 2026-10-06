/// Speaks an agent's turn aloud — the mobile equivalent of the real web's
/// `speechSynthesis.speak(...)` (`GD_app/static/GD_app/js/gd.js`, read in
/// full: every non-user `type: 'message'` is queued through `speakText`).
/// One small `flutter_tts`-wrapping service scoped to this feature, same
/// convention as `GrammarTtsService` (`lib/features/grammar/domain/services/
/// grammar_tts_service.dart`) rather than reusing that feature-scoped class
/// directly.
abstract interface class GdTtsService {
  Future<void> speak(String text);
  Future<void> stop();

  /// Fires once the current utterance finishes — `GdSessionController` uses
  /// this only to know when it's safe to consider the agent "done talking"
  /// for UI purposes; it does not gate the turn-taking protocol itself
  /// (the server, not this client, decides when the next agent speaks).
  void setOnComplete(void Function() callback);
}
