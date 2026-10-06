import 'package:flutter/material.dart';

import '../../../presentation/widgets/mock_exam_colors.dart';

/// Mirrors `updateTimerDisplay()` (`amcat_mock_test.html:655-661`): `MM:SS`,
/// switching to a warning color at `remaining <= 30` seconds — a
/// deliberately different, confirmed threshold from OOP/Subject Quiz's
/// `<= 300`, so this is its own small widget rather than reusing
/// `MockTestTimerBadge`. Colors match the same effective navy/gold `.timer`
/// styling both engines share (`amcat_mock_test.html`'s `#amcat-oop-skin`
/// override).
class AmcatTimerBadge extends StatelessWidget {
  const AmcatTimerBadge({required this.remainingSeconds, super.key});

  final int remainingSeconds;

  static const int _warnThresholdSeconds = 30;

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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
