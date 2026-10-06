import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/services/audio_recorder_service.dart';

/// Wraps `package:record`'s [AudioRecorder] — the web equivalent is
/// `MediaRecorder` (`static/activities/js/speaking.js:434-486`, preferring
/// `audio/webm;codecs=opus`). Mobile has no equivalent WebM/Opus recorder
/// in a small, well-maintained package, so this uses the package's default
/// encoder (AAC-LC, `.m4a`) instead — a standard, widely-supported mobile
/// audio format the server's Sarvam transcription call accepts the same as
/// any other uploaded audio file (it is not format-specific server-side).
class AudioRecorderServiceImpl implements AudioRecorderService {
  AudioRecorderServiceImpl([AudioRecorder? recorder]) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/speaking_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
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
