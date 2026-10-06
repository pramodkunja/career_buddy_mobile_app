import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../providers/grammar_providers.dart';

/// The "Video Lesson" media card's expanded viewer
/// (`templates/subject/detail.html`'s `openMedia('video')` branch, lines
/// 693-715 — the local-video path, since every topic has a real
/// `protected_media/subjectvideos/<slug>.mp4`, confirmed on disk). The real
/// page uses a native `<video controls autoplay>` element; this reproduces
/// autoplay-on-open plus a minimal tap-to-toggle/scrub control set with
/// `video_player`, which has no built-in chrome of its own.
class GrammarVideoPlayerSheet extends ConsumerStatefulWidget {
  const GrammarVideoPlayerSheet({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<GrammarVideoPlayerSheet> createState() => _GrammarVideoPlayerSheetState();
}

class _GrammarVideoPlayerSheetState extends ConsumerState<GrammarVideoPlayerSheet> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = await ref.read(grammarMediaDataSourceProvider).fetchVideoToTempFile(widget.slug);
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title: 'Video Lesson', onClose: () => Navigator.of(context).pop()),
          SizedBox(height: 420, child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('Could not load the video.', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: GestureDetector(
          onTap: _togglePlayPause,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                if (!controller.value.isPlaying)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(controller, allowScrubbing: true),
                ),
              ],
            ),
          ),
        ),
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
