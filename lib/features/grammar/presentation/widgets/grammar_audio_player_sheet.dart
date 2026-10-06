import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/grammar_tts_service.dart';
import '../providers/grammar_providers.dart';

enum _AudioPlaybackState { playing, paused, idle }

/// The "Audio Recap" media card's expanded viewer
/// (`templates/subject/detail.html`'s `openMedia('audio', ...)` branch,
/// lines 786-826 — auto-plays `topic.audio_text` and shows a headphones
/// icon, the spoken text, and exactly two controls: "Restart" (replay icon)
/// and a Play/Pause/Resume toggle, `updateAudioControls()` lines 865-884).
/// Uses [GrammarTtsService] for the always-available
/// `speechSynthesis`-equivalent playback path — see that interface's doc
/// comment for why the neural-TTS-server preference in front of it isn't
/// reproduced.
class GrammarAudioPlayerSheet extends ConsumerStatefulWidget {
  const GrammarAudioPlayerSheet({required this.audioText, super.key});

  final String audioText;

  @override
  ConsumerState<GrammarAudioPlayerSheet> createState() => _GrammarAudioPlayerSheetState();
}

class _GrammarAudioPlayerSheetState extends ConsumerState<GrammarAudioPlayerSheet> {
  _AudioPlaybackState _state = _AudioPlaybackState.idle;
  late final GrammarTtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(grammarTtsServiceProvider);
    _tts.setOnComplete(() {
      if (!mounted) return;
      setState(() => _state = _AudioPlaybackState.idle);
    });
    _play();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _play() async {
    setState(() => _state = _AudioPlaybackState.playing);
    await _tts.speak(widget.audioText);
  }

  Future<void> _togglePlayPause() async {
    if (_state == _AudioPlaybackState.playing) {
      await _tts.stop();
      setState(() => _state = _AudioPlaybackState.paused);
    } else {
      await _play();
    }
  }

  Future<void> _restart() => _play();

  String get _playPauseLabel {
    switch (_state) {
      case _AudioPlaybackState.playing:
        return 'Pause';
      case _AudioPlaybackState.paused:
        return 'Resume';
      case _AudioPlaybackState.idle:
        return 'Play';
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _state == _AudioPlaybackState.playing;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title: 'Audio Recap', onClose: () => Navigator.of(context).pop()),
          Container(
            width: double.infinity,
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0EA5E9)),
                  child: const Icon(Icons.headphones, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.audioText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 18, height: 1.5),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _restart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE2E8F0),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      icon: const Icon(Icons.replay),
                      label: const Text('Restart'),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: _togglePlayPause,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      label: Text(_playPauseLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reproduces `#media-player-container`'s header bar (`detail.html:547-554`)
/// — a dark bar with the player title and a circular close button that
/// calls `closeMedia()`.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
