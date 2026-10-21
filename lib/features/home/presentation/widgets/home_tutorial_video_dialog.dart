import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/home_tutorial_video_url.dart';

/// A real tutorial video, played from the genuine static file the landing
/// page itself serves (`homeTutorialVideoUrl`) — never a placeholder, and
/// never claimed playable unless [videoId] is one of the 5 confirmed-real
/// ids. Opened as a full-screen dialog rather than inline, since a 16:9
/// network video at full card width needs more vertical room than a
/// scrolling card can spare.
class HomeTutorialVideoDialog extends StatefulWidget {
  const HomeTutorialVideoDialog({required this.videoId, required this.title, super.key});

  final String videoId;
  final String title;

  static Future<void> show(BuildContext context, {required String videoId, required String title}) {
    return showDialog<void>(
      context: context,
      builder: (context) => HomeTutorialVideoDialog(videoId: videoId, title: title),
    );
  }

  @override
  State<HomeTutorialVideoDialog> createState() => _HomeTutorialVideoDialogState();
}

class _HomeTutorialVideoDialogState extends State<HomeTutorialVideoDialog> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(homeTutorialVideoUrl(widget.videoId)));
    try {
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller != null)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: GestureDetector(
                onTap: () => setState(() {
                  controller.value.isPlaying ? controller.pause() : controller.play();
                }),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying)
                      const Icon(Icons.play_circle_fill, color: Colors.white70, size: 56),
                  ],
                ),
              ),
            )
          else if (_error != null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'This tutorial video could not be played right now.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (controller != null) VideoProgressIndicator(controller, allowScrubbing: true),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textOnDark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
