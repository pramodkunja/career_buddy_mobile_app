import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/grammar_slide_deck.dart';
import '../providers/grammar_providers.dart';

/// The "Visual Guide" media card's expanded viewer
/// (`templates/subject/detail.html`'s `openMedia('image')` branch,
/// lines 735-785 — `.big-slideshow` markup with prev/next chevrons and dot
/// indicators). Fetches the topic's real presentation-slide PNGs
/// (`01.png`..`NN.png` under `protected_media/subjectslides/<slug>/`,
/// counted by [kGrammarSlideDeckCounts]) through the app's authenticated
/// [GrammarMediaDataSource], since `subject_slide_image` is
/// `@login_required`. The real page's CSS opacity crossfade is
/// approximated here with an [AnimatedSwitcher].
class GrammarImageCarouselSheet extends ConsumerStatefulWidget {
  const GrammarImageCarouselSheet({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<GrammarImageCarouselSheet> createState() => _GrammarImageCarouselSheetState();
}

class _GrammarImageCarouselSheetState extends ConsumerState<GrammarImageCarouselSheet> {
  List<Uint8List>? _images;
  Object? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final count = kGrammarSlideDeckCounts[widget.slug] ?? 0;
    final dataSource = ref.read(grammarMediaDataSourceProvider);
    try {
      final images = <Uint8List>[];
      for (var i = 1; i <= count; i++) {
        final fileName = '${i.toString().padLeft(2, '0')}.png';
        images.add(await dataSource.fetchSlideImage(widget.slug, fileName));
      }
      if (!mounted) return;
      setState(() => _images = images);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _show(int newIndex) {
    final images = _images;
    if (images == null || images.isEmpty) return;
    setState(() => _index = (newIndex + images.length) % images.length);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title: 'Presentation Slides', onClose: () => Navigator.of(context).pop()),
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
          child: Text('Could not load the slides.', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final images = _images;
    if (images == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (images.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('No slides available for this topic.', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Padding(
              key: ValueKey<int>(_index),
              padding: const EdgeInsets.all(10),
              child: Image.memory(images[_index], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              onPressed: () => _show(_index - 1),
            ),
          ),
          Positioned(
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
              onPressed: () => _show(_index + 1),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < images.length; i++)
                    GestureDetector(
                      onTap: () => _show(i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
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
