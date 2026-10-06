/// A thin, testable seam over the platform's microphone/recording
/// capability (`package:record`'s `AudioRecorder` in production — see
/// `AudioRecorderServiceImpl`), the same "define an interface for a
/// platform capability, inject it" pattern already used for `ApiClient`
/// itself. Lets `AiSpeakingController` be tested without a real
/// microphone/plugin.
abstract class AudioRecorderService {
  /// Requests (if not already granted) and reports microphone permission —
  /// mirrors the web's own `getUserMedia({audio:true})` permission prompt
  /// (`static/activities/js/speaking.js:444`).
  Future<bool> hasPermission();

  /// Starts recording to a fresh temporary file. Throws if [hasPermission]
  /// was never confirmed true.
  Future<void> start();

  Future<void> pause();
  Future<void> resume();

  /// Stops recording and returns the recorded file's path, or `null` if
  /// nothing was recorded.
  Future<String?> stop();

  /// Stops and discards the current recording without keeping the file —
  /// used when a new recording starts before a previous temp file was
  /// submitted, so unsent recordings don't accumulate on device storage.
  Future<void> cancel();
}
