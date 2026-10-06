import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `.score-ring-wrap`/`#score-ring`/`.score-center`
/// (`resume_match_result.html:184-198,490-497`) — a 160×160 circular SVG
/// gauge, `r=65`, `stroke-width=10`, track `#e2e8f0`, progress `#0ea5e9`,
/// animated from 0 to the real percentage over ~1.2s (the web does this
/// after a 300ms `setTimeout`; reproduced here as one continuous
/// `TweenAnimationBuilder`, close enough for a value that never changes
/// again once shown). No color-coding by score range exists on the real
/// page (confirmed by reading the template — the stroke color is a fixed
/// `#0ea5e9` regardless of the percentage), so none is invented here.
class ResumeScoreRing extends StatelessWidget {
  const ResumeScoreRing({required this.percentage, required this.label, super.key});

  final int percentage;

  /// "ATS Score" or "Match" (`resume_match_result.html:196`).
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percentage.toDouble().clamp(0, 100)),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return CustomPaint(
            painter: _RingPainter(value / 100),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.round()}%',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    final track = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, track);

    final ring = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    // `transform: rotate(-90deg)` (`resume_match_result.html:16`) — the arc
    // starts at 12 o'clock, not 3 o'clock.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}
