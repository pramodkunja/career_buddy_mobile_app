import 'package:flutter/material.dart';

import 'mock_exam_colors.dart';

/// Mirrors `.exam-timer`'s exact styling (`005 oop-mastery.html:2427`):
/// a translucent white pill with a gold-tinted border by default,
/// switching to a solid, pulsing red once `remaining <= 300` seconds (the
/// web's exact threshold) — `.exam-timer.warn{background:#e53e3e}`.
class MockTestTimerBadge extends StatelessWidget {
  const MockTestTimerBadge({required this.remainingSeconds, super.key});

  final int remainingSeconds;

  static const int _warnThresholdSeconds = 300;

  @override
  Widget build(BuildContext context) {
    final clamped = remainingSeconds < 0 ? 0 : remainingSeconds;
    final minutes = (clamped ~/ 60).toString().padLeft(2, '0');
    final seconds = (clamped % 60).toString().padLeft(2, '0');
    final isWarning = clamped <= _warnThresholdSeconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning ? MockExamColors.danger : Colors.white.withValues(alpha: 0.12),
        border: isWarning ? null : Border.all(color: MockExamColors.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$minutes:$seconds',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
