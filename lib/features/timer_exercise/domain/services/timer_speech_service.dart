/// Invoked with each partial ("interim") or final speech-recognition
/// update. Unlike the web's own `SpeechRecognition.onresult` (which fires
/// once per newly recognized chunk, requiring the caller to concatenate —
/// `taskTranscripts[taskIdx] += event.results[i][0].transcript`,
/// `static/js/exercises.js:1148-1150`), `package:speech_to_text` reports
/// the **entire phrase recognized so far in the current [listen] session**
/// on every callback (confirmed against the plugin's own README example,
/// which simply *replaces* its displayed text with each callback rather
/// than appending it) — so `recognizedWords` here is already the
/// cumulative transcript for the task currently being listened to; the
/// caller should replace, not append. `isFinal` is true only once the
/// platform has finished recognizing (a pause in speech, or [stop] being
/// called).
typedef TimerSpeechResultCallback = void Function(String recognizedWords, bool isFinal);

/// A thin, testable seam over the platform's on-device speech-to-text
/// capability (`package:speech_to_text`'s `SpeechToText` in production —
/// see `TimerSpeechServiceImpl`) — the genuine Flutter/native equivalent of
/// the web's own browser `SpeechRecognition` API used by `initTimer()`
/// (`static/js/exercises.js:1141-1163`: `continuous = true`,
/// `interimResults = true`). Same "define an interface for a platform
/// capability, inject it" pattern already used for `AudioRecorderService`
/// (`ai_speaking`) and `GrammarTtsService` (`grammar`). Lets
/// `TimerExerciseController` be tested without a real microphone/plugin,
/// and — critically — lets a genuine initialization/permission failure
/// surface as a real, honest error state instead of ever being silently
/// swapped for fake transcript text.
abstract class TimerSpeechService {
  /// Requests (if not already granted) microphone + speech-recognition
  /// permission and prepares the platform recognizer — mirrors the web's
  /// own implicit `getUserMedia`-style permission prompt the first time
  /// `recognition.start()` is called. Returns `false` on any genuine
  /// failure (unsupported platform, permission denied) — callers must
  /// surface this honestly, never substitute placeholder text.
  Future<bool> initialize();

  /// Starts listening, invoking [onResult] with each partial and final
  /// transcript update. Throws if [initialize] was never confirmed true.
  Future<void> listen({required TimerSpeechResultCallback onResult});

  /// Stops listening (keeping whatever was already recognized) — mirrors
  /// the web's `recognition.stop()` inside `finishTask()`.
  Future<void> stop();

  /// Stops and discards the current listening session entirely — used on
  /// controller disposal so a stray recognizer session doesn't keep the
  /// microphone open after the user leaves the screen.
  Future<void> cancel();
}
