import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/services/audio_recorder_service.dart';

/// Wraps `package:record`'s [AudioRecorder] — the web equivalent is
/// `MediaRecorder` (`static/activities/js/speaking.js:434-486`, preferring
/// `audio/webm;codecs=opus`). Mobile has no equivalent WebM/Opus recorder
/// in a small, well-maintained package, so this uses the package's default
/// encoder (AAC-LC, `.m4a`) unless a caller asks for something else via
/// [encoder]/[fileExtension] — see `ariaAudioRecorderServiceProvider` for a
/// caller that does: **confirmed live against production**
/// (`POST /api/voice/transcribe/`) that the real Sarvam STT call this
/// server makes (`transcribe_with_sarvam`, `riya_bot/agents/utils.py:261`)
/// consistently rejects this plugin's `.m4a`/AAC-LC output with
/// `{success: false, error: "...temporarily unavailable for this
/// language."}` across both retries and languages, while the exact same
/// endpoint/session transcribes a `.wav` file correctly — so it *is*
/// format-specific server-side, contrary to what this comment used to
/// claim. `ai_speaking`'s own upload endpoint (`ai_speaking_remote_datasource.dart`,
/// a different, multipart-based endpoint) was not part of this finding and
/// is left on the previous default on purpose.
class AudioRecorderServiceImpl implements AudioRecorderService {
  AudioRecorderServiceImpl([AudioRecorder? recorder, this.encoder = AudioEncoder.aacLc, this.fileExtension = 'm4a'])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final AudioEncoder encoder;
  final String fileExtension;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/speaking_${DateTime.now().microsecondsSinceEpoch}.$fileExtension';
    await _recorder.start(RecordConfig(encoder: encoder), path: path);
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();
}
